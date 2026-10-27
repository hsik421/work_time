import 'package:flutter/material.dart';
import 'package:work_time/domain/work_entry.dart';
import 'package:work_time/features/attendance/view_models/work_time_view_model.dart';
import 'package:work_time/shared/presentation/work_colors.dart';

import 'save_success_overlay.dart';

class EntryEditor extends StatelessWidget {
  const EntryEditor({super.key, required this.model, this.inlineTime = false});
  final WorkTimeViewModel model;
  final bool inlineTime;
  Future<void> pickTime(BuildContext context, bool clockIn) async {
    final draft = model.draft!;
    final old = clockIn ? draft.clockIn : draft.clockOut;
    final picked = await showTimePicker(
      context: context,
      initialEntryMode: TimePickerEntryMode.input,
      helpText: clockIn ? '출근시간 입력' : '퇴근시간 입력',
      hourLabelText: '시 (00~23)',
      minuteLabelText: '분 (00~59)',
      errorInvalidText: '시간은 00~23, 분은 00~59로 입력하세요.',
      confirmText: '적용',
      cancelText: '취소',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
      initialTime: old == null
          ? TimeOfDay(hour: clockIn ? 9 : 18, minute: 0)
          : TimeOfDay.fromDateTime(old),
    );
    if (picked == null || !context.mounted || model.draft != draft) return;
    final base = clockIn ? draft.date : old ?? draft.date;
    final value = DateTime(
      base.year,
      base.month,
      base.day,
      picked.hour,
      picked.minute,
    );
    model.updateDraft(
      clockIn
          ? draft.copyWith(clockIn: value)
          : draft.copyWith(clockOut: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = model.draft;
    if (draft == null) return const SizedBox.shrink();
    final enabled = !model.saving && !model.externalBusy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${dateKey(draft.date)} · 기준 ${durationText(draft.standardMinutes)}',
        ),
        const SizedBox(height: 12),
        if (inlineTime)
          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: [
              for (final clockIn in [true, false])
                SizedBox(
                  width: 200,
                  child: TextFormField(
                    key: ValueKey('inline-${dateKey(draft.date)}-$clockIn'),
                    initialValue:
                        (clockIn ? draft.clockIn : draft.clockOut) == null
                        ? ''
                        : timeText(clockIn ? draft.clockIn : draft.clockOut),
                    enabled: enabled,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: clockIn ? '출근' : '퇴근',
                      hintText: clockIn ? '09:00' : '18:00',
                      helperText: '24시간제 HH:mm',
                      errorText: model.timeInputError(clockIn),
                    ),
                    onChanged: (text) => model.updateTimeInput(clockIn, text),
                  ),
                ),
            ],
          ),
        if (!inlineTime)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: enabled ? () => pickTime(context, true) : null,
                child: Text('출근 ${timeText(draft.clockIn)}'),
              ),
              OutlinedButton(
                onPressed: enabled ? () => pickTime(context, false) : null,
                child: Text('퇴근 ${timeText(draft.clockOut)}'),
              ),
              TextButton(
                onPressed: enabled
                    ? () => model.updateDraft(
                        draft.copyWith(clearIn: true, clearOut: true),
                      )
                    : null,
                child: const Text('출퇴근 비우기'),
              ),
            ],
          ),
        if (draft.clockOut != null)
          TextButton.icon(
            onPressed: enabled
                ? () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: draft.clockOut!,
                      firstDate: DateTime(draft.date.year - 1),
                      lastDate: DateTime(draft.date.year + 2),
                    );
                    if (date == null ||
                        !context.mounted ||
                        model.draft != draft) {
                      return;
                    }
                    model.updateDraft(
                      draft.copyWith(
                        clockOut: DateTime(
                          date.year,
                          date.month,
                          date.day,
                          draft.clockOut!.hour,
                          draft.clockOut!.minute,
                        ),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.date_range),
            label: Text('퇴근일 ${dateKey(draft.clockOut!)}'),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<LeaveType>(
          key: ValueKey('${dateKey(draft.date)}-${draft.leave.name}'),
          initialValue: draft.leave,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '휴가 유형'),
          items: LeaveType.values
              .map((v) => DropdownMenuItem(value: v, child: Text(v.label)))
              .toList(),
          onChanged: enabled
              ? (v) => model.updateDraft(
                  draft.copyWith(
                    leave: v,
                    hourlyLeaveMinutes: v == LeaveType.hourly
                        ? (draft.hourlyLeaveMinutes > 0
                              ? draft.hourlyLeaveMinutes
                              : 60)
                        : 0,
                  ),
                )
              : null,
        ),
        if (draft.leave == LeaveType.hourly)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextFormField(
              key: ValueKey('leave-${dateKey(draft.date)}'),
              initialValue: '${draft.hourlyLeaveMinutes}',
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '시간차 (분)'),
              onChanged: (v) => model.updateDraft(
                model.draft!.copyWith(hourlyLeaveMinutes: int.tryParse(v) ?? 0),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text(draft.clockIn == null ? '휴가만 기록하면 휴게 공제 없음' : '휴게시간 01:00 고정 공제'),
        if (!model.hasTimeInputErrors &&
            !draft.isEmpty &&
            draft.validate() == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${draft.statusLabel} ${draft.displayText}\n${draft.remainingMinutes == null ? '채워야 할 시간 · 퇴근 입력 후 계산' : '채워야 할 시간 ${durationText(draft.remainingMinutes!)}'}',
              style: TextStyle(color: entryColor(draft)),
            ),
          ),
        if (model.editError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              model.editError,
              style: const TextStyle(color: negativeColor),
            ),
          ),
        if (model.saving)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: enabled
                  ? () async {
                      final overlay = Overlay.of(context, rootOverlay: true);
                      final reduceMotion = MediaQuery.disableAnimationsOf(
                        context,
                      );
                      final saved = await model.save();
                      if (saved && inlineTime && overlay.mounted) {
                        showSaveSuccessOverlay(
                          overlay,
                          reduceMotion: reduceMotion,
                        );
                      }
                    }
                  : null,
              icon: const Icon(Icons.check),
              label: Text(model.saving ? '저장 중…' : '저장'),
            ),
            TextButton(
              onPressed: enabled ? model.discard : null,
              child: const Text('입력 취소'),
            ),
            if (model.entry(draft.date) != null)
              TextButton(
                onPressed: enabled
                    ? () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('이 날짜 기록을 삭제할까요?'),
                            content: const Text('출퇴근과 휴가 기록을 함께 삭제합니다.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('취소'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('삭제'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) await model.deleteSelected();
                      }
                    : null,
                child: const Text('기록 삭제'),
              ),
          ],
        ),
      ],
    );
  }
}
