import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_time/data/csv_file_access.dart';

void main() {
  late FilePickerPlatform original;
  late PickerStub picker;
  setUp(() {
    original = FilePickerPlatform.instance;
    picker = PickerStub();
    FilePickerPlatform.instance = picker;
  });
  tearDown(() {
    FilePickerPlatform.instance = original;
  });
  test('시스템 파일 선택 취소와 CSV 확장자 필터 전달', () async {
    expect(await SystemCsvFileAccess().open(), isNull);
    expect(picker.extensions, ['csv']);
    expect(picker.type, FileType.custom);
  });
  test('선택한 저장 위치에 CSV 바이트·이름·MIME 전달 및 취소 구분', () async {
    final access = SystemCsvFileAccess();
    final bytes = Uint8List.fromList([239, 187, 191, 65]);
    expect(await access.save(bytes, '근무.csv'), Uri.file('C:/records/근무.csv'));
    expect(picker.bytes, bytes);
    expect(picker.name, '근무.csv');
    expect(picker.mime, 'text/csv');
    picker.location = null;
    expect(await access.save(bytes, '근무.csv'), isNull);
  });
}

class PickerStub extends FilePickerPlatform {
  List<String>? extensions;
  FileType? type;
  Uint8List? bytes;
  String? name, mime;
  Uri? location = Uri.file('C:/records/근무.csv');
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    extensions = allowedExtensions;
    this.type = type;
    return null;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    this.bytes = bytes;
    name = fileName;
    mime = mimeType;
    return location;
  }
}
