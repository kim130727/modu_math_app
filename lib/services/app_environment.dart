import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnvironment {
  const AppEnvironment._();

  static String get aiTutorMode {
    return _envValue('AI_TUTOR_MODE', fallback: 'rule').toLowerCase().trim();
  }

  static String get backendBaseUrl {
    return _envValue('BACKEND_API_BASE_URL').trim();
  }

  static String? get backendSessionToken {
    return _optionalEnvValue('BACKEND_SESSION_TOKEN');
  }

  static String get openAiApiKey {
    return _envValue('OPENAI_API_KEY').trim();
  }

  static String get openAiModel {
    return _optionalEnvValue('OPENAI_MODEL') ?? 'gpt-5.4-nano';
  }

  static bool get openAiConfigured {
    final key = openAiApiKey;
    return key.isNotEmpty && key != 'sk-your-api-key';
  }

  static String _envValue(String key, {String fallback = ''}) {
    if (!dotenv.isInitialized) {
      return fallback;
    }
    return dotenv.env[key] ?? fallback;
  }

  static String? _optionalEnvValue(String key) {
    final value = _envValue(key).trim();
    return value.isEmpty ? null : value;
  }
}
