import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/content_models.dart';
import '../models/tutor_models.dart';
import '../utils/tutor_text_sanitizer.dart';
import 'ai_tutor_service.dart';

class OpenAiTutorService extends AiTutorService {
  OpenAiTutorService({
    required this.apiKey,
    required this.model,
    http.Client? client,
  }) : client = client ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client client;

  static final Uri _responsesUri = Uri.https(
    'api.openai.com',
    '/v1/responses',
  );

  @override
  List<TutorMessage> startSession(ProblemContent content) {
    return [
      _tutor(
        '좋아요. 문제를 같이 읽고 한 단계씩 풀어볼게요.\n'
        '먼저 문제에서 구해야 하는 것이 무엇인지 말해볼까요?',
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
    return _ask(
      content: content,
      messages: messages,
      request:
          '학생이 힌트를 요청했습니다. 정답을 바로 말하지 말고, 지금 생각할 한 가지 단서만 알려 주세요. 힌트 번호: ${hintLevel + 1}',
      type: TutorReplyType.hint,
    );
  }

  @override
  Future<TutorMessage> nextQuestion({
    required ProblemContent content,
    required List<TutorMessage> messages,
    required int stepIndex,
  }) {
    return _ask(
      content: content,
      messages: messages,
      request:
          '다음 풀이 단계로 넘어가 주세요. 정답을 공개하지 말고, 학생이 직접 말할 수 있는 짧은 질문 하나를 해 주세요. 단계 번호: ${stepIndex + 1}',
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
    return _ask(
      content: content,
      messages: messages,
      request:
          '학생의 마지막 말을 초등학생 눈높이로 평가하고 자연스럽게 이어가 주세요. 맞는 방향이면 칭찬하고 다음 질문을 해 주세요. 틀렸다면 정답을 말하지 말고 어디를 다시 보면 좋을지 알려 주세요. 현재 단계: ${stepIndex + 1}',
      type: TutorReplyType.question,
    );
  }

  @override
  Future<TutorMessage> reviewAnswer({
    required ProblemContent content,
    required List<TutorMessage> messages,
    required String answer,
  }) {
    return _ask(
      content: content,
      messages: messages,
      request:
          '학생이 최종 답을 제출했습니다. 답이 맞는지 판단하고, 맞으면 왜 맞는지 짧게 설명해 주세요. 틀렸다면 정답을 바로 공개하지 말고 다시 확인할 부분을 안내해 주세요. 제출 답: $answer',
      type: TutorReplyType.question,
    );
  }

  Future<TutorMessage> _ask({
    required ProblemContent content,
    required List<TutorMessage> messages,
    required String request,
    required TutorReplyType type,
  }) async {
    if (apiKey.trim().isEmpty) {
      return _tutor(
        'OpenAI API 키가 아직 설정되지 않았어요. .env의 OPENAI_API_KEY를 확인해 주세요.',
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
          {
            'role': 'user',
            'content': request,
          },
        ],
        'text': {'verbosity': 'low'},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _tutor(
        'AI 튜터 연결 중 문제가 생겼어요. 잠시 뒤 다시 시도해 주세요. (${response.statusCode})',
        TutorReplyType.retry,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final text = sanitizeTutorText(_extractOutputText(decoded));
    return _tutor(
      text.isEmpty ? '좋아요. 여기서 다음으로 무엇을 생각하면 좋을까요?' : text,
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
너는 초등학생에게 수학을 가르치는 따뜻한 한국어 AI 튜터다.

튜터링 원칙:
- 학생은 초등학생이다. 쉬운 말, 짧은 문장, 친절한 격려를 사용한다.
- 학생이 스스로 생각하도록 질문한다.
- 정답은 바로 공개하지 않는다. 학생이 최종 답을 냈거나 충분히 시도한 뒤에만 맞고 틀림과 이유를 알려 준다.
- 한 번에 1~2문장으로 답한다.
- 음성으로 읽기 좋게 짧은 호흡으로 말한다.
- 설명은 길게 이어가지 말고, 짧은 칭찬 1개와 질문 1개를 우선한다.
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

extension _TakeLast<T> on List<T> {
  Iterable<T> takeLast(int count) {
    if (length <= count) {
      return this;
    }
    return skip(length - count);
  }
}
