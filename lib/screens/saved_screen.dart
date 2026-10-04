import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/anime_item.dart';
import '../services/saved.dart';
import '../services/watch_history.dart';
import '../theme/app_theme.dart';
import '../widgets/anime_card.dart';
import 'detail_screen.dart';
import 'player_screen.dart';

/// Saved: the "my list" queue. Two stacked blocks — continue watching first
/// (with resume bar), then the full saved library. Empty states lean on the
/// night-broadcast copy.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

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
              'MY LIST',
              style: context.appTextTheme.displayMedium?.copyWith(
                color: context.appOnSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ChangeNotifierProvider.value(
              value: Saved.instance,
              child: ChangeNotifierProvider.value(
                value: WatchHistory.instance,
                child: const _SavedBody(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedBody extends StatefulWidget {
  const _SavedBody();

  @override
  State<_SavedBody> createState() => _SavedBodyState();
}

class _SavedBodyState extends State<_SavedBody> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.wait([
      Saved.instance.ensureLoaded(),
      WatchHistory.instance.ensureLoaded(),
    ]).then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final history =
        context.select<WatchHistory, List<HistoryEntry>>((s) => s.entries);
    final saved = context.select<Saved, List<AnimeDetail>>((s) => s.items);
    final nothing = history.isEmpty && saved.isEmpty;

    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (nothing)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOTHING SAVED YET.',
                  style: context.appTextTheme.titleMedium?.copyWith(
                    color: context.appOnSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bookmark a title or start an episode and it shows up here.',
                  style: context.appTextTheme.bodyMedium,
                ),
              ],
            ),
          ),
        if (history.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: SectionLabel(text: 'CONTINUE WATCHING'),
          ),
          for (final entry in history.take(8))
            _ContinueTile(entry: entry, onTap: () => _resume(context, entry)),
        ],
        if (saved.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: SectionLabel(text: 'IN THE QUEUE'),
          ),
          for (final detail in saved.take(60)) _SavedTile(detail: detail),
        ],
      ],
    );
  }

  void _resume(BuildContext context, HistoryEntry entry) {
    AnimeDetail? detail;
    final saved = Saved.instance.items;
    for (var i = 0; i < saved.length; i++) {
      if (saved[i].item.id == entry.item.id) {
        detail = saved[i];
        break;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          item: entry.item,
          ep: entry.ep,
          dub: entry.dub,
          subtitle: 'EP ${entry.ep}',
          initialPosition: Duration(milliseconds: entry.resumePosition),
          episodes: detail?.episodes,
        ),
      ),
    );
  }
}

class _ContinueTile extends StatelessWidget {
  const _ContinueTile({required this.entry, required this.onTap});

  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = entry.progress.clamp(0.02, 1.0);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextTheme.titleMedium?.copyWith(
                      color: context.appOnSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'EP ${entry.ep.toString().padLeft(2, '0')}',
                        style: context.appTextTheme.labelSmall?.copyWith(
                          color: context.appAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(height: 3, width: 66, color: context.appOutline),
                      Expanded(
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(height: 3, color: context.appAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.play_circle_outline_rounded,
                color: context.appOnSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile({required this.detail});

  final AnimeDetail detail;

  @override
  Widget build(BuildContext context) {
    final item = detail.item;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => DetailScreen(item: item)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 60,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: item.hasImage
                    ? CachedNetworkImage(
                        imageUrl: item.image!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: context.appSurfaceVariant,
                        ),
                      )
                    : ColoredBox(color: context.appSurfaceVariant),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextTheme.labelMedium?.copyWith(
                      color: context.appOnSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${detail.subEps > 0 ? 'S${detail.subEps}' : ''}'
                    '${detail.dubEps > 0 ? ' · D${detail.dubEps}' : ''}'
                    '${detail.totalEps > 0 ? ' · ${detail.totalEps} EPS' : ''}',
                    style: context.appTextTheme.labelSmall?.copyWith(
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.appOnSurfaceVariant),
          ],
        ),
      ),
    );
  }
}