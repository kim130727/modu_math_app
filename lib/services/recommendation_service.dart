import '../models/content_models.dart';
import '../models/learning_progress.dart';
import 'learning_progress_repository.dart';

class RecommendedProblem {
  const RecommendedProblem({
    required this.problem,
    required this.reason,
    required this.tag,
  });

  final ProblemSummary problem;
  final String reason;
  final String tag;
}

class RecommendationService {
  const RecommendationService();

  Future<List<RecommendedProblem>> getDailyRecommendation({
    required List<ProblemSummary> allProblems,
    required LearningProgressRepository progressRepository,
    int targetCount = 10,
  }) async {
    final attempts = await progressRepository.getAttempts();
    final reviewQueue = await progressRepository.getReviewQueue();

    final latestByProblem = <String, StudentAttempt>{};
    for (final a in attempts) {
      final existing = latestByProblem[a.problemId];
      if (existing == null || a.timestamp.isAfter(existing.timestamp)) {
        latestByProblem[a.problemId] = a;
      }
    }

    final recommendations = <RecommendedProblem>[];
    final addedProblemIds = <String>{};

    // 1. Spaced repetition review problems (틀린 사고 단계 복습)
    for (final reviewAttempt in reviewQueue) {
      if (recommendations.length >= targetCount) break;
      final problem = allProblems.firstWhere(
        (p) => p.id == reviewAttempt.problemId,
        orElse: () => ProblemSummary(
          id: reviewAttempt.problemId,
          grade: 3,
          subject: 'math',
          unit: reviewAttempt.unit,
          type: 'review',
          title: reviewAttempt.problemId,
          path: '',
          raw: const {},
        ),
      );

      if (!addedProblemIds.contains(problem.id)) {
        addedProblemIds.add(problem.id);
        recommendations.add(
          RecommendedProblem(
            problem: problem,
            reason: '이전에 틀린 문제를 간격 복습으로 다시 풀어봅니다.',
            tag: '오답 복습',
          ),
        );
      }
    }

    // 2. Unsolved / New problems in active unit
    for (final problem in allProblems) {
      if (recommendations.length >= targetCount) break;
      if (!addedProblemIds.contains(problem.id) &&
          !latestByProblem.containsKey(problem.id)) {
        addedProblemIds.add(problem.id);
        recommendations.add(
          RecommendedProblem(
            problem: problem,
            reason: '오늘 새로 도전하는 3학년 수학 개념 문제입니다.',
            tag: '오늘의 도전',
          ),
        );
      }
    }

    // 3. Fallback: Re-try partially solved or older problems to fill up to targetCount
    if (recommendations.length < targetCount) {
      for (final problem in allProblems) {
        if (recommendations.length >= targetCount) break;
        if (!addedProblemIds.contains(problem.id)) {
          addedProblemIds.add(problem.id);
          recommendations.add(
            RecommendedProblem(
              problem: problem,
              reason: '완벽한 개념 숙달을 위해 다시 확인해보는 문제입니다.',
              tag: '개념 다지기',
            ),
          );
        }
      }
    }

    return recommendations;
  }
}
