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
        Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * 0.12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: context.appOutline),
          ),
          child: Image.asset(
            'assets/logo/mirai_logo.png',
            fit: BoxFit.contain,
          ),
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