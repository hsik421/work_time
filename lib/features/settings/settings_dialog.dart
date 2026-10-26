import 'package:flutter/material.dart';

Future<int?> showWorkSettingsDialog(BuildContext context, int initialMinutes) =>
    showDialog<int>(
      context: context,
      builder: (context) => WorkSettingsDialog(initialMinutes: initialMinutes),
    );

class WorkSettingsDialog extends StatefulWidget {
  const WorkSettingsDialog({super.key, required this.initialMinutes});
  final int initialMinutes;
  @override
  State<WorkSettingsDialog> createState() => _WorkSettingsDialogState();
}

class _WorkSettingsDialogState extends State<WorkSettingsDialog> {
  late final TextEditingController _controller;
  String? _validation;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialMinutes}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('근무 설정'),
    content: TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: '하루 기준근무시간 (분)',
        errorText: _validation,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: () {
          final value = int.tryParse(_controller.text);
          if (value == null || value <= 0) {
            setState(() => _validation = '양의 정수 분을 입력하세요.');
            return;
          }
          Navigator.pop(context, value);
        },
        child: const Text('적용'),
      ),
    ],
  );
}
