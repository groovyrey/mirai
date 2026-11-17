import 'package:flutter/material.dart';

import '../../models/anime_item.dart';
import '../../theme/app_theme.dart';
import 'episode_selection.dart';
import 'episode_selector_fields.dart';

class EpisodeSelectorBody extends StatelessWidget {
  const EpisodeSelectorBody({
    super.key,
    required this.loading,
    this.error,
    required this.matches,
    required this.hasDub,
    required this.query,
    required this.remaining,
    required this.perPage,
    required this.currentEpisode,
    required this.defaultDub,
    required this.onSelected,
    required this.onLoadMore,
  });

  final bool loading;
  final String? error;
  final List<Episode> matches;
  final bool hasDub;
  final String query;
  final int remaining;
  final int perPage;
  final int currentEpisode;
  final bool defaultDub;
  final void Function(EpisodeSelection selection) onSelected;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: 180,
        child: Center(
          child: CircularProgressIndicator(color: context.appAccent),
        ),
      );
    }
    if (error != null) {
      return _message(context, error!);
    }
    if (matches.isEmpty) {
      return _message(
        context,
        query.isEmpty
            ? 'No episodes are available for this title.'
            : 'No episode matches "$query".',
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: matches.length + (remaining > 0 ? 1 : 0),
      separatorBuilder: (_, index) {
        if (remaining > 0 && index == matches.length - 1) {
          return const SizedBox(height: 8);
        }
        return Divider(height: 1, thickness: 1, color: context.appOutline);
      },
      itemBuilder: (context, index) {
        if (index == matches.length) {
          final nextCount = remaining < perPage ? remaining : perPage;
          return EpisodeLoadMoreButton(
            nextCount: nextCount,
            onPressed: onLoadMore,
          );
        }
        return EpisodeTile(
          episode: matches[index],
          currentEpisode: currentEpisode,
          defaultDub: defaultDub,
          hasDub: hasDub,
          onSelected: onSelected,
        );
      },
    );
  }

  Widget _message(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.appTextTheme.bodyMedium?.copyWith(
          color: context.appOnSurfaceVariant,
        ),
      ),
    );
  }
}
