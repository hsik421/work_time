import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_time/data/settings_store.dart';
import 'package:work_time/features/attendance/view_models/work_time_view_model.dart';
import 'package:work_time/features/attendance/views/day_list_panel.dart';
import 'package:work_time/features/attendance/widgets/save_success_overlay.dart';

import 'fakes.dart';

void main() {
  testWidgets('목록 직접 입력은 체크 저장 후 적용되고 오류·실패 시 보존', (tester) async {
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
    addTearDown(model.dispose);
    model.select(date);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: model,
              builder: (context, _) =>
                  DayListPanel(model: model, onSelect: model.select),
            ),
          ),
        ),
      ),
    );
    final start = find.byKey(const ValueKey('inline-2026-10-01-true'));
    final end = find.byKey(const ValueKey('inline-2026-10-01-false'));
    await tester.enterText(start, '09:00');
    await tester.enterText(end, '18:00');
    await tester.pump();
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(repo.records, isEmpty);
    expect(model.summary.completed, 0);
    await tester.enterText(end, '24:60');
    await tester.pump();
    expect(await model.save(), false);
    expect(model.dirty, true);
    expect(repo.records, isEmpty);
    await tester.enterText(end, '17:00');
    await tester.pump();
    repo.failSave = true;
    await tester.ensureVisible(find.text('저장'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(model.draft, isNotNull);
    expect(find.byType(SaveSuccessOverlay), findsNothing);
    expect(repo.records, isEmpty);
    expect(find.text('17:00'), findsOneWidget);
    repo.failSave = false;
    await tester.tap(find.text('저장'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SaveSuccessOverlay), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    final asset = tester.widget<Image>(find.byType(Image)).image as AssetImage;
    expect(saveSuccessImages, contains(asset.assetName));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester
          .widget<RotationTransition>(
            find.descendant(
              of: find.byType(SaveSuccessOverlay),
              matching: find.byType(RotationTransition),
            ),
          )
          .turns
          .value,
      closeTo(0.5, 0.02),
    );
    await tester.pumpAndSettle();
    expect(model.entry(date)!.remainingMinutes, 60);
    expect(model.summary.remaining, 60);
    expect(model.draft, isNull);
    expect(find.byType(SaveSuccessOverlay), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
