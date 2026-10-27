import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_time/features/attendance/widgets/animated_day_item.dart';
import 'package:work_time/features/attendance/widgets/save_success_overlay.dart';

void main() {
  testWidgets('입력 영역은 흔들림 없이 접힘', (tester) async {
    Future<void> show(bool editing) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: AnimatedDayItem(
              header: const SizedBox(height: 64),
              editor: editing ? const SizedBox(height: 240) : null,
            ),
          ),
        ),
      ),
    );
    await show(true);
    expect(tester.getSize(find.byType(AnimatedDayItem)).height, 304);
    await show(false);
    await tester.pump(const Duration(milliseconds: 40));
    final height = tester.getSize(find.byType(AnimatedDayItem)).height;
    expect(height, greaterThan(64));
    expect(height, lessThan(304));
    expect(
      find.descendant(
        of: find.byType(AnimatedDayItem),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AnimatedDayItem)).height, 64);
  });

  for (final reduceMotion in [false, true]) {
    testWidgets('dim·단일 이미지·500ms 회전/종료 (동작 줄이기 $reduceMotion)', (
      tester,
    ) async {
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                SaveSuccessOverlay(
                  imageAsset: saveSuccessImages.first,
                  reduceMotion: reduceMotion,
                  onComplete: () => completed++,
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<ModalBarrier>(
              find.descendant(
                of: find.byType(SaveSuccessOverlay),
                matching: find.byType(ModalBarrier),
              ),
            )
            .color,
        const Color(0x80000000),
      );
      expect(find.byType(Image), findsOneWidget);
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
        closeTo(reduceMotion ? 0 : 0.5, 0.001),
      );
      expect(completed, 0);
      await tester.pump(const Duration(milliseconds: 249));
      expect(completed, 0);
      await tester.pump(const Duration(milliseconds: 2));
      expect(completed, 1);
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
        reduceMotion ? 0 : 1,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
