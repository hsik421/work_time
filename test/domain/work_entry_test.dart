import 'package:flutter_test/flutter_test.dart';
import 'package:work_time/domain/work_entry.dart';
import 'package:work_time/domain/work_repository.dart';

void main() {
  final date = DateTime(2026, 10, 26);
  WorkEntry record(
    int endHour, {
    LeaveType leave = LeaveType.none,
    int minutes = 0,
  }) => WorkEntry(
    date: date,
    clockIn: DateTime(2026, 10, 26, 9),
    clockOut: DateTime(2026, 10, 26, endHour),
    leave: leave,
    hourlyLeaveMinutes: minutes,
  );
  test('고정 휴게와 초과·충족·부족 계산', () {
    expect(record(18).differenceMinutes, 0);
    expect(record(20).overtimeMinutes, 120);
    expect(record(17).differenceMinutes, -60);
    expect(record(17).overtimeMinutes, 0);
    expect(record(10).workMinutes, 0);
    expect(record(9).validate(), isNotNull);
  });
  test('야간·월경계 기록과 분 단위 계산', () {
    final night = WorkEntry(
      date: DateTime(2026, 10, 31),
      clockIn: DateTime(2026, 10, 31, 22),
      clockOut: DateTime(2026, 11, 1, 8),
    );
    expect(night.overtimeMinutes, 60);
    expect(monthKey(night.date), '2026-10');
    final minute = WorkEntry(
      date: date,
      clockIn: DateTime(2026, 10, 26, 9, 10),
      clockOut: DateTime(2026, 10, 26, 18, 45),
    );
    expect(minute.differenceMinutes, 35);
  });
  test('채워야 할 시간은 휴가와 기록별 기준을 반영하고 미확정은 제외', () {
    expect(record(17).remainingMinutes, 60);
    expect(record(18).remainingMinutes, 0);
    expect(record(20).remainingMinutes, 0);
    expect(record(14, leave: LeaveType.halfDay).remainingMinutes, 0);
    expect(WorkEntry(date: date, leave: LeaveType.annual).remainingMinutes, 0);
    expect(
      WorkEntry(date: date, leave: LeaveType.halfDay).remainingMinutes,
      240,
    );
    expect(
      WorkEntry(
        date: date,
        leave: LeaveType.hourly,
        hourlyLeaveMinutes: 90,
      ).remainingMinutes,
      390,
    );
    expect(
      WorkEntry(
        date: date,
        standardMinutes: 360,
        leave: LeaveType.halfDay,
      ).remainingMinutes,
      180,
    );
    expect(WorkEntry(date: date).remainingMinutes, isNull);
    expect(WorkEntry(date: date, clockIn: date).remainingMinutes, isNull);
    final summary = MonthSummary([
      record(20),
      record(17),
      WorkEntry(date: date, leave: LeaveType.halfDay),
      WorkEntry(date: date),
      WorkEntry(date: date, clockIn: date),
    ]);
    expect(summary.remaining, 300);
    expect(summary.overtime, 120);
  });
  test('휴가 인정시간과 미완료 구분', () {
    final annual = WorkEntry(date: date, leave: LeaveType.annual);
    expect(annual.isComplete, true);
    expect(annual.workMinutes, 0);
    expect(annual.differenceMinutes, 0);
    expect(record(14, leave: LeaveType.halfDay).differenceMinutes, 0);
    expect(record(15, leave: LeaveType.halfDay).overtimeMinutes, 60);
    expect(
      WorkEntry(
        date: date,
        leave: LeaveType.hourly,
        hourlyLeaveMinutes: 90,
      ).differenceMinutes,
      -390,
    );
    expect(
      WorkEntry(date: date, clockIn: date, leave: LeaveType.annual).isPending,
      true,
    );
    expect(WorkEntry(date: date).isEmpty, true);
    expect(
      WorkEntry(
        date: date,
        leave: LeaveType.hourly,
        hourlyLeaveMinutes: 0,
      ).validate(),
      isNotNull,
    );
    expect(
      WorkEntry(
        date: date,
        leave: LeaveType.halfDay,
        standardMinutes: 481,
      ).validate(),
      isNotNull,
    );
  });
  test('초과는 부족과 상계하지 않고 진행 중을 제외', () {
    final summary = MonthSummary([
      record(20),
      record(17),
      WorkEntry(date: date, leave: LeaveType.annual),
      WorkEntry(date: date, clockIn: date),
    ]);
    expect(summary.overtime, 120);
    expect(summary.completed, 3);
    expect(summary.pending, 1);
    expect(summary.leave, 480);
  });
  test('시간 길이와 윤년·연도경계', () {
    expect(durationText(-60), '01:00');
    expect(durationText(5), '00:05');
    expect(durationText(1380), '23:00');
    expect(durationText(1500), '25:00');
    expect(monthDates(DateTime(2024, 2)).length, 29);
    expect(monthDates(DateTime(2025, 2)).length, 28);
    expect(monthKey(DateTime(2026, 13)), '2027-01');
  });
  test('직렬화 복원과 손상·중복 거부', () {
    final row = record(20).toRow(updatedAt: 'r1');
    expect(WorkEntry.fromRow(row).overtimeMinutes, 120);
    expect(decodeRows([csvHeaders, row]).length, 1);
    expect(() => decodeRows([csvHeaders, row, row]), throwsFormatException);
    expect(
      () => decodeRows([
        ['wrong'],
      ]),
      throwsFormatException,
    );
    row[0] = '2026-02-30';
    expect(() => WorkEntry.fromRow(row), throwsFormatException);
  });
}
