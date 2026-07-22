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

  group('LearningProgressSummary', () {
    test('uses the latest attempt for each problem', () {
      final now = DateTime(2026, 7, 22, 9);
      final summary = LearningProgressSummary.fromAttempts(
        problems: const [
          ProblemSummary(
            id: 'P001',
            grade: 3,
            subject: 'math',
            unit: 'multiplication',
            type: 'calc',
            title: 'Problem 1',
            path: '',
            raw: {},
          ),
          ProblemSummary(
            id: 'P002',
            grade: 3,
            subject: 'math',
            unit: 'multiplication',
            type: 'calc',
            title: 'Problem 2',
            path: '',
            raw: {},
          ),
        ],
        attempts: [
          StudentAttempt(
            id: 'old',
            problemId: 'P001',
            unit: 'multiplication',
            answer: '4',
            isCorrect: false,
            timestamp: now,
          ),
          StudentAttempt(
            id: 'new',
            problemId: 'P001',
            unit: 'multiplication',
            answer: '6',
            isCorrect: true,
            timestamp: now.add(const Duration(minutes: 1)),
          ),
          StudentAttempt(
            id: 'other',
            problemId: 'P002',
            unit: 'multiplication',
            answer: '9',
            isCorrect: false,
            timestamp: now,
          ),
        ],
      );

      expect(summary.solvedCount, equals(2));
      expect(summary.correctCount, equals(1));
      expect(summary.accuracy, equals(0.5));
      expect(summary.resultFor('P001')?.answer, equals('6'));
      expect(summary.wrongResults.single.problem.id, equals('P002'));
    });

    test('ignores attempts for problems outside the manifest', () {
      final summary = LearningProgressSummary.fromAttempts(
        problems: const [
          ProblemSummary(
            id: 'P001',
            grade: 3,
            subject: 'math',
            unit: 'multiplication',
            type: 'calc',
            title: 'Problem 1',
            path: '',
            raw: {},
          ),
        ],
        attempts: [
          StudentAttempt(
            id: 'known',
            problemId: 'P001',
            unit: 'multiplication',
            answer: '12',
            isCorrect: true,
            timestamp: DateTime(2026, 7, 22),
          ),
          StudentAttempt(
            id: 'unknown',
            problemId: 'P999',
            unit: 'multiplication',
            answer: '99',
            isCorrect: false,
            timestamp: DateTime(2026, 7, 22),
          ),
        ],
      );

      expect(summary.solvedCount, equals(1));
      expect(summary.resultFor('P999'), isNull);
    });
  });
}
