import 'dart:typed_data';

import 'package:work_time/data/csv_file_access.dart';
import 'package:work_time/data/settings_store.dart';
import 'package:work_time/domain/work_entry.dart';
import 'package:work_time/domain/work_repository.dart';

class MemorySettings implements SettingsStore {
  final values = <String, String>{};
  bool failWrite = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('설정 저장 실패');
    values[key] = value;
  }
}

class MemoryRepository implements WorkRepository {
  final records = <String, WorkEntry>{};
  bool failLoad = false, failSave = false;
  int loads = 0, saves = 0;

  @override
  Future<List<WorkEntry>> loadMonth(DateTime month) async {
    loads++;
    if (failLoad) throw StateError('조회 실패');
    return records.values
        .where((e) => monthKey(e.date) == monthKey(month))
        .toList();
  }

  @override
  Future<void> save(WorkEntry entry, {String? expectedRevision}) async {
    saves++;
    if (failSave) throw StateError('저장 실패');
    records[dateKey(entry.date)] = entry;
  }

  @override
  Future<void> delete(WorkEntry entry) async {
    records.remove(dateKey(entry.date));
  }
}

class MemoryFiles implements CsvFileAccess {
  CsvSource? source;
  Uri? saveLocation = Uri(path: 'work-time.csv');
  Uint8List? savedBytes;
  bool failOpen = false, failSave = false;
  @override
  bool canChooseSaveLocation = true;
  @override
  Future<CsvSource?> open() async {
    if (failOpen) throw StateError('파일 읽기 실패');
    return source;
  }

  @override
  Future<Uri?> save(Uint8List bytes, String suggestedName) async {
    if (failSave) throw StateError('파일 저장 실패');
    if (saveLocation != null) savedBytes = bytes;
    return saveLocation;
  }
}
