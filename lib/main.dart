import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'models/content_models.dart';
import 'screens/json_renderer_preview_screen.dart';
import 'services/content_repository.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  runApp(const ModuMathApp());
}

class ModuMathApp extends StatefulWidget {
  const ModuMathApp({super.key});

  @override
  State<ModuMathApp> createState() => _ModuMathAppState();
}

class _ModuMathAppState extends State<ModuMathApp> {
  final SessionProgress progress = SessionProgress();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Modu Math',
      debugShowCheckedModeBanner: false,
      theme: buildKidsTheme(),
      home: JsonRendererPreviewScreen(
        repository: ContentRepository(),
        progress: progress,
      ),
    );
  }
}
