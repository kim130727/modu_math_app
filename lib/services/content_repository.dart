import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/content_models.dart';

class ContentRepository {
  static const String manifestPath = 'assets/content/problems/manifest.json';

  Future<ProblemManifest> loadManifest() async {
    final source = await rootBundle.loadString(manifestPath);
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return ProblemManifest.fromJson(decoded);
  }

  Future<ProblemContent> loadProblem(ProblemSummary summary) async {
    final svg = await rootBundle.loadString(summary.assetPath('svg'));
    final semantic = await _loadJson(summary.assetPath('semantic.json'));
    final solvable = await _loadSolvable(summary);
    return ProblemContent(
      summary: summary,
      svg: svg,
      semantic: semantic,
      solvable: solvable,
    );
  }

  Future<Map<String, dynamic>> _loadSolvable(ProblemSummary summary) async {
    for (final fileName in const [
      'solvable.json',
      'solvable.v1.1.json',
      'solvable.v1.json',
    ]) {
      try {
        return await _loadJson(summary.assetPath(fileName));
      } on FlutterError {
        continue;
      }
    }
    return const {};
  }

  Future<Map<String, dynamic>> _loadJson(String assetPath) async {
    final source = await rootBundle.loadString(assetPath);
    return jsonDecode(source) as Map<String, dynamic>;
  }
}
