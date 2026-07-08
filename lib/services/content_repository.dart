import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/content_models.dart';

class ContentRepository {
  static const String manifestPath = 'assets/content/problems/manifest.json';
  static const String grade3Path = 'assets/content/problems/grade3';

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

  Future<ProblemJsonBundle> loadProblemJsonBundle(String filePrefix) async {
    final basePath = '$grade3Path/$filePrefix';
    return ProblemJsonBundle(
      filePrefix: filePrefix,
      semantic: await _loadJson('$basePath.semantic.json'),
      layout: await _loadJson('$basePath.layout.json'),
      renderer: await _loadJson('$basePath.renderer.json'),
      solvable: await _loadOptionalJson('$basePath.solvable.v1.1.json'),
    );
  }

  Future<List<String>> loadGrade3JsonProblemPrefixes() async {
    final manifest = await _loadAssetManifest();
    final prefixes = manifest.keys
        .where(
          (path) =>
              path.startsWith('$grade3Path/') &&
              path.endsWith('.renderer.json'),
        )
        .map((path) {
          final fileName = path.split('/').last;
          return fileName.replaceFirst('.renderer.json', '');
        })
        .toSet()
        .toList()
      ..sort();
    return prefixes;
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

  Future<Map<String, dynamic>> _loadAssetManifest() async {
    final source = await rootBundle.loadString('AssetManifest.json');
    return jsonDecode(source) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _loadOptionalJson(String assetPath) async {
    try {
      return await _loadJson(assetPath);
    } on FlutterError {
      return const {};
    }
  }
}

class ProblemJsonBundle {
  const ProblemJsonBundle({
    required this.filePrefix,
    required this.semantic,
    required this.layout,
    required this.renderer,
    required this.solvable,
  });

  final String filePrefix;
  final Map<String, dynamic> semantic;
  final Map<String, dynamic> layout;
  final Map<String, dynamic> renderer;
  final Map<String, dynamic> solvable;
}
