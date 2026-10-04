import 'dart:async';

import 'package:flutter/material.dart';

import '../services/broadcast_schedule.dart';
import '../theme/app_theme.dart';

/// Live countdown to the next predicted airing for titles that are currently
/// airing. Ticks every second while the screen is visible and stops the timer
/// on dispose, so it never burns battery in the background. Renders nothing
/// for finished (or otherwise not currently airing) titles.
class NextEpisodeCountdown extends StatefulWidget {
  const NextEpisodeCountdown({
    super.key,
    required this.broadcast,
    required this.status,
  });

  final String broadcast;
  final String status;

  @override
  State<NextEpisodeCountdown> createState() => _NextEpisodeCountdownState();
}

class _NextEpisodeCountdownState extends State<NextEpisodeCountdown> {
  DateTime? _next;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_isAiring(widget.status)) {
      _next = BroadcastSchedule.nextAiringUtc(widget.broadcast);
    }
    if (_next != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _isAiring(String status) {
    final s = status.toLowerCase();
    if (s.isEmpty) return false;
    if (s.contains('finish') ||
        s.contains('completed') ||
        s.contains('ended')) {
      return false;
    }
    return s.contains('air') || s.contains('ongoing');
  }

  @override
  Widget build(BuildContext context) {
    final next = _next;
    if (next == null) return const SizedBox.shrink();
    final remaining = next.difference(DateTime.now().toUtc());
    final countdown = remaining > Duration.zero
        ? BroadcastSchedule.countdownText(remaining)
        : 'Airing now';
    final airingLabel = BroadcastSchedule.airingLabel(next);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: context.appOutline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT EPISODE',
            style: context.appTextTheme.labelSmall?.copyWith(
              color: context.appOnSurfaceVariant,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            countdown,
            style: context.appTextTheme.displayMedium?.copyWith(
              color: context.appAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Predicted $airingLabel',
            style: context.appTextTheme.bodySmall?.copyWith(
              color: context.appOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}