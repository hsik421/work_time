import 'dart:math' as math;

enum LeaveType {
  none('없음'),
  annual('연차'),
  halfDay('반차'),
  hourly('시간차');

  const LeaveType(this.label);
  final String label;
}

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String monthKey(DateTime date) => dateKey(date).substring(0, 7);
String durationText(int minutes) =>
    '${(minutes.abs() ~/ 60).toString().padLeft(2, '0')}:${(minutes.abs() % 60).toString().padLeft(2, '0')}';
String timeText(DateTime? value) => value == null
    ? '--:--'
    : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
List<DateTime> monthDates(DateTime month) => List.generate(
  DateTime(month.year, month.month + 1, 0).day,
  (i) => DateTime(month.year, month.month, i + 1),
);

class WorkEntry {
  const WorkEntry({
    required this.date,
    this.clockIn,
    this.clockOut,
    this.standardMinutes = 480,
    this.leave = LeaveType.none,
    this.hourlyLeaveMinutes = 0,
    this.revision = '',
  });
  final DateTime date;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final int standardMinutes;
  final LeaveType leave;
  final int hourlyLeaveMinutes;
  final String revision;

  bool get isEmpty =>
      clockIn == null && clockOut == null && leave == LeaveType.none;
  bool get isPending => clockIn != null && clockOut == null;
  bool get isComplete => !isEmpty && !isPending;
  int get leaveMinutes => switch (leave) {
    LeaveType.none => 0,
    LeaveType.annual => standardMinutes,
    LeaveType.halfDay => standardMinutes ~/ 2,
    LeaveType.hourly => hourlyLeaveMinutes,
  };
  // Treat input as wall-clock values; no daylight-saving conversion.
  int get workMinutes => clockIn == null || clockOut == null
      ? 0
      : _wallTime(clockOut!).difference(_wallTime(clockIn!)).inMinutes - 60;
  int? get differenceMinutes =>
      isComplete ? workMinutes + leaveMinutes - standardMinutes : null;
  int get overtimeMinutes => math.max(0, differenceMinutes ?? 0);
  int? get remainingMinutes =>
      isComplete ? math.max(0, -differenceMinutes!) : null;
  String get displayText => isEmpty
      ? ''
      : isPending
      ? '진행 중'
      : durationText(differenceMinutes!);
  String get statusLabel => isPending
      ? '진행 중'
      : (differenceMinutes ?? 0) > 0
      ? '초과'
      : (differenceMinutes ?? 0) < 0
      ? '부족'
      : '충족';
  static DateTime _wallTime(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day, d.hour, d.minute);

  String? validate() {
    if (standardMinutes <= 0) return '기준근무시간은 양의 정수여야 합니다.';
    if (clockIn != null && dateKey(clockIn!) != dateKey(date)) {
      return '출근 날짜가 기록 날짜와 다릅니다.';
    }
    if (clockOut != null && clockIn == null) return '퇴근시간보다 출근시간을 먼저 입력하세요.';
    if (clockOut != null && workMinutes < 0) return '출퇴근 간격은 휴게 1시간 이상이어야 합니다.';
    if (leave == LeaveType.halfDay && standardMinutes.isOdd) {
      return '반차 계산을 위해 기준근무시간을 짝수 분으로 설정하세요.';
    }
    if (leave == LeaveType.hourly &&
        (hourlyLeaveMinutes <= 0 || hourlyLeaveMinutes > standardMinutes)) {
      return '시간차는 1분 이상 기준근무시간 이하로 입력하세요.';
    }
    return null;
  }

  WorkEntry copyWith({
    DateTime? clockIn,
    DateTime? clockOut,
    bool clearIn = false,
    bool clearOut = false,
    LeaveType? leave,
    int? hourlyLeaveMinutes,
  }) => WorkEntry(
    date: date,
    clockIn: clearIn ? null : clockIn ?? this.clockIn,
    clockOut: clearOut ? null : clockOut ?? this.clockOut,
    standardMinutes: standardMinutes,
    leave: leave ?? this.leave,
    hourlyLeaveMinutes: hourlyLeaveMinutes ?? this.hourlyLeaveMinutes,
    revision: revision,
  );
  List<Object> toRow({String? updatedAt}) => [
    dateKey(date),
    clockIn == null ? '' : _iso(clockIn!),
    clockOut == null ? '' : _iso(clockOut!),
    60,
    standardMinutes,
    leave.name,
    leave == LeaveType.hourly ? hourlyLeaveMinutes : 0,
    updatedAt ?? revision,
    1,
  ];
  static String _iso(DateTime d) => '${dateKey(d)}T${timeText(d)}';

  factory WorkEntry.fromRow(List<dynamic> cells) {
    final row = List<Object?>.from(cells);
    while (row.length < 9) {
      row.add('');
    }
    DateTime parse(String text, {bool dateOnly = false}) {
      final pattern = dateOnly
          ? RegExp(r'^\d{4}-\d{2}-\d{2}$')
          : RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$');
      if (!pattern.hasMatch(text)) {
        throw const FormatException('날짜 형식이 올바르지 않습니다.');
      }
      final parsed = DateTime.parse(text);
      if ((dateOnly ? dateKey(parsed) : _iso(parsed)) != text) {
        throw const FormatException('존재하지 않는 날짜 또는 시간입니다.');
      }
      return parsed;
    }

    int integer(int index) =>
        int.tryParse('${row[index]}') ??
        (throw const FormatException('시간 분 또는 버전이 올바르지 않습니다.'));
    if (integer(3) != 60 || integer(8) != 1) {
      throw const FormatException('휴게 정책 또는 스키마 버전이 다릅니다.');
    }
    final entry = WorkEntry(
      date: parse('${row[0]}', dateOnly: true),
      clockIn: '${row[1]}'.isEmpty ? null : parse('${row[1]}'),
      clockOut: '${row[2]}'.isEmpty ? null : parse('${row[2]}'),
      standardMinutes: integer(4),
      leave: LeaveType.values.firstWhere(
        (v) => v.name == '${row[5]}',
        orElse: () => throw const FormatException('휴가 유형이 올바르지 않습니다.'),
      ),
      hourlyLeaveMinutes: integer(6),
      revision: '${row[7]}',
    );
    final error = entry.validate();
    if (error != null || entry.isEmpty) {
      throw FormatException(error ?? '빈 기록이 저장되어 있습니다.');
    }
    return entry;
  }
}

class MonthSummary {
  MonthSummary(Iterable<WorkEntry> entries) {
    for (final entry in entries) {
      if (entry.isPending) {
        pending++;
      }
      if (entry.isComplete) {
        completed++;
        work += entry.workMinutes;
        leave += entry.leaveMinutes;
        overtime += entry.overtimeMinutes;
        remaining += entry.remainingMinutes!;
      }
    }
  }
  int completed = 0,
      pending = 0,
      work = 0,
      leave = 0,
      overtime = 0,
      remaining = 0;
}
