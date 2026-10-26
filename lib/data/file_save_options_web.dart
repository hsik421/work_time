import 'package:file_picker/file_picker.dart' show WebOptions;
import 'package:file_picker_web/file_picker_web.dart';

bool get supportsSaveLocation => supportsShowSaveFileDialog;
WebOptions csvSaveOptions() => FilePickerWebOptions(
  saveMode: supportsShowSaveFileDialog
      ? WebSaveFileMode.dialog
      : WebSaveFileMode.download,
);
