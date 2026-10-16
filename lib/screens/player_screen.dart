import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../config.dart';
import '../models/anime_item.dart';
import '../services/resolver_service.dart';
import '../services/watch_history.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/embed_ad_guard.dart';

/// Immersive full-screen player. Two sources: AniWatch's ZokoAnime server plays
/// natively through media_kit (its VTT subtitle tracks are selectable), and
/// aniwaves DoodStream is resolved to a direct MP4 on the phone and also played
/// natively, with its embed page opened in the WebView as a last resort. When
/// ZokoAnime can't serve an episode, the player falls through to DoodStream
/// rather than a bare watch page.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.item,
    required this.ep,
    this.dub = false,
    this.sv,
    this.embed = false,
    this.sourceKind,
    this.initialPosition,
    this.episodes,
  });

  final AnimeItem item;
  final int ep;
  final bool dub;

  /// Optional pinned aniwaves server id. When set, resolution is forced to
  /// that server instead of the worker's default priority.
  final int? sv;

  /// When true the player opens directly in the DoodStream embed instead of
  /// trying native playback first.
  final bool embed;

  /// Which catalog resolves the episode: 'aniwatch' (default, ZokoAnime native
  /// HLS with subtitles) or 'aniwaves' (DoodStream, native MP4 first). Carried
  /// across prev/next so the source choice survives episode navigation.
  final String? sourceKind;

  /// Resume position passed from the "continue watching" row.
  final Duration? initialPosition;

  /// Full episode list for the title, used to enable prev/next navigation.
  /// When omitted (e.g. player opened from continue watching) the prev/next
  /// buttons are hidden.
  final List<Episode>? episodes;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final ResolverService _resolver = ResolverService();

  _PlayerMode _mode = _PlayerMode.loading;
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<String>? _errorSub;

  // Native readiness gate: the spinner stays until the stream reports a real
  // duration and actually starts playing. `Media.open` resolving only means the
  // demuxer attached, not that a frame is on screen, so switching to the video
  // surface on open alone leaves a black screen under a vanished spinner.
  StreamSubscription<Duration>? _readyDurationSub;
  StreamSubscription<bool>? _readyPlayingSub;
  bool _videoReady = false;
  WebViewController? _web;
  String _fallbackNotice = '';
  bool _nativeFailed = false;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  double? _dragSeconds;
  int _nativeAttempts = 0;

  /// Which catalog the current playback came from. Drives the source sheet and
  /// keeps the choice when navigating between episodes. AniWatch's ZokoAnime
  /// server is the primary/default source (native HLS with subtitles).
  String _sourceKind = 'aniwatch';

  // Native watchdog: retries when the stream stalls instead of leaving the
  // clock frozen at 0:00 or mid-episode. Guarded by live playing state, so a
  // user-initiated pause never trips it.
  Timer? _stallTimer;
  Duration _lastSeenPosition = Duration.zero;
  DateTime _lastMovedAt = DateTime.now();
  int _stallTicks = 0;
  bool _seenFirstProgress = false;
  String? _fatalMessage;

  // The embed page the current resolution supplied, kept so failures fall back
  // onto the real page instead of the generic watch URL.
  String? _lastEmbedUrl;

  // Subtitle tracks shipped by the current source (aniwatch's ZokoAnime server
  // publishes VTT tracks). The active URL drives the CC sheet's check mark.
  List<ResolvedSubtitle> _subtitles = const [];
  String? _activeSubtitleUrl;

  /// Whether playback is pinned to the DoodStream embed. Set when the player
  /// opens in embed mode or falls back to it, so switching episodes stays
  /// there instead of jumping back to native playback.
  bool _embed = false;

  /// The episode currently on screen. Starts at [PlayerScreen.ep] and changes
  /// in place when the user steps to a neighbour, so the route (and its
  /// transition) never changes, only the video does.
  late int _ep;

  // Settings snapshot taken when the player opens.
  bool _hardwareDecode = false;
  double _defaultRate = 1.0;
  bool _keepAwake = true;
  double _subtitleSize = 22;
  Color _subtitleColor = Colors.white;
  double _subtitleBackground = 0.5;

  // Resume / progress tracking.
  Duration? _resumePosition;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completedSub;
  Duration _lastPosition = Duration.zero;
  DateTime _lastSaveAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final app = context.read<AppState>();
    _hardwareDecode = app.hardwareDecode;
    _defaultRate = app.defaultSpeed;
    _keepAwake = app.keepAwake;
    _subtitleSize = app.subtitleSize;
    _subtitleColor = app.subtitleColor.color;
    _subtitleBackground = app.subtitleBackground;
    _sourceKind = widget.sourceKind ?? 'aniwatch';
    _ep = widget.ep;
    _embed = widget.embed;
    unawaited(_bootstrap());
  }

  /// Restores the saved position first, then starts playback. Loading the
  /// resume point before resolving the stream keeps a cold open from racing
  /// ahead of the history read and starting at 0:00.
  Future<void> _bootstrap() async {
    await _loadResume();
    if (!mounted) return;
    await _start();
  }

  Future<void> _loadResume() async {
    await WatchHistory.instance.ensureLoaded();
    if (!mounted) return;
    _resumePosition = _resumeFor(_ep);
  }

  /// Resume point for [ep]: the position passed into the player for the episode
  /// it opened on, otherwise that episode's own saved position.
  Duration _resumeFor(int ep) {
    if (ep == widget.ep && widget.initialPosition != null) {
      return widget.initialPosition!;
    }
    return WatchHistory.instance.resumeFor(widget.item, ep);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    unawaited(WakelockPlus.disable());
    unawaited(_saveFinalProgress());
    unawaited(_positionSub?.cancel());
    unawaited(_completedSub?.cancel());
    _positionSub = null;
    _completedSub = null;
    _hideTimer?.cancel();
    _stopStallWatchdog();
    unawaited(_errorSub?.cancel());
    _errorSub = null;
    unawaited(_readyDurationSub?.cancel());
    unawaited(_readyPlayingSub?.cancel());
    _readyDurationSub = null;
    _readyPlayingSub = null;
    EmbedAdGuard.detach();
    final player = _player;
    _player = null;
    _videoController = null;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }

  Future<void> _saveFinalProgress() async {
    if (_lastPosition > const Duration(seconds: 5)) {
      await _saveProgress(_lastPosition);
      _lastPosition = Duration.zero;
    }
  }

  Future<void> _saveProgress(Duration position) async {
    if (position < const Duration(seconds: 5)) return;
    await WatchHistory.instance.update(
      item: widget.item,
      ep: _ep,
      dub: widget.dub,
      position: position,
      duration: _player?.state.duration ?? Duration.zero,
    );
  }

  /// Position mpv opens at, handed to [Media.start] so playback begins there
  /// as part of the load. Opening at the resume point is what actually sticks:
  /// a runtime [Player.seek] issued right after open gets undone on some
  /// network streams (it lands for a second, then the demuxer restarts at
  /// 0:00), whereas mpv's `start` is applied before the first frame.
  Duration? get _startPosition {
    final resume = _resumePosition;
    if (resume == null || resume <= const Duration(seconds: 5)) return null;
    return resume;
  }

  /// Fallback for sources that ignore [Media.start]: once the stream reports a
  /// real duration and is playing, and after a short grace so an honored
  /// `start` has settled the position, seek only when playback is still at the
  /// top of the file.
  Future<void> _seekAfterOpen(Player player) async {
    final resume = _resumePosition;
    if (resume == null || resume <= const Duration(seconds: 5)) return;
    final ready = Completer<void>();
    void check() {
      if (ready.isCompleted) return;
      if (player.state.duration > Duration.zero && player.state.playing) {
        ready.complete();
      }
    }
    final durationSub = player.stream.duration.listen((_) => check());
    final playingSub = player.stream.playing.listen((_) => check());
    check();
    try {
      await Future.any<void>([
        ready.future,
        Future<void>.delayed(const Duration(seconds: 10)),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    } finally {
      await durationSub.cancel();
      await playingSub.cancel();
    }
    if (!mounted || !identical(_player, player)) return;
    if (player.state.position < const Duration(seconds: 8)) {
      await player.seek(resume);
    }
  }

  String _embedWrapUrl() =>
      aniwavesEmbedUrl(id: widget.item.id, slug: widget.item.slug, ep: _ep);

  Episode? get _prevEpisode => _neighborEpisode(-1);

  Episode? get _nextEpisode => _neighborEpisode(1);

  /// Picks the closest available episode from the current one in [dir]
  /// direction, preferring the current audio track and falling back to the
  /// other one when that number only exists with different audio.
  Episode? _neighborEpisode(int dir) {
    final episodes = widget.episodes;
    if (episodes == null || episodes.isEmpty) return null;
    final current = _ep;
    Episode? best;
    Episode? fallback;
    for (final e in episodes) {
      if (dir < 0 ? e.ep < current : e.ep > current) {
        final sameTrack = widget.dub ? e.dub : e.sub;
        if (sameTrack &&
            (best == null ||
                (dir < 0 ? e.ep > best.ep : e.ep < best.ep))) {
          best = e;
        }
        if (fallback == null ||
            (dir < 0 ? e.ep > fallback.ep : e.ep < fallback.ep)) {
          fallback = e;
        }
      }
    }
    return best ?? fallback;
  }

  /// Steps to the neighbouring episode in place: the same screen, source and
  /// audio track stay put, only the video reloads. A route push would slide in
  /// a new screen and feel like navigation instead of a channel change.
  Future<void> _switchEpisode(Episode target) async {
    if (target.ep == _ep) return;
    _hideTimer?.cancel();
    _stopStallWatchdog();
    _stopReadyWatch();
    await _saveProgress(_lastPosition);
    final broken = _player;
    final brokenSub = _errorSub;
    setState(() {
      _nativeFailed = false;
      _fallbackNotice = '';
      _player = null;
      _videoController = null;
      _videoReady = false;
      _web = null;
      _mode = _PlayerMode.loading;
      _subtitles = const [];
      _activeSubtitleUrl = null;
      _ep = target.ep;
    });
    _errorSub = null;
    _lastEmbedUrl = null;
    _nativeAttempts = 0;
    _lastSeenPosition = Duration.zero;
    _lastPosition = Duration.zero;
    unawaited(brokenSub?.cancel());
    await broken?.dispose();
    if (!mounted) return;
    _resumePosition = _resumeFor(_ep);
    await _start();
  }

  Widget _episodeNavButton(
    BuildContext context, {
    required VoidCallback onTap,
    required IconData icon,
    required String tooltip,
    required String label,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 34),
              const SizedBox(height: 2),
              Text(
                label,
                style: context.appTextTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Resolves the selected source. ZokoAnime plays natively through media_kit;
  /// DoodStream is resolved to a direct MP4 on the phone and also played
  /// natively, with its embed page as a last resort.
  Future<void> _start() async {
    if (_sourceKind == 'aniwatch') {
      await _startAniwatch();
      return;
    }
    await _startDood();
  }

  /// Resolves through aniwatch.lu instead of aniwaves.
  ///
  /// The worker maps the title onto the mirror's catalog and returns its native
  /// HLS (ZokoAnime / MegaPlay), already wrapped in the media proxy because the
  /// CDN gates on a mobile UA and a zokoanime referer. When the mirror has no
  /// entry for the title or the episode, playback falls through to the
  /// DoodStream source so the user is never stuck on a dead screen.
  Future<void> _startAniwatch() async {
    setState(() => _mode = _PlayerMode.loading);
    try {
      final source = await _resolver.resolveAniwatch(
        widget.item,
        _ep,
        dub: widget.dub,
      );
      if (!mounted) return;
      if (await _playNative(source)) return;
      await _startDood(
        notice:
            'ZokoAnime\'s stream couldn\'t be reached, so Mirai played the DoodStream source instead.',
      );
    } on ResolveFailure catch (error) {
      if (!mounted) return;
      await _startDood(
        notice:
            'ZokoAnime didn\'t have this episode (${error.message}), so Mirai played the DoodStream source instead.',
      );
    } catch (_) {
      if (!mounted) return;
      await _startDood(
        notice:
            'ZokoAnime couldn\'t be reached, so Mirai played the DoodStream source instead.',
      );
    }
  }

  /// Loads the embed player. [url] is the embed page supplied by the worker
  /// (echovideo / byse / dood wrapper) or the site watch page as a last resort.
  void _fallbackToEmbed({required String url, String? notice}) {
    if (!mounted) return;
    _stopStallWatchdog();
    final controller = _buildController(url);
    setState(() {
      _web = controller;
      _mode = _PlayerMode.embed;
      _embed = true;
      _nativeFailed = notice != null;
      _fallbackNotice = notice ?? '';
    });
    _scheduleHide();
  }

  /// Starts native playback; returns true when the media actually opened.
  /// [Media.open] can hang or take very long on flaky dood CDN connections, so
  /// it is capped with a 25s timeout after which the attempt is abandoned.
  Future<bool> _playNative(ResolvedSource source) async {
    if (_nativeAttempts >= 2) return false;
    _nativeAttempts += 1;
    final player = Player();
    final controller = VideoController(
      player,
      // Hardware decode can be enabled in Settings; off by default because
      // MediaCodec has been flaky for both H.264 and HEVC on some devices.
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: _hardwareDecode,
      ),
    );
    final errorSub = player.stream.error.listen((message) {
      if (!mounted || !identical(_player, player)) return;
      debugPrint('[player] native error: $message');
      unawaited(_recoverNative('runtime error'));
    });
    _errorSub = errorSub;
    setState(() {
      _mode = _PlayerMode.loading;
    });
    try {
      var opened = false;
      await Future.any<void>([
        player
            .open(
              Media(
                source.playUrl,
                httpHeaders: source.httpHeaders,
                start: _startPosition,
              ),
            )
            .then((_) => opened = true),
        Future<void>.delayed(const Duration(seconds: 25)),
      ]);
      if (!mounted || !opened) {
        unawaited(errorSub.cancel());
        unawaited(player.dispose());
        return false;
      }
      setState(() {
        _player = player;
        _videoController = controller;
        _videoReady = false;
        _mode = _PlayerMode.native;
      });
      _watchReady(player);
      _lastPosition = Duration.zero;
      _positionSub?.cancel();
      _positionSub = player.stream.position.listen(_onNativePosition);
      unawaited(_attachSubtitles(player, source));
      _completedSub?.cancel();
      _completedSub = player.stream.completed.listen((_) {
        unawaited(WatchHistory.instance.clearEntry(widget.item.id, _ep));
      });
      if (_resumePosition != null) unawaited(_seekAfterOpen(player));
      if (_defaultRate != 1.0) unawaited(player.setRate(_defaultRate));
      if (_keepAwake) unawaited(WakelockPlus.enable());
      _startStallWatchdog(player);
      _scheduleHide();
      return true;
    } catch (error) {
      debugPrint('[player] open failed: $error');
      unawaited(errorSub.cancel());
      unawaited(player.dispose());
      return false;
    }
  }

  /// Flips [_videoReady] once the stream reports a real duration and is actually
  /// playing, so the spinner covers the black surface until the first frame is
  /// up instead of vanishing the moment `Media.open` resolves.
  void _watchReady(Player player) {
    _stopReadyWatch();
    var duration = player.state.duration;
    var playing = player.state.playing;
    void evaluate() {
      if (!mounted || !identical(_player, player)) return;
      if (!_videoReady && duration > Duration.zero && playing) {
        setState(() {
          _videoReady = true;
          _controlsVisible = true;
        });
        _scheduleHide();
      }
    }
    _readyDurationSub = player.stream.duration.listen((value) {
      duration = value;
      evaluate();
    });
    _readyPlayingSub = player.stream.playing.listen((value) {
      playing = value;
      evaluate();
    });
    evaluate();
  }

  void _stopReadyWatch() {
    unawaited(_readyDurationSub?.cancel());
    unawaited(_readyPlayingSub?.cancel());
    _readyDurationSub = null;
    _readyPlayingSub = null;
  }

  /// Stores the source's subtitle tracks and auto-selects a sensible default.
  ///
  /// AniWatch's ZokoAnime server publishes VTT tracks; aniwaves hands back an
  /// MP4 with none, so this is a no-op there. The first English track wins,
  /// otherwise the first listed. Failures are swallowed: a missing or rejected
  /// track must never take playback down.
  Future<void> _attachSubtitles(Player player, ResolvedSource source) async {
    final tracks = source.subtitles ?? const <ResolvedSubtitle>[];
    if (!mounted) return;
    setState(() {
      _subtitles = tracks;
      _activeSubtitleUrl = null;
    });
    if (tracks.isEmpty) return;
    await _applySubtitle(player, _defaultSubtitle(tracks), force: true);
  }

  ResolvedSubtitle _defaultSubtitle(List<ResolvedSubtitle> tracks) {
    for (final track in tracks) {
      final label = track.label.toLowerCase();
      if (label.contains('english') || label == 'en') return track;
    }
    return tracks.first;
  }

  /// Applies [track] to the player and records it as active. [force] re-applies
  /// even when the track is already active (used for the initial auto-select).
  Future<void> _applySubtitle(
    Player player,
    ResolvedSubtitle track, {
    bool force = false,
  }) async {
    if (!force && _activeSubtitleUrl == track.url) return;
    try {
      await player.setSubtitleTrack(
        SubtitleTrack.uri(track.url, title: track.label),
      );
      if (mounted) setState(() => _activeSubtitleUrl = track.url);
    } catch (error) {
      debugPrint('[player] subtitle track failed: $error');
    }
  }

  Future<void> _clearSubtitle(Player player) async {
    try {
      await player.setSubtitleTrack(SubtitleTrack.no());
    } catch (error) {
      debugPrint('[player] subtitle off failed: $error');
    }
    if (mounted) setState(() => _activeSubtitleUrl = null);
  }

  /// Polls the player every 3s. Two failure modes are caught:
  ///
  /// 1. Hung load: [Media.open] returned ok but the stream never produces a
  ///    non-zero position or duration (the frozen 00:00 case). mpv can sit in
  ///    this state with `playing` false forever, so the old "skip when paused"
  ///    guard would have let it spin indefinitely.
  /// 2. Mid-playback stall: playing but no position tick for a long stretch.
  ///
  /// Watching the live `playing` state means a user-initiated pause never
  /// triggers a false recovery after playback has genuinely started.
  void _startStallWatchdog(Player player) {
    _stopStallWatchdog();
    _lastMovedAt = DateTime.now();
    _stallTicks = 0;
    _seenFirstProgress = false;
    _stallTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || !identical(_player, player)) {
        _stopStallWatchdog();
        return;
      }
      late final Duration pos;
      late final Duration dur;
      late final bool playing;
      try {
        pos = player.state.position;
        dur = player.state.duration;
        playing = player.state.playing;
        if (player.state.completed) return;
      } catch (_) {
        return;
      }
      if (!_seenFirstProgress) {
        // Open "succeeded" but nothing has actually played yet. Give it a
        // moment; if position/duration stay dead this is a hung load, so
        // recover instead of leaving a frozen 00:00 forever.
        if (pos > const Duration(milliseconds: 300) || dur > Duration.zero) {
          _seenFirstProgress = true;
          _touchWatchdog();
          return;
        }
        final idleFor = DateTime.now().difference(_lastMovedAt);
        if (idleFor < const Duration(seconds: 12)) return;
        _stallTicks += 1;
        if (_stallTicks >= 2) {
          debugPrint('[player] watchdog: load hung at 00:00');
          await _recoverNative('load hang at 00:00');
        }
        return;
      }
      if (!playing) return;
      final idleFor = DateTime.now().difference(_lastMovedAt);
      if (idleFor < const Duration(seconds: 18)) {
        _stallTicks = 0;
        return;
      }
      _stallTicks += 1;
      if (_stallTicks >= 2) {
        debugPrint('[player] stall watchdog fired, frozen at $_lastSeenPosition');
        await _recoverNative('stall at $_lastSeenPosition');
      }
    });
  }

  void _stopStallWatchdog() {
    _stallTimer?.cancel();
    _stallTimer = null;
  }

  /// Resets the stall timer after any user-driven control or position move.
  void _touchWatchdog() {
    _lastMovedAt = DateTime.now();
    _stallTicks = 0;
  }

  void _onNativePosition(Duration position) {
    _lastPosition = position;
    _lastSeenPosition = position;
    _touchWatchdog();
    final now = DateTime.now();
    if (now.difference(_lastSaveAt).inSeconds < 8) return;
    _lastSaveAt = now;
    unawaited(_saveProgress(position));
  }

  /// Tears down the failed native player after a runtime error or a confirmed
  /// stall, retries the same stream up to the attempt cap, then falls through
  /// to the embed player so the user isn't left staring at a frozen clock.
  Future<void> _recoverNative(String reason) async {
    debugPrint('[player] recover: $reason');
    _stopStallWatchdog();
    _stopReadyWatch();
    final broken = _player;
    final brokenSub = _errorSub;
    setState(() {
      _player = null;
      _videoController = null;
      _videoReady = false;
      _mode = _PlayerMode.loading;
    });
    _errorSub = null;
    unawaited(brokenSub?.cancel());
    await broken?.dispose();
    if (!mounted) return;
    if (_lastSeenPosition > const Duration(seconds: 8)) {
      _resumePosition = _lastSeenPosition;
    }
    // aniwatch HLS URLs are short-lived and token-bound, so replaying the same
    // stream would just fail again. Re-resolve instead to get fresh URLs.
    if (_sourceKind == 'aniwatch') {
      _nativeAttempts = 0;
      await _startAniwatch();
      return;
    }
    // A dood stream that stalled is dropped to the embed rather than retried,
    // because the client-side dood walk re-resolves the same wrapper and would
    // otherwise loop between a stall and another failing native attempt.
    _startEmbedFallback(
      'The stream kept dropping, so Mirai opened the embed player instead.',
      url: _lastEmbedUrl ?? _embedWrapUrl(),
    );
  }

  /// Opens the real embed player page. [url] is the embed page the worker
  /// supplied (echovideo / byse / dood wrapper); when it is absent the site
  /// watch page is the very last resort.
  void _startEmbedFallback(String? notice, {String? url}) {
    if (!mounted) return;
    _stopStallWatchdog();
    try {
      final target = url ?? _lastEmbedUrl ?? _embedWrapUrl();
      _fallbackToEmbed(url: target, notice: notice);
    } catch (error) {
      debugPrint('[player] embed fallback failed: $error');
      setState(() {
        _fatalMessage =
            'Neither the direct stream nor the embed player could load. '
            'Check your connection and retry.';
        _mode = _PlayerMode.error;
      });
    }
  }

  /// The source currently on screen, used to highlight the sheet item. Native
  /// playback follows the active source kind; the embed always belongs to the
  /// DoodStream source.
  String? _currentSourceName() {
    if (_mode == _PlayerMode.embed) return 'aniwaves';
    if (_mode == _PlayerMode.native) {
      return _sourceKind == 'aniwatch' ? 'aniwatch' : 'aniwaves';
    }
    return null;
  }

  /// Switches between the aniwatch source (ZokoAnime) and DoodStream.
  void _switchSource(String name) {
    if (name == _currentSourceName()) return;
    _hideTimer?.cancel();
    _stopStallWatchdog();
    _stopReadyWatch();
    final broken = _player;
    final brokenSub = _errorSub;
    setState(() {
      _nativeFailed = false;
      _fallbackNotice = '';
      _player = null;
      _videoController = null;
      _videoReady = false;
      _web = null;
      _mode = _PlayerMode.loading;
      _subtitles = const [];
      _activeSubtitleUrl = null;
      _embed = false;
    });
    _errorSub = null;
    _lastEmbedUrl = null;
    unawaited(brokenSub?.cancel());
    unawaited(broken?.dispose());
    _nativeAttempts = 0;
    if (name == 'aniwaves') {
      _sourceKind = 'aniwaves';
      unawaited(_startDood());
    } else {
      _sourceKind = 'aniwatch';
      unawaited(_startAniwatch());
    }
  }

  /// Resolves and plays the aniwaves DoodStream source.
  ///
  /// The worker hands back a dood embed wrapper (its Cloudflare egress can't
  /// pass dood's challenge), so the direct MP4 is resolved on the phone from
  /// that wrapper and played natively. The embed page is only opened when that
  /// on-device walk fails, or when the caller asked for the embed explicitly;
  /// [notice] explains why playback isn't on ZokoAnime.
  Future<void> _startDood({String? notice}) async {
    setState(() {
      _sourceKind = 'aniwaves';
      _mode = _PlayerMode.loading;
    });
    _lastEmbedUrl = null;
    _nativeAttempts = 0;
    try {
      final source = await _resolver.resolve(
        widget.item,
        _ep,
        dub: widget.dub,
        sv: widget.sv ?? 2,
        proxy: true,
        embed: _embed,
      );
      if (!mounted) return;
      _lastEmbedUrl = source.embedUrl?.isNotEmpty == true
          ? source.embedUrl
          : (source.embedMode ? source.playUrl : null);
      if (!_embed) {
        if (await _tryPlayDoodClient(source)) return;
        if (!source.embedMode && await _playNative(source)) return;
      }
    } catch (error) {
      debugPrint('[player] dood resolve failed: $error');
    }
    if (!mounted) return;
    _startEmbedFallback(notice, url: _lastEmbedUrl ?? _embedWrapUrl());
  }

  /// Attempts native playback of a dood source resolved directly on the phone
  /// from the original embed wrapper, bypassing the proxied worker MP4. Only
  /// DoodStream qualifies.
  Future<bool> _tryPlayDoodClient(ResolvedSource source) async {
    if (source.provider != 'doodstream' && source.provider != 'dood') {
      return false;
    }
    final direct = await _tryClientDoodNative(source);
    if (direct == null) return false;
    return _playNative(direct);
  }

  /// The worker returns a dood embed page when its own network can't pass
  /// dood's challenge. A real device passes, so the direct MP4 is resolved here
  /// and played straight from dood's CDN (which blocks CF egress) with the
  /// mobile UA it expects, with no worker proxy in between.
  Future<ResolvedSource?> _tryClientDoodNative(ResolvedSource source) async {
    if (source.provider != 'doodstream' && source.provider != 'dood') {
      return null;
    }
    try {
      final mp4 = await _resolver.resolveDoodNative(
        source.embedUrl ?? source.playUrl,
        animeId: widget.item.id,
        ep: _ep,
      );
      return ResolvedSource(
        playUrl: mp4,
        provider: 'doodstream',
        quality: 'auto',
        embedMode: false,
        httpHeaders: {
          'User-Agent': ResolverService.mobileUa,
          'Referer': ResolverService.doodReferer,
        },
      );
    } catch (error) {
      debugPrint('[player] client dood native failed: $error');
      return null;
    }
  }

  void _showSourceSheet(BuildContext context) {
    final current = _currentSourceName();
    final items = <({String name, String label, bool current})>[
      (
        name: 'aniwatch',
        label: 'ZokoAnime · primary',
        current: current == 'aniwatch',
      ),
      (
        name: 'aniwaves',
        label: 'DoodStream',
        current: current == 'aniwaves',
      ),
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.65,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SWITCH SOURCE',
                    style: context.appTextTheme.titleMedium?.copyWith(
                      color: context.appOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 4),
                  children: [
                    for (final item in items)
                      ListTile(
                        leading: Icon(
                          item.current
                              ? PhosphorIcons.checkCircle()
                              : PhosphorIcons.playCircle(),
                          color: item.current
                              ? context.appAccent
                              : context.appOnSurfaceVariant,
                        ),
                        title: Text(
                          item.label,
                          style: context.appTextTheme.bodyMedium?.copyWith(
                            color: context.appOnSurface,
                          ),
                        ),
                        trailing: item.current
                            ? Icon(PhosphorIcons.check(), color: context.appAccent)
                            : null,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          if (!item.current) _switchSource(item.name);
                        },
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  WebViewController _buildController(String url) {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params);
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            EmbedAdGuard.strip(controller);
          },
          onPageFinished: (_) {
            EmbedAdGuard.strip(controller);
          },
          onWebResourceError: (_) {},
          onNavigationRequest: EmbedAdGuard.guardNavigation,
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(false);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    controller.loadRequest(Uri.parse(url));
    EmbedAdGuard.attach(controller);
    return controller;
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      _scheduleHide();
    });
  }

  String _fmtTime(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  Widget _bottomControls(BuildContext context) {
    final player = _player;
    if (_mode != _PlayerMode.native || player == null || !_videoReady) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.only(left: 8, right: 16, top: 18, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _timeText(context, player.stream.position, player.state.position),
              Expanded(child: _seekBar(context, player)),
              _timeText(context, player.stream.duration, player.state.duration),
            ],
          ),
          Row(
            children: [
              _speedButton(context, player),
              const SizedBox(width: 4),
              _subtitleButton(context, player),
              const Spacer(),
              Text(
                _sourceLabel,
                style: context.appTextTheme.labelMedium?.copyWith(
                  color: Colors.white38,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Big central transport cluster: previous episode, rewind 10s, play/pause,
  /// forward 10s, next episode. The episode buttons only appear when a neighbor
  /// exists.
  Widget _centerControls(BuildContext context) {
    final player = _player;
    if (_mode != _PlayerMode.native || player == null || !_videoReady) {
      return const SizedBox.shrink();
    }
    final prev = _prevEpisode;
    final next = _nextEpisode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prev != null)
            _episodeNavButton(
              context,
              onTap: () => unawaited(_switchEpisode(prev)),
              icon: Icons.skip_previous_rounded,
              tooltip: 'Previous episode',
              label: 'EP ${prev.ep}',
            ),
          IconButton(
            padding: const EdgeInsets.all(10),
            iconSize: 40,
            onPressed: () {
              _hideTimer?.cancel();
              _seekBy(player, -10);
              _scheduleHide();
            },
            icon: Icon(Icons.replay_10, color: Colors.white),
          ),
          _centerPlayPauseButton(context, player),
          IconButton(
            padding: const EdgeInsets.all(10),
            iconSize: 40,
            onPressed: () {
              _hideTimer?.cancel();
              _seekBy(player, 10);
              _scheduleHide();
            },
            icon: Icon(Icons.forward_10, color: Colors.white),
          ),
          if (next != null)
            _episodeNavButton(
              context,
              onTap: () => unawaited(_switchEpisode(next)),
              icon: Icons.skip_next_rounded,
              tooltip: 'Next episode',
              label: 'EP ${next.ep}',
            ),
        ],
      ),
    );
  }

  void _seekBy(Player player, int seconds) {
    var target = player.state.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    unawaited(player.seek(target));
    _touchWatchdog();
  }

  Widget _centerPlayPauseButton(BuildContext context, Player player) {
    return StreamBuilder<bool>(
      stream: player.stream.playing,
      initialData: player.state.playing,
      builder: (context, snap) {
        final playing = snap.data ?? player.state.playing;
        final completed = player.state.completed;
        return IconButton(
          padding: const EdgeInsets.all(12),
          iconSize: 72,
          onPressed: () {
            _hideTimer?.cancel();
            if (completed) {
              unawaited(player.seek(Duration.zero));
              unawaited(player.play());
            } else {
              unawaited(player.playOrPause());
            }
            _touchWatchdog();
            _scheduleHide();
          },
          icon: Icon(
            completed
                ? PhosphorIcons.arrowsClockwise()
                : (playing ? PhosphorIcons.pause() : PhosphorIcons.play()),
            color: Colors.white,
          ),
        );
      },
    );
  }

  Widget _timeText(
    BuildContext context,
    Stream<Duration> stream,
    Duration initial,
  ) {
    return StreamBuilder<Duration>(
      stream: stream,
      initialData: initial,
      builder: (context, snap) {
        final value = snap.data ?? Duration.zero;
        return Text(
          _fmtTime(value),
          style: context.appTextTheme.bodySmall?.copyWith(color: Colors.white70),
        );
      },
    );
  }

  Widget _seekBar(BuildContext context, Player player) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (context, snapPos) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          initialData: player.state.duration,
          builder: (context, snapDur) {
            final duration = snapDur.data ?? Duration.zero;
            final max = duration.inMilliseconds > 0
                ? duration.inMilliseconds.toDouble()
                : 1.0;
            final drag = _dragSeconds;
            final value = (drag != null
                    ? drag * 1000
                    : (snapPos.data ?? Duration.zero).inMilliseconds.toDouble())
                .clamp(0.0, max);
            return Slider(
              value: value,
              min: 0,
              max: max,
              activeColor: context.appAccent,
              inactiveColor: Colors.white24,
              onChangeStart: (_) => _hideTimer?.cancel(),
              onChanged: (v) => setState(() => _dragSeconds = v / 1000),
              onChangeEnd: (v) {
                setState(() => _dragSeconds = null);
                unawaited(player.seek(Duration(milliseconds: v.round())));
                _scheduleHide();
              },
            );
          },
        );
      },
    );
  }

  void _showSpeedMenu(BuildContext context, Player player) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in speeds)
              ListTile(
                title: Text(
                  '${s.toStringAsFixed(2)}x',
                  style: context.appTextTheme.bodyMedium?.copyWith(
                    color: context.appOnSurface,
                  ),
                ),
                trailing: player.state.rate == s
                    ? Icon(PhosphorIcons.check(), color: context.appAccent)
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(player.setRate(s));
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _speedButton(BuildContext context, Player player) {
    return StreamBuilder<double>(
      stream: player.stream.rate,
      initialData: player.state.rate,
      builder: (context, snap) {
        final rate = snap.data ?? 1.0;
        return InkWell(
          onTap: () => _showSpeedMenu(context, player),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              '${rate.toStringAsFixed(2)}x',
              style: context.appTextTheme.labelMedium?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Provider label shown at the right of the control bar.
  String get _sourceLabel {
    if (_sourceKind == 'aniwatch') return 'ZOKOANIME';
    return 'DOODSTREAM';
  }

  /// 'CC' button; only shown when the current source ships subtitle tracks.
  Widget _subtitleButton(BuildContext context, Player player) {
    if (_subtitles.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: () => _showSubtitleSheet(context, player),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          'CC',
          style: context.appTextTheme.labelMedium?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Subtitle picker mirroring Kumi's player: an Off row plus one row per
  /// track, with a check on the active selection.
  void _showSubtitleSheet(BuildContext context, Player player) {
    final items = <({bool isOff, String label, ResolvedSubtitle? track})>[
      (isOff: true, label: 'Off', track: null),
      for (final track in _subtitles)
        (isOff: false, label: track.label, track: track),
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.65,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Subtitles',
                    style: context.appTextTheme.titleMedium?.copyWith(
                      color: context.appOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 4),
                  children: [
                    for (final item in items)
                      ListTile(
                        title: Text(
                          item.label,
                          style: context.appTextTheme.bodyMedium?.copyWith(
                            color: context.appOnSurface,
                          ),
                        ),
                        trailing: _activeSubtitleUrl == null && item.isOff
                            ? Icon(PhosphorIcons.check(),
                                color: context.appAccent)
                            : (item.track != null &&
                                    item.track!.url == _activeSubtitleUrl)
                                ? Icon(PhosphorIcons.check(),
                                    color: context.appAccent)
                                : null,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          final track = item.track;
                          if (track == null) {
                            unawaited(_clearSubtitle(player));
                          } else {
                            unawaited(
                                _applySubtitle(player, track, force: true));
                          }
                        },
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoBody() {
    final player = _player;
    final controller = _videoController;
    if (player == null || controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Center(
      child: Video(
        controller: controller,
        controls: NoVideoControls,
        fit: BoxFit.contain,
        fill: const Color(0xFF000000),
        // media_kit's own subtitle view scales text by a factor derived from
        // the surface area (shrinking it on small screens) and lets its
        // padding drift, so it is disabled in favour of [_subtitleOverlay].
        subtitleViewConfiguration: const SubtitleViewConfiguration(
          visible: false,
        ),
      ),
    );
  }

  /// Bottom-aligned subtitle track, drawn by the app instead of media_kit so
  /// the size, colour and bottom gap stay fixed at any screen size and across
  /// pause/resume and settings changes.
  Widget _subtitleOverlay() {
    final player = _player;
    if (player == null) return const SizedBox.shrink();
    return StreamBuilder<List<String>>(
      stream: player.stream.subtitle,
      initialData: player.state.subtitle,
      builder: (context, snapshot) {
        final lines = snapshot.data ?? const <String>[];
        if (lines.isEmpty) return const SizedBox.shrink();
        final height = MediaQuery.sizeOf(context).height;
        final bottom = (height * 0.06).clamp(20.0, 96.0).toDouble();
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
          child: Text(
            lines.join('\n'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _subtitleSize,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: _subtitleColor,
              backgroundColor:
                  Colors.black.withValues(alpha: _subtitleBackground),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _buildPlayerArea()),
              if (_mode == _PlayerMode.native)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _subtitleOverlay(),
                    ),
                  ),
                ),
              if (_mode == _PlayerMode.native && !_videoReady)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
              if (_nativeFailed)
                Positioned(
                  top: 10,
                  left: 12,
                  right: 12,
                  child: _fallbackBanner(context),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: _topBar(context),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _centerControls(context),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: _bottomControls(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerArea() {
    switch (_mode) {
      case _PlayerMode.loading:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      case _PlayerMode.native:
        return _videoBody();
      case _PlayerMode.embed:
        final web = _web;
        if (web == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: WebViewWidget(controller: web),
        );
      case _PlayerMode.error:
        return _fatalErrorView(context);
    }
  }

  Widget _fatalErrorView(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIcons.warningCircle(),
                color: Colors.white54,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Playback failed',
                style: context.appTextTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _fatalMessage ?? '',
                textAlign: TextAlign.center,
                style: context.appTextTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  _nativeAttempts = 0;
                  _lastEmbedUrl = null;
                  _fatalMessage = null;
                  setState(() => _mode = _PlayerMode.loading);
                  unawaited(_start());
                },
                icon: Icon(PhosphorIcons.arrowsClockwise(), size: 18),
                label: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(color: context.appAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.info(), size: 16, color: context.appAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _fallbackNotice,
              style: context.appTextTheme.bodySmall?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _nativeFailed = false),
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(PhosphorIcons.x(), size: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.only(left: 4, right: 8, top: 6, bottom: 18),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(PhosphorIcons.arrowLeft(), color: Colors.white, size: 26),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'EP $_ep',
                  style: context.appTextTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showSourceSheet(context),
            tooltip: 'Switch source',
            icon: Icon(
              PhosphorIcons.arrowsClockwise(),
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

enum _PlayerMode { loading, native, embed, error }