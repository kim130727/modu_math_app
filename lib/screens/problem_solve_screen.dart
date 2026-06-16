import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/content_models.dart';
import '../models/tutor_models.dart';
import '../services/ai_tutor_service.dart';
import '../services/content_repository.dart';
import '../services/mock_ai_tutor_service.dart';
import '../services/openai_tutor_service.dart';
import '../utils/answer_normalizer.dart';
import '../widgets/problem_svg_viewer.dart';
import '../widgets/tutor_chat_panel.dart';

class ProblemSolveScreen extends StatefulWidget {
  const ProblemSolveScreen({
    super.key,
    required this.repository,
    required this.progress,
    required this.problem,
    this.unitProblems = const [],
    this.problemIndex = 0,
  });

  final ContentRepository repository;
  final SessionProgress progress;
  final ProblemSummary problem;
  final List<ProblemSummary> unitProblems;
  final int problemIndex;

  @override
  State<ProblemSolveScreen> createState() => _ProblemSolveScreenState();
}

class _ProblemSolveScreenState extends State<ProblemSolveScreen> {
  late final Future<ProblemContent> contentFuture;
  late final AiTutorService tutorService;
  final List<TutorMessage> tutorMessages = [];
  bool tutorBusy = false;
  String? tutorProblemId;
  String? submittedAnswer;
  bool? isCorrect;
  int hintLevel = 0;
  int tutorStepIndex = 0;

  @override
  void initState() {
    super.initState();
    tutorService = _createTutorService();
    contentFuture = widget.repository.loadProblem(widget.problem);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.problem.title)),
      body: FutureBuilder<ProblemContent>(
        future: contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '문제를 불러오지 못했습니다.\n${snapshot.error}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }

          final content = snapshot.data!;
          _ensureTutorSession(content);
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final svgViewer = ProblemSvgViewer(svg: content.svg);
              final tutorPanel = TutorChatPanel(
                content: content,
                messages: tutorMessages,
                isBusy: tutorBusy,
                submittedAnswer: submittedAnswer,
                isCorrect: isCorrect,
                onSubmit: (answer) => _submit(content, answer),
                onSend: (message) => _sendTutorMessage(content, message),
                onHint: () => _requestHint(content),
                onNextStep: () => _requestNextStep(content),
                hasNextProblem: _hasNextProblem,
                onNextProblem: _openNextProblem,
              );

              if (wide) {
                return Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: svgViewer,
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 16, 16, 24),
                        child: ListView(
                          children: [tutorPanel],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SizedBox(height: 330, child: svgViewer),
                  const SizedBox(height: 14),
                  tutorPanel,
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _submit(ProblemContent content, String answer) async {
    final correct = isSameAnswer(answer, content.correctAnswer);
    widget.progress.record(content.summary, answer, correct);
    setState(() {
      submittedAnswer = answer;
      isCorrect = correct;
      tutorMessages.add(tutorService.student(answer));
    });
    await _addTutorReply(
      () => tutorService.reviewAnswer(
        content: content,
        messages: tutorMessages,
        answer: answer,
      ),
    );
  }

  void _ensureTutorSession(ProblemContent content) {
    if (tutorProblemId == content.summary.id) {
      return;
    }
    tutorProblemId = content.summary.id;
    tutorMessages
      ..clear()
      ..addAll(tutorService.startSession(content));
    hintLevel = 0;
    tutorStepIndex = 0;
  }

  Future<void> _sendTutorMessage(ProblemContent content, String message) async {
    setState(() {
      tutorMessages.add(tutorService.student(message));
    });
    await _addTutorReply(
      () => tutorService.respondToStudent(
        content: content,
        messages: tutorMessages,
        message: message,
        stepIndex: tutorStepIndex,
      ),
    );
  }

  Future<void> _requestHint(ProblemContent content) async {
    final currentHintLevel = hintLevel;
    setState(() => hintLevel += 1);
    await _addTutorReply(
      () => tutorService.hint(
        content: content,
        messages: tutorMessages,
        hintLevel: currentHintLevel,
      ),
    );
  }

  Future<void> _requestNextStep(ProblemContent content) async {
    final currentStepIndex = tutorStepIndex;
    setState(() => tutorStepIndex += 1);
    await _addTutorReply(
      () => tutorService.nextQuestion(
        content: content,
        messages: tutorMessages,
        stepIndex: currentStepIndex,
      ),
    );
  }

  Future<void> _addTutorReply(Future<TutorMessage> Function() request) async {
    if (tutorBusy) {
      return;
    }
    setState(() => tutorBusy = true);
    try {
      final reply = await request();
      if (!mounted) {
        return;
      }
      setState(() {
        tutorMessages.add(reply);
        tutorBusy = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        tutorMessages.add(
          TutorMessage(
            role: TutorMessageRole.tutor,
            text: 'AI 튜터 응답을 가져오지 못했어요. 잠시 후 다시 시도해 주세요.',
            replyType: TutorReplyType.retry,
            createdAt: DateTime.now(),
          ),
        );
        tutorBusy = false;
      });
    }
  }

  AiTutorService _createTutorService() {
    final mode = dotenv.env['AI_TUTOR_MODE']?.toLowerCase().trim() ?? 'mock';
    if (mode == 'openai') {
      return OpenAiTutorService(
        apiKey: dotenv.env['OPENAI_API_KEY'] ?? '',
        model: dotenv.env['OPENAI_MODEL'] ?? 'gpt-5.4-mini',
      );
    }
    return const MockAiTutorService();
  }

  bool get _hasNextProblem {
    return widget.unitProblems.isNotEmpty &&
        widget.problemIndex + 1 < widget.unitProblems.length;
  }

  void _openNextProblem() {
    if (!_hasNextProblem) {
      Navigator.of(context).pop();
      return;
    }
    final nextIndex = widget.problemIndex + 1;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => ProblemSolveScreen(
          repository: widget.repository,
          progress: widget.progress,
          problem: widget.unitProblems[nextIndex],
          unitProblems: widget.unitProblems,
          problemIndex: nextIndex,
        ),
      ),
    );
  }
}
