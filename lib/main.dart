import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'models/content_models.dart';
import 'screens/problem_list_screen.dart';
import 'services/content_repository.dart';

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
      title: '모두수학',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8FB),
        useMaterial3: true,
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          titleMedium: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      home: ProblemListScreen(
        repository: ContentRepository(),
        progress: progress,
      ),
    );
  }
}
