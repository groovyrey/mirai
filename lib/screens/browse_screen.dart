import 'package:flutter/material.dart';

import '../models/anime_item.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../widgets/anime_card.dart';
import 'detail_screen.dart';

/// The full catalogue, browseable by first letter (or ALL for the master
/// listing). Each selection paginates through the worker as the user scrolls.
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  static const _letters = [
    'ALL', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  final CatalogService _catalog = CatalogService();
  final ScrollController _scroll = ScrollController();

  final List<AnimeItem> _items = [];
  String _letter = 'ALL';
  int _page = 1;
  int _generation = 0;
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _done || !mounted) return;
    final gen = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final isAll = _letter == 'ALL';
      final results = await _catalog.rail(
        isAll ? 'trending' : 'az',
        page: _page,
        letter: isAll ? null : _letter,
      );
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(results);
        _done = results.isEmpty;
        _page += 1;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _loading = false;
        _error = 'The broadcast is down.';
      });
    }
  }

  void _maybeLoadMore() {
    if (_scroll.position.extentAfter < 400) _load();
  }

  void _selectLetter(String letter) {
    if (letter == _letter) return;
    setState(() {
      _letter = letter;
      _items.clear();
      _page = 1;
      _done = false;
      _loading = false;
      _error = null;
      _generation += 1;
    });
    _scroll.jumpTo(0);
    _load();
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
              'BROWSE ALL',
              style: context.appTextTheme.displayMedium?.copyWith(
                color: context.appOnSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              children: [
                for (final letter in _letters)
                  _letterTab(context, letter),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Expanded(
            child: _error != null && _items.isEmpty
                ? _errorState(context)
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: GridView.builder(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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

  Widget _letterTab(BuildContext context, String letter) {
    final active = letter == _letter;
    return GestureDetector(
      onTap: () => _selectLetter(letter),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Center(
                child: Text(
                  letter,
                  style: context.appTextTheme.labelSmall?.copyWith(
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    color: active ? context.appAccent : context.appOnSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (active)
              Container(
                height: 2,
                width: 16,
                decoration: BoxDecoration(
                  color: context.appAccent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _page = 1;
      _done = false;
      _loading = false;
      _error = null;
      _generation += 1;
    });
    _scroll.jumpTo(0);
    await _load();
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