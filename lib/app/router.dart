import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../screens/json_renderer_preview_screen.dart';
import '../screens/learning_report_screen.dart';
import '../screens/problem_list_screen.dart';
import '../services/content_repository.dart';
import '../services/learning_progress_repository.dart';

abstract final class ModuMathRoutes {
  static const home = '/';
  static const curriculum = '/curriculum';
  static const progress = '/progress';
  static const developerStudio = '/dev/studio';
}

class ModuMathRouter {
  const ModuMathRouter({
    required this.contentRepository,
    required this.progressRepository,
  });

  final ContentRepository contentRepository;
  final LearningProgressRepository progressRepository;

  Route<void> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => switch (settings.name) {
        ModuMathRoutes.home => HomeScreen(
            repository: contentRepository,
            progressRepository: progressRepository,
          ),
        ModuMathRoutes.curriculum => ProblemListScreen(
            repository: contentRepository,
            progressRepository: progressRepository,
          ),
        ModuMathRoutes.progress => LearningReportScreen(
            progressRepository: progressRepository,
          ),
        ModuMathRoutes.developerStudio => JsonRendererPreviewScreen(
            repository: contentRepository,
            progressRepository: progressRepository,
          ),
        _ => HomeScreen(
            repository: contentRepository,
            progressRepository: progressRepository,
          ),
      },
    );
  }
}
