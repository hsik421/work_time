import 'package:flutter/material.dart';
import 'package:work_time/shared/presentation/work_colors.dart';

import 'csv_view_model.dart';

class CsvPanel extends StatelessWidget {
  const CsvPanel({
    super.key,
    required this.model,
    required this.busy,
    required this.error,
    required this.notice,
    required this.saving,
    required this.onImport,
    required this.onExport,
  });
  final CsvViewModel model;
  final bool busy;
  final String error;
  final String notice;
  final bool saving;
  final VoidCallback onImport;
  final VoidCallback onExport;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${model.fileName} · 전체 ${model.count}일'),
          const SizedBox(height: 6),
          Text(
            model.needsExport
                ? '기기에 보관됨 · CSV 저장 필요'
                : 'CSV와 동일한 기록 · 기기에도 보관됨',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: saving || busy ? null : onImport,
                icon: const Icon(Icons.folder_open),
                label: const Text('CSV 불러오기'),
              ),
              FilledButton.icon(
                onPressed: saving || busy ? null : onExport,
                icon: const Icon(Icons.save_alt),
                label: Text(
                  model.canChooseSaveLocation ? 'CSV 저장 위치 선택' : 'CSV 다운로드',
                ),
              ),
            ],
          ),
          if (!model.canChooseSaveLocation)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('이 브라우저는 저장 위치 선택을 지원하지 않습니다. 다운로드 설정에 따라 저장됩니다.'),
            ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error, style: const TextStyle(color: negativeColor)),
            ),
          if (notice.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(notice),
            ),
        ],
      ),
    ),
  );
}
