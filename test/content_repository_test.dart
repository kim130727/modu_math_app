import 'package:flutter_test/flutter_test.dart';
import 'package:modu_math_app/services/content_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContentRepository', () {
    test('discovers bundled grade 3 problem assets', () async {
      final repository = ContentRepository();

      final manifest = await repository.loadManifest();

      expect(manifest.problems, isNotEmpty);
      expect(manifest.problems.first.id, isNotEmpty);
      expect(
        manifest.problems.first.path,
        startsWith(ContentRepository.grade3Path),
      );
    });

    test('loads a discovered problem through svg semantic and solvable files',
        () async {
      final repository = ContentRepository();
      final manifest = await repository.loadManifest();

      final content = await repository.loadProblem(manifest.problems.first);

      expect(content.svg, contains('<svg'));
      expect(content.semantic, isNotEmpty);
      expect(content.solvable, isNotEmpty);
      expect(content.correctAnswer, isNotEmpty);
    });
  });
}
