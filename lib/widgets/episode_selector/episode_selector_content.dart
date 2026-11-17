import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/anime_item.dart';
import '../../services/catalog_service.dart';
import 'episode_selector_body.dart';
import 'episode_selector_fields.dart';

class EpisodeSelectorContent extends StatefulWidget {
  const EpisodeSelectorContent({
    super.key,
    required this.item,
    required this.currentEpisode,
    required this.episodes,
    required this.defaultDub,
  });

  final AnimeItem item;
  final int currentEpisode;
  final List<Episode>? episodes;
  final bool defaultDub;

  @override
  State<EpisodeSelectorContent> createState() => _EpisodeSelectorContentState();
}

class _EpisodeSelectorContentState extends State<EpisodeSelectorContent> {
  static const _episodesPerPage = 10;

  late final TextEditingController _controller;
  List<Episode> _episodes = const [];
  int _visibleEps = _episodesPerPage;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    final episodes = widget.episodes;
    if (episodes == null || episodes.isEmpty) {
      _loading = true;
      unawaited(_loadEpisodes());
      return;
    }
    _episodes = episodes;
    _visibleEps = _episodesPerPage;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadEpisodes() async {
    try {
      final detail = await CatalogService().detail(
        widget.item.id,
        widget.item.slug,
      );
      if (!mounted) return;
      setState(() {
        _episodes = detail.episodes;
        _visibleEps = _episodesPerPage;
        _error = null;
        _loading = false;
      });
    } on CatalogFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final matches = query.isEmpty
        ? _episodes
        : _episodes
            .where((episode) => episode.ep.toString().contains(query))
            .toList();
    final visibleMatches = query.isEmpty && matches.length > _visibleEps
        ? matches.sublist(0, _visibleEps)
        : matches;
    final remaining = matches.length - visibleMatches.length;
    final hasDub = _episodes.any((episode) => episode.dub);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EpisodeSearchField(
          controller: _controller,
          onChanged: () => setState(() {}),
        ),
        Flexible(
          fit: FlexFit.loose,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxBodyHeight = constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 360.0;
              final body = EpisodeSelectorBody(
                loading: _loading,
                error: _error,
                matches: visibleMatches,
                hasDub: hasDub,
                query: query,
                remaining: remaining,
                perPage: _episodesPerPage,
                currentEpisode: widget.currentEpisode,
                defaultDub: widget.defaultDub,
                onSelected: (selection) => Navigator.pop(context, selection),
                onLoadMore: () => setState(() {
                  _visibleEps += _episodesPerPage;
                }),
              );
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxBodyHeight),
                child: SingleChildScrollView(child: body),
              );
            },
          ),
        ),
      ],
    );
  }
}
