import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import '../domain/work_entry.dart';
import '../domain/work_repository.dart';
import 'settings_store.dart';

class CsvWorkRepository implements WorkRepository {
  CsvWorkRepository(this.store);
  final SettingsStore store;
  static const snapshotKey = 'work_time.csv.snapshot.v1';
  final Csv _csv = Csv(autoDetect: false, addBom: true);
  Map<String, WorkEntry> _records = {};
  String fileName = 'work-time.csv';
  bool needsExport = true;
  int get count => _records.length;

  Map<String, WorkEntry> parseBytes(Uint8List bytes) {
    if (bytes.length > 10 * 1024 * 1024) {
      throw const FormatException('CSV 파일은 10MB 이하로 선택하세요.');
    }
    var text = utf8.decode(bytes);
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    return decodeRows(_csv.decode(text));
  }

  Uint8List encodeRecords(Map<String, WorkEntry> records) {
    final entries = records.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return Uint8List.fromList(
      utf8.encode(_csv.encode([csvHeaders, ...entries.map((e) => e.toRow())])),
    );
  }

  Uint8List exportBytes() => encodeRecords(_records);
  Future<void> initialize() async {
    final snapshot = await store.read(snapshotKey);
    if (snapshot == null) return;
    final data = jsonDecode(snapshot) as Map<String, dynamic>;
    final records = parseBytes(
      Uint8List.fromList(utf8.encode(data['csv'] as String)),
    );
    _records = records;
    fileName = data['fileName'] as String;
    needsExport = data['needsExport'] as bool;
  }

  Future<void> _commit(
    Map<String, WorkEntry> records,
    String name,
    bool pending,
  ) async {
    final snapshot = jsonEncode({
      'csv': utf8.decode(encodeRecords(records)),
      'fileName': name,
      'needsExport': pending,
    });
    await store.write(snapshotKey, snapshot);
    _records = records;
    fileName = name;
    needsExport = pending;
  }

  Future<void> replaceFromFile(Uint8List bytes, String name) async {
    final records = parseBytes(bytes);
    await _commit(records, name, false);
  }

  Future<void> markExported(String name) =>
      _commit(Map.of(_records), name, false);
  @override
  Future<List<WorkEntry>> loadMonth(DateTime month) async => _records.values
      .where((e) => monthKey(e.date) == monthKey(month))
      .toList();
  @override
  Future<void> save(WorkEntry entry, {String? expectedRevision}) async {
    final error = entry.validate();
    if (error != null) throw FormatException(error);
    if (entry.isEmpty) throw const FormatException('빈 기록은 저장하지 않습니다.');
    final row = entry.toRow(
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    final next = Map<String, WorkEntry>.of(_records)
      ..[dateKey(entry.date)] = WorkEntry.fromRow(row);
    await _commit(next, fileName, true);
  }

  @override
  Future<void> delete(WorkEntry entry) async {
    final next = Map<String, WorkEntry>.of(_records)
      ..remove(dateKey(entry.date));
    await _commit(next, fileName, true);
  }
}
