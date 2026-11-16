import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/anime_item.dart';
import '../services/catalog_service.dart';
import '../services/saved.dart';
import '../services/watch_history.dart';
import '../theme/app_theme.dart';
import '../widgets/anime_card.dart';
import 'detail_screen.dart';
import 'player_screen.dart';
import 'trending_screen.dart';

/// Home = the "tonight" signal row (top trending) framed by secondary rails.
/// The vertical rhythm is editorial: a lead block, then dense poster rails.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final CatalogService _catalog = CatalogService();
  final Saved _saved = Saved.instance;
  final WatchHistory _history = WatchHistory.instance;

  List<AnimeItem>? _lead;
  List<AnimeItem>? _rail;
  List<AnimeItem>? _newest;
  List<HistoryEntry>? _continueWatching;
  List<SavedEntry>? _queue;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _saved.addListener(_onStoresChanged);
    _history.addListener(_onStoresChanged);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saved.removeListener(_onStoresChanged);
    _history.removeListener(_onStoresChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // A long background stint is the common way a saved title picks up new
    // episodes, so refresh the queue snapshots as soon as the app comes back.
    _refreshQueue();
  }

  /// The stored queue detail is the snapshot captured when the title was
  /// saved, so airing shows need a fresh fetch to pick up new episodes.
  void _refreshQueue() {
    unawaited(
      _saved.refreshDetails(
        (item) => _catalog.detail(item.id, item.slug),
        limit: 10,
        onlyAiring: true,
      ),
    );
  }

  void _onStoresChanged() {
    if (!mounted) return;
    setState(() {
      _queue = _saved.entries.take(10).toList();
      _continueWatching = _history.entries.take(10).toList();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Local stores first so the queue and continue rail can render even when
    // the catalog request fails.
    await Future.wait([
      _saved.ensureLoaded(),
      _history.ensureLoaded(),
    ]);
    if (!mounted) return;
    setState(() {
      _queue = _saved.entries.take(10).toList();
      _continueWatching = _history.entries.take(10).toList();
    });
    _refreshQueue();
    try {
      final results = await Future.wait([
        _catalog.rail('trending'),
        _catalog.rail('updated'),
        _catalog.rail('newest'),
      ]);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _lead = results[0];
        _rail = results[1];
        _newest = results[2];
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'The broadcast is down.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _intro(context),
          if (_loading && _lead == null) _loadingState(context),
          if (_error != null) _errorState(context),
          if (_lead != null) _leadSection(context),
          if (_rail != null) _railSection(context),
          if (_newest != null) _newestSection(context),
          if (_continueWatching != null) _continueSection(context),
          if (_queue != null) _queueSection(context),
        ],
      ),
    );
  }

  Widget _intro(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Text(
        'What\'s on\ntonight',
        style: context.appTextTheme.displayMedium?.copyWith(
          color: context.appOnSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _leadSection(BuildContext context) {
    final leads = _lead!.take(5).toList();
    if (leads.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: SectionLabel(
            text: 'Top 5',
            onMore: () => _openTrending(context),
          ),
        ),
        SizedBox(
          height: 214,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: leads.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(
              width: 320,
              child: LeadCard(
                item: leads[i],
                rank: i + 1,
                onTap: () => _openDetail(context, leads[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _railSection(BuildContext context) {
    final rail = _rail!.take(10).toList();
    if (rail.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
          child: SectionLabel(text: 'Recently on'),
        ),
        SizedBox(
          height: 236,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: rail.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(
              width: 132,
              child: AnimeCard(
                item: rail[i],
                onTap: () => _openDetail(context, rail[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _newestSection(BuildContext context) {
    final newest = _newest!.take(10).toList();
    if (newest.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
          child: SectionLabel(text: 'Newest'),
        ),
        SizedBox(
          height: 236,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: newest.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(
              width: 132,
              child: AnimeCard(
                item: newest[i],
                onTap: () => _openDetail(context, newest[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _continueSection(BuildContext context) {
    final entries = _continueWatching ?? [];
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
          child: SectionLabel(text: 'Continue watching'),
        ),
        SizedBox(
          height: 236,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final entry = entries[i];
              return SizedBox(
                width: 132,
                child: _ContinueCard(
                  entry: entry,
                  onTap: () => _resume(context, entry),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _queueSection(BuildContext context) {
    final entries = _queue ?? [];
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
          child: SectionLabel(text: 'Your queue'),
        ),
        SizedBox(
          height: 236,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final entry = entries[i];
              final detail = entry.detail;
              return SizedBox(
                width: 132,
                child: _QueueCard(
                  detail: detail,
                  onTap: () => _openDetail(context, detail.item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _loadingState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            'Loading the lineup',
            style: context.appTextTheme.labelSmall?.copyWith(
              color: context.appOnSurfaceVariant,
              letterSpacing: 2,
            ),
          ),
        ),
        SizedBox(
          height: 236,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => const SizedBox(
              width: 132,
              child: _SkeletonCard(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _error!,
            style: context.appTextTheme.titleMedium?.copyWith(
              color: context.appOnSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to retry the feed.',
            style: context.appTextTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, AnimeItem item, {int? ep, bool? dub}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailScreen(
          item: item,
          initialEp: ep,
          initialDub: dub,
        ),
      ),
    );
  }

  /// Resumes the last watched episode exactly where it stopped, going straight
  /// to the player rather than routing through the info page.
  void _resume(BuildContext context, HistoryEntry entry) {
    AnimeDetail? detail;
    for (final saved in _saved.entries) {
      if (saved.detail.item.id == entry.item.id) {
        detail = saved.detail;
        break;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          item: entry.item,
          ep: entry.ep,
          dub: entry.dub,
          initialPosition: Duration(milliseconds: entry.resumePosition),
          episodes: detail?.episodes,
        ),
      ),
    );
  }

  void _openTrending(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: context.appBackground,
          body: TrendingScreen(
            header: 'Trending',
          ),
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.entry,
    required this.onTap,
  });

  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = entry.progress;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: context.appSurfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: context.appOutline),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: entry.item.image ?? '',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorWidget: (_, __, ___) => Container(
                        color: context.appSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                if (progress > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(AppRadius.card),
                        ),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.appAccent,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(AppRadius.card),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appTextTheme.labelMedium?.copyWith(
                color: context.appOnSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'EP ${entry.ep}${entry.dub ? ' DUB' : ' SUB'}',
              style: context.appTextTheme.labelSmall?.copyWith(
                color: context.appOnSurfaceVariant,
                fontSize: 10,
              ),
            ),
            if (progress > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${(progress * 100).round()}% watched',
                style: context.appTextTheme.labelSmall?.copyWith(
                  color: context.appAccent,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.detail,
    required this.onTap,
  });

  final AnimeDetail detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final eps = detail.episodeCount;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: context.appSurfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: context.appOutline),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: detail.item.image ?? '',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorWidget: (_, __, ___) => Container(
                        color: context.appSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                if (eps > 0)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Text(
                      '$eps EPS',
                      style: context.appTextTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 11,
                        letterSpacing: 0.6,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              detail.item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appTextTheme.labelMedium?.copyWith(
                color: context.appOnSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.appSurfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 10,
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.appSurfaceVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}