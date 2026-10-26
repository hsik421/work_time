import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_time/data/settings_store.dart';
import 'package:work_time/domain/work_entry.dart';
import 'package:work_time/features/view_models.dart';
import 'package:work_time/ui/screens.dart';

import 'fakes.dart';

void main() {
  late WorkTimeViewModel model;
  Future<void> openEditor(WidgetTester tester, {WorkEntry? entry}) async {
    final date = DateTime(2026, 10, 26);
    model = WorkTimeViewModel(
      repository: MemoryRepository(),
      store: MemorySettings(),
      settings: const WorkSettings(),
      month: date,
      entries: entry == null ? [] : [entry],
      title: 'test',
    );
    model.select(date);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: model,
              builder: (context, _) => EntryEditor(model: model),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('출근 ${timeText(entry?.clockIn)}'));
    await tester.pumpAndSettle();
  }

  Finder fields() => find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextFormField),
  );
  testWidgets('키보드·숫자 키패드로 24시간제 출퇴근 입력', (tester) async {
    await openEditor(tester);
    expect(fields(), findsNWidgets(2));
    final textFields = tester.widgetList<TextField>(
      find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextField),
      ),
    );
    expect(
      textFields.every((field) => field.keyboardType == TextInputType.number),
      true,
    );
    await tester.enterText(fields().at(0), '09');
    await tester.enterText(fields().at(1), '15');
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(timeText(model.draft!.clockIn), '09:15');
    await tester.tap(find.text('퇴근 --:--'));
    await tester.pumpAndSettle();
    await tester.enterText(fields().at(0), '23');
    await tester.enterText(fields().at(1), '05');
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(timeText(model.draft!.clockOut), '23:05');
    expect(dateKey(model.draft!.clockOut!), '2026-10-26');
  });
  testWidgets('잘못된 시·분은 적용 차단, 취소는 이전 시간 유지', (tester) async {
    final original = WorkEntry(
      date: DateTime(2026, 10, 26),
      clockIn: DateTime(2026, 10, 26, 9, 30),
    );
    await openEditor(tester, entry: original);
    await tester.enterText(fields().at(0), '24');
    await tester.enterText(fields().at(1), '60');
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(timeText(model.draft!.clockIn), '09:30');
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(timeText(model.draft!.clockIn), '09:30');
  });
  testWidgets('시계 선택과 키보드 입력 전환 가능, 자정 값 유지', (tester) async {
    await openEditor(tester);
    await tester.enterText(fields().at(0), '00');
    await tester.enterText(fields().at(1), '05');
    await tester.tap(find.byIcon(Icons.access_time));
    await tester.pumpAndSettle();
    expect(fields(), findsNothing);
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    expect(fields(), findsNWidgets(2));
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(timeText(model.draft!.clockIn), '00:05');
  });
}
