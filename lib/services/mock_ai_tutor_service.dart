import '../models/content_models.dart';
import '../models/tutor_models.dart';
import 'ai_tutor_service.dart';
import '../utils/answer_normalizer.dart';

class MockAiTutorService extends AiTutorService {
  const MockAiTutorService();

  @override
  List<TutorMessage> startSession(ProblemContent content) {
    final context = _TutorProblemContext.from(content);
    return [
      _tutor(
        '좋아요. 이 문제를 함께 읽고 같이 풀어볼게요.\n'
        '${context.openingSummary}\n\n'
        '${context.firstPrompt}',
        TutorReplyType.greeting,
      ),
    ];
  }

  @override
  Future<TutorMessage> hint({
    required ProblemContent content,
    required List<TutorMessage> messages,
    required int hintLevel,
  }) async {
    final context = _TutorProblemContext.from(content);
    final hint = context.hintAt(hintLevel);
    return _tutor(
      '힌트 ${hintLevel + 1}\n$hint\n\n'
      '이 힌트로 한 번 직접 생각해보고, 풀이를 적어보세요.',
      TutorReplyType.hint,
    );
  }

  @override
  Future<TutorMessage> nextQuestion({
    required ProblemContent content,
    required List<TutorMessage> messages,
    required int stepIndex,
  }) async {
    final context = _TutorProblemContext.from(content);
    return _tutor(context.questionAt(stepIndex), TutorReplyType.question);
  }

  @override
  Future<TutorMessage> respondToStudent({
    required ProblemContent content,
    required List<TutorMessage> messages,
    required String message,
    required int stepIndex,
  }) async {
    final context = _TutorProblemContext.from(content);
    final answer = message.trim();

    if (isSameAnswer(answer, content.correctAnswer)) {
      return _tutor(
        '맞았어요. 정답과 일치합니다.\n'
        '마무리로 풀이 흐름은 이렇게 정리할 수 있어요: ${context.compactPlan}',
        TutorReplyType.correct,
      );
    }

    final matchedStep = context.matchStep(answer);
    if (matchedStep != null) {
      return _tutor(
        '좋아요. 방금 말한 내용은 풀이 단계의 "${matchedStep.explanation}"와 연결돼요.\n'
        '${context.questionAt(stepIndex + 1)}',
        TutorReplyType.question,
      );
    }

    final matchedGiven = context.matchGiven(answer);
    if (matchedGiven != null) {
      return _tutor(
        '맞아요, 그건 문제에서 주어진 조건이에요: $matchedGiven\n'
        '이 조건을 이용해서 다음에는 무엇을 계산하거나 비교해야 할까요?',
        TutorReplyType.question,
      );
    }

    return _tutor(
      '아직 풀이 흐름과는 조금 달라 보여요.\n'
      '${context.hintAt(stepIndex)}',
      TutorReplyType.retry,
    );
  }

  @override
  Future<TutorMessage> reviewAnswer({
    required ProblemContent content,
    required List<TutorMessage> messages,
    required String answer,
  }) async {
    final context = _TutorProblemContext.from(content);
    if (isSameAnswer(answer, content.correctAnswer)) {
      return _tutor(
        '맞았어요. 정답과 일치합니다.\n'
        '풀이 근거: ${context.compactPlan}',
        TutorReplyType.correct,
      );
    }

    return _tutor(
      '아직 정답과는 달라요. 바로 정답을 보기 전에 풀이 계획을 따라 다시 볼게요.\n'
      '${context.hintAt(0)}',
      TutorReplyType.retry,
    );
  }

  TutorMessage _tutor(String text, TutorReplyType type) {
    return TutorMessage(
      role: TutorMessageRole.tutor,
      text: text,
      replyType: type,
      createdAt: DateTime.now(),
    );
  }
}

class _TutorProblemContext {
  const _TutorProblemContext({
    required this.question,
    required this.method,
    required this.givens,
    required this.plan,
    required this.steps,
    required this.checks,
    required this.choices,
    required this.target,
  });

  final String question;
  final String method;
  final List<String> givens;
  final List<String> plan;
  final List<SolutionStep> steps;
  final List<String> checks;
  final List<String> choices;
  final String target;

  factory _TutorProblemContext.from(ProblemContent content) {
    return _TutorProblemContext(
      question: content.prompt,
      method: content.solvable['method']?.toString() ??
          content.semantic['problem_type']?.toString() ??
          content.summary.type,
      givens: _readGivens(content),
      plan: _stringList(content.solvable['plan']),
      steps: content.steps,
      checks: _readChecks(content.solvable['checks']),
      choices: content.choices,
      target: _readTarget(content),
    );
  }

  String get openingSummary {
    final parts = <String>[
      if (question.isNotEmpty) '문제: $question',
      if (target.isNotEmpty) '목표: $target',
      if (method.isNotEmpty) '풀이 방법: $method',
      if (givens.isNotEmpty) '주어진 것: ${givens.take(3).join(', ')}',
      if (choices.isNotEmpty) '선택지: ${choices.join(', ')}',
    ];
    return parts.join('\n');
  }

  String get firstPrompt {
    if (plan.isNotEmpty) {
      return '먼저 첫 번째 풀이 계획을 따라가 볼게요.\n${plan.first}\n'
          '여기서 가장 먼저 확인해야 할 값은 무엇일까요?';
    }
    if (givens.isNotEmpty) {
      return '먼저 주어진 조건 중 계산에 필요한 값을 하나 골라볼까요?';
    }
    return '먼저 문제에서 무엇을 구해야 하는지 말해볼까요?';
  }

  String get compactPlan {
    if (plan.isNotEmpty) {
      return plan.join(' → ');
    }
    if (steps.isNotEmpty) {
      return steps.map((step) => step.explanation).join(' → ');
    }
    return '주어진 조건을 확인하고 목표에 맞게 계산 또는 비교합니다.';
  }

  String hintAt(int index) {
    if (plan.isNotEmpty && index < plan.length) {
      return '계획: ${plan[index]}';
    }
    if (steps.isNotEmpty) {
      final step = steps[index.clamp(0, steps.length - 1)];
      final value = step.value.isEmpty ? '' : '\n이 단계에서 확인되는 값: ${step.value}';
      return '풀이 단계: ${step.explanation}$value';
    }
    if (givens.isNotEmpty) {
      return '주어진 것부터 다시 볼게요: ${givens.join(', ')}';
    }
    return '문제에서 구해야 하는 것과 이미 주어진 것을 나누어 적어보세요.';
  }

  String questionAt(int index) {
    if (steps.isEmpty || index >= steps.length) {
      if (checks.isNotEmpty) {
        return '이제 계산이 맞는지 확인해볼 차례예요.\n검산 근거: ${checks.first}\n'
            '이 결과가 선택지나 답과 어떻게 연결되나요?';
      }
      return '좋아요. 이제 지금까지의 풀이를 이용해 답을 골라볼까요?';
    }

    final step = steps[index];
    final value = step.value.isEmpty ? '' : '\n이 단계에서 나오는 값은 무엇인지도 같이 생각해보세요.';
    return '풀이 ${index + 1}단계로 가볼게요.\n'
        '${step.explanation}$value\n'
        '왜 이 단계가 필요한지 설명해볼까요?';
  }

  SolutionStep? matchStep(String message) {
    final normalized = _compact(message);
    for (final step in steps) {
      final candidates = [
        step.explanation,
        step.value,
        step.id,
      ].where((value) => value.isNotEmpty);
      for (final candidate in candidates) {
        final compact = _compact(candidate);
        if (compact.isNotEmpty &&
            (normalized.contains(compact) || compact.contains(normalized))) {
          return step;
        }
      }
    }
    return null;
  }

  String? matchGiven(String message) {
    final normalized = _compact(message);
    for (final given in givens) {
      final compact = _compact(given);
      if (compact.isNotEmpty &&
          (normalized.contains(compact) || compact.contains(normalized))) {
        return given;
      }
    }
    return null;
  }
}

List<String> _readGivens(ProblemContent content) {
  final givens = <String>[];
  final rawGivens = content.solvable['given'];
  if (rawGivens is List) {
    for (final item in rawGivens.whereType<Map<String, dynamic>>()) {
      final ref = item['ref']?.toString();
      final value = _stringify(item['value']);
      if (value.isNotEmpty) {
        givens.add(ref == null || ref.isEmpty ? value : '$ref = $value');
      }
    }
  }

  final domain = _mapAt(content.semantic, 'domain');
  final objects = domain['objects'];
  if (givens.isEmpty && objects is List) {
    for (final item in objects.whereType<Map<String, dynamic>>()) {
      final id = item['id']?.toString();
      final text = _stringify(item['text']);
      if (text.isNotEmpty) {
        givens.add(id == null || id.isEmpty ? text : '$id = $text');
      }
    }
  }
  return givens;
}

List<String> _readChecks(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map<String, dynamic>>()
      .map((item) {
        final expr = item['expr']?.toString() ?? '';
        final expected = _stringify(item['expected']);
        final actual = _stringify(item['actual']);
        if (expected.isEmpty && actual.isEmpty) {
          return expr;
        }
        return '$expr expected=$expected actual=$actual';
      })
      .where((item) => item.trim().isNotEmpty)
      .toList();
}

String _readTarget(ProblemContent content) {
  final solvableTarget = _mapAt(content.solvable, 'target');
  final answerTarget = _mapAt(content.answerMap, 'target');
  final description = answerTarget['description']?.toString();
  if (description != null && description.isNotEmpty) {
    return description;
  }
  final type = solvableTarget['type']?.toString();
  final ref = solvableTarget['ref']?.toString();
  if (type != null && type.isNotEmpty) {
    return ref == null || ref.isEmpty ? type : '$ref ($type)';
  }
  return content.summary.title;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map(_stringify).where((item) => item.isNotEmpty).toList();
}

Map<String, dynamic> _mapAt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  return const {};
}

String _stringify(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is List) {
    return value.map(_stringify).where((item) => item.isNotEmpty).join(', ');
  }
  if (value is Map) {
    return value.entries
        .map((entry) => '${entry.key}: ${_stringify(entry.value)}')
        .where((item) => item.trim().isNotEmpty)
        .join(', ');
  }
  return value.toString();
}

String _compact(String value) {
  return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
}
