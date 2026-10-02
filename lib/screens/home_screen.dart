import 'package:flutter/material.dart';

import '../models/anime_item.dart';
import '../services/catalog_service.dart';
import '../services/saved.dart';
import '../services/watch_history.dart';
import '../theme/app_theme.dart';
import '../widgets/anime_card.dart';
import 'detail_screen.dart';
import 'trending_screen.dart';

/// Home = the "tonight" signal row (top trending) framed by secondary rails.
/// The vertical rhythm is editorial: a lead block, then dense poster rails.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CatalogService _catalog = CatalogService();
  final Saved _saved = Saved.instance;
  final WatchHistory _history = WatchHistory.instance;

  List<AnimeItem>? _lead;
  List<AnimeItem>? _rail;
  List<AnimeItem>? _newest;
  List<WatchHistory.HistoryEntry>? _continueWatching;
  List<Saved.SavedEntry>? _queue;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Ensure local stores are loaded
      await Future.wait([
        _saved.ensureLoaded(),
        _history.ensureLoaded(),
      ]);

      final results = await Future.wait([
        _catalog.rail('trending'),
        _catalog.rail('updated'),
        _catalog.rail('newest'),
      ]);
      if (!mounted) return;
      setState(() {
        _lead = results[0];
        _rail = results[1];
        _newest = results[2];
        _continueWatching = _history.entries.take(10).toList();
        _queue = _saved.entries.take(10).toList();
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'The broadcast is down.');
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
        'WHAT\'S ON\nTONIGHT',
        style: context.appTextTheme.displayMedium?.copyWith(
          color: context.appOnSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _leadSection(BuildContext context) {
    final leads = _lead!.take(4).toList();
    if (leads.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: SectionLabel(
            text: 'TOP SIGNAL',
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
          child: SectionLabel(text: 'RECENTLY ON'),
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
          child: SectionLabel(text: 'NEWEST'),
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
          child: SectionLabel(text: 'CONTINUE WATCHING'),
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
                  onTap: () => _openDetail(
                    context,
                    entry.item,
                    ep: entry.ep,
                    dub: entry.dub,
                  ),
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
          child: SectionLabel(text: 'YOUR QUEUE'),
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
              final nextEp = detail.nextEpisode;
              return SizedBox(
                width: 132,
                child: _QueueCard(
                  detail: detail,
                  nextEp: nextEp,
                  onTap: () => _openDetail(
                    context,
                    detail.item,
                    ep: nextEp?.ep ?? 1,
                    dub: false,
                  ),
                ),
              );
            },
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

  void _openTrending(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: context.appBackground,
          body: TrendingScreen(
            header: 'TRENDING',
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

  final WatchHistory.HistoryEntry entry;
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: Image.network(
                      entry.item.image,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
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
                        color: Colors.black.withOpacity(0.5),
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
    required this.nextEp,
    required this.onTap,
  });

  final AnimeDetail detail;
  final Episode? nextEp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Image.network(
                  detail.item.image,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
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
            if (nextEp != null) ...[
              const SizedBox(height: 2),
              Text(
                'Next: EP ${nextEp!.ep}${nextEp!.dub ? ' DUB' : ' SUB'}',
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