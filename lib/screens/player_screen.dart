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

/// Immersive full-screen player. Same source strategy as Kumi: direct-file
/// sources are preferred, then the embed. For aniwaves the direct source is
/// DoodStream (a real MP4, played natively with media_kit); when the worker can
/// only hand back an embed page (echovideo / byse / challenge-gated DoodStream)
/// playback falls back to the WebView embed with the ad layer stripped.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.item,
    required this.ep,
    this.dub = false,
    this.sv,
    this.embed = false,
    this.subtitle,
    this.initialPosition,
  });

  final AnimeItem item;
  final int ep;
  final bool dub;

  /// Optional pinned aniwaves server id. When set, resolution is forced to
  /// that server instead of the worker's default priority.
  final int? sv;

  /// When true the player opens directly in the DoodStream embed instead of
  /// attempting a direct native stream first.
  final bool embed;

  /// Short label like "EP 05" shown under the title in the top bar.
  final String? subtitle;

  /// Resume position passed from the "continue watching" row.
  final Duration? initialPosition;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final ResolverService _resolver = ResolverService();

  _PlayerMode _mode = _PlayerMode.loading;
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<String>? _errorSub;
  WebViewController? _web;
  String _nativeLabel = '';
  String _fallbackNotice = '';
  bool _nativeFailed = false;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  double? _dragSeconds;
  String? _embedProvider;
  int _nativeAttempts = 0;

  // Settings snapshot taken when the player opens.
  bool _hardwareDecode = false;
  double _defaultRate = 1.0;
  bool _keepAwake = true;

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
    unawaited(_loadResume());
    _start();
  }

  Future<void> _loadResume() async {
    await WatchHistory.instance.ensureLoaded();
    if (!mounted) return;
    _resumePosition = widget.initialPosition ??
        WatchHistory.instance.resumeFor(widget.item, widget.ep);
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
    unawaited(_errorSub?.cancel());
    _errorSub = null;
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
      ep: widget.ep,
      dub: widget.dub,
      position: position,
      duration: _player?.state.duration ?? Duration.zero,
    );
  }

  /// Seeks to the saved position once the video is actually playing. Waiting
  /// on `playing` avoids seeking while the buffer is still warming up, and an
  /// earlier manual seek near the start is never overridden.
  Future<void> _seekAfterOpen(Player player) async {
    final resume = _resumePosition;
    if (resume == null || resume <= const Duration(seconds: 5)) return;
    final playing = Completer<void>();
    late final StreamSubscription<bool> sub;
    sub = player.stream.playing.listen((value) {
      if (value && !playing.isCompleted) playing.complete();
    });
    try {
      await Future.any<void>([
        playing.future,
        Future<void>.delayed(const Duration(seconds: 3)),
      ]);
    } finally {
      await sub.cancel();
    }
    if (!mounted || !identical(_player, player)) return;
    if (player.state.position < const Duration(seconds: 8)) {
      player.seek(resume);
    }
  }

  String _embedWrapUrl() =>
      aniwavesEmbedUrl(id: widget.item.id, slug: widget.item.slug, ep: widget.ep);

  /// Native-first. The worker picks the best server for the episode: when
  /// DoodStream resolves we get a real MP4 and play it with media_kit (routed
  /// through the worker proxy so the CDN's required headers are present);
  /// otherwise the worker hands back an embed page which we load in the WebView.
  Future<void> _start() async {
    setState(() => _mode = _PlayerMode.loading);
    if (widget.embed) {
      await _startWithEmbed();
      return;
    }
    try {
      final source = await _resolver.resolve(
        widget.item,
        widget.ep,
        dub: widget.dub,
        sv: widget.sv,
        proxy: true,
      );
      if (!mounted) return;
      if (source.embedMode) {
        _fallbackToEmbed(
          url: source.playUrl,
          provider: source.provider,
          notice: source.note != null && source.note!.isNotEmpty
              ? 'Direct playback wasn\'t possible for this title, so Mirai opened the embed player instead.'
              : null,
        );
        return;
      }
      final started = await _playNative(source);
      if (!mounted) return;
      if (!started) {
        _fallbackToEmbed(
          url: _embedWrapUrl(),
          notice:
              'The direct stream couldn\'t be reached, so Mirai opened the embed player instead.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      _fallbackToEmbed(
        url: _embedWrapUrl(),
        notice:
            'The direct stream couldn\'t be reached, so Mirai opened the embed player instead.',
      );
    }
  }

  /// Loads the embed player. [url] is the embed page supplied by the worker
  /// (echovideo / byse / dood wrapper) or the site watch page as a last resort.
  void _fallbackToEmbed({required String url, String? provider, String? notice}) {
    if (!mounted) return;
    final controller = _buildController(url);
    setState(() {
      _web = controller;
      _mode = _PlayerMode.embed;
      _embedProvider = provider;
      _nativeFailed = notice != null;
      _fallbackNotice = notice ?? '';
    });
    _scheduleHide();
  }

  /// Starts native playback; returns true when the media actually opened.
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
      unawaited(_retryAfterRuntimeError());
    });
    _errorSub = errorSub;
    setState(() {
      _mode = _PlayerMode.loading;
      _nativeLabel = 'DoodStream';
    });
    try {
      await player.open(Media(source.playUrl));
      if (!mounted) {
        unawaited(errorSub.cancel());
        unawaited(player.dispose());
        return false;
      }
      setState(() {
        _player = player;
        _videoController = controller;
        _mode = _PlayerMode.native;
      });
      _lastPosition = Duration.zero;
      _positionSub?.cancel();
      _positionSub = player.stream.position.listen(_onNativePosition);
      _completedSub?.cancel();
      _completedSub = player.stream.completed.listen((_) {
        unawaited(WatchHistory.instance.clearEntry(widget.item.id, widget.ep));
      });
      if (_resumePosition != null) unawaited(_seekAfterOpen(player));
      if (_defaultRate != 1.0) unawaited(player.setRate(_defaultRate));
      if (_keepAwake) unawaited(WakelockPlus.enable());
      _scheduleHide();
      return true;
    } catch (error) {
      debugPrint('[player] open failed: $error');
      unawaited(errorSub.cancel());
      unawaited(player.dispose());
      return false;
    }
  }

  void _onNativePosition(Duration position) {
    _lastPosition = position;
    final now = DateTime.now();
    if (now.difference(_lastSaveAt).inSeconds < 8) return;
    _lastSaveAt = now;
    unawaited(_saveProgress(position));
  }

  /// Tears down the failed native player and falls through to the embed, since
  /// DoodStream is the only direct source for a given episode.
  Future<void> _retryAfterRuntimeError() async {
    final broken = _player;
    final brokenSub = _errorSub;
    setState(() {
      _player = null;
      _videoController = null;
      _mode = _PlayerMode.loading;
    });
    _errorSub = null;
    unawaited(brokenSub?.cancel());
    await broken?.dispose();
    if (!mounted) return;
    if (_nativeAttempts < 2) {
      await _start();
    } else {
      _fallbackToEmbed(
        url: _embedWrapUrl(),
        notice:
            'DoodStream dropped the stream, so Mirai opened the embed player instead.',
      );
    }
  }

  /// The source currently on screen, used to highlight the sheet item.
  String? _currentSourceName() {
    if (_mode == _PlayerMode.embed) return 'embed';
    if (_mode == _PlayerMode.native) return 'doodstream';
    return null;
  }

  /// Switches between the direct DoodStream player and the embed player.
  void _switchSource(String name) {
    if (name == _currentSourceName()) return;
    _hideTimer?.cancel();
    final broken = _player;
    final brokenSub = _errorSub;
    setState(() {
      _nativeFailed = false;
      _fallbackNotice = '';
      _player = null;
      _videoController = null;
      _web = null;
      _mode = _PlayerMode.loading;
    });
    _errorSub = null;
    unawaited(brokenSub?.cancel());
    unawaited(broken?.dispose());
    if (name == 'embed') {
      // Ask the worker for an embed explicitly so we get the actual player
      // page (echovideo / byse) instead of the dood stream again.
      unawaited(_startWithEmbed());
    } else {
      _nativeAttempts = 0;
      unawaited(_start());
    }
  }

  Future<void> _startWithEmbed() async {
    setState(() => _mode = _PlayerMode.loading);
    try {
      final source = await _resolver.resolve(
        widget.item,
        widget.ep,
        dub: widget.dub,
        sv: widget.sv,
        embed: true,
      );
      if (!mounted) return;
      if (source.embedMode) {
        _fallbackToEmbed(url: source.playUrl, provider: source.provider);
      } else {
        // Shouldn't happen with embed:true, but never surprise the user.
        if (await _playNative(source)) return;
        _fallbackToEmbed(url: _embedWrapUrl());
      }
    } catch (_) {
      if (!mounted) return;
      _fallbackToEmbed(url: _embedWrapUrl());
    }
  }

  void _showSourceSheet(BuildContext context) {
    final current = _currentSourceName();
    final items = <({String name, String label, bool current})>[
      (
        name: 'doodstream',
        label: 'Direct · DoodStream',
        current: current == 'doodstream',
      ),
      (
        name: 'embed',
        label: 'Embed player',
        current: current == 'embed',
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
    if (_mode != _PlayerMode.native || player == null) {
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
              const Spacer(),
              Text(
                'DOODSTREAM',
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

  /// Big central transport cluster: rewind 10s, play/pause, forward 10s.
  Widget _centerControls(BuildContext context) {
    final player = _player;
    if (_mode != _PlayerMode.native || player == null) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
      ],
    );
  }

  void _seekBy(Player player, int seconds) {
    var target = player.state.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    unawaited(player.seek(target));
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
      ),
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
                    child: Center(child: _centerControls(context)),
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
    }
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
    final subtitle = _mode == _PlayerMode.native
        ? 'Playing via $_nativeLabel'
        : _mode == _PlayerMode.embed
            ? 'Embedded player${_embedProvider != null ? ' · $_embedProvider' : ''}'
            : null;
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
                if (subtitle != null)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextTheme.bodySmall?.copyWith(
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

enum _PlayerMode { loading, native, embed }