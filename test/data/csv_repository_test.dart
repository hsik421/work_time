import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_time/data/csv_repository.dart';
import 'package:work_time/domain/work_entry.dart';

import '../fakes.dart';

void main() {
  test('UTF-8 BOM·헤더·다중 연도 기록 CSV 왕복', () {
    final repo = CsvWorkRepository(MemorySettings());
    final date = DateTime(2026, 10, 26);
    final entries = {
      dateKey(date): WorkEntry(date: date, leave: LeaveType.annual),
      '2027-01-01': WorkEntry(
        date: DateTime(2027, 1, 1),
        leave: LeaveType.hourly,
        hourlyLeaveMinutes: 90,
      ),
    };
    final bytes = repo.encodeRecords(entries);
    expect(bytes.take(3), [239, 187, 191]);
    final decoded = repo.parseBytes(bytes);
    expect(decoded.length, 2);
    expect(decoded['2027-01-01']!.differenceMinutes, -390);
    expect(
      repo
          .parseBytes(
            Uint8List.fromList(
              utf8.encode(utf8.decode(bytes).replaceFirst('\uFEFF', '')),
            ),
          )
          .length,
      2,
    );
  });
  test('빈 헤더·중복·열 누락·잘못된 UTF-8 거부', () {
    final repo = CsvWorkRepository(MemorySettings());
    expect(() => repo.parseBytes(Uint8List(0)), throwsFormatException);
    expect(
      () => repo.parseBytes(Uint8List.fromList([255, 255])),
      throwsFormatException,
    );
    final date = DateTime(2026, 10, 26);
    final text = utf8.decode(
      repo.encodeRecords({
        '2026-10-26': WorkEntry(date: date, leave: LeaveType.annual),
      }),
    );
    final lines = text.split('\r\n');
    final duplicate = [lines[0], lines[1], lines[1]].join('\r\n');
    expect(
      () => repo.parseBytes(Uint8List.fromList(utf8.encode(duplicate))),
      throwsFormatException,
    );
    expect(
      () => repo.parseBytes(
        Uint8List.fromList(
          utf8.encode(text.replaceFirst('schemaVersion', 'wrong')),
        ),
      ),
      throwsFormatException,
    );
  });
  test('저장 실패 시 메모리·기존 스냅샷 보존, 삭제·빈 달', () async {
    final store = MemorySettings();
    final repo = CsvWorkRepository(store);
    await repo.initialize();
    final date = DateTime(2026, 10, 26);
    final entry = WorkEntry(date: date, leave: LeaveType.annual);
    await repo.save(entry);
    final snapshot = store.values[CsvWorkRepository.snapshotKey];
    store.failWrite = true;
    await expectLater(repo.delete(entry), throwsStateError);
    expect(repo.count, 1);
    expect(store.values[CsvWorkRepository.snapshotKey], snapshot);
    store.failWrite = false;
    await repo.delete(entry);
    expect(repo.count, 0);
    expect(await repo.loadMonth(DateTime(2027)), isEmpty);
  });
}
