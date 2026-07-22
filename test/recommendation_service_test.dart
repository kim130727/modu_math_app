import 'package:flutter_test/flutter_test.dart';
import 'package:modu_math_app/models/content_models.dart';
import 'package:modu_math_app/services/local_progress_repository.dart';
import 'package:modu_math_app/services/recommendation_service.dart';

void main() {
  group('RecommendationService Tests', () {
    test('should recommend daily target problems from pool', () async {
      final repository = LocalProgressRepository();
      const recommendationService = RecommendationService();

      final allProblems = List.generate(
        15,
        (index) => ProblemSummary(
          id: 'P00$index',
          grade: 3,
          subject: 'math',
          unit: '단원 ${(index % 3) + 1}',
          type: 'calc',
          title: '문제 $index',
          path: '',
          raw: const {},
        ),
      );

      final recs = await recommendationService.getDailyRecommendation(
        allProblems: allProblems,
        progressRepository: repository,
        targetCount: 10,
      );

      expect(recs.length, equals(10));
      expect(recs.first.tag, equals('오늘의 도전'));
    });
  });
}
