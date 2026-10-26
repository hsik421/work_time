import '../features/csv/csv_view_model.dart';
import '../features/settings/settings_view_model.dart';

import 'package:flutter/foundation.dart';

import '../data/settings_store.dart';
import '../data/csv_repository.dart';
import '../data/csv_file_access.dart';

import 'package:work_time/features/attendance/view_models/work_time_view_model.dart';

import '../shared/errors/error_message.dart';

enum StartupStage { loading, ready, error }

class AppViewModel extends ChangeNotifier {
  AppViewModel({required this.store, CsvFileAccess? files, DateTime? today})
    : files = files ?? SystemCsvFileAccess(),
      today = today ?? DateTime.now() {
    repository = CsvWorkRepository(store);
    csv = CsvViewModel(repository: repository, files: this.files)
      ..addListener(_emit);
    settingsModel = SettingsViewModel(store)..addListener(_emit);
  }
  final SettingsStore store;
  final CsvFileAccess files;
  final DateTime today;
  late final CsvWorkRepository repository;
  late final CsvViewModel csv;
  late final SettingsViewModel settingsModel;
  WorkSettings get settings => settingsModel.settings;
  StartupStage stage = StartupStage.loading;
  WorkTimeViewModel? work;
  String message = '기기에 저장된 기록 불러오는 중';
  String _startupError = '';
  String get error => _startupError.isNotEmpty
      ? _startupError
      : csv.error.isNotEmpty
      ? csv.error
      : settingsModel.error;
  String get notice =>
      csv.notice.isNotEmpty ? csv.notice : settingsModel.notice;
  bool _starting = false, _disposed = false;
  bool get busy => _starting || csv.busy || settingsModel.busy;
  static const settingsKey = SettingsViewModel.storageKey;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (busy) return;
    _starting = true;
    stage = StartupStage.loading;
    _startupError = '';
    _emit();
    try {
      await settingsModel.load();
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
      _startupError = errorMessage(e);
    } finally {
      _starting = false;
      _emit();
    }
  }

  bool get _canRunFeature =>
      !busy && work != null && !work!.dirty && !work!.saving;

  void _clearFeatureMessages() {
    _startupError = '';
    csv.clearMessages();
    settingsModel.clearMessages();
  }

  Future<bool> importCsv() async {
    if (!_canRunFeature) return false;
    _clearFeatureMessages();
    return csv.importCsv(work!);
  }

  Future<bool> exportCsv() async {
    if (!_canRunFeature) return false;
    _clearFeatureMessages();
    return csv.exportCsv(work!);
  }

  Future<bool> updateStandard(int minutes) async {
    if (!_canRunFeature) return false;
    _clearFeatureMessages();
    return settingsModel.updateStandard(minutes, work!);
  }

  @override
  void dispose() {
    _disposed = true;
    csv.removeListener(_emit);
    settingsModel.removeListener(_emit);
    csv.dispose();
    settingsModel.dispose();
    work?.dispose();
    super.dispose();
  }
}
