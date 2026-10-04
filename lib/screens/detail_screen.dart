import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/anime_item.dart';
import '../services/catalog_service.dart';
import '../services/saved.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/anime_card.dart';
import 'player_screen.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    super.key,
    required this.item,
    this.initialEp,
    this.initialDub,
  });

  final AnimeItem item;
  final int? initialEp;
  final bool? initialDub;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  AnimeDetail? _detail;
  bool _loading = true;
  bool _error = false;
  int _visibleEps = 10;

  static const _epsPerPage = 10;

  @override
  void initState() {
    super.initState();
    Saved.instance.addListener(_onSavedChanged);
    _load();
  }

  @override
  void dispose() {
    Saved.instance.removeListener(_onSavedChanged);
    super.dispose();
  }

  void _onSavedChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    // One retry: a first-open cold build on the worker can exceed the request
    // timeout once (large titles), but the retry joins the in-flight build and
    // the fresh cache. Only show the error view after both attempts fail.
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final detail =
            await CatalogService().detail(widget.item.id, widget.item.slug);
        if (!mounted) return;
        setState(() {
          _detail = detail;
          _loading = false;
          _visibleEps = _epsPerPage;
        });
        // Auto-play if initial episode was specified
        if (widget.initialEp != null) {
          final episodes = detail.episodes;
          final targetEp = episodes.firstWhere(
            (e) => e.ep == widget.initialEp,
            orElse: () => episodes.first,
          );
          final dub = widget.initialDub ?? false;
          if (mounted) {
            final app = context.read<AppState>();
            final pref = app.preferredSv(widget.item.id.toString());
            _play(context, widget.item, targetEp, dub,
                sv: 2, embed: pref == 0);
          }
        }
        return;
      } catch (_) {
        if (attempt == 2) {
          if (!mounted) return;
          setState(() {
            _error = true;
            _loading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? _errorView(context)
              : _content(context),
    );
  }

  Widget _errorView(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Timeline lost.',
              style: context.appTextTheme.titleMedium?.copyWith(
                color: context.appOnSurface,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: _load, child: const Text('RETRY')),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final detail = _detail!;
    final item = detail.item;
    final saved = Saved.instance.contains(item.id);
    final hasSub = detail.subEps > 0;
    final hasDub = detail.dubEps > 0;
    final episodes = detail.episodes;
    final app = context.watch<AppState>();
    final defaultDub = app.audioMode == AudioMode.dub;
    final prefSv = app.preferredSv(item.id.toString());

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: context.appBackground,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: Icon(
                saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: saved ? context.appAccent : null,
              ),
              onPressed: () => Saved.instance.toggle(detail),
            ),
          ],
        ),
        SliverToBoxAdapter(child: _summary(context, item, detail, app)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: SectionLabel(
              text: 'EPISODES',
              onMore: episodes.length > 12
                  ? () => _showEpisodeLocator(context)
                  : null,
              moreLabel: 'LOCATE',
            ),
          ),
        ),
        if (!hasSub && !hasDub)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                'No episodes are available for this title yet.',
                style: context.appTextTheme.bodyMedium,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            sliver: SliverList.builder(
              itemCount: episodes.isEmpty
                  ? 1
                  : _visibleEps < episodes.length
                      ? _visibleEps + 1
                      : episodes.length,
              itemBuilder: (context, index) {
                if (episodes.isEmpty) {
                  return Text(
                    'Episode list is empty.',
                    style: context.appTextTheme.bodyMedium,
                  );
                }
                if (_visibleEps < episodes.length && index == _visibleEps) {
                  return _loadMoreButton(context);
                }
                return _EpisodeRow(
                  episode: episodes[index],
                  hasDub: hasDub,
                  defaultDub: defaultDub,
                  onTap: (dub) => _play(context, item, episodes[index], dub,
                      sv: 2, embed: prefSv == 0),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _summary(
  BuildContext context,
  AnimeItem item,
  AnimeDetail detail,
  AppState app,
) {
    final hasSub = detail.subEps > 0;
    final hasDub = detail.dubEps > 0;
    final maxEp = detail.subEps > detail.dubEps ? detail.subEps : detail.dubEps;
    final prefSv = app.preferredSv(item.id.toString());
    final children = <Widget>[
      if (detail.coverUrl != null && detail.coverUrl!.isNotEmpty) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.width * 9 / 16,
            child: CachedNetworkImage(
              imageUrl: detail.coverUrl!,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              placeholder: (_, __) => Container(
                color: context.appSurfaceVariant,
                alignment: Alignment.center,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.appAccent,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
      Text(
        item.title,
        style: context.appTextTheme.displayMedium?.copyWith(
          color: context.appOnSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      if (item.originalTitle != null && item.originalTitle != item.title) ...[
        const SizedBox(height: 6),
        Text(
          item.originalTitle!,
          style: context.appTextTheme.bodyMedium?.copyWith(
            color: context.appOnSurfaceVariant,
          ),
        ),
      ],
      if (detail.synopsis != null && detail.synopsis!.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          detail.synopsis!,
          style: context.appTextTheme.bodyMedium?.copyWith(
            color: context.appOnSurfaceVariant,
          ),
        ),
      ],
    ];

    final meta = <({IconData icon, String label, String value})>[
      if (hasSub)
        (
          icon: Icons.closed_caption_rounded,
          label: 'Episodes',
          value: '${detail.subEps} sub${hasDub ? ' / ${detail.dubEps} dub' : ''}',
        ),
      if (!hasSub && hasDub)
        (
          icon: Icons.translate_rounded,
          label: 'Episodes',
          value: '${detail.dubEps} dub',
        ),
      if (detail.totalEps > 0 && detail.totalEps != maxEp)
        (
          icon: Icons.video_collection_outlined,
          label: 'Total',
          value: '${detail.totalEps} eps',
        ),
      if (item.rating != null && item.rating!.isNotEmpty)
        (icon: Icons.star_rounded, label: 'Rating', value: item.rating!),
      if (item.type != null && item.type!.isNotEmpty)
        (icon: _typeIcon(item.type!), label: 'Type', value: item.type!),
      if (detail.ageRating != null && detail.ageRating!.isNotEmpty)
        (
          icon: Icons.shield_outlined,
          label: 'Age rating',
          value: detail.ageRating!,
        ),
      if (detail.quality != null && detail.quality!.isNotEmpty)
        (
          icon: Icons.high_quality_outlined,
          label: 'Quality',
          value: detail.quality!,
        ),
      if (detail.status != null && detail.status!.isNotEmpty)
        (icon: _statusIcon(detail.status!), label: 'Status', value: detail.status!),
      if (detail.premiered != null && detail.premiered!.isNotEmpty)
        (
          icon: Icons.calendar_month_outlined,
          label: 'Premiered',
          value: detail.premiered!,
        ),
      if (detail.country != null && detail.country!.isNotEmpty)
        (icon: Icons.public_rounded, label: 'Country', value: detail.country!),
      if (detail.source != null && detail.source!.isNotEmpty)
        (
          icon: Icons.menu_book_outlined,
          label: 'Source',
          value: detail.source!,
        ),
      if (detail.duration != null && detail.duration!.isNotEmpty)
        (icon: Icons.timer_outlined, label: 'Duration', value: detail.duration!),
      if (detail.aired != null && detail.aired!.isNotEmpty)
        (icon: Icons.event_outlined, label: 'Aired', value: detail.aired!),
      if (detail.broadcast != null && detail.broadcast!.isNotEmpty)
        (
          icon: Icons.schedule_rounded,
          label: 'Broadcast',
          value: detail.broadcast!,
        ),
      if (detail.reviews != null && detail.reviews!.isNotEmpty)
        (
          icon: Icons.rate_review_outlined,
          label: 'Ratings',
          value: detail.reviews!,
        ),
      if (detail.genres.isNotEmpty)
        (
          icon: Icons.category_outlined,
          label: 'Genres',
          value: detail.genres.join(', '),
        ),
      if (detail.studios.isNotEmpty)
        (
          icon: Icons.theaters_outlined,
          label: 'Studios',
          value: detail.studios.join(', '),
        ),
      if (detail.producers.isNotEmpty)
        (
          icon: Icons.factory_outlined,
          label: 'Producers',
          value: detail.producers.join(', '),
        ),
      if (detail.licensors.isNotEmpty)
        (
          icon: Icons.local_shipping_outlined,
          label: 'Licensors',
          value: detail.licensors.join(', '),
        ),
    ];

    final hasEps = detail.episodes.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...children,
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 16),
            _metaList(context, meta),
          ],
          if (hasEps) ...[
            const SizedBox(height: 20),
            const SectionLabel(text: 'PLAY SOURCE'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _sourceChip(
                  context,
                  item,
                  embed: false,
                  label: 'DoodStream',
                  active: prefSv != 0,
                ),
                _sourceChip(
                  context,
                  item,
                  embed: true,
                  label: 'Embed',
                  active: prefSv == 0,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaList(
    BuildContext context,
    List<({IconData icon, String label, String value})> meta,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: context.appOutline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          for (var i = 0; i < meta.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: context.appOutline),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    meta[i].icon,
                    size: 16,
                    color: context.appAccent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      meta[i].label,
                      style: context.appTextTheme.labelMedium?.copyWith(
                        color: context.appOnSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      meta[i].value,
                      textAlign: TextAlign.right,
                      style: context.appTextTheme.labelMedium?.copyWith(
                        color: context.appOnSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sourceChip(
    BuildContext context,
    AnimeItem item, {
    required bool embed,
    required String label,
    required bool active,
  }) {
    return GestureDetector(
      onTap: () => _selectSource(context, item, embed),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? context.appAccent : Colors.transparent,
          border: Border.all(
            color: active ? context.appAccent : context.appOutline,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_arrow_rounded,
              size: 15,
              color: active ? context.appOnAccent : context.appAccent,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: context.appTextTheme.labelSmall?.copyWith(
                fontSize: 11,
                letterSpacing: 0.4,
                color: active ? context.appOnAccent : context.appOnSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pins the source choice for this anime (2 = DoodStream native, 0 = embed)
  /// and plays the first available episode so the choice is immediately felt.
  void _selectSource(BuildContext context, AnimeItem item, bool embed) {
    final app = context.read<AppState>();
    app.setPreferredSv(item.id.toString(), embed ? 0 : 2);
    final episodes = _detail!.episodes;
    if (episodes.isEmpty) return;
    _play(context, item, episodes.first, app.audioMode == AudioMode.dub,
        sv: 2, embed: embed);
  }

  IconData _statusIcon(String status) {
    final s = status.toLowerCase();
    if (s.contains('ongo') || s.contains('airing')) {
      return Icons.play_circle_outline_rounded;
    }
    if (s.contains('finish') || s.contains('end')) {
      return Icons.check_circle_outline_rounded;
    }
    if (s.contains('upcom')) {
      return Icons.upcoming_rounded;
    }
    return Icons.autorenew_rounded;
  }

  IconData _typeIcon(String type) {
    final t = type.toLowerCase();
    if (t == 'movie') return Icons.movie_rounded;
    if (t == 'tv' || t.contains('series')) return Icons.tv_rounded;
    return Icons.ondemand_video_outlined;
  }

  void _play(
    BuildContext context,
    AnimeItem item,
    Episode episode,
    bool dub, {
    int? sv,
    bool embed = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          item: item,
          ep: episode.ep,
          dub: dub,
          sv: sv,
          embed: embed,
          subtitle: 'EP ${episode.ep}',
          episodes: _detail?.episodes,
        ),
      ),
    );
  }

  /// Opens a searchable sheet that locates episodes by number, handy for
  /// titles with hundreds of episodes (One Piece, Detective Conan, ...).
  void _showEpisodeLocator(BuildContext context) {
    final detail = _detail;
    if (detail == null || detail.episodes.isEmpty) return;
    final app = context.read<AppState>();
    final defaultDub = app.audioMode == AudioMode.dub;
    final prefSv = app.preferredSv(detail.item.id.toString());
    final hasDub = detail.dubEps > 0;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _EpisodeLocatorSheet(
        item: detail.item,
        episodes: detail.episodes,
        hasDub: hasDub,
        defaultDub: defaultDub,
        onPlay: (episode, dub) {
          Navigator.pop(sheetContext);
          _play(context, detail.item, episode, dub,
              sv: 2, embed: prefSv == 0);
        },
      ),
    );
  }

  Widget _loadMoreButton(BuildContext context) {
    final remaining = _detail!.episodes.length - _visibleEps;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => setState(() => _visibleEps += _epsPerPage),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.appAccent,
            side: BorderSide(color: context.appOutline),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
          ),
          child: Text(
            'LOAD $remaining MORE',
            style: context.appTextTheme.labelSmall?.copyWith(
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.episode,
    required this.hasDub,
    required this.defaultDub,
    required this.onTap,
  });

  final Episode episode;
  final bool hasDub;
  final bool defaultDub;
  final void Function(bool dub) onTap;

  @override
  Widget build(BuildContext context) {
    final subActive = episode.sub;
    final dubActive = episode.dub && hasDub;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTap(defaultDub),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 54,
                    child: Text(
                      episode.ep.toString().padLeft(2, '0'),
                      style: context.appTextTheme.labelSmall?.copyWith(
                        fontSize: 12,
                        color: context.appAccent,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'EP ${episode.ep}',
                      style: context.appTextTheme.titleMedium?.copyWith(
                        color: context.appOnSurface,
                      ),
                    ),
                  ),
                  if (dubActive)
                    GestureDetector(
                      onTap: () => onTap(true),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.appSurfaceVariant,
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                        ),
                        child: Text(
                          'DUB',
                          style: context.appTextTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: context.appOnSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
if (subActive) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.appAccent,
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      child: Text(
                        'SUB',
                        style: context.appTextTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: context.appOnAccent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: context.appOutline,
        ),
      ],
    );
  }
}

/// Searchable episode list for long-run titles. Typing a number narrows the
/// list to episodes whose number contains the typed digits; tapping one plays
/// it directly with the current audio settings.
class _EpisodeLocatorSheet extends StatefulWidget {
  const _EpisodeLocatorSheet({
    required this.item,
    required this.episodes,
    required this.hasDub,
    required this.defaultDub,
    required this.onPlay,
  });

  final AnimeItem item;
  final List<Episode> episodes;
  final bool hasDub;
  final bool defaultDub;
  final void Function(Episode episode, bool dub) onPlay;

  @override
  State<_EpisodeLocatorSheet> createState() => _EpisodeLocatorSheetState();
}

class _EpisodeLocatorSheetState extends State<_EpisodeLocatorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final matches = query.isEmpty
        ? const <Episode>[]
        : widget.episodes
            .where((e) => e.ep.toString().contains(query))
            .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LOCATE EPISODE',
                      style: context.appTextTheme.titleMedium?.copyWith(
                        color: context.appOnSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type a number such as 568 to find it.',
                      style: context.appTextTheme.bodySmall?.copyWith(
                        color: context.appOnSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.search,
                      style: context.appTextTheme.bodyMedium?.copyWith(
                        color: context.appOnSurface,
                      ),
                      cursorColor: context.appAccent,
                      decoration: InputDecoration(
                        hintText: '1, 24, 568 ...',
                        hintStyle: context.appTextTheme.bodyMedium?.copyWith(
                          color: context.appOnSurfaceVariant,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: context.appOnSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: context.appSurfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.field),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (query.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        matches.isEmpty
                            ? 'No episode matches "$query".'
                            : '${matches.length} match${matches.length == 1 ? '' : 'es'}.',
                        style: context.appTextTheme.bodySmall?.copyWith(
                          color: context.appOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (matches.isEmpty)
                const SizedBox(height: 40)
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final episode = matches[index];
                      final dubActive = episode.dub && widget.hasDub;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => widget.onPlay(episode, widget.defaultDub),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 46,
                                  child: Text(
                                    episode.ep.toString().padLeft(2, '0'),
                                    style:
                                        context.appTextTheme.labelSmall?.copyWith(
                                      fontSize: 12,
                                      color: context.appAccent,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'EP ${episode.ep}',
                                    style: context.appTextTheme.titleMedium
                                        ?.copyWith(color: context.appOnSurface),
                                  ),
                                ),
                                if (episode.sub)
                                  _audioTag(
                                    context,
                                    'SUB',
                                    filled: true,
                                  ),
                                if (dubActive) ...[
                                  const SizedBox(width: 8),
                                  _audioTag(context, 'DUB', filled: false),
                                ],
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.play_arrow_rounded,
                                  size: 20,
                                  color: context.appOnSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _audioTag(BuildContext context, String label, {required bool filled}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? context.appAccent : context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: context.appTextTheme.labelSmall?.copyWith(
          fontSize: 9,
          color: filled ? context.appOnAccent : context.appOnSurfaceVariant,
        ),
      ),
    );
  }
}