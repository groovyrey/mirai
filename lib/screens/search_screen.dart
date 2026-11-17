import 'dart:async';

import 'package:flutter/material.dart';

import '../models/anime_item.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../widgets/anime_card.dart';
import 'detail_screen.dart';

/// Search: a full-width query field plus the poster grid results.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.autofocus = false,
    this.showBackButton = false,
  });

  final bool autofocus;
  final bool showBackButton;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final CatalogService _catalog = CatalogService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  List<AnimeItem>? _results;
  bool _searching = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      setState(() {
        _results = null;
        _error = null;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _run(query));
  }

  Future<void> _run(String query) async {
    if (!mounted) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await _catalog.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'No signal.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Row(
              children: [
                if (widget.showBackButton) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: context.appOnSurfaceVariant,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  'Search',
                  style: context.appTextTheme.displayMedium?.copyWith(
                    color: context.appOnSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              style: context.appTextTheme.titleMedium?.copyWith(
                color: context.appOnSurface,
              ),
              cursorColor: context.appAccent,
              decoration: InputDecoration(
                hintText: 'Title, genre, name',
                hintStyle: context.appTextTheme.labelSmall?.copyWith(
                  letterSpacing: 1.5,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: _searching ? context.appAccent : context.appOnSurfaceVariant,
                ),
                filled: true,
                fillColor: context.appSurface,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                  borderSide: BorderSide(color: context.appOutline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                  borderSide: BorderSide(color: context.appOutline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                  borderSide: BorderSide(color: context.appAccent, width: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: context.appTextTheme.bodyMedium,
        ),
      );
    }
    final results = _results;
    if (results == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Type at least three letters\nto tune the feed.',
            textAlign: TextAlign.center,
            style: context.appTextTheme.labelSmall?.copyWith(
              fontSize: 12,
              height: 1.6,
              letterSpacing: 1,
            ),
          ),
        ),
      );
    }
    if (results.isEmpty) {
      return Center(
        child: Text(
          'Nothing on this channel.',
          style: context.appTextTheme.labelSmall?.copyWith(
            letterSpacing: 1,
          ),
        ),
      );
    }
    return GridView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 18,
        crossAxisSpacing: 12,
        childAspectRatio: 0.5,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return AnimeCard(
          item: item,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => DetailScreen(item: item)),
          ),
        );
      },
    );
  }
}