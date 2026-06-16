import 'package:flutter/material.dart';

import '../models/content_models.dart';

class AnswerPanel extends StatefulWidget {
  const AnswerPanel({
    super.key,
    required this.content,
    required this.submittedAnswer,
    required this.isCorrect,
    required this.onSubmit,
    required this.onShowSolution,
  });

  final ProblemContent content;
  final String? submittedAnswer;
  final bool? isCorrect;
  final ValueChanged<String> onSubmit;
  final VoidCallback onShowSolution;

  @override
  State<AnswerPanel> createState() => _AnswerPanelState();
}

class _AnswerPanelState extends State<AnswerPanel> {
  final TextEditingController controller = TextEditingController();
  String? selectedChoice;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choices = widget.content.choices;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE3EA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.content.prompt, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (choices.isEmpty)
              TextField(
                controller: controller,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  labelText: '답 입력',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: widget.onSubmit,
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: choices.map((choice) {
                  final selected = selectedChoice == choice;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(choice, style: const TextStyle(fontSize: 18)),
                    onSelected: (_) => setState(() => selectedChoice = choice),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final answer = choices.isEmpty ? controller.text : selectedChoice;
                if (answer == null || answer.trim().isEmpty) {
                  return;
                }
                widget.onSubmit(answer);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('정답 확인', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: widget.onShowSolution,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('풀이 보기', style: TextStyle(fontSize: 18)),
              ),
            ),
            if (widget.isCorrect != null) ...[
              const SizedBox(height: 14),
              _ResultBanner(
                isCorrect: widget.isCorrect!,
                answer: widget.submittedAnswer ?? '',
                correctAnswer: widget.content.correctAnswer,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.isCorrect,
    required this.answer,
    required this.correctAnswer,
  });

  final bool isCorrect;
  final String answer;
  final String correctAnswer;

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final textColor = isCorrect ? const Color(0xFF166534) : const Color(0xFF991B1B);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isCorrect ? '맞았어요!' : '다시 확인해 봐요. 정답: $correctAnswer',
        style: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
