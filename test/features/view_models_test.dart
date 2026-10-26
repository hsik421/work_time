import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_time/data/csv_file_access.dart';
import 'package:work_time/data/settings_store.dart';
import 'package:work_time/domain/work_entry.dart';
import 'package:work_time/features/view_models.dart';

import '../fakes.dart';

void main() {
  final today = DateTime(2026, 10, 26);
  test('시작 시 메인 진입, 기록·CSV 미반영 상태 재실행 복원', () async {
    final store = MemorySettings();
    final app = AppViewModel(store: store, files: MemoryFiles(), today: today);
    await app.start();
    expect(app.stage, StartupStage.ready);
    app.work!.select(today);
    app.work!.updateDraft(app.work!.draft!.copyWith(leave: LeaveType.annual));
    expect(await app.work!.save(), true);
    expect(app.repository.needsExport, true);
    final restored = AppViewModel(
      store: store,
      files: MemoryFiles(),
      today: today,
    );
    await restored.start();
    expect(restored.work!.entry(today)!.leave, LeaveType.annual);
    expect(restored.repository.needsExport, true);
    app.dispose();
    restored.dispose();
  });
  test('파일 선택 취소·손상 CSV·로컬 저장 실패는 기존 기록 보존', () async {
    final store = MemorySettings();
    final files = MemoryFiles();
    final app = AppViewModel(store: store, files: files, today: today);
    await app.start();
    await app.repository.save(WorkEntry(date: today, leave: LeaveType.annual));
    expect(await app.importCsv(), false);
    expect(app.repository.count, 1);
    files.source = CsvSource('bad.csv', Uint8List.fromList('wrong'.codeUnits));
    expect(await app.importCsv(), false);
    expect(app.repository.count, 1);
    expect(app.busy, false);
    files.source = CsvSource('empty.csv', app.repository.encodeRecords({}));
    store.failWrite = true;
    expect(await app.importCsv(), false);
    expect(app.repository.count, 1);
    app.dispose();
  });
  test('모든 월 CSV 불러오기·내보내기와 저장 취소·실패', () async {
    final files = MemoryFiles();
    final app = AppViewModel(
      store: MemorySettings(),
      files: files,
      today: today,
    );
    await app.start();
    final entries = [
      WorkEntry(date: today, leave: LeaveType.annual),
      WorkEntry(date: DateTime(2027, 1, 1), leave: LeaveType.halfDay),
    ];
    files.source = CsvSource(
      'all.csv',
      app.repository.encodeRecords({
        for (final e in entries) dateKey(e.date): e,
      }),
    );
    expect(await app.importCsv(), true);
    expect(app.repository.count, 2);
    expect(app.work!.summary.leave, 480);
    await app.repository.save(entries.first);
    files.saveLocation = null;
    expect(await app.exportCsv(), false);
    expect(app.repository.needsExport, true);
    files.failSave = true;
    expect(await app.exportCsv(), false);
    expect(app.repository.needsExport, true);
    files.failSave = false;
    files.saveLocation = Uri(path: 'all.csv');
    expect(await app.exportCsv(), true);
    expect(app.repository.parseBytes(files.savedBytes!).length, 2);
    expect(app.repository.needsExport, false);
    app.dispose();
  });
  test('기준 변경은 기존 기록에 소급하지 않음', () async {
    final app = AppViewModel(
      store: MemorySettings(),
      files: MemoryFiles(),
      today: today,
    );
    await app.start();
    app.work!.select(today);
    app.work!.updateDraft(app.work!.draft!.copyWith(leave: LeaveType.annual));
    await app.work!.save();
    expect(await app.updateStandard(420), true);
    app.work!.select(today);
    expect(app.work!.draft!.standardMinutes, 480);
    app.work!.discard();
    app.work!.select(DateTime(2026, 10, 27));
    expect(app.work!.draft!.standardMinutes, 420);
    app.dispose();
  });
  test('공통 초안 저장·실패·중복 날짜·기준 보존·삭제', () async {
    final repo = MemoryRepository();
    final vm = WorkTimeViewModel(
      repository: repo,
      store: MemorySettings(),
      settings: const WorkSettings(),
      month: today,
      entries: [],
      title: 'test',
    );
    vm.select(today);
    vm.updateDraft(vm.draft!.copyWith(leave: LeaveType.annual));
    expect(vm.dirty, true);
    repo.failSave = true;
    expect(await vm.save(), false);
    expect(vm.draft, isNotNull);
    expect(vm.saving, false);
    repo.failSave = false;
    expect(await vm.save(), true);
    expect(vm.entry(today)!.differenceMinutes, 0);
    vm.select(today);
    expect(vm.draft!.standardMinutes, 480);
    vm.updateDraft(vm.draft!.copyWith(leave: LeaveType.halfDay));
    expect(await vm.save(), true);
    expect(repo.records.length, 1);
    vm.select(today);
    expect(await vm.deleteSelected(), true);
    expect(vm.entry(today), isNull);
    vm.dispose();
  });
  test('데이터 없는 연도 탐색과 실패 상태 구분', () async {
    final repo = MemoryRepository();
    final vm = WorkTimeViewModel(
      repository: repo,
      store: MemorySettings(),
      settings: const WorkSettings(),
      month: today,
      entries: [],
      title: 'test',
    );
    await vm.changeMonth(DateTime(2024, 2));
    expect(vm.dates.length, 29);
    expect(vm.loaded, true);
    expect(repo.saves, 0);
    repo.failLoad = true;
    await vm.changeMonth(DateTime(2027, 1));
    expect(vm.loaded, false);
    expect(vm.error, isNotEmpty);
    expect(vm.loading, false);
    vm.dispose();
  });
  test('늦은 월 응답이 현재 월과 로딩 상태를 덮어쓰지 않음', () async {
    final repo = DelayedRepository();
    final vm = WorkTimeViewModel(
      repository: repo,
      store: MemorySettings(),
      settings: const WorkSettings(),
      month: today,
      entries: [],
      title: 'test',
    );
    final old = vm.changeMonth(DateTime(2025, 1));
    final next = vm.changeMonth(DateTime(2027, 1));
    repo.pending[0].complete([]);
    await old;
    expect(vm.loading, true);
    expect(vm.month.year, 2027);
    repo.pending[1].complete([]);
    await next;
    expect(vm.loading, false);
    expect(vm.loaded, true);
    vm.dispose();
  });
}

class DelayedRepository extends MemoryRepository {
  final pending = <Completer<List<WorkEntry>>>[];
  @override
  Future<List<WorkEntry>> loadMonth(DateTime month) {
    final c = Completer<List<WorkEntry>>();
    pending.add(c);
    return c.future;
  }
}
