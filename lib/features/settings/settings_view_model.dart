import 'package:flutter/foundation.dart';

import '../../data/settings_store.dart';
import '../../domain/work_entry.dart';
import '../../shared/errors/error_message.dart';
import '../attendance/view_models/work_time_view_model.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(this.store);
  static const storageKey = 'work_time.csv.settings.v1';
  final SettingsStore store;
  WorkSettings settings = const WorkSettings();
  bool busy = false, _disposed = false;
  String error = '', notice = '';
  void clearMessages() {
    error = '';
    notice = '';
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final standard = await store.read(storageKey);
    final minutes = standard == null ? 480 : int.tryParse(standard);
    if (minutes == null || minutes <= 0) {
      throw const FormatException('저장된 기준근무시간을 확인하세요.');
    }
    settings = WorkSettings(standardMinutes: minutes);
  }

  Future<bool> updateStandard(int minutes, WorkTimeViewModel work) async {
    if (busy || work.dirty || work.saving || work.externalBusy) return false;
    if (minutes <= 0) {
      error = '기준근무시간은 양의 정수 분으로 입력하세요.';
      _emit();
      return false;
    }
    busy = true;
    error = '';
    work.setExternalBusy(true);
    _emit();
    try {
      await store.write(storageKey, '$minutes');
      settings = WorkSettings(standardMinutes: minutes);
      work.settings = settings;
      notice = '새 기록부터 기준 ${durationText(minutes)}를 적용합니다.';
      return true;
    } catch (e) {
      error = errorMessage(e);
      return false;
    } finally {
      busy = false;
      work.setExternalBusy(false);
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
