import 'package:flutter/material.dart';

import '../models/content_models.dart';

class ProgressPanel extends StatelessWidget {
  const ProgressPanel({super.key, required this.progress});

  final SessionProgress progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.accuracy * 100).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('학습 결과', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Metric(label: '푼 문제', value: '${progress.solvedCount}')),
                Expanded(child: _Metric(label: '맞힌 문제', value: '${progress.correctCount}')),
                Expanded(child: _Metric(label: '정답률', value: '$percent%')),
              ],
            ),
            if (progress.wrongResults.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                '틀린 문제',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              ...progress.wrongResults.map(
                (result) => Text(
                  result.problem.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
