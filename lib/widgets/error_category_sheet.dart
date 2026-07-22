import 'package:flutter/material.dart';

import '../models/learning_progress.dart';
import '../theme/app_theme.dart';

class ErrorCategorySheet extends StatelessWidget {
  const ErrorCategorySheet({
    super.key,
    required this.onCategorySelected,
  });

  final ValueChanged<ErrorCategory> onCategorySelected;

  static const _categoryOptions = [
    _CategoryOption(
      category: ErrorCategory.understandingTarget,
      title: '🔍 구하려는 것 놓침',
      description: '문제에서 무엇을 구해야 하는지 잘 못 봤어요.',
      color: Color(0xFFEFF6FF),
    ),
    _CategoryOption(
      category: ErrorCategory.understandingGiven,
      title: '📄 주어진 조건 해석 실수',
      description: '주어진 숫무나 수식 조건을 다르게 읽었어요.',
      color: Color(0xFFF0FDF4),
    ),
    _CategoryOption(
      category: ErrorCategory.planningConcept,
      title: '💡 개념/공식 연결 오류',
      description: '어떤 수학 개념이나 법칙을 써야 할지 생각 안 났어요.',
      color: Color(0xFFFEF3C7),
    ),
    _CategoryOption(
      category: ErrorCategory.planningOperation,
      title: '📐 연산 순서/식 세우기 오류',
      description: '덧셈, 뺄셈, 곱셈, 나눗셈 등 해결 순서를 틀렸어요.',
      color: Color(0xFFFEE2E2),
    ),
    _CategoryOption(
      category: ErrorCategory.executionCalculation,
      title: '✏️ 아쉬운 계산 실수',
      description: '식은 맞았는데 사칙연산 계산에서 오차가 생겼어요.',
      color: Color(0xFFF3E8FF),
    ),
    _CategoryOption(
      category: ErrorCategory.reviewUnit,
      title: '🔎 단위 또는 마지막 검산 부족',
      description: '단위(cm, 개 등)를 빠뜨렸거나 검산을 안 했어요.',
      color: Color(0xFFECFDF5),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.psychology, color: KidsPalette.cocoa, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '어느 생각 단계에서 아쉬웠나요?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: KidsPalette.ink,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '원인을 기록하면 다음에 AI 튜터가 맞춤 힌트를 준비할 수 있어요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: KidsPalette.cocoaSoft,
                ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _categoryOptions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final option = _categoryOptions[index];
                return InkWell(
                  onTap: () {
                    onCategorySelected(option.category);
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: option.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KidsPalette.line),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: KidsPalette.ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                option.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: KidsPalette.cocoaSoft),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryOption {
  const _CategoryOption({
    required this.category,
    required this.title,
    required this.description,
    required this.color,
  });

  final ErrorCategory category;
  final String title;
  final String description;
  final Color color;
}
