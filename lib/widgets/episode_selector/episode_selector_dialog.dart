import 'package:flutter/material.dart';

import '../../models/anime_item.dart';
import '../app_modal.dart';
import 'episode_selection.dart';
import 'episode_selector_content.dart';

class EpisodeSelectorDialog extends AppModal<EpisodeSelection> {
  const EpisodeSelectorDialog({
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
  Future<EpisodeSelection?> show(BuildContext context) {
    return AppDialog<EpisodeSelection>(
      title: 'Select episode',
      builder: (_) => EpisodeSelectorContent(
        item: item,
        currentEpisode: currentEpisode,
        episodes: episodes,
        defaultDub: defaultDub,
      ),
    ).show(context);
  }
}
