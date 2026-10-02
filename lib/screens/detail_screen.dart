import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/anime_item.dart';
import '../services/catalog_service.dart';
import '../services/resolver_service.dart';
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
    try {
      final detail = await CatalogService().detail(widget.item.id, widget.item.slug);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
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
          _play(context, widget.item, targetEp, dub, sv: null);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
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
            child: SectionLabel(text: 'EPISODES'),
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
              itemCount: episodes.length + (episodes.isEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (episodes.isEmpty) {
                  return Text(
                    'Episode list is empty.',
                    style: context.appTextTheme.bodyMedium,
                  );
                }
                return _EpisodeRow(
                  episode: episodes[index],
                  hasDub: hasDub,
                  defaultDub: defaultDub,
                  onTap: (dub) =>
                      _play(context, item, episodes[index], dub, sv: prefSv),
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
            child: Image.network(
              detail.coverUrl!,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
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
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
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

    final meta = <({IconData icon, String label})>[
      if (hasSub)
        (
          icon: Icons.closed_caption_rounded,
          label: 'SUB ${detail.subEps}',
        ),
      if (hasDub)
        (icon: Icons.translate_rounded, label: 'DUB ${detail.dubEps}'),
      if (detail.totalEps > 0 && detail.totalEps != maxEp)
        (
          icon: Icons.video_collection_outlined,
          label: '${detail.totalEps} EPS',
        ),
      if (item.rating != null && item.rating!.isNotEmpty)
        (icon: Icons.star_rounded, label: item.rating!),
      if (item.type != null && item.type!.isNotEmpty)
        (icon: _typeIcon(item.type!), label: item.type!),
      if (detail.ageRating != null && detail.ageRating!.isNotEmpty)
        (icon: Icons.shield_outlined, label: detail.ageRating!),
      if (detail.quality != null && detail.quality!.isNotEmpty)
        (icon: Icons.high_quality_outlined, label: detail.quality!),
      if (detail.status != null && detail.status!.isNotEmpty)
        (icon: _statusIcon(detail.status!), label: detail.status!),
      if (detail.premiered != null && detail.premiered!.isNotEmpty)
        (
          icon: Icons.calendar_month_outlined,
          label: detail.premiered!,
        ),
      if (detail.country != null && detail.country!.isNotEmpty)
        (icon: Icons.public_rounded, label: detail.country!),
      if (detail.source != null && detail.source!.isNotEmpty)
        (
          icon: Icons.menu_book_outlined,
          label: 'Source ${detail.source}',
        ),
      if (detail.duration != null && detail.duration!.isNotEmpty)
        (icon: Icons.timer_outlined, label: detail.duration!),
      if (detail.aired != null && detail.aired!.isNotEmpty)
        (
          icon: Icons.event_outlined,
          label: 'Aired ${detail.aired}',
        ),
      if (detail.broadcast != null && detail.broadcast!.isNotEmpty)
        (
          icon: Icons.schedule_rounded,
          label: 'Broadcast ${detail.broadcast}',
        ),
      if (detail.reviews != null && detail.reviews!.isNotEmpty)
        (
          icon: Icons.rate_review_outlined,
          label: '${detail.reviews} ratings',
        ),
    ];
    final tags = <String>[
      ...detail.genres,
      ...detail.studios,
      ...detail.producers,
      ...detail.licensors,
    ];

    final hasEps = detail.episodes.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...children,
          if (meta.isNotEmpty || tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in meta) _metaBadge(context, b.icon, b.label),
                for (final t in tags) _tagChip(context, t),
              ],
            ),
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
                  sv: null,
                  label: 'Auto',
                  active: prefSv == null,
                ),
                for (final sv in ResolverService.serverOrder)
                  _sourceChip(
                    context,
                    item,
                    sv: sv,
                    label: ResolverService.serverNames[sv] ?? 'S$sv',
                    active: prefSv == sv,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaBadge(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: context.appOutline),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.appAccent),
          const SizedBox(width: 5),
          Text(
            label,
            style: context.appTextTheme.labelSmall?.copyWith(
              fontSize: 11,
              letterSpacing: 0.4,
              color: context.appOnSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.appTextTheme.labelSmall?.copyWith(
          fontSize: 11,
          color: context.appOnSurfaceVariant,
        ),
      ),
    );
  }

  Widget _sourceChip(
    BuildContext context,
    AnimeItem item, {
    required int? sv,
    required String label,
    required bool active,
  }) {
    return GestureDetector(
      onTap: () => _selectSource(context, item, sv),
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

  /// Pins [sv] for this anime (null clears the preference) and plays the first
  /// available episode so the choice is immediately felt.
  void _selectSource(BuildContext context, AnimeItem item, int? sv) {
    final app = context.read<AppState>();
    app.setPreferredSv(item.id.toString(), sv);
    final episodes = _detail!.episodes;
    if (episodes.isEmpty) return;
    _play(context, item, episodes.first, app.audioMode == AudioMode.dub,
        sv: sv);
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
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          item: item,
          ep: episode.ep,
          dub: dub,
          sv: sv,
          subtitle: 'EP ${episode.ep}',
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