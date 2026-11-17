import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});

  static const _qrAsset = 'assets/IMG_0965.jpeg';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: context.appOnSurfaceVariant,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Text(
                  'Support',
                  style: context.appTextTheme.titleLarge?.copyWith(
                    color: context.appOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Donate with GCash',
              style: context.appTextTheme.titleMedium?.copyWith(
                color: context.appOnSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open GCash, tap Scan QR, and scan the code below.',
              style: context.appTextTheme.bodyMedium?.copyWith(
                color: context.appOnSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Image.asset(
                _qrAsset,
                width: double.infinity,
                fit: BoxFit.contain,
                semanticLabel: 'GCash QR code for donations',
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Thank you for supporting Mirai.',
              style: context.appTextTheme.bodySmall?.copyWith(
                color: context.appOnSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
