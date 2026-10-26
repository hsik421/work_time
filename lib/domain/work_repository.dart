import 'work_entry.dart';

const csvHeaders = [
  'workDate',
  'clockIn',
  'clockOut',
  'breakMinutes',
  'standardMinutes',
  'leaveType',
  'hourlyLeaveMinutes',
  'updatedAt',
  'schemaVersion',
];

abstract interface class WorkRepository {
  Future<List<WorkEntry>> loadMonth(DateTime month);
  Future<void> save(WorkEntry entry, {String? expectedRevision});
  Future<void> delete(WorkEntry entry);
}

Map<String, WorkEntry> decodeRows(List<dynamic> rows) {
  if (rows.isEmpty) throw const FormatException('CSV 헤더가 없습니다.');
  final headers = (rows.first as List).map((e) => '$e').toList();
  if (headers.length != csvHeaders.length ||
      !List.generate(
        csvHeaders.length,
        (i) => headers[i] == csvHeaders[i],
      ).every((e) => e)) {
    throw const FormatException('CSV 열 구조가 다릅니다. 기존 기록은 유지됩니다.');
  }
  final result = <String, WorkEntry>{};
  for (final raw in rows.skip(1)) {
    final cells = raw as List;
    if (cells.every((v) => v == null || '$v'.isEmpty)) continue;
    if (cells.length != csvHeaders.length) {
      throw const FormatException('CSV 열 개수가 올바르지 않습니다.');
    }
    final entry = WorkEntry.fromRow(cells.map((v) => v ?? '').toList());
    final key = dateKey(entry.date);
    if (result.containsKey(key)) {
      throw const FormatException('같은 날짜의 중복 기록이 있습니다.');
    }
    result[key] = entry;
  }
  return result;
}
