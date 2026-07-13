import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/content_models.dart';
import '../models/tutor_models.dart';
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
    return _ask(
      content: content,
      messages: messages,
      request:
          '[힌트] 정답을 바로 말하지 말고, 지금 볼 부분 하나와 짧은 질문 하나만 주세요. 힌트 번호: ${hintLevel + 1}',
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
          '다음 작은 단계로 이어 가 주세요. 정답은 공개하지 말고 학생이 직접 말할 수 있는 질문 하나를 주세요. 현재 단계: ${stepIndex + 1}',
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
          '학생의 마지막 말을 초등학생 눈높이로 평가하고 자연스럽게 이어 가 주세요. 맞는 방향이면 칭찬하고 다음 질문을 주세요. 틀리면 정답을 말하지 말고 다시 볼 곳을 알려 주세요. 현재 단계: ${stepIndex + 1}',
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
          '학생이 최종 답을 제출했습니다. 답이 맞는지 판단하고, 맞으면 왜 맞는지 짧게 설명해 주세요. 틀리면 정답을 바로 공개하지 말고 다시 확인할 부분을 안내해 주세요. 제출 답: $answer',
      type: TutorReplyType.question,
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
        'text': {'verbosity': 'low'},
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
너는 초등학생에게 수학을 가르치는 한국어 AI 튜터다.
authoring JSON은 내부 교사용 자료로만 사용한다.
정답, 정확한 중간 계산값, solvable 단계는 학생이 충분히 시도하기 전에는 바로 공개하지 않는다.
아주 쉬운 한국어와 짧은 문장을 쓴다.
한 번에 1~3줄만 답한다.
마크다운, 표, 제목, 굵게 표시를 쓰지 않는다.
힌트/모르겠어요/이유 같은 내부 모드 이름을 출력하지 않는다.
학생이 맞는 방향이면 짧게 칭찬하고 다음 작은 질문 하나를 한다.
학생이 틀리면 정답을 말하지 말고 다시 볼 곳 하나만 알려 준다.
선택형 문제는 보기를 하나씩 확인하고 틀린 보기를 줄이도록 돕는다.

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
