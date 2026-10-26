import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_time/app/app_view_model.dart';

import '../fakes.dart';

void main() {
  test('CSV 처리 중 설정과 편집을 차단하고 취소 후 잠금을 해제', () async {
    final files = WaitingFiles();
    final app = AppViewModel(store: MemorySettings(), files: files);
    addTearDown(app.dispose);
    await app.start();
    var notifications = 0;
    app.addListener(() => notifications++);

    final exporting = app.exportCsv();
    expect(app.csv.busy, true);
    expect(app.busy, true);
    expect(app.work!.canEdit, false);
    expect(await app.updateStandard(360), false);
    expect(app.settings.standardMinutes, 480);
    expect(await app.importCsv(), false);

    files.result.complete(null);
    expect(await exporting, false);
    expect(app.csv.busy, false);
    expect(app.busy, false);
    expect(app.work!.canEdit, true);
    expect(notifications, greaterThanOrEqualTo(2));
  });

  test('설정 실패는 기준을 유지하고 다음 CSV 작업은 이전 오류를 지움', () async {
    final store = MemorySettings();
    final app = AppViewModel(store: store, files: MemoryFiles());
    addTearDown(app.dispose);
    await app.start();
    store.failWrite = true;
    expect(await app.updateStandard(360), false);
    expect(app.settingsModel.error, isNotEmpty);
    expect(app.error, app.settingsModel.error);
    expect(app.work!.settings.standardMinutes, 480);
    expect(app.work!.canEdit, true);

    store.failWrite = false;
    expect(await app.exportCsv(), true);
    expect(app.error, isEmpty);
    expect(app.csv.notice, isNotEmpty);
    expect(app.notice, app.csv.notice);
    expect(await app.updateStandard(360), true);
    expect(app.csv.notice, isEmpty);
    expect(app.notice, app.settingsModel.notice);
    expect(app.settings.standardMinutes, 360);
  });
}

class WaitingFiles extends MemoryFiles {
  final result = Completer<Uri?>();
  @override
  Future<Uri?> save(Uint8List bytes, String suggestedName) => result.future;
}
