import 'package:flutter/material.dart';

import '../models/content_models.dart';
import '../models/tutor_models.dart';

class TutorChatPanel extends StatefulWidget {
  const TutorChatPanel({
    super.key,
    required this.content,
    required this.messages,
    required this.isBusy,
    required this.submittedAnswer,
    required this.isCorrect,
    required this.onSubmit,
    required this.onSend,
    required this.onHint,
    required this.onNextStep,
    required this.hasNextProblem,
    required this.onNextProblem,
  });

  final ProblemContent content;
  final List<TutorMessage> messages;
  final bool isBusy;
  final String? submittedAnswer;
  final bool? isCorrect;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onSend;
  final VoidCallback onHint;
  final VoidCallback onNextStep;
  final bool hasNextProblem;
  final VoidCallback onNextProblem;

  @override
  State<TutorChatPanel> createState() => _TutorChatPanelState();
}

class _TutorChatPanelState extends State<TutorChatPanel> {
  final TextEditingController chatController = TextEditingController();
  final TextEditingController answerController = TextEditingController();
  String? selectedChoice;

  @override
  void dispose() {
    chatController.dispose();
    answerController.dispose();
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
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '\u0041\u0049 \uD29C\uD130',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.content.prompt,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            if (choices.isEmpty)
              TextField(
                controller: answerController,
                style: const TextStyle(fontSize: 18),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '\uB2F5 \uC785\uB825',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _submitAnswer,
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: choices.map((choice) {
                  final selected = selectedChoice == choice;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(choice, style: const TextStyle(fontSize: 17)),
                    onSelected: widget.isBusy
                        ? null
                        : (_) => setState(() => selectedChoice = choice),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.isBusy ? null : _submitSelectedAnswer,
              icon: const Icon(Icons.check),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '\uC815\uB2F5 \uD655\uC778',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
            if (widget.isCorrect != null) ...[
              const SizedBox(height: 12),
              _ResultBanner(isCorrect: widget.isCorrect!),
            ],
            if (widget.isCorrect == true) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.onNextProblem,
                icon: Icon(
                  widget.hasNextProblem
                      ? Icons.navigate_next
                      : Icons.check_circle_outline,
                ),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    widget.hasNextProblem
                        ? '\uB2E4\uC74C \uBB38\uC81C\uB85C'
                        : '\uB2E8\uC6D0 \uB9C8\uCE58\uAE30',
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ),
            ],
            const Divider(height: 30),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 390),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.messages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _MessageBubble(message: widget.messages[index]);
                },
              ),
            ),
            if (widget.isBusy) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.isBusy ? null : widget.onHint,
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('\uD78C\uD2B8'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.isBusy ? null : widget.onNextStep,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('\uB2E4\uC74C \uB2E8\uACC4'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: chatController,
                    minLines: 1,
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      labelText:
                          '\uD480\uC774\uB098 \uC9C8\uBB38\uC744 \uC801\uC5B4\uBCF4\uC138\uC694',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: '\uBCF4\uB0B4\uAE30',
                  onPressed:
                      widget.isBusy ? null : () => _send(chatController.text),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submitSelectedAnswer() {
    final answer = widget.content.choices.isEmpty
        ? answerController.text.trim()
        : selectedChoice;
    if (answer == null || answer.trim().isEmpty) {
      return;
    }
    widget.onSubmit(answer);
  }

  void _submitAnswer(String value) {
    final answer = value.trim();
    if (answer.isEmpty) {
      return;
    }
    widget.onSubmit(answer);
  }

  void _send(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return;
    }
    widget.onSend(text);
    chatController.clear();
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.isCorrect});

  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5);
    final textColor =
        isCorrect ? const Color(0xFF166534) : const Color(0xFF9A3412);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isCorrect
            ? '\uB9DE\uC558\uC5B4\uC694! \uC774\uC81C \uD29C\uD130\uC640 \uD480\uC774\uB97C \uC815\uB9AC\uD574\uBCF4\uC138\uC694.'
            : '\uB2E4\uC2DC \uD655\uC778\uD574 \uBD10\uC694. \uD29C\uD130\uC640 \uD55C \uB2E8\uACC4 \uB354 \uD480\uC5B4\uBD05\uC2DC\uB2E4.',
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final TutorMessage message;

  @override
  Widget build(BuildContext context) {
    final isTutor = message.isTutor;
    final bubbleColor =
        isTutor ? const Color(0xFFF1F5F9) : const Color(0xFFDBEAFE);
    final textColor =
        isTutor ? const Color(0xFF0F172A) : const Color(0xFF1E3A8A);
    return Align(
      alignment: isTutor ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: textColor,
            fontSize: 15.5,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
