import 'package:flutter/material.dart';

import '../domain/work_entry.dart';
import '../features/view_models.dart';

const positiveColor = Color(0xff16763c);
const negativeColor = Color(0xffb3261e);
Color entryColor(WorkEntry? entry) => (entry?.differenceMinutes ?? 0) > 0
    ? positiveColor
    : (entry?.differenceMinutes ?? 0) < 0
    ? negativeColor
    : Colors.black;

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key, required this.app});
  final AppViewModel app;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                '나의 근무 달력',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text('출퇴근과 휴가를 한눈에'),
              const SizedBox(height: 32),
              if (app.busy) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Semantics(liveRegion: true, child: Text(app.message)),
              ],
              if (app.error.isNotEmpty) ...[
                Text(app.error, style: const TextStyle(color: negativeColor)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: app.start,
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 시도'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class WorkMainScreen extends StatefulWidget {
  const WorkMainScreen({super.key, required this.app, required this.model});
  final AppViewModel app;
  final WorkTimeViewModel model;
  @override
  State<WorkMainScreen> createState() => _WorkMainScreenState();
}

class _WorkMainScreenState extends State<WorkMainScreen> {
  WorkTimeViewModel get vm => widget.model;
  Future<bool> guard() async {
    if (vm.saving || widget.app.busy) return false;
    if (!vm.dirty) {
      vm.discard();
      return true;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('변경한 기록이 있습니다'),
        content: const Text('다른 날짜로 이동하기 전에 처리 방법을 선택하세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('버리기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (choice == 'discard') {
      vm.discard();
      return true;
    }
    if (choice == 'save') return vm.save();
    return false;
  }

  Future<void> move(DateTime month) async {
    if (await guard()) await vm.changeMonth(month);
  }

  Future<void> select(DateTime date, {bool dialog = false}) async {
    if (!await guard() || !mounted || !vm.canEdit) return;
    vm.select(date);
    if (dialog) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AnimatedBuilder(
          animation: vm,
          builder: (context, _) => PopScope(
            canPop: !vm.saving && !vm.dirty,
            child: AlertDialog(
              title: Text('${dateKey(date)} 기록'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(child: EntryEditor(model: vm)),
              ),
              actions: [
                TextButton(
                  onPressed: vm.saving
                      ? null
                      : () async {
                          if (await guard() && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Future<void> settings() async {
    if (!await guard() || !mounted) return;
    final controller = TextEditingController(
      text: '${widget.app.settings.standardMinutes}',
    );
    try {
      final value = await showDialog<int>(
        context: context,
        builder: (context) {
          String? validation;
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: const Text('근무 설정'),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '하루 기준근무시간 (분)',
                  errorText: validation,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = int.tryParse(controller.text);
                    if (value == null || value <= 0) {
                      setState(() => validation = '양의 정수 분을 입력하세요.');
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  child: const Text('적용'),
                ),
              ],
            ),
          );
        },
      );
      if (value != null) await widget.app.updateStandard(value);
    } finally {
      controller.dispose();
    }
  }

  Future<void> fileAction(bool importing) async {
    if (!await guard() || !mounted) return;
    if (importing && widget.app.repository.count > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('CSV 기록으로 교체할까요?'),
          content: const Text(
            '모든 월의 현재 기록을 선택한 CSV 내용으로 교체합니다. 필요하면 먼저 CSV로 저장하세요. 파일 선택을 취소하거나 검증에 실패하면 기존 기록을 유지합니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('파일 선택'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (importing) {
      await widget.app.importCsv();
    } else {
      await widget.app.exportCsv();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: vm,
    builder: (context, _) {
      final summary = vm.summary;
      final scale = MediaQuery.textScalerOf(context).scale(1);
      return PopScope(
        canPop: !vm.saving && !vm.dirty,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop && !vm.saving) await guard();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('나의 근무 달력'),
            actions: [
              IconButton(
                tooltip: '새로고침',
                onPressed: vm.loading || vm.saving
                    ? null
                    : () async {
                        if (await guard()) {
                          await vm.changeMonth(vm.month, refresh: true);
                        }
                      },
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: '근무 설정',
                onPressed: vm.saving || widget.app.busy ? null : settings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        vm.title,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.app.repository.fileName} · 전체 ${widget.app.repository.count}일',
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.app.repository.needsExport
                                    ? '기기에 보관됨 · CSV 저장 필요'
                                    : 'CSV와 동일한 기록 · 기기에도 보관됨',
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: vm.saving || widget.app.busy
                                        ? null
                                        : () => fileAction(true),
                                    icon: const Icon(Icons.folder_open),
                                    label: const Text('CSV 불러오기'),
                                  ),
                                  FilledButton.icon(
                                    onPressed: vm.saving || widget.app.busy
                                        ? null
                                        : () => fileAction(false),
                                    icon: const Icon(Icons.save_alt),
                                    label: Text(
                                      widget.app.files.canChooseSaveLocation
                                          ? 'CSV 저장 위치 선택'
                                          : 'CSV 다운로드',
                                    ),
                                  ),
                                ],
                              ),
                              if (!widget.app.files.canChooseSaveLocation)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    '이 브라우저는 저장 위치 선택을 지원하지 않습니다. 다운로드 설정에 따라 저장됩니다.',
                                  ),
                                ),
                              if (widget.app.busy)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: LinearProgressIndicator(),
                                ),
                              if (widget.app.error.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    widget.app.error,
                                    style: const TextStyle(
                                      color: negativeColor,
                                    ),
                                  ),
                                ),
                              if (widget.app.notice.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(widget.app.notice),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          summaryCard(
                            '실근무',
                            vm.loaded ? durationText(summary.work) : '—',
                          ),
                          summaryCard(
                            '휴가',
                            vm.loaded ? durationText(summary.leave) : '—',
                          ),
                          summaryCard(
                            '초과근무',
                            vm.loaded ? durationText(summary.overtime) : '—',
                          ),
                          summaryCard(
                            '채워야 할 시간 (완료 기록)',
                            vm.loaded ? durationText(summary.remaining) : '—',
                          ),
                          summaryCard(
                            '완료 / 진행 중',
                            vm.loaded
                                ? '${summary.completed}일 / ${summary.pending}일'
                                : '—',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: '이전 해',
                            onPressed: vm.saving
                                ? null
                                : () => move(
                                    DateTime(vm.month.year - 1, vm.month.month),
                                  ),
                            icon: const Icon(Icons.keyboard_double_arrow_left),
                          ),
                          IconButton(
                            tooltip: '이전 달',
                            onPressed: vm.saving
                                ? null
                                : () => move(
                                    DateTime(vm.month.year, vm.month.month - 1),
                                  ),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text(
                            '${vm.month.year}년 ${vm.month.month}월',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          IconButton(
                            tooltip: '다음 달',
                            onPressed: vm.saving
                                ? null
                                : () => move(
                                    DateTime(vm.month.year, vm.month.month + 1),
                                  ),
                            icon: const Icon(Icons.chevron_right),
                          ),
                          IconButton(
                            tooltip: '다음 해',
                            onPressed: vm.saving
                                ? null
                                : () => move(
                                    DateTime(vm.month.year + 1, vm.month.month),
                                  ),
                            icon: const Icon(Icons.keyboard_double_arrow_right),
                          ),
                          TextButton(
                            onPressed: vm.saving
                                ? null
                                : () => move(widget.app.today),
                            child: const Text('오늘'),
                          ),
                        ],
                      ),
                      if (vm.loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            children: [
                              LinearProgressIndicator(),
                              SizedBox(height: 8),
                              Text('근무 기록 불러오는 중…'),
                            ],
                          ),
                        ),
                      if (vm.error.isNotEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  vm.error,
                                  style: const TextStyle(color: negativeColor),
                                ),
                                TextButton(
                                  onPressed: () => vm.changeMonth(vm.month),
                                  child: const Text('다시 불러오기'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final calendar = CalendarPanel(
                            model: vm,
                            onSelect: (date) => select(date, dialog: true),
                          );
                          final list = DayListPanel(
                            model: vm,
                            onSelect: (date) => select(date),
                          );
                          return constraints.maxWidth >= 1024 && scale <= 1.3
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: calendar),
                                    const SizedBox(width: 20),
                                    Expanded(child: list),
                                  ],
                                )
                              : Column(
                                  children: [
                                    calendar,
                                    const SizedBox(height: 20),
                                    list,
                                  ],
                                );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  Widget summaryCard(String label, String value) => Card(
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
            ListTile(
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
            if (model.draft != null &&
                dateKey(model.draft!.date) == dateKey(date))
              Padding(
                padding: const EdgeInsets.all(8),
                child: EntryEditor(model: model),
              ),
            const Divider(height: 1),
          ],
        ],
      ),
    ),
  );
}

class EntryEditor extends StatelessWidget {
  const EntryEditor({super.key, required this.model});
  final WorkTimeViewModel model;
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
        if (!draft.isEmpty && draft.validate() == null)
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
              onPressed: enabled ? model.save : null,
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
