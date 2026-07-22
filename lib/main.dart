import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/student_home_screen.dart';
import 'services/content_repository.dart';
import 'services/local_progress_repository.dart';
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
  final ContentRepository contentRepository = ContentRepository();
  final LocalProgressRepository progressRepository = LocalProgressRepository();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '모두수학 - 초등 맞춤학습',
      debugShowCheckedModeBanner: false,
      theme: buildKidsTheme(),
      home: StudentHomeScreen(
        repository: contentRepository,
        progressRepository: progressRepository,
      ),
    );
  }
}
