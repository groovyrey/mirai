import 'package:flutter/material.dart';

import '../models/anime_item.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../widgets/anime_card.dart';
import 'detail_screen.dart';

/// A ranked, paged grid of the trending slate. Uses a custom "MIRAIGRID"
/// counter mode — named after the broadcast grid aesthetic.
class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key, this.header = 'TRENDING'});

  final String header;

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  final CatalogService _catalog = CatalogService();
  final ScrollController _scroll = ScrollController();

  final List<AnimeItem> _items = [];
  int _page = 1;
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || _done || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _catalog.rail('trending', page: _page);
      if (!mounted) return;
      setState(() {
        _items.addAll(results);
        _done = results.isEmpty;
        _page += 1;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The broadcast is down.';
      });
    }
  }

  void _maybeLoadMore() {
    if (_scroll.position.extentAfter < 400) _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
            child: Text(
              widget.header,
              style: context.appTextTheme.displayMedium?.copyWith(
                color: context.appOnSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: _error != null && _items.isEmpty
                ? _errorState(context)
                : RefreshIndicator(
                    onRefresh: () async {
                      final wasDone = _done;
                      setState(() {
                        _items.clear();
                        _page = 1;
                        _done = false;
                      });
                      await _load(reset: true);
                      if (!mounted) return;
                      // Restore pagination state if the reset was a no-op.
                      if (wasDone && _done && _items.isEmpty) {
                        setState(() => _done = false);
                      }
                    },
                    child: GridView.builder(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.5,
                      ),
                      itemCount: _items.length + (_loading ? 6 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _items.length) {
                          return const _SkeletonCard();
                        }
                        final item = _items[index];
                        return AnimeCard(
                          item: item,
                          rank: index + 1,
                          onTap: () => _openDetail(context, item),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error!,
            style: context.appTextTheme.titleMedium?.copyWith(
              color: context.appOnSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pull down to retry.',
            style: context.appTextTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, AnimeItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DetailScreen(item: item)),
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
        const SizedBox(height: 6),
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