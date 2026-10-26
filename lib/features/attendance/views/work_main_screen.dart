import 'package:flutter/material.dart';
import 'package:work_time/domain/work_entry.dart';
import 'package:work_time/features/attendance/view_models/work_time_view_model.dart';
import 'package:work_time/app/app_view_model.dart';
import 'package:work_time/shared/presentation/work_colors.dart';

import 'calendar_panel.dart';
import 'day_list_panel.dart';
import '../widgets/entry_editor.dart';
import '../widgets/month_summary_panel.dart';
import '../../csv/csv_panel.dart';
import '../../csv/csv_import_dialog.dart';
import '../../settings/settings_dialog.dart';

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
    final value = await showWorkSettingsDialog(
      context,
      widget.app.settings.standardMinutes,
    );
    if (value != null) await widget.app.updateStandard(value);
  }

  Future<void> fileAction(bool importing) async {
    if (!await guard() || !mounted) return;
    if (importing && widget.app.csv.count > 0) {
      final confirmed = await confirmCsvImport(context);
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
                      CsvPanel(
                        model: widget.app.csv,
                        busy: widget.app.busy,
                        error: widget.app.error,
                        notice: widget.app.notice,
                        saving: vm.saving,
                        onImport: () => fileAction(true),
                        onExport: () => fileAction(false),
                      ),
                      MonthSummaryPanel(summary: vm.summary, loaded: vm.loaded),
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
}
