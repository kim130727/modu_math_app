import 'package:flutter_test/flutter_test.dart';
import 'package:modu_math_app/models/content_models.dart';
import 'package:modu_math_app/models/learning_progress.dart';
import 'package:modu_math_app/services/local_progress_repository.dart';

void main() {
  group('LocalProgressRepository Tests', () {
    late LocalProgressRepository repository;

    setUp(() {
      repository = LocalProgressRepository();
    });

    test('should record attempt and calculate daily summary', () async {
      const summary = ProblemSummary(
        id: 'P001',
        grade: 3,
        subject: 'math',
        unit: '덧셈과 뺄셈',
        type: 'calc',
        title: '문제 1',
        path: '',
        raw: {},
      );

      await repository.recordAttempt(
        problem: summary,
        answer: '15',
        isCorrect: true,
      );

      final daily = await repository.getDailySummary(DateTime.now());
      expect(daily.totalAttempted, equals(1));
      expect(daily.totalCorrect, equals(1));
      expect(daily.accuracy, equals(1.0));

      final masteries = await repository.getSkillMasteries();
      expect(masteries.length, equals(1));
      expect(masteries.first.unit, equals('덧셈과 뺄셈'));
      expect(masteries.first.accuracy, equals(1.0));
    });

    test('should populate review queue for wrong attempts', () async {
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      final repoWithHistory = LocalProgressRepository(
        initialAttempts: [
          StudentAttempt(
            id: 'att_1',
            problemId: 'P002',
            unit: '나눗셈',
            answer: '4',
            isCorrect: false,
            timestamp: pastDate,
          ),
        ],
      );

      final queue = await repoWithHistory.getReviewQueue();
      expect(queue.length, equals(1));
      expect(queue.first.problemId, equals('P002'));
    });
  });
}
