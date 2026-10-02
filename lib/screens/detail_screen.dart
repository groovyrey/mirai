import 'package:flutter/material.dart';

import '../models/anime_item.dart';
import '../services/catalog_service.dart';
import '../services/saved.dart';
import '../theme/app_theme.dart';
import '../widgets/anime_card.dart';
import 'player_screen.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.item});

  final AnimeItem item;

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
        SliverToBoxAdapter(child: _summary(context, item, detail)),
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
                  onTap: (dub) => _play(context, item, episodes[index], dub),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _summary(BuildContext context, AnimeItem item, AnimeDetail detail) {
    final hasSub = detail.subEps > 0;
    final hasDub = detail.dubEps > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: context.appTextTheme.displayMedium?.copyWith(
              color: context.appOnSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (item.originalTitle != null &&
              item.originalTitle != item.title) ...[
            const SizedBox(height: 6),
            Text(
              item.originalTitle!,
              style: context.appTextTheme.bodyMedium?.copyWith(
                color: context.appOnSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasSub) _chip(context, 'S${detail.subEps}'),
              if (hasDub) _chip(context, 'D${detail.dubEps}'),
              if (detail.totalEps > 0) _chip(context, '${detail.totalEps} EPS'),
              if (item.rating != null && item.rating!.isNotEmpty)
                _chip(context, '${item.rating}★'),
              if (item.type != null && item.type!.isNotEmpty)
                _chip(context, item.type!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: context.appOutline),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: context.appTextTheme.labelSmall?.copyWith(
          fontSize: 10,
          letterSpacing: 1,
          color: context.appOnSurface,
        ),
      ),
    );
  }

  void _play(
    BuildContext context,
    AnimeItem item,
    Episode episode,
    bool dub,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          item: item,
          ep: episode.ep,
          dub: dub,
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
    required this.onTap,
  });

  final Episode episode;
  final bool hasDub;
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
            onTap: () => onTap(false),
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
                        'PLAY',
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
        const Divider(
          height: 1,
          thickness: 1,
          color: context.appOutlineVariant,
        ),
      ],
    );
  }
}