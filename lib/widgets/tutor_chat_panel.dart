import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/content_models.dart';
import '../models/tutor_models.dart';
import '../utils/tutor_text_sanitizer.dart';

class TutorChatPanel extends StatefulWidget {
  const TutorChatPanel({
    super.key,
    required this.content,
    required this.mode,
    required this.openAiConfigured,
    required this.openAiModel,
    required this.messages,
    required this.isBusy,
    required this.submittedAnswer,
    required this.isCorrect,
    required this.onModeChanged,
    required this.onSubmit,
    required this.onSend,
    required this.onHint,
    required this.onNextStep,
    required this.onRestart,
    required this.onReset,
    required this.hasNextProblem,
    required this.onNextProblem,
  });

  final ProblemContent content;
  final TutorMode mode;
  final bool openAiConfigured;
  final String openAiModel;
  final List<TutorMessage> messages;
  final bool isBusy;
  final String? submittedAnswer;
  final bool? isCorrect;
  final ValueChanged<TutorMode> onModeChanged;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onSend;
  final VoidCallback onHint;
  final VoidCallback onNextStep;
  final VoidCallback onRestart;
  final VoidCallback onReset;
  final bool hasNextProblem;
  final VoidCallback onNextProblem;

  @override
  State<TutorChatPanel> createState() => _TutorChatPanelState();
}

class _TutorChatPanelState extends State<TutorChatPanel> {
  final TextEditingController chatController = TextEditingController();
  final TextEditingController answerController = TextEditingController();
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();
  String? selectedChoice;
  bool voiceEnabled = false;
  bool speechAvailable = false;
  bool isListening = false;
  int lastSpokenMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _configureVoice();
  }

  @override
  void didUpdateWidget(covariant TutorChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content.summary.id != widget.content.summary.id) {
      selectedChoice = null;
      answerController.clear();
      chatController.clear();
    }
    final newestMessage = widget.messages.lastOrNull;
    if (voiceEnabled &&
        newestMessage?.isTutor == true &&
        widget.messages.length > lastSpokenMessageCount) {
      _speakLatestTutorMessage();
    }
  }

  @override
  void dispose() {
    speech.cancel();
    tts.stop();
    chatController.dispose();
    answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choices = widget.content.choices;
    final tutorChoices = widget.messages.lastWhereOrNull((message) {
          return message.isTutor && message.choices.isNotEmpty;
        })?.choices ??
        const <String>[];
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.school_outlined,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rule Tutor Preview',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        _subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: voiceEnabled ? '자동 읽기 끄기' : '자동 읽기 켜기',
                  onPressed: _toggleVoice,
                  icon: Icon(
                    voiceEnabled
                        ? Icons.volume_up_outlined
                        : Icons.volume_off_outlined,
                  ),
                ),
                IconButton(
                  tooltip: '마지막 튜터 말 듣기',
                  onPressed: _speakLatestTutorMessage,
                  icon: const Icon(Icons.record_voice_over_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<TutorMode>(
              segments: [
                const ButtonSegment(
                  value: TutorMode.rule,
                  icon: Icon(Icons.account_tree_outlined),
                  label: Text('Rule'),
                ),
                const ButtonSegment(
                  value: TutorMode.mock,
                  icon: Icon(Icons.speed_outlined),
                  label: Text('Mock'),
                ),
                ButtonSegment(
                  value: TutorMode.openai,
                  enabled: widget.openAiConfigured,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('OpenAI'),
                ),
              ],
              selected: {widget.mode},
              onSelectionChanged: widget.isBusy
                  ? null
                  : (selection) => widget.onModeChanged(selection.first),
            ),
            if (widget.mode == TutorMode.openai &&
                !widget.openAiConfigured) ...[
              const SizedBox(height: 10),
              const _Notice(
                text: 'OPENAI_API_KEY가 .env에서 확인되지 않았습니다.',
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: widget.isBusy ? null : widget.onRestart,
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: const Text('시작'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.isBusy || widget.messages.isEmpty
                      ? null
                      : widget.onNextStep,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('다음 단계'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.isBusy || widget.messages.isEmpty
                      ? null
                      : widget.onRestart,
                  icon: const Icon(Icons.replay_outlined),
                  label: const Text('처음부터'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.isBusy || widget.messages.isEmpty
                      ? null
                      : widget.onReset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('초기화'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.content.prompt,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 16),
            if (choices.isEmpty)
              TextField(
                controller: answerController,
                style: const TextStyle(fontSize: 18),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '정답 입력',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _submitAnswer,
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: choices.map((choice) {
                  final selected = selectedChoice == choice;
                  return ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    avatar: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 19,
                    ),
                    label: Text(
                      choice,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    labelPadding: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    selectedColor: colorScheme.primaryContainer,
                    side: BorderSide(
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onSelected: widget.isBusy
                        ? null
                        : (_) => setState(() => selectedChoice = choice),
                  );
                }).toList(),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: widget.isBusy ? null : _submitSelectedAnswer,
              icon: const Icon(Icons.check),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('정답 확인', style: TextStyle(fontSize: 18)),
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
                    widget.hasNextProblem ? '다음 문제로' : '단원 마치기',
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ),
            ],
            const Divider(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 390),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: widget.messages.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('solvable JSON을 바탕으로 단계별 선택지를 자동 생성합니다.'),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        shrinkWrap: true,
                        itemCount: widget.messages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _MessageBubble(
                              message: widget.messages[index]);
                        },
                      ),
              ),
            ),
            if (widget.isBusy) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const LinearProgressIndicator(minHeight: 4),
              ),
            ],
            if (tutorChoices.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tutorChoices.indexed.map((entry) {
                  final index = entry.$1 + 1;
                  final choice = entry.$2;
                  return OutlinedButton.icon(
                    onPressed: widget.isBusy ? null : () => _send(choice),
                    icon: CircleAvatar(
                      radius: 11,
                      child:
                          Text('$index', style: const TextStyle(fontSize: 12)),
                    ),
                    label: Text(choice),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.isBusy ? null : widget.onHint,
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('힌트'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.isBusy ? null : widget.onNextStep,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('다음 단계'),
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
                      labelText: '직접 입력하거나 선택지를 클릭하세요',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: isListening ? '듣기 중지' : '음성으로 말하기',
                  onPressed: widget.isBusy ? null : _toggleListening,
                  icon: Icon(isListening ? Icons.mic : Icons.mic_none),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: '보내기',
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

  String get _subtitle {
    return switch (widget.mode) {
      TutorMode.rule => 'solvable JSON 기반 선택형 진행',
      TutorMode.mock => 'Mock 빠른 점검',
      TutorMode.openai => '${widget.openAiModel} 실전 응답',
    };
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
    final text = sanitizeTutorText(value);
    if (text.isEmpty) {
      return;
    }
    widget.onSend(text);
    chatController.clear();
  }

  Future<void> _configureVoice() async {
    await tts.awaitSpeakCompletion(false);
    await tts.setLanguage('ko-KR');
    await tts.setSpeechRate(1);
    await tts.setVolume(1);
    await tts.setPitch(1.1);
  }

  Future<void> _toggleVoice() async {
    setState(() => voiceEnabled = !voiceEnabled);
    if (voiceEnabled) {
      await _speakLatestTutorMessage();
    } else {
      await tts.stop();
    }
  }

  Future<void> _speakLatestTutorMessage() async {
    final latestTutorMessage = widget.messages.where((message) {
      return message.isTutor && sanitizeTutorText(message.text).isNotEmpty;
    }).lastOrNull;
    if (latestTutorMessage == null) {
      _showVoiceMessage('아직 읽어 줄 튜터 말이 없어요.');
      return;
    }
    final text = sanitizeTutorText(latestTutorMessage.text)
        .replaceAll(RegExp(r'\s*\n+\s*'), ' ');
    lastSpokenMessageCount = widget.messages.length;
    try {
      await tts.stop();
      await tts.speak(text);
    } catch (_) {
      _showVoiceMessage('브라우저 음성 합성이 차단되었어요. 화면을 한 번 클릭한 뒤 다시 눌러 주세요.');
    }
  }

  void _showVoiceMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _toggleListening() async {
    if (isListening) {
      await speech.stop();
      setState(() => isListening = false);
      final text = chatController.text.trim();
      if (text.isNotEmpty) {
        _send(text);
      }
      return;
    }

    if (!speechAvailable) {
      final available = await speech.initialize(
        onStatus: (status) {
          if (!mounted) {
            return;
          }
          setState(() => isListening = status == 'listening');
        },
        onError: (_) {
          if (!mounted) {
            return;
          }
          setState(() => isListening = false);
        },
      );
      if (!mounted) {
        return;
      }
      setState(() => speechAvailable = available);
      if (!available) {
        return;
      }
    }

    await tts.stop();
    await speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: 'ko_KR',
        partialResults: true,
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 3),
      ),
      onResult: (result) {
        final text = sanitizeTutorText(result.recognizedWords);
        chatController.text = text;
        chatController.selection = TextSelection.collapsed(offset: text.length);
        if (result.finalResult && text.isNotEmpty) {
          speech.stop();
          setState(() => isListening = false);
          _send(text);
        }
      },
    );
    if (mounted) {
      setState(() => isListening = true);
    }
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child:
          Text(text, style: TextStyle(color: colorScheme.onTertiaryContainer)),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.isCorrect});

  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor =
        isCorrect ? const Color(0xFFDCFCE7) : colorScheme.tertiaryContainer;
    final textColor =
        isCorrect ? const Color(0xFF166534) : colorScheme.onTertiaryContainer;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCorrect ? const Color(0xFF86EFAC) : colorScheme.tertiary,
        ),
      ),
      child: Text(
        isCorrect ? '맞아요! 이제 풀이 이유를 정리해 봐요.' : '다시 확인해 봐요. 튜터가 한 단계씩 도와줄게요.',
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
    final colorScheme = Theme.of(context).colorScheme;
    final isTutor = message.isTutor;
    final bubbleColor =
        isTutor ? colorScheme.surface : colorScheme.primaryContainer;
    final textColor =
        isTutor ? colorScheme.onSurface : colorScheme.onPrimaryContainer;

    return Align(
      alignment: isTutor ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isTutor ? colorScheme.outlineVariant : colorScheme.primary,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTutor ? 'Tutor' : 'Student',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sanitizeTutorText(message.text),
              style: TextStyle(
                color: textColor,
                fontSize: 15.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _IterableLastOrNull<T> on Iterable<T> {
  T? get lastOrNull {
    T? value;
    for (final item in this) {
      value = item;
    }
    return value;
  }

  T? lastWhereOrNull(bool Function(T item) test) {
    T? value;
    for (final item in this) {
      if (test(item)) {
        value = item;
      }
    }
    return value;
  }
}
