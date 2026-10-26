import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/settings_store.dart';
import '../data/csv_repository.dart';
import '../data/csv_file_access.dart';
import '../domain/work_entry.dart';
import '../domain/work_repository.dart';

enum StartupStage { loading, ready, error }

String errorMessage(Object e) => e is TimeoutException
    ? '처리 시간이 초과되었습니다. 다시 시도하세요.'
    : e.toString().replaceFirst(
        RegExp(r'^(Bad state: |FormatException: |Exception: )'),
        '',
      );

class AppViewModel extends ChangeNotifier {
  AppViewModel({required this.store, CsvFileAccess? files, DateTime? today})
    : files = files ?? SystemCsvFileAccess(),
      today = today ?? DateTime.now() {
    repository = CsvWorkRepository(store);
  }
  final SettingsStore store;
  final CsvFileAccess files;
  final DateTime today;
  late final CsvWorkRepository repository;
  WorkSettings settings = const WorkSettings();
  StartupStage stage = StartupStage.loading;
  WorkTimeViewModel? work;
  String message = '기기에 저장된 기록 불러오는 중', error = '', notice = '';
  bool busy = false, _disposed = false;
  static const settingsKey = 'work_time.csv.settings.v1';
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (busy) return;
    busy = true;
    stage = StartupStage.loading;
    error = '';
    _emit();
    try {
      final standard = await store.read(settingsKey);
      final minutes = standard == null ? 480 : int.tryParse(standard);
      if (minutes == null || minutes <= 0) {
        throw const FormatException('저장된 기준근무시간을 확인하세요.');
      }
      settings = WorkSettings(standardMinutes: minutes);
      await repository.initialize();
      final month = DateTime(today.year, today.month);
      final entries = await repository.loadMonth(month);
      if (_disposed) return;
      final old = work;
      work = WorkTimeViewModel(
        repository: repository,
        store: store,
        settings: settings,
        month: month,
        entries: entries,
        title: '내 근무 기록',
      );
      stage = StartupStage.ready;
      old?.dispose();
    } catch (e) {
      stage = StartupStage.error;
      error = errorMessage(e);
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<bool> importCsv() async {
    if (busy || work == null || work!.dirty || work!.saving) return false;
    busy = true;
    error = '';
    notice = '';
    work!.setExternalBusy(true);
    _emit();
    try {
      final source = await files.open();
      if (source == null || _disposed) return false;
      await repository.replaceFromFile(source.bytes, source.name);
      await work!.changeMonth(work!.month);
      notice = '${source.name} · ${repository.count}개 날짜 기록을 불러왔습니다.';
      return true;
    } catch (e) {
      error = errorMessage(e);
      return false;
    } finally {
      busy = false;
      work?.setExternalBusy(false);
      _emit();
    }
  }

  Future<bool> exportCsv() async {
    if (busy || work == null || work!.dirty || work!.saving) return false;
    busy = true;
    error = '';
    notice = '';
    work!.setExternalBusy(true);
    _emit();
    try {
      final location = await files.save(
        repository.exportBytes(),
        repository.fileName,
      );
      if (location == null || _disposed) return false;
      final name = location.pathSegments.isEmpty
          ? repository.fileName
          : location.pathSegments.last.split(RegExp(r'[/\\:]')).last;
      try {
        await repository.markExported(
          name.toLowerCase().endsWith('.csv') ? name : repository.fileName,
        );
      } catch (_) {
        notice = 'CSV 파일은 내보냈지만 기기의 내보내기 상태를 갱신하지 못했습니다.';
        return true;
      }
      notice = files.canChooseSaveLocation
          ? '선택한 위치에 CSV를 저장했습니다.'
          : 'CSV 다운로드를 요청했습니다. 브라우저 다운로드 목록을 확인하세요.';
      return true;
    } catch (e) {
      error = errorMessage(e);
      return false;
    } finally {
      busy = false;
      work?.setExternalBusy(false);
      _emit();
    }
  }

  Future<bool> updateStandard(int minutes) async {
    if (busy || work == null || work!.dirty || work!.saving) return false;
    if (minutes <= 0) {
      error = '기준근무시간은 양의 정수 분으로 입력하세요.';
      _emit();
      return false;
    }
    busy = true;
    error = '';
    work!.setExternalBusy(true);
    _emit();
    try {
      await store.write(settingsKey, '$minutes');
      settings = WorkSettings(standardMinutes: minutes);
      work!.settings = settings;
      notice = '새 기록부터 기준 ${durationText(minutes)}를 적용합니다.';
      return true;
    } catch (e) {
      error = errorMessage(e);
      return false;
    } finally {
      busy = false;
      work?.setExternalBusy(false);
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    work?.dispose();
    super.dispose();
  }
}

class WorkTimeViewModel extends ChangeNotifier {
  WorkTimeViewModel({
    required this.repository,
    required this.store,
    required this.settings,
    required this.month,
    required List<WorkEntry> entries,
    required this.title,
  }) {
    _records = {for (final e in entries) dateKey(e.date): e};
  }
  final WorkRepository repository;
  final SettingsStore store;
  WorkSettings settings;
  final String title;
  DateTime month;
  DateTime? selectedDate;
  WorkEntry? draft;
  Map<String, WorkEntry> _records = {};
  bool loading = false, saving = false, loaded = true;
  String error = '', editError = '';
  int _generation = 0;
  bool _disposed = false;
  List<DateTime> get dates => monthDates(month);
  WorkEntry? entry(DateTime date) => _records[dateKey(date)];
  MonthSummary get summary => MonthSummary(_records.values);
  bool externalBusy = false;
  bool get canEdit => loaded && !loading && !saving && !externalBusy;
  void setExternalBusy(bool value) {
    externalBusy = value;
    _emit();
  }

  bool get dirty =>
      draft != null &&
      jsonEncode(draft!.toRow()) !=
          jsonEncode(
            (entry(draft!.date) ??
                    WorkEntry(
                      date: draft!.date,
                      standardMinutes: settings.standardMinutes,
                    ))
                .toRow(),
          );
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> changeMonth(DateTime value, {bool refresh = false}) async {
    if (saving || dirty) return;
    final generation = ++_generation;
    final next = DateTime(value.year, value.month);
    final same = monthKey(next) == monthKey(month);
    month = next;
    loading = true;
    loaded = false;
    error = '';
    if (!same || !refresh) _records = {};
    draft = null;
    selectedDate = null;
    _emit();
    try {
      final entries = await repository.loadMonth(next);
      if (generation != _generation || _disposed) return;
      _records = {for (final e in entries) dateKey(e.date): e};
      loaded = true;
    } catch (e) {
      if (generation == _generation) error = errorMessage(e);
    } finally {
      if (generation == _generation) {
        loading = false;
        _emit();
      }
    }
  }

  void select(DateTime date) {
    if (!canEdit || dirty) return;
    selectedDate = date;
    draft =
        entry(date) ??
        WorkEntry(date: date, standardMinutes: settings.standardMinutes);
    editError = '';
    _emit();
  }

  void updateDraft(WorkEntry entry) {
    if (saving) return;
    draft = entry;
    editError = '';
    _emit();
  }

  void discard() {
    if (saving) return;
    draft = null;
    editError = '';
    _emit();
  }

  Future<bool> save() async {
    final value = draft;
    if (value == null || !canEdit) return false;
    editError = value.validate() ?? '';
    if (editError.isNotEmpty) {
      _emit();
      return false;
    }

    saving = true;
    _emit();
    try {
      final previous = entry(value.date);
      if (value.isEmpty) {
        if (previous != null) await repository.delete(previous);
      } else {
        await repository.save(value, expectedRevision: previous?.revision);
      }
      final records = await repository.loadMonth(month);
      if (_disposed) return false;
      _records = {for (final e in records) dateKey(e.date): e};
      draft = null;
      return true;
    } catch (e) {
      editError = errorMessage(e);
      return false;
    } finally {
      saving = false;
      _emit();
    }
  }

  Future<bool> deleteSelected() async {
    final original = draft == null ? null : entry(draft!.date);
    if (original == null || !canEdit) return false;
    saving = true;
    editError = '';
    _emit();
    try {
      await repository.delete(original);
      final records = await repository.loadMonth(month);
      if (_disposed) return false;
      _records = {for (final e in records) dateKey(e.date): e};
      draft = null;
      return true;
    } catch (e) {
      editError = errorMessage(e);
      return false;
    } finally {
      saving = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
