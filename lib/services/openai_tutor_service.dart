import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/content_models.dart';
import '../models/tutor_models.dart';
import '../utils/answer_normalizer.dart';
import '../utils/tutor_text_sanitizer.dart';
import 'ai_tutor_service.dart';

class OpenAiTutorService extends AiTutorService {
  OpenAiTutorService({
    required this.apiKey,
    this.model = 'gpt-5.4-nano',
    http.Client? client,
  }) : client = client ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client client;

  static final Uri _responsesUri = Uri.https('api.openai.com', '/v1/responses');

  @override
  TutorMode get mode => TutorMode.openai;

  @override
  String get label => 'OpenAI';

  bool get isConfigured {
    final key = apiKey.trim();
    return key.isNotEmpty && key != 'sk-your-api-key';
  }

  @override
  List<TutorMessage> startSession(ProblemContent content) {
    return [
      _tutor(
        'OpenAI 실전 응답 모드예요.\n'
        '문제를 보고 지금 생각한 답이나 막힌 부분을 말해 주세요.',
        TutorReplyType.greeting,
      ),
    ];
  }

  @override
  Future<TutorMessage> hint({
    required ProblemContent content,
    required List<TutorMessage> messages,
    required int hintLevel,
  }) {
    final strategy = _hintStrategy(content, hintLevel);
    return _ask(
      content: content,
      messages: messages,
      request: '''
학생이 ${hintLevel + 1}번째 힌트를 요청했다.
이번 개입 수준: ${strategy.level}
이번에 사용할 근거: ${strategy.evidence}
지도 행동: ${strategy.action}
앞선 힌트를 반복하지 말고, 학생이 바로 답할 수 있는 확인 질문 하나로 끝내라.
''',
      type: TutorReplyType.hint,
    );
  }

  @override
  Future<TutorMessage> nextQuestion({
    required ProblemContent content,
    required List<TutorMessage> messages,
    required int stepIndex,
  }) {
    final step = _stepAt(content, stepIndex);
    return _ask(
      content: content,
      messages: messages,
      request: '''
풀이의 ${stepIndex + 1}번째 단계를 지도한다.
현재 단계 근거: ${step ?? '주어진 조건과 구할 것을 연결하는 단계'}
이 단계를 대신 풀지 말고, 학생이 필요한 연산이나 판단을 직접 말하도록 질문하라.
이미 대화에서 확인된 내용은 다시 묻지 마라.
''',
      type: TutorReplyType.question,
    );
  }

  @override
  Future<TutorMessage> respondToStudent({
    required ProblemContent content,
    required List<TutorMessage> messages,
    required String message,
    required int stepIndex,
  }) {
    final exactAnswer = isSameAnswer(message, content.correctAnswer);
    return _ask(
      content: content,
      messages: messages,
      request: '''
학생 발화: "$message"
현재 풀이 단계: ${stepIndex + 1}
최종 정답과의 정확 일치: $exactAnswer

학생 발화를 정답, 부분 이해, 개념 오류, 계산 오류, 질문/무관 응답 중 하나로 내부 진단하라.
정답이라고 단정하는 것은 정확 일치가 true일 때만 허용한다.
부분 이해면 맞은 부분을 구체적으로 짚고 다음 연결 질문을 한다.
개념 오류면 문제의 조건 하나를 다시 보게 하고, 계산 오류면 계산식의 어느 부분을 검산할지 묻는다.
학생이 질문했다면 그 질문에 먼저 답한 뒤 풀이로 돌아온다.
진단 이름은 출력하지 말고 2~4문장과 질문 하나로 답하라.
''',
      type: TutorReplyType.question,
    );
  }

  @override
  Future<TutorMessage> reviewAnswer({
    required ProblemContent content,
    required List<TutorMessage> messages,
    required String answer,
  }) {
    final correct = isSameAnswer(answer, content.correctAnswer);
    return _ask(
      content: content,
      messages: messages,
      request: '''
학생이 최종 답 "$answer"을 제출했다.
앱의 확정 판정: ${correct ? '정답' : '오답'}
기준 정답: "${content.correctAnswer}"

앱의 확정 판정을 절대 뒤집지 마라.
정답이면 문제의 핵심 근거로 왜 맞는지 설명하고 학생의 생각을 한 번 되짚게 하라.
오답이면 "맞았다"는 표현을 쓰지 말고, 제출 답과 기준 정답이 달라지는 핵심 지점 하나만 찾아 검산 질문을 하라. 기준 정답 자체는 바로 공개하지 마라.
''',
      type: correct ? TutorReplyType.correct : TutorReplyType.retry,
    );
  }

  Future<TutorMessage> _ask({
    required ProblemContent content,
    required List<TutorMessage> messages,
    required String request,
    required TutorReplyType type,
  }) async {
    if (!isConfigured) {
      return _tutor(
        'OPENAI_API_KEY가 아직 설정되지 않았어요.\n'
        '.env에서 키를 설정하면 $model 실전 응답을 사용할 수 있어요.',
        TutorReplyType.retry,
      );
    }

    final response = await client.post(
      _responsesUri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'instructions': _instructions(content),
        'input': [
          ..._messageInputs(messages),
          {'role': 'user', 'content': request},
        ],
        'text': {'verbosity': 'medium'},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _tutor(
        'AI 튜터 연결 중 문제가 생겼어요.\n'
        '잠시 뒤 다시 시도해 주세요. (${response.statusCode})',
        TutorReplyType.retry,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final text = sanitizeTutorText(_extractOutputText(decoded));
    return _tutor(
      text.isEmpty ? '좋아요. 여기서 다음으로 무엇을 볼까요?' : text,
      type,
    );
  }

  String _instructions(ProblemContent content) {
    final problemContext = {
      'title': content.summary.title,
      'grade': content.summary.grade,
      'unit': content.summary.unit,
      'type': content.summary.type,
      'question': content.prompt,
      'choices': content.choices,
      'correctAnswer': content.correctAnswer,
      'semantic': content.semantic,
      'solvable': content.solvable,
    };

    return '''
너는 초등학생의 풀이 과정을 진단하며 지도하는 한국어 수학 튜터다.

판단 우선순위:
- 문제 자료의 correctAnswer를 정오 판단의 유일한 기준으로 삼는다.
- 요청에 "앱의 확정 판정"이 있으면 그 판정을 절대 뒤집지 않는다.
- 답이 비슷해 보여도 계산이나 표현이 다르면 함부로 맞다고 하지 않는다.
- semantic과 solvable이 충돌하면 correctAnswer와 solvable.answer를 우선한다.

매 응답 전에 내부적으로 수행할 일:
1. 학생이 이해한 것과 아직 확인되지 않은 것을 구분한다.
2. 발화를 정답, 부분 이해, 개념 오류, 계산 오류, 질문/무관 응답 중 하나로 진단한다.
3. 가장 작은 다음 개입 하나만 고른다.
4. 문제 자료와 계산상 모순되지 않는지 검산한다.

개입 휴리스틱:
- 처음에는 구할 것과 주어진 조건을 학생의 말로 확인한다.
- 부분 이해에는 구체적으로 맞은 지점을 짚고 한 단계만 확장한다.
- 개념 오류에는 정의나 조건을 그림 또는 문제 문장과 연결하는 질문을 한다.
- 계산 오류에는 자리값, 연산 기호, 중간값 중 하나를 검산하게 한다.
- 막힘이 반복되면 조건 확인 → 개념 단서 → 연산 선택 → 부분 풀이 순으로 도움을 강화한다.
- 같은 질문이나 힌트를 표현만 바꿔 반복하지 않는다.
- 학생의 질문에는 먼저 직접 답하고 풀이 흐름으로 돌아온다.

표현 원칙:
- 학생은 초등학생이다. 쉬운 말, 짧은 문장, 친절한 격려를 사용한다.
- 학생이 스스로 생각하도록 질문한다.
- 근거 없는 칭찬이나 "맞았어요"를 쓰지 않는다.
- 보통 2~4문장으로 답하고, 핵심 설명 하나와 질문 하나만 둔다.
- 음성으로 읽기 좋게 짧은 호흡으로 말한다.
- 설명을 길게 이어가지 않는다.
- 어려운 용어를 쓰면 바로 쉬운 말로 풀어 준다.
- JSON, semantic, solvable, 내부 데이터 같은 표현은 학생에게 말하지 않는다.
- 한국어로만 답한다.
- 마크다운 굵게 표시를 쓰지 않는다. 별표 두 개(**)를 절대 출력하지 않는다.
- 번호 목록이 필요하면 "1.", "2."처럼 간단히 쓴다.
- 학생이 문제와 상관없는 말을 해도 짧게 받아 준 뒤 다시 문제로 부드럽게 돌아온다.

문제 자료:
${jsonEncode(problemContext)}
''';
  }

  List<Map<String, String>> _messageInputs(List<TutorMessage> messages) {
    return messages.takeLast(12).map((message) {
      return {
        'role': message.isTutor ? 'assistant' : 'user',
        'content': sanitizeTutorText(message.text),
      };
    }).toList();
  }

  _HintStrategy _hintStrategy(ProblemContent content, int hintLevel) {
    final step = _stepAt(content, hintLevel);
    switch (hintLevel) {
      case 0:
        return _HintStrategy(
          level: '조건 확인',
          evidence: content.prompt,
          action: '구할 것과 주어진 수 또는 도형 조건 하나를 다시 말하게 한다.',
        );
      case 1:
        return _HintStrategy(
          level: '개념 단서',
          evidence: step ?? content.summary.type,
          action: '필요한 개념이나 관계를 정답 없이 하나 떠올리게 한다.',
        );
      case 2:
        return _HintStrategy(
          level: '연산 선택',
          evidence: step ?? _solvablePlan(content),
          action: '어떤 연산이나 비교를 해야 하는지 선택하게 한다.',
        );
      default:
        return _HintStrategy(
          level: '부분 풀이',
          evidence: step ?? _solvablePlan(content),
          action: '첫 계산 또는 판단까지만 함께 수행하고 나머지는 학생에게 맡긴다.',
        );
    }
  }

  String? _stepAt(ProblemContent content, int index) {
    if (content.steps.isEmpty) {
      return null;
    }
    final step = content.steps[index.clamp(0, content.steps.length - 1)];
    final value = step.value.isEmpty ? '' : ' → ${step.value}';
    return '${step.explanation}$value';
  }

  String _solvablePlan(ProblemContent content) {
    final rawPlan = content.solvable['plan'];
    if (rawPlan is List) {
      final plan = rawPlan.map((item) => item.toString()).join(' → ');
      if (plan.isNotEmpty) {
        return plan;
      }
    }
    return '문제의 조건과 구할 것을 연결한다.';
  }

  String _extractOutputText(Object? decoded) {
    if (decoded is! Map<String, dynamic>) {
      return '';
    }

    final outputText = decoded['output_text'];
    if (outputText is String) {
      return outputText;
    }

    final output = decoded['output'];
    if (output is! List) {
      return '';
    }

    final chunks = <String>[];
    for (final item in output.whereType<Map<String, dynamic>>()) {
      final content = item['content'];
      if (content is! List) {
        continue;
      }
      for (final part in content.whereType<Map<String, dynamic>>()) {
        final text = part['text'];
        if (text is String) {
          chunks.add(text);
        }
      }
    }
    return chunks.join('\n');
  }

  TutorMessage _tutor(String text, TutorReplyType type) {
    return TutorMessage(
      role: TutorMessageRole.tutor,
      text: sanitizeTutorText(text),
      replyType: type,
      createdAt: DateTime.now(),
    );
  }
}

class _HintStrategy {
  const _HintStrategy({
    required this.level,
    required this.evidence,
    required this.action,
  });

  final String level;
  final String evidence;
  final String action;
}

extension _TakeLast<T> on List<T> {
  Iterable<T> takeLast(int count) {
    if (length <= count) {
      return this;
    }
    return skip(length - count);
  }
}
