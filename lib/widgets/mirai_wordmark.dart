import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Mirai's wordmark: the squared logo mark plus a wide display glyph. Distinct
/// from Kumi's rounded mark — this reads like broadcast identification.
class MiraiWordmark extends StatelessWidget {
  const MiraiWordmark({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/logo/mirai_logo.png',
          width: size * 0.9,
          height: size * 0.9,
          fit: BoxFit.contain,
        ),
        SizedBox(width: size * 0.35),
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