import 'package:daily_you/models/entry.dart';
import 'package:daily_you/widgets/mood_icon.dart';
import 'package:flutter/material.dart';

/// Compact overview card showing key stats for a date range:
/// entry count, completion rate, and average mood with trend indicator.
class MonthOverviewCard extends StatelessWidget {
  final List<Entry> entriesInRange;
  final int totalDaysInRange;

  const MonthOverviewCard({
    super.key,
    required this.entriesInRange,
    required this.totalDaysInRange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (entriesInRange.isEmpty) return const SizedBox.shrink();

    final entriesWithMood =
        entriesInRange.where((e) => e.mood != null).toList();

    // Entry count + distinct days
    final distinctDays = entriesInRange
        .map((e) =>
            '${e.timeCreate.year}-${e.timeCreate.month}-${e.timeCreate.day}')
        .toSet()
        .length;

    // Average mood
    final double? avgMood = entriesWithMood.isNotEmpty
        ? entriesWithMood.map((e) => e.mood!).reduce((a, b) => a + b) /
            entriesWithMood.length
        : null;

    // Completion rate
    final completionRate = totalDaysInRange > 0
        ? (distinctDays / totalDaysInRange).clamp(0.0, 1.0)
        : 0.0;

    return Card.filled(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Entry count
            _StatColumn(
              value: '${entriesInRange.length}',
              label: 'Entries',
              icon: Icons.edit_note_rounded,
              theme: theme,
            ),
            const SizedBox(width: 8),
            // Completion: distinct days / total days
            Expanded(
              child: _StatColumn(
                value: '$distinctDays/$totalDaysInRange',
                label: 'Days',
                icon: Icons.calendar_month_rounded,
                theme: theme,
                progress: completionRate,
              ),
            ),
            const SizedBox(width: 8),
            // Average mood
            _StatColumn(
              value: avgMood != null
                  ? MoodIcon.getMoodIcon(avgMood.round().clamp(-2, 2))
                  : '–',
              rawValue: avgMood,
              label: 'Avg Mood',
              icon: Icons.sentiment_satisfied_alt_rounded,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final double? rawValue;
  final String label;
  final IconData icon;
  final ThemeData theme;
  final double? progress;

  const _StatColumn({
    required this.value,
    this.rawValue,
    required this.label,
    required this.icon,
    required this.theme,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
          ),
        ),
        if (progress != null) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: 48,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.15),
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
