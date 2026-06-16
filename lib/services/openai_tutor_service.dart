import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/content_models.dart';
import '../models/tutor_models.dart';
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
        '좋아요. 문제를 함께 읽고 한 단계씩 풀어볼게요.\n'
        '정답을 바로 말하기보다, 먼저 어떤 값을 찾아야 하는지부터 생각해봅시다.',
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
          '학생이 힌트를 요청했습니다. 정답은 직접 말하지 말고, 현재 문제를 푸는 데 필요한 다음 생각만 짧게 안내하세요. 힌트 번호: ${hintLevel + 1}',
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
          '학생과 다음 풀이 단계로 이동하세요. 정답을 공개하지 말고, 학생이 답할 수 있는 짧은 질문을 하나 던지세요. 단계 번호: ${stepIndex + 1}',
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
          '학생의 마지막 말을 평가하고 자연스럽게 이어가세요. 맞는 방향이면 칭찬하고 다음 질문을 하세요. 틀리면 정답을 밝히지 말고 오개념을 부드럽게 바로잡으세요. 현재 단계: ${stepIndex + 1}',
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
          '학생이 최종 답을 제출했습니다. 답이 맞는지 판단하고, 맞으면 왜 맞는지 짧게 설명하세요. 틀리면 정답을 바로 공개하지 말고 확인해야 할 부분을 안내하세요. 제출 답: $answer',
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
        'AI 튜터 연결 중 문제가 생겼어요. 잠시 후 다시 시도해 주세요. (${response.statusCode})',
        TutorReplyType.retry,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final text = _extractOutputText(decoded).trim();
    return _tutor(
      text.isEmpty ? '좋아요. 여기서 다음 생각을 한 번 말해볼까요?' : text,
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
너는 초등학생을 돕는 한국어 수학 AI 튜터다.

목표:
- 학생과 자연스럽게 대화하며 문제를 한 단계씩 풀어간다.
- 학생이 스스로 생각하도록 질문하고, 필요한 만큼만 힌트를 준다.
- 학생에게 JSON, semantic, solvable, 데이터 파일, 내부 자료라는 말을 절대 하지 않는다.
- 내부 문제 자료는 교사용 해설지처럼 참고만 하고, 학생에게는 문제 설명과 풀이 안내로 바꿔 말한다.
- 정답을 바로 공개하지 않는다. 학생이 최종 답을 제출했거나 충분히 시도했을 때만 정답 여부와 이유를 설명한다.
- 답변은 1~4문장으로 짧고 친절하게 한다.
- 학생이 문제와 상관없는 질문을 해도 짧게 응답한 뒤 다시 문제 풀이로 부드럽게 돌아온다.
- 한국어로만 답한다.

내부 문제 자료:
${jsonEncode(problemContext)}
''';
  }

  List<Map<String, String>> _messageInputs(List<TutorMessage> messages) {
    return messages.takeLast(12).map((message) {
      return {
        'role': message.isTutor ? 'assistant' : 'user',
        'content': message.text,
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
      text: text,
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
