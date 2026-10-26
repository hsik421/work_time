import 'package:flutter/material.dart';
import 'package:work_time/domain/work_entry.dart';
import 'package:work_time/features/attendance/view_models/work_time_view_model.dart';
import 'package:work_time/shared/presentation/work_colors.dart';

class CalendarPanel extends StatelessWidget {
  const CalendarPanel({super.key, required this.model, required this.onSelect});
  final WorkTimeViewModel model;
  final ValueChanged<DateTime> onSelect;
  @override
  Widget build(BuildContext context) {
    final firstOffset =
        DateTime(model.month.year, model.month.month).weekday % 7;
    final dates = model.dates;
    final cells = ((firstOffset + dates.length + 6) ~/ 7) * 7;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                for (final label in ['일', '월', '화', '수', '목', '금', '토'])
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(label),
                      ),
                    ),
                  ),
              ],
            ),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                children: List.generate(cells, (index) {
                  final day = index - firstOffset + 1;
                  if (day < 1 || day > dates.length) {
                    return SizedBox(
                      width: constraints.maxWidth / 7,
                      height: 96 * textScale,
                    );
                  }
                  final date = dates[day - 1];
                  final record = model.entry(date);
                  final selected =
                      model.selectedDate != null &&
                      dateKey(model.selectedDate!) == dateKey(date);
                  return SizedBox(
                    width: constraints.maxWidth / 7,
                    height: 96 * textScale,
                    child: Semantics(
                      label:
                          '${dateKey(date)} ${record == null ? '미입력' : '${record.statusLabel} ${record.displayText} ${record.leave.label}'}',
                      button: true,
                      child: Material(
                        color: selected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: model.canEdit ? () => onSelect(date) : null,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$day',
                                maxLines: 1,
                                softWrap: false,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (model.loaded && record != null)
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    record.displayText,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      color: entryColor(record),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              if (model.loaded &&
                                  record != null &&
                                  record.leave != LeaveType.none)
                                Text(
                                  record.leave.label,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: const TextStyle(fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const Divider(),
            const Wrap(
              spacing: 16,
              children: [
                Text('초과', style: TextStyle(color: positiveColor)),
                Text('충족', style: TextStyle(color: Colors.black)),
                Text('부족', style: TextStyle(color: negativeColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
