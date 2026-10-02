import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Mirai's wordmark: a wide display glyph plus a volt slash. Distinct from
/// Kumi's rounded mark — this reads like broadcast identification.
class MiraiWordmark extends StatelessWidget {
  const MiraiWordmark({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: size * 0.18,
          height: size * 0.9,
          color: context.appAccent,
        ),
        const SizedBox(width: size * 0.12),
        Text(
          'MIRAI',
          style: context.appTextTheme.displayMedium?.copyWith(
            fontSize: size,
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: 0.02,
            color: context.appOnSurface,
          ),
        ),
      ],
    );
  }
}