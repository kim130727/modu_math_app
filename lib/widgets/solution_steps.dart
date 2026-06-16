import 'package:flutter/material.dart';

import '../models/content_models.dart';

class SolutionSteps extends StatelessWidget {
  const SolutionSteps({super.key, required this.steps});

  final List<SolutionStep> steps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDE3EA)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('풀이 단계', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (steps.isEmpty)
                const Text('등록된 풀이 단계가 없습니다.', style: TextStyle(fontSize: 17))
              else
                ...steps.indexed.map((entry) {
                  final index = entry.$1 + 1;
                  final step = entry.$2;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 15,
                          child: Text('$index'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            step.value.isEmpty
                                ? step.explanation
                                : '${step.explanation}\n${step.value}',
                            style: const TextStyle(fontSize: 17, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
