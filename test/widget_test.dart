import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_time/data/settings_store.dart';
import 'package:work_time/domain/work_entry.dart';
import 'package:work_time/app/app_view_model.dart';
import 'package:work_time/features/attendance/view_models/work_time_view_model.dart';

import 'package:work_time/app/app.dart';
import 'package:work_time/features/attendance/views/work_main_screen.dart';
import 'package:work_time/shared/presentation/work_colors.dart';

import 'fakes.dart';

void main() {
  testWidgets('최초 실행에서 파일 버튼 표시, 선택 취소 시 기존 화면 유지', (tester) async {
    final app = AppViewModel(
      store: MemorySettings(),
      files: MemoryFiles(),
      today: DateTime(2026, 10, 26),
    );
    await tester.pumpWidget(WorkTimeApp(model: app));
    await tester.pumpAndSettle();
    expect(find.text('CSV 불러오기'), findsOneWidget);
    expect(find.text('CSV 저장 위치 선택'), findsOneWidget);
    await tester.tap(find.text('CSV 불러오기'));
    await tester.pumpAndSettle();
    expect(find.text('날짜별 기록'), findsOneWidget);
    expect(app.repository.count, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('달력 상태 색상과 데이터 없는 연도', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final date = DateTime(2026, 10, 1);
    final repo = MemoryRepository();
    final entries = [
      WorkEntry(date: date, leave: LeaveType.annual),
      WorkEntry(date: DateTime(2026, 10, 2), leave: LeaveType.halfDay),
      WorkEntry(
        date: DateTime(2026, 10, 3),
        clockIn: DateTime(2026, 10, 3, 9),
        clockOut: DateTime(2026, 10, 3, 20),
      ),
    ];
    final vm = WorkTimeViewModel(
      repository: repo,
      store: MemorySettings(),
      settings: const WorkSettings(),
      month: date,
      entries: entries,
      title: 'test',
    );
    final app = AppViewModel(store: MemorySettings(), today: date);
    await tester.pumpWidget(
      MaterialApp(
        home: WorkMainScreen(app: app, model: vm),
      ),
    );
    final green = tester
        .widgetList<Text>(find.text('02:00'))
        .where((w) => w.style?.color == positiveColor);
    expect(green, isNotEmpty);
    expect(
      tester
          .widgetList<Text>(find.text('04:00'))
          .any((w) => w.style?.color == negativeColor),
      true,
    );
    expect(
      tester
          .widgetList<Text>(find.text('00:00'))
          .any((w) => w.style?.color == Colors.black),
      true,
    );
    await tester.tap(find.byTooltip('다음 해'));
    await tester.pumpAndSettle();
    expect(find.text('2027년 10월'), findsOneWidget);
    expect(vm.dates.length, 31);
    expect(tester.takeException(), isNull);
  });
  testWidgets('좁은 화면과 큰 글자에서 달력 오버플로 없음', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final date = DateTime(2026, 10, 26);
    final vm = WorkTimeViewModel(
      repository: MemoryRepository(),
      store: MemorySettings(),
      settings: const WorkSettings(),
      month: date,
      entries: [WorkEntry(date: date, leave: LeaveType.annual)],
      title: 'test',
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: WorkMainScreen(
          app: AppViewModel(store: MemorySettings()),
          model: vm,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
