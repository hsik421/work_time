import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_view_model.dart';
import '../features/startup/intro_screen.dart';
import '../features/attendance/views/work_main_screen.dart';

class WorkTimeApp extends StatefulWidget {
  const WorkTimeApp({super.key, required this.model});
  final AppViewModel model;
  @override
  State<WorkTimeApp> createState() => _WorkTimeAppState();
}

class _WorkTimeAppState extends State<WorkTimeApp> {
  @override
  void initState() {
    super.initState();
    widget.model.start();
  }

  @override
  void dispose() {
    widget.model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '나의 근무 달력',
    locale: const Locale('ko', 'KR'),
    supportedLocales: const [Locale('ko', 'KR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff176b52),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xfff5f7f5),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: AnimatedBuilder(
      animation: widget.model,
      builder: (context, _) => switch (widget.model.stage) {
        StartupStage.ready => WorkMainScreen(
          app: widget.model,
          model: widget.model.work!,
        ),
        _ => IntroScreen(app: widget.model),
      },
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
}
