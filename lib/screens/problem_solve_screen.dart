import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/content_models.dart';
import '../models/tutor_models.dart';
import '../services/ai_tutor_service.dart';
import '../services/backend_tutor_service.dart';
import '../services/content_repository.dart';
import '../services/learning_progress_repository.dart';
import '../services/mock_ai_tutor_service.dart';
import '../services/openai_tutor_service.dart';
import '../services/rule_tutor_service.dart';
import '../utils/answer_normalizer.dart';
import '../widgets/problem_svg_viewer.dart';
import '../widgets/tutor_chat_panel.dart';

class ProblemSolveScreen extends StatefulWidget {
  const ProblemSolveScreen({
    super.key,
    required this.repository,
    this.progress,
    this.progressRepository,
    required this.problem,
    this.unitProblems = const [],
    this.problemIndex = 0,
  });

  final ContentRepository repository;
  final SessionProgress? progress;
  final LearningProgressRepository? progressRepository;
  final ProblemSummary problem;
  final List<ProblemSummary> unitProblems;
  final int problemIndex;

  @override
  State<ProblemSolveScreen> createState() => _ProblemSolveScreenState();
}

class _ProblemSolveScreenState extends State<ProblemSolveScreen> {
  late final Future<ProblemContent> contentFuture;
  late AiTutorService tutorService;
  final List<TutorMessage> tutorMessages = [];
  bool tutorBusy = false;
  String? tutorProblemId;
  String? submittedAnswer;
  bool? isCorrect;
  int hintLevel = 0;
  int tutorStepIndex = 0;
  TutorMode tutorMode = TutorMode.rule;

  @override
  void initState() {
    super.initState();
    tutorService = _createTutorService();
    contentFuture = widget.repository.loadProblem(widget.problem);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.problem.title),
        toolbarHeight: 72,
      ),
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
                mode: tutorMode,
                openAiConfigured: _openAiConfigured,
                openAiModel: _openAiModel,
                messages: tutorMessages,
                isBusy: tutorBusy,
                submittedAnswer: submittedAnswer,
                isCorrect: isCorrect,
                onModeChanged: (mode) => _changeTutorMode(content, mode),
                onSubmit: (answer) => _submit(content, answer),
                onSend: (message) => _sendTutorMessage(content, message),
                onHint: () => _requestHint(content),
                onNextStep: () => _requestNextStep(content),
                onRestart: () => _restartTutor(content),
                onReset: _resetTutor,
                hasNextProblem: _hasNextProblem,
                onNextProblem: _openNextProblem,
              );

              if (wide) {
                return SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1480),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 5,
                              child: svgViewer,
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 4,
                              child: ListView(
                                children: [tutorPanel],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              return SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    SizedBox(height: 340, child: svgViewer),
                    const SizedBox(height: 16),
                    tutorPanel,
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _submit(ProblemContent content, String answer) async {
    final correct = isSameAnswer(answer, content.correctAnswer);
    if (widget.progressRepository != null) {
      await widget.progressRepository!.recordAttempt(
        problem: content.summary,
        answer: answer,
        isCorrect: correct,
        hintLevelUsed: hintLevel,
      );
    } else {
      widget.progress?.record(content.summary, answer, correct);
    }
    setState(() {
      submittedAnswer = answer;
      isCorrect = correct;
      if (tutorMessages.isEmpty) {
        tutorMessages.addAll(tutorService.startSession(content));
      }
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
    tutorMessages.clear();
    hintLevel = 0;
    tutorStepIndex = 0;
  }

  void _changeTutorMode(ProblemContent content, TutorMode mode) {
    setState(() {
      tutorMode = mode;
      tutorService = _createTutorService(mode);
      tutorProblemId = null;
      submittedAnswer = null;
      isCorrect = null;
      tutorMessages.clear();
      tutorMessages.addAll(tutorService.startSession(content));
      tutorProblemId = content.summary.id;
      hintLevel = 0;
      tutorStepIndex = 0;
    });
  }

  void _restartTutor(ProblemContent content) {
    setState(() {
      submittedAnswer = null;
      isCorrect = null;
      tutorMessages.clear();
      tutorMessages.addAll(tutorService.startSession(content));
      tutorProblemId = content.summary.id;
      hintLevel = 0;
      tutorStepIndex = 0;
    });
  }

  void _resetTutor() {
    setState(() {
      tutorMessages.clear();
      tutorProblemId = null;
      submittedAnswer = null;
      isCorrect = null;
      hintLevel = 0;
      tutorStepIndex = 0;
    });
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
            text: 'AI 튜터 응답을 가져오지 못했어요. 잠시 뒤 다시 시도해 주세요.',
            replyType: TutorReplyType.retry,
            createdAt: DateTime.now(),
          ),
        );
        tutorBusy = false;
      });
    }
  }

  AiTutorService _createTutorService([TutorMode? overrideMode]) {
    final mode = overrideMode ?? _modeFromEnv;
    tutorMode = mode;
    if (mode == TutorMode.backend) {
      return BackendTutorService(
        baseUrl: dotenv.env['BACKEND_API_BASE_URL'] ?? '',
        sessionToken: dotenv.env['BACKEND_SESSION_TOKEN'],
      );
    }
    if (mode == TutorMode.openai) {
      return OpenAiTutorService(
        apiKey: dotenv.env['OPENAI_API_KEY'] ?? '',
        model: _openAiModel,
      );
    }
    if (mode == TutorMode.mock) {
      return const MockAiTutorService();
    }
    return const RuleTutorService();
  }

  TutorMode get _modeFromEnv {
    final mode = dotenv.env['AI_TUTOR_MODE']?.toLowerCase().trim() ?? 'rule';
    return switch (mode) {
      'openai' => TutorMode.openai,
      'backend' => TutorMode.backend,
      'mock' => TutorMode.mock,
      _ => TutorMode.rule,
    };
  }

  String get _openAiModel {
    final model = dotenv.env['OPENAI_MODEL']?.trim();
    return model == null || model.isEmpty ? 'gpt-5.4-nano' : model;
  }

  bool get _openAiConfigured {
    final key = dotenv.env['OPENAI_API_KEY']?.trim() ?? '';
    return key.isNotEmpty && key != 'sk-your-api-key';
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
          progressRepository: widget.progressRepository,
          problem: widget.unitProblems[nextIndex],
          unitProblems: widget.unitProblems,
          problemIndex: nextIndex,
        ),
      ),
    );
  }
}
