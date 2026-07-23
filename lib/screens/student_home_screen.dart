import 'package:flutter/material.dart';

import '../app/router.dart';
import '../models/content_models.dart';
import '../models/learning_progress.dart';
import '../models/student_profile.dart';
import '../services/content_repository.dart';
import '../services/learning_progress_repository.dart';
import '../services/recommendation_service.dart';
import '../theme/app_theme.dart';
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
  late Future<ProblemManifest> _manifestFuture;
  late Future<StudentProfile> _profileFuture;
  late Future<DailySummary> _dailySummaryFuture;
  late Future<List<RecommendedProblem>> _recommendationsFuture;
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
    setState(_loadData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              return _HomeStateMessage(
                icon: Icons.cloud_off_outlined,
                title: '학습 정보를 불러오지 못했어요',
                message: '${snapshot.error}',
                actionLabel: '다시 시도',
                onAction: _refresh,
              );
            }

            final profile = snapshot.data![0] as StudentProfile;
            final dailySummary = snapshot.data![1] as DailySummary;
            final manifest = snapshot.data![2] as ProblemManifest;
            final recommendations =
                snapshot.data![3] as List<RecommendedProblem>;

            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1080;
                  final horizontal = wide ? 28.0 : 16.0;
                  return ListView(
                    padding:
                        EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32),
                    children: [
                      _TopNavigation(
                        onReview: _openReview,
                        onProgress: _openProgress,
                      ),
                      const SizedBox(height: 24),
                      _TodayPanel(
                        wide: wide,
                        profile: profile,
                        dailySummary: dailySummary,
                        recommendations: recommendations,
                        onStart: recommendations.isEmpty
                            ? null
                            : () => _startDailyChallenge(recommendations),
                        onCurriculum: _openCurriculum,
                      ),
                      const SizedBox(height: 24),
                      _UnitRail(
                        problems: manifest.problems,
                        onOpenUnit: (unit) =>
                            _openCurriculum(initialUnit: unit),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openReview() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ReviewNoteScreen(
          repository: widget.repository,
          progressRepository: widget.progressRepository,
        ),
      ),
    );
    _refresh();
  }

  Future<void> _openProgress() async {
    await Navigator.of(context).pushNamed(ModuMathRoutes.progress);
    _refresh();
  }

  Future<void> _startDailyChallenge(
    List<RecommendedProblem> recommendations,
  ) async {
    if (recommendations.isEmpty) {
      return;
    }
    final problems = recommendations.map((item) => item.problem).toList();
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

  Future<void> _openCurriculum({String? initialUnit}) async {
    await Navigator.of(context).pushNamed(
      ModuMathRoutes.curriculum,
      arguments: CurriculumRouteArguments(initialUnit: initialUnit),
    );
    _refresh();
  }
}

class _TopNavigation extends StatelessWidget {
  const _TopNavigation({
    required this.onReview,
    required this.onProgress,
  });

  final VoidCallback onReview;
  final VoidCallback onProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: KidsPalette.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KidsPalette.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: KidsPalette.ink, size: 28),
          const SizedBox(width: 10),
          Text(
            '모두수학',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '오답 노트',
            onPressed: onReview,
            icon: const Icon(Icons.fact_check_outlined),
          ),
          IconButton(
            tooltip: '학습 리포트',
            onPressed: onProgress,
            icon: const Icon(Icons.bar_chart_rounded),
          ),
        ],
      ),
    );
  }
}

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({
    required this.wide,
    required this.profile,
    required this.dailySummary,
    required this.recommendations,
    required this.onStart,
    required this.onCurriculum,
  });

  final bool wide;
  final StudentProfile profile;
  final DailySummary dailySummary;
  final List<RecommendedProblem> recommendations;
  final VoidCallback? onStart;
  final VoidCallback onCurriculum;

  @override
  Widget build(BuildContext context) {
    final firstProblem =
        recommendations.isEmpty ? null : recommendations.first.problem;
    final content = _TodayCopy(
      profile: profile,
      dailySummary: dailySummary,
      onStart: onStart,
      onCurriculum: onCurriculum,
    );
    final preview = _LearningPreview(
      problem: firstProblem,
      dailySummary: dailySummary,
      targetDailyCount: profile.targetDailyCount,
    );

    return Container(
      padding: EdgeInsets.all(wide ? 32 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KidsPalette.line),
      ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 5, child: content),
                const SizedBox(width: 28),
                Expanded(flex: 6, child: preview),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content,
                const SizedBox(height: 22),
                preview,
              ],
            ),
    );
  }
}

class _TodayCopy extends StatelessWidget {
  const _TodayCopy({
    required this.profile,
    required this.dailySummary,
    required this.onStart,
    required this.onCurriculum,
  });

  final StudentProfile profile;
  final DailySummary dailySummary;
  final VoidCallback? onStart;
  final VoidCallback onCurriculum;

  @override
  Widget build(BuildContext context) {
    final compactType = MediaQuery.sizeOf(context).width < 460;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '오늘은 한 문제씩\n생각해 볼까요?',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: compactType ? 32 : 42,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: 14),
        Text(
          '${profile.grade}학년 ${profile.name}에게 맞춘 문제로 풀이 단계를 천천히 확인해요.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: KidsPalette.cocoaSoft,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 22),
        _HeroStats(
          solved: dailySummary.totalAttempted,
          target: profile.targetDailyCount,
          accuracy: dailySummary.accuracy,
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(58),
                ),
                label: const Text(
                  '오늘 학습 시작',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onCurriculum,
                icon: const Icon(Icons.list_alt_rounded),
                style: OutlinedButton.styleFrom(
                  backgroundColor: KidsPalette.paper,
                  minimumSize: const Size.fromHeight(54),
                ),
                label: const Text(
                  '단원에서 고르기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroStats extends StatelessWidget {
  const _HeroStats({
    required this.solved,
    required this.target,
    required this.accuracy,
  });

  final int solved;
  final int target;
  final double accuracy;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatPill(label: '오늘', value: '$solved/$target'),
        _StatPill(label: '정답률', value: '${(accuracy * 100).round()}%'),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: KidsPalette.paper,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: KidsPalette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 8),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _LearningPreview extends StatelessWidget {
  const _LearningPreview({
    required this.problem,
    required this.dailySummary,
    required this.targetDailyCount,
  });

  final ProblemSummary? problem;
  final DailySummary dailySummary;
  final int targetDailyCount;

  @override
  Widget build(BuildContext context) {
    final ratio = targetDailyCount == 0
        ? 0.0
        : (dailySummary.totalAttempted / targetDailyCount).clamp(0.0, 1.0);

    return AspectRatio(
      aspectRatio: 1.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KidsPalette.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KidsPalette.line),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _PreviewGridPainter())),
            Positioned(
              left: 20,
              top: 20,
              right: 20,
              child: _ProblemPreviewCard(problem: problem),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: _ProgressStrip(
                value: ratio,
                title: problem?.unit ?? '오늘의 문제',
                caption: problem?.title ?? '추천 문제를 준비하고 있어요.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProblemPreviewCard extends StatelessWidget {
  const _ProblemPreviewCard({required this.problem});

  final ProblemSummary? problem;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFECEEFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KidsPalette.sage.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 54,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: KidsPalette.sage,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(Icons.functions_rounded, color: Colors.white),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    problem?.unit ?? '오늘의 문제',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    problem?.title ?? '추천 문제를 불러오는 중입니다.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({
    required this.value,
    required this.title,
    required this.caption,
  });

  final double value;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KidsPalette.paper.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KidsPalette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${(value * 100).round()}%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: KidsPalette.sage,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: value,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: KidsPalette.butter,
              color: KidsPalette.sage,
            ),
            const SizedBox(height: 10),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitRail extends StatelessWidget {
  const _UnitRail({
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('단원별 학습', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SizedBox(
          height: 152,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: units.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final unit = units[index];
              final count = unitGroups[unit]?.length ?? 0;
              return _UnitTile(
                unit: unit,
                count: count,
                onTap: () => onOpenUnit(unit),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({
    required this.unit,
    required this.count,
    required this.onTap,
  });

  final String unit;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      '$count문제',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFF7F8FC), BlendMode.src);

    final gridPaint = Paint()
      ..color = KidsPalette.line.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (double x = 24; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 24; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final accentPaint = Paint()
      ..color = KidsPalette.warning.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(size.width * 0.82, size.height * 0.24), 54, accentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomeStateMessage extends StatelessWidget {
  const _HomeStateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: KidsPalette.cocoaSoft),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
