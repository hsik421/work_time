import 'package:flutter/material.dart';

Future<bool?> confirmCsvImport(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('CSV 기록으로 교체할까요?'),
      content: const Text(
        '모든 월의 현재 기록을 선택한 CSV 내용으로 교체합니다. 필요하면 먼저 CSV로 저장하세요. 파일 선택을 취소하거나 검증에 실패하면 기존 기록을 유지합니다.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('파일 선택'),
        ),
      ],
    ),
  );
}
