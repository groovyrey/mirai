import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/anime_item.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
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
  late final TextEditingController _controller;
  List<Episode> _episodes = const [];
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
    final hasDub = _episodes.any((episode) => episode.dub);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EpisodeSearchField(
          controller: _controller,
          onChanged: () => setState(() {}),
        ),
        if (_loading)
          Expanded(
            child: Center(
              child: CircularProgressIndicator(color: context.appAccent),
            ),
          )
        else if (_error != null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: context.appTextTheme.bodyMedium?.copyWith(
                  color: context.appOnSurfaceVariant,
                ),
              ),
            ),
          )
        else if (_episodes.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No episodes are available for this title.',
                style: context.appTextTheme.bodyMedium?.copyWith(
                  color: context.appOnSurfaceVariant,
                ),
              ),
            ),
          )
        else if (matches.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No episode matches "$query".',
                style: context.appTextTheme.bodyMedium?.copyWith(
                  color: context.appOnSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: matches.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                color: context.appOutline,
              ),
              itemBuilder: (context, index) => EpisodeTile(
                episode: matches[index],
                currentEpisode: widget.currentEpisode,
                defaultDub: widget.defaultDub,
                hasDub: hasDub,
                onSelected: (selection) => Navigator.pop(context, selection),
              ),
            ),
          ),
      ],
    );
  }
}
