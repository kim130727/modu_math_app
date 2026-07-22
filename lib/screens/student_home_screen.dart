import 'package:flutter/material.dart';

import '../models/content_models.dart';
import '../models/learning_progress.dart';
import '../models/student_profile.dart';
import '../services/content_repository.dart';
import '../services/learning_progress_repository.dart';
import '../services/recommendation_service.dart';
import '../theme/app_theme.dart';
import '../app/router.dart';
import 'learning_report_screen.dart';
import 'problem_list_screen.dart';
import 'problem_solve_screen.dart';
import 'review_note_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    super.key,
    required this.repository,
    required this.progressRepository,
  });

  final ContentRepository repository;
  final LearningProgressRepository progressRepository;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  late final Future<ProblemManifest> _manifestFuture;
  late final Future<StudentProfile> _profileFuture;
  late final Future<DailySummary> _dailySummaryFuture;
  late final Future<List<RecommendedProblem>> _recommendationsFuture;
  final RecommendationService _recommendationService =
      const RecommendationService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _manifestFuture = widget.repository.loadManifest();
    _profileFuture = widget.progressRepository.getProfile();
    _dailySummaryFuture =
        widget.progressRepository.getDailySummary(DateTime.now());
    _recommendationsFuture = _manifestFuture.then((manifest) {
      return _recommendationService.getDailyRecommendation(
        allProblems: manifest.problems,
        progressRepository: widget.progressRepository,
      );
    });
  }

  void _refresh() {
    setState(() {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KidsPalette.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.school, color: KidsPalette.cocoa, size: 28),
            const SizedBox(width: 10),
            Text(
              '모두수학',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: KidsPalette.cocoa,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '오답노트 & 사고 복습',
            icon:
                const Icon(Icons.fact_check_outlined, color: KidsPalette.cocoa),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => ReviewNoteScreen(
                    repository: widget.repository,
                    progressRepository: widget.progressRepository,
                  ),
                ),
              );
              _refresh();
            },
          ),
          IconButton(
            tooltip: '학습 성장 리포트',
            icon: const Icon(Icons.bar_chart_rounded, color: KidsPalette.cocoa),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => LearningReportScreen(
                    progressRepository: widget.progressRepository,
                  ),
                ),
              );
              _refresh();
            },
          ),
          IconButton(
            tooltip: '개발자 스튜디오 (Developer Studio)',
            icon:
                const Icon(Icons.developer_mode, color: KidsPalette.cocoaSoft),
            onPressed: () async {
              await Navigator.of(context)
                  .pushNamed(ModuMathRoutes.developerStudio);
              _refresh();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: Future.wait([
            _profileFuture,
            _dailySummaryFuture,
            _manifestFuture,
            _recommendationsFuture,
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('데이터를 불러오지 못했습니다.\n${snapshot.error}'),
                ),
              );
            }

            final profile = snapshot.data![0] as StudentProfile;
            final dailySummary = snapshot.data![1] as DailySummary;
            final manifest = snapshot.data![2] as ProblemManifest;
            final recommendations =
                snapshot.data![3] as List<RecommendedProblem>;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    children: [
                      _StudentHeader(
                        profile: profile,
                        dailySummary: dailySummary,
                      ),
                      const SizedBox(height: 20),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _DailyChallengeCard(
                                recommendations: recommendations,
                                onStartChallenge: () =>
                                    _startDailyChallenge(recommendations),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 4,
                              child: _QuickStatsCard(
                                dailySummary: dailySummary,
                                targetDailyCount: profile.targetDailyCount,
                                onOpenUnitMap: () => _openUnitMap(manifest),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _DailyChallengeCard(
                          recommendations: recommendations,
                          onStartChallenge: () =>
                              _startDailyChallenge(recommendations),
                        ),
                        const SizedBox(height: 16),
                        _QuickStatsCard(
                          dailySummary: dailySummary,
                          targetDailyCount: profile.targetDailyCount,
                          onOpenUnitMap: () => _openUnitMap(manifest),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        '단원별 맞춤 학습',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: KidsPalette.ink,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _UnitGridSection(
                        problems: manifest.problems,
                        onOpenUnit: (unit) =>
                            _openUnitMap(manifest, initialUnit: unit),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _startDailyChallenge(
      List<RecommendedProblem> recommendations) async {
    if (recommendations.isEmpty) return;
    final problems = recommendations.map((r) => r.problem).toList();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProblemSolveScreen(
          repository: widget.repository,
          progressRepository: widget.progressRepository,
          problem: problems.first,
          unitProblems: problems,
          problemIndex: 0,
        ),
      ),
    );
    _refresh();
  }

  Future<void> _openUnitMap(ProblemManifest manifest,
      {String? initialUnit}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProblemListScreen(
          repository: widget.repository,
          progressRepository: widget.progressRepository,
          initialUnit: initialUnit,
        ),
      ),
    );
    _refresh();
  }
}

class _StudentHeader extends StatelessWidget {
  const _StudentHeader({
    required this.profile,
    required this.dailySummary,
  });

  final StudentProfile profile;
  final DailySummary dailySummary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KidsPalette.butter,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: KidsPalette.cocoa.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: KidsPalette.sage,
            child: Text(
              '${profile.grade}학년',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '반가워요, ${profile.name}! 👋',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: KidsPalette.ink,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '사고 과정을 한 단계씩 풀어가며 수학 자신감을 키워보세요.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KidsPalette.cocoaSoft,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department,
                    color: Colors.orange, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${dailySummary.streakDays}일째',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: KidsPalette.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyChallengeCard extends StatelessWidget {
  const _DailyChallengeCard({
    required this.recommendations,
    required this.onStartChallenge,
  });

  final List<RecommendedProblem> recommendations;
  final VoidCallback onStartChallenge;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: KidsPalette.sage.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.auto_awesome, color: KidsPalette.sage),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘의 10문제 도전 🚀',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'AI 튜터와 함께 10문제를 풀고 원인을 진단합니다.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[700],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recommendations.take(4).map((r) {
                return Chip(
                  avatar: const Icon(Icons.star_outline, size: 16),
                  label: Text('${r.tag}: ${r.problem.title}'),
                  backgroundColor: KidsPalette.paper,
                  side: const BorderSide(color: KidsPalette.line),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: recommendations.isEmpty ? null : onStartChallenge,
                style: FilledButton.styleFrom(
                  backgroundColor: KidsPalette.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 26),
                label: const Text(
                  '오늘의 추천 문제 시작',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatsCard extends StatelessWidget {
  const _QuickStatsCard({
    required this.dailySummary,
    required this.targetDailyCount,
    required this.onOpenUnitMap,
  });

  final DailySummary dailySummary;
  final int targetDailyCount;
  final VoidCallback onOpenUnitMap;

  @override
  Widget build(BuildContext context) {
    final progressRatio =
        (dailySummary.totalAttempted / targetDailyCount).clamp(0.0, 1.0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '오늘의 학습 목표',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progressRatio,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: KidsPalette.line,
              color: KidsPalette.sage,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '달성: ${dailySummary.totalAttempted} / $targetDailyCount 문제',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '정답률: ${(dailySummary.accuracy * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: KidsPalette.cocoaSoft,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onOpenUnitMap,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text('전체 단원 지도로 이동'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitGridSection extends StatelessWidget {
  const _UnitGridSection({
    required this.problems,
    required this.onOpenUnit,
  });

  final List<ProblemSummary> problems;
  final ValueChanged<String> onOpenUnit;

  @override
  Widget build(BuildContext context) {
    final unitGroups = <String, List<ProblemSummary>>{};
    for (final problem in problems) {
      unitGroups.putIfAbsent(problem.unit, () => []).add(problem);
    }
    final units = unitGroups.keys.toList()..sort();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: units.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 340,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (context, index) {
        final unit = units[index];
        final count = unitGroups[unit]?.length ?? 0;
        return Card(
          margin: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onOpenUnit(unit),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$count개 문제',
                        style: const TextStyle(
                          color: KidsPalette.cocoaSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: KidsPalette.cocoa,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
