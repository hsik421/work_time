import 'package:flutter/foundation.dart';

import '../../data/csv_file_access.dart';
import '../../data/csv_repository.dart';
import '../../shared/errors/error_message.dart';
import '../attendance/view_models/work_time_view_model.dart';

class CsvViewModel extends ChangeNotifier {
  CsvViewModel({required this.repository, required this.files});
  final CsvWorkRepository repository;
  final CsvFileAccess files;
  bool busy = false, _disposed = false;
  String error = '', notice = '';
  String get fileName => repository.fileName;
  int get count => repository.count;
  bool get needsExport => repository.needsExport;
  bool get canChooseSaveLocation => files.canChooseSaveLocation;
  void clearMessages() {
    error = '';
    notice = '';
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> importCsv(WorkTimeViewModel work) async {
    if (busy || work.dirty || work.saving || work.externalBusy) return false;
    busy = true;
    error = '';
    notice = '';
    work.setExternalBusy(true);
    _emit();
    try {
      final source = await files.open();
      if (source == null || _disposed) return false;
      await repository.replaceFromFile(source.bytes, source.name);
      await work.changeMonth(work.month);
      notice = '${source.name} · ${repository.count}개 날짜 기록을 불러왔습니다.';
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

  Future<bool> exportCsv(WorkTimeViewModel work) async {
    if (busy || work.dirty || work.saving || work.externalBusy) return false;
    busy = true;
    error = '';
    notice = '';
    work.setExternalBusy(true);
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
