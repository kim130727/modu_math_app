import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modu_math_app/services/app_environment.dart';

void main() {
  tearDown(dotenv.clean);

  test('uses safe defaults before dotenv is initialized', () {
    dotenv.clean();

    expect(AppEnvironment.aiTutorMode, equals('rule'));
    expect(AppEnvironment.backendBaseUrl, isEmpty);
    expect(AppEnvironment.backendSessionToken, isNull);
    expect(AppEnvironment.openAiModel, equals('gpt-5.4-nano'));
    expect(AppEnvironment.openAiConfigured, isFalse);
  });

  test('reads configured environment values after dotenv is initialized', () {
    dotenv.loadFromString(
      envString: [
        'AI_TUTOR_MODE=backend',
        'BACKEND_API_BASE_URL=https://api.example.test',
        'BACKEND_SESSION_TOKEN=session-token',
        'OPENAI_API_KEY=sk-test',
        'OPENAI_MODEL=gpt-test',
      ].join('\n'),
    );

    expect(AppEnvironment.aiTutorMode, equals('backend'));
    expect(AppEnvironment.backendBaseUrl, equals('https://api.example.test'));
    expect(AppEnvironment.backendSessionToken, equals('session-token'));
    expect(AppEnvironment.openAiApiKey, equals('sk-test'));
    expect(AppEnvironment.openAiModel, equals('gpt-test'));
    expect(AppEnvironment.openAiConfigured, isTrue);
  });
}
