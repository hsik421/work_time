import 'package:flutter/material.dart';
import 'package:work_time/domain/work_entry.dart';
import 'package:work_time/features/attendance/view_models/work_time_view_model.dart';
import 'package:work_time/shared/presentation/work_colors.dart';

import '../widgets/entry_editor.dart';
import '../widgets/animated_day_item.dart';

class DayListPanel extends StatelessWidget {
  const DayListPanel({super.key, required this.model, required this.onSelect});
  final WorkTimeViewModel model;
  final ValueChanged<DateTime> onSelect;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('날짜별 기록', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final date in model.dates) ...[
            AnimatedDayItem(
              key: ValueKey('animated-day-${dateKey(date)}'),
              header: ListTile(
                key: ValueKey('day-${dateKey(date)}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                onTap: model.canEdit ? () => onSelect(date) : null,
                title: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text('${date.day}일 (${'월화수목금토일'[date.weekday - 1]})'),
                    if (model.loaded)
                      Text(
                        '${timeText(model.entry(date)?.clockIn)} → ${timeText(model.entry(date)?.clockOut)}',
                      ),
                  ],
                ),
                subtitle: model.entry(date) == null || !model.loaded
                    ? const Text('기록 없음 · 선택하여 입력')
                    : Text(
                        '${model.entry(date)!.leave == LeaveType.none ? '근무' : model.entry(date)!.leave.label}${model.entry(date)!.clockOut != null && dateKey(model.entry(date)!.clockOut!) != dateKey(date) ? ' · 퇴근 ${dateKey(model.entry(date)!.clockOut!)}' : ''}\n${model.entry(date)!.remainingMinutes == null ? '채워야 할 시간 · 퇴근 입력 후 계산' : '채워야 할 시간 ${durationText(model.entry(date)!.remainingMinutes!)}'}',
                      ),
                trailing: model.loaded
                    ? Text(
                        model.entry(date)?.displayText ?? '',
                        style: TextStyle(
                          color: entryColor(model.entry(date)),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              editor:
                  model.draft != null &&
                      dateKey(model.draft!.date) == dateKey(date)
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: EntryEditor(model: model, inlineTime: true),
                    )
                  : null,
            ),
            const Divider(height: 1),
          ],
        ],
      ),
    ),
  );
}
