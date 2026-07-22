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
    final bundledProblems = await _loadBundledProblems();
    if (bundledProblems.isEmpty) {
      return ProblemManifest.fromJson(decoded);
    }
    return ProblemManifest(
      version: decoded['version']?.toString() ?? '0.1.0',
      problems: bundledProblems,
      raw: {
        ...decoded,
        'problems': bundledProblems.map((problem) => problem.raw).toList(),
      },
    );
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
    final basePath = await _basePathForPrefix(filePrefix);
    final solvableV12 = await _loadOptionalJson('$basePath.solvable.v1.2.json');
    return ProblemJsonBundle(
      filePrefix: filePrefix,
      semantic: await _loadJson('$basePath.semantic.json'),
      layout: await _loadJson('$basePath.layout.json'),
      renderer: await _loadJson('$basePath.renderer.json'),
      solvable: solvableV12.isEmpty
          ? await _loadOptionalJson('$basePath.solvable.v1.1.json')
          : solvableV12,
    );
  }

  Future<List<String>> loadGrade3JsonProblemPrefixes() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final prefixes = manifest
        .listAssets()
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
      'solvable.v1.2.json',
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

  Future<String> _basePathForPrefix(String filePrefix) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final rendererPath = manifest.listAssets().firstWhere(
          (path) =>
              path.startsWith('$grade3Path/') &&
              path.endsWith('/$filePrefix.renderer.json'),
          orElse: () => '',
        );
    if (rendererPath.isEmpty) {
      return '$grade3Path/$filePrefix';
    }
    return rendererPath.substring(
      0,
      rendererPath.length - '.renderer.json'.length,
    );
  }

  Future<List<ProblemSummary>> _loadBundledProblems() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets().toSet();
    final semanticPaths = assets
        .where(
          (path) =>
              path.startsWith('$grade3Path/') &&
              path.endsWith('.semantic.json'),
        )
        .toList()
      ..sort();

    final problems = <ProblemSummary>[];
    for (final semanticPath in semanticPaths) {
      final filePrefix = semanticPath
          .split('/')
          .last
          .replaceFirst(RegExp(r'\.semantic\.json$'), '');
      final basePath = semanticPath.substring(
        0,
        semanticPath.length - '.semantic.json'.length,
      );
      if (!assets.contains('$basePath.svg')) {
        continue;
      }

      final semantic = await _loadOptionalJson(semanticPath);
      if (semantic.isEmpty) {
        continue;
      }

      problems.add(_summaryFromSemantic(
        semantic: semantic,
        path: semanticPath
            .split('/')
            .sublist(0, semanticPath.split('/').length - 1)
            .join('/'),
        filePrefix: filePrefix,
      ));
    }
    return problems;
  }

  ProblemSummary _summaryFromSemantic({
    required Map<String, dynamic> semantic,
    required String path,
    required String filePrefix,
  }) {
    final metadata = _mapAt(semantic, 'metadata');
    final grade = _readInt(metadata['grade']) ?? _gradeFromPrefix(filePrefix);
    final semester =
        _readInt(metadata['semester']) ?? _semesterFromPrefix(filePrefix);
    final unitNumber = _unitNumberFromPrefix(filePrefix);
    final topic = metadata['topic']?.toString().trim();
    final title = metadata['title']?.toString().trim();
    final question = metadata['question']?.toString().trim();
    final type = semantic['problem_type']?.toString() ?? 'unknown';
    final unitTopic = topic == null || topic.isEmpty ? '수학' : topic;
    final unit = '$semester학기 $unitNumber. $unitTopic';
    final id = semantic['problem_id']?.toString() ?? filePrefix;
    final raw = <String, dynamic>{
      'id': id,
      'grade': grade,
      'subject': metadata['subject']?.toString() ?? 'math',
      'unit': unit,
      'type': type,
      'title': title == null || title.isEmpty ? question ?? id : title,
      'path': path,
      'filePrefix': filePrefix,
      'semester': '$semester학기',
      'unitNumber': unitNumber,
      'unitTopic': unitTopic,
    };

    return ProblemSummary.fromJson(raw);
  }

  Future<Map<String, dynamic>> _loadJson(String assetPath) async {
    final source = await rootBundle.loadString(assetPath);
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

Map<String, dynamic> _mapAt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  return const {};
}

int? _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '');
}

int _gradeFromPrefix(String filePrefix) {
  final match = RegExp(r'^P(\d+)_').firstMatch(filePrefix);
  return int.tryParse(match?.group(1) ?? '') ?? 3;
}

int _semesterFromPrefix(String filePrefix) {
  final parts = filePrefix.split('_');
  return parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
}

int _unitNumberFromPrefix(String filePrefix) {
  final parts = filePrefix.split('_');
  return parts.length > 2 ? int.tryParse(parts[2]) ?? 1 : 1;
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
