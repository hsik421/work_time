import 'package:flutter/material.dart';
import 'package:work_time/app/app_view_model.dart';
import 'package:work_time/shared/presentation/work_colors.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key, required this.app});
  final AppViewModel app;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                '나의 근무 달력',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text('출퇴근과 휴가를 한눈에'),
              const SizedBox(height: 32),
              if (app.busy) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Semantics(liveRegion: true, child: Text(app.message)),
              ],
              if (app.error.isNotEmpty) ...[
                Text(app.error, style: const TextStyle(color: negativeColor)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: app.start,
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 시도'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
