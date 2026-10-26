import 'package:flutter/material.dart';
import 'package:work_time/domain/work_entry.dart';

class MonthSummaryPanel extends StatelessWidget {
  const MonthSummaryPanel({
    super.key,
    required this.summary,
    required this.loaded,
  });
  final MonthSummary summary;
  final bool loaded;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _summaryCard(context, '실근무', loaded ? durationText(summary.work) : '—'),
      _summaryCard(context, '휴가', loaded ? durationText(summary.leave) : '—'),
      _summaryCard(
        context,
        '초과근무',
        loaded ? durationText(summary.overtime) : '—',
      ),
      _summaryCard(
        context,
        '채워야 할 시간 (완료 기록)',
        loaded ? durationText(summary.remaining) : '—',
      ),
      _summaryCard(
        context,
        '완료 / 진행 중',
        loaded ? '${summary.completed}일 / ${summary.pending}일' : '—',
      ),
    ],
  );
  Widget _summaryCard(BuildContext context, String label, String value) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ),
  );
}
