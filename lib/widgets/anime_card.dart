import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/anime_item.dart';
import '../theme/app_theme.dart';

/// A compact poster card used across rails and grids.
class AnimeCard extends StatelessWidget {
  const AnimeCard({super.key, required this.item, this.rank, this.onTap});

  final AnimeItem item;
  final int? rank;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: item.hasImage
                      ? CachedNetworkImage(
                          imageUrl: item.image!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _placeholder(context),
                        )
                      : _placeholder(context),
                ),
              ),
              if (rank != null)
                Positioned(
                  left: 6,
                  bottom: 4,
                  child: Text(
                    rank.toString().padLeft(2, '0'),
                    style: context.appTextTheme.displayMedium?.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 0.9,
                      color: context.appAccent,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.appTextTheme.labelMedium?.copyWith(
              color: context.appOnSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            [item.type, item.rating].where((s) => s?.isNotEmpty ?? false).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.appTextTheme.labelSmall?.copyWith(
              fontSize: 10,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: context.appSurfaceVariant,
      child: Center(
        child: Text(
          'MIRAI',
          style: context.appTextTheme.labelSmall?.copyWith(
            letterSpacing: 3,
            color: context.appOnSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A fine-hairline section label used above rails.
class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.text,
    this.onMore,
    this.moreLabel = 'VIEW ALL',
  });

  final String text;
  final VoidCallback? onMore;
  final String moreLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 12,
          decoration: BoxDecoration(
            color: context.appAccent,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: context.appTextTheme.labelSmall?.copyWith(
            color: context.appOnSurface,
            letterSpacing: 2,
          ),
        ),
        const Spacer(),
        if (onMore != null)
          GestureDetector(
            onTap: onMore,
            child: Text(
              moreLabel,
              style: context.appTextTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: context.appOnSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// A large ranked lead card for the home "tonight" row.
class LeadCard extends StatelessWidget {
  const LeadCard({super.key, required this.item, required this.rank, this.onTap});

  final AnimeItem item;
  final int rank;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.hasImage)
                CachedNetworkImage(
                  imageUrl: item.image!,
                  fit: BoxFit.cover,
                )
              else
                ColoredBox(color: context.appSurfaceVariant),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NO. ${rank.toString().padLeft(2, '0')}',
                      style: context.appTextTheme.labelSmall?.copyWith(
                        color: context.appAccent,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [item.type, item.rating]
                          .where((s) => s?.isNotEmpty ?? false)
                          .join(' · '),
                      style: context.appTextTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}