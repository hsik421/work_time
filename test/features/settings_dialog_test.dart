import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_time/features/settings/settings_dialog.dart';

void main() {
  testWidgets('분리한 설정창은 기존 기준을 표시하고 잘못된 입력을 차단', (tester) async {
    int? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showWorkSettingsDialog(context, 480);
              },
              child: const Text('설정 열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('설정 열기'));
    await tester.pumpAndSettle();
    expect(find.text('480'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(find.text('양의 정수 분을 입력하세요.'), findsOneWidget);
    expect(result, isNull);
    await tester.enterText(find.byType(TextField), '360');
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(result, 360);
    expect(tester.takeException(), isNull);
  });
}
