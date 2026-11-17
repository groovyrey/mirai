import 'package:flutter/material.dart';

import '../../models/anime_item.dart';
import '../../theme/app_theme.dart';
import 'episode_selection.dart';

class EpisodeSearchField extends StatelessWidget {
  const EpisodeSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.search,
        style: context.appTextTheme.bodyMedium?.copyWith(
          color: context.appOnSurface,
        ),
        cursorColor: context.appAccent,
        decoration: InputDecoration(
          hintText: 'Search episode number',
          hintStyle: context.appTextTheme.bodyMedium?.copyWith(
            color: context.appOnSurfaceVariant,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: context.appOnSurfaceVariant,
          ),
          filled: true,
          fillColor: context.appSurfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

class EpisodeTile extends StatelessWidget {
  const EpisodeTile({
    super.key,
    required this.episode,
    required this.currentEpisode,
    required this.defaultDub,
    required this.hasDub,
    required this.onSelected,
  });

  final Episode episode;
  final int currentEpisode;
  final bool defaultDub;
  final bool hasDub;
  final void Function(EpisodeSelection selection) onSelected;

  @override
  Widget build(BuildContext context) {
    final current = episode.ep == currentEpisode;
    final dubAvailable = episode.dub && hasDub;
    final subAvailable = episode.sub;
    final dub = defaultDub ? dubAvailable : !subAvailable && dubAvailable;
    final tracks = <String>[
      if (subAvailable) 'SUB',
      if (dubAvailable) 'DUB',
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(
          EpisodeSelection(episode: episode, dub: dub),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 48,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Episode ${episode.ep}',
                      style: context.appTextTheme.titleMedium?.copyWith(
                        color: context.appOnSurface,
                      ),
                    ),
                    if (tracks.isNotEmpty)
                      Text(
                        tracks.join('  '),
                        style: context.appTextTheme.labelSmall?.copyWith(
                          color: context.appOnSurfaceVariant,
                          letterSpacing: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
              if (current)
                Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: context.appAccent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EpisodeLoadMoreButton extends StatelessWidget {
  const EpisodeLoadMoreButton({
    super.key,
    required this.nextCount,
    required this.onPressed,
  });

  final int nextCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: context.appAccent,
            side: BorderSide(color: context.appOutline),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
          ),
          child: Text(
            'Load $nextCount more',
            style: context.appTextTheme.labelSmall?.copyWith(
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
