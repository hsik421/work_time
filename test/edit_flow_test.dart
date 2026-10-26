import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:work_time/data/settings_store.dart';
import 'package:work_time/domain/work_entry.dart';
import 'package:work_time/app/app_view_model.dart';
import 'package:work_time/features/attendance/view_models/work_time_view_model.dart';

import 'package:work_time/features/attendance/views/work_main_screen.dart';

import 'fakes.dart';

void main() {
  testWidgets('리스트에서 연차 저장 후 달력·합계가 공통 기록으로 갱신', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = MemoryRepository();
    final date = DateTime(2026, 10, 1);
    final model = WorkTimeViewModel(
      repository: repo,
      store: MemorySettings(),
      settings: const WorkSettings(),
      month: date,
      entries: [],
      title: 'test',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WorkMainScreen(
          app: AppViewModel(store: MemorySettings()),
          model: model,
        ),
      ),
    );
    final row = find.byKey(const ValueKey('day-2026-10-01'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    final dropdown = find.byType(DropdownButtonFormField<LeaveType>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('연차').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('저장'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(repo.records.length, 1);
    expect(model.summary.leave, 480);
    expect(model.summary.completed, 1);
    expect(model.entry(date)!.displayText, '00:00');
    expect(model.summary.remaining, 0);
    expect(find.text('채워야 할 시간 (완료 기록)'), findsOneWidget);
    expect(find.textContaining('채워야 할 시간 00:00'), findsWidgets);
    expect(model.draft, isNull);
    expect(tester.takeException(), isNull);
  });
}
