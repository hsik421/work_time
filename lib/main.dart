import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/app_view_model.dart';
import 'data/settings_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(WorkTimeApp(model: AppViewModel(store: LocalSettingsStore())));
}
