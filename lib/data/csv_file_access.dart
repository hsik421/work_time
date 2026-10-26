import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'file_save_options.dart';

class CsvSource {
  const CsvSource(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

abstract interface class CsvFileAccess {
  bool get canChooseSaveLocation;
  Future<CsvSource?> open();
  Future<Uri?> save(Uint8List bytes, String suggestedName);
}

class SystemCsvFileAccess implements CsvFileAccess {
  @override
  bool get canChooseSaveLocation => supportsSaveLocation;
  @override
  Future<CsvSource?> open() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      dialogTitle: '불러올 CSV 파일 선택',
    );
    if (file == null) return null;
    final size = await file.length();
    if (size != null && size > 10 * 1024 * 1024) {
      throw const FormatException('CSV 파일은 10MB 이하로 선택하세요.');
    }
    return CsvSource(file.name, await file.readAsBytes());
  }

  @override
  Future<Uri?> save(Uint8List bytes, String suggestedName) =>
      FilePicker.saveFile(
        fileName: suggestedName,
        bytes: bytes,
        mimeType: 'text/csv',
        dialogTitle: 'CSV 저장 위치 선택',
        webOptions: csvSaveOptions(),
      );
}
