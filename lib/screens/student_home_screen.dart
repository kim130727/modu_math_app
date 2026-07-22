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
                  final wide = constraints.maxWidth >= 1180;
                  final horizontal = wide ? 24.0 : 16.0;

                  return ListView(
                    padding:
                        EdgeInsets.fromLTRB(horizontal, 18, horizontal, 32),
                    children: [
                      _TopNavigation(
                        onReview: () => _openReview(),
                        onProgress: () => _openProgress(),
                      ),
                      const SizedBox(height: 48),
                      _HeroPanel(
                        wide: wide,
                        profile: profile,
                        dailySummary: dailySummary,
                        recommendations: recommendations,
                        onStart: recommendations.isEmpty
                            ? null
                            : () => _startDailyChallenge(recommendations),
                        onCurriculum: _openCurriculum,
                      ),
                      const SizedBox(height: 26),
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
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: KidsPalette.paper,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: KidsPalette.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: KidsPalette.ink, size: 30),
          const SizedBox(width: 10),
          Text(
            '모두수학',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 24,
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

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
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
    final preview = _LearningPreview(
      recommendation: recommendations.isEmpty ? null : recommendations.first,
      dailySummary: dailySummary,
      targetDailyCount: profile.targetDailyCount,
    );

    final copy = _HeroCopy(
      profile: profile,
      dailySummary: dailySummary,
      onStart: onStart,
      onCurriculum: onCurriculum,
    );

    return Container(
      constraints: BoxConstraints(minHeight: wide ? 620 : 0),
      padding: EdgeInsets.all(wide ? 42 : 22),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1EE),
        borderRadius: BorderRadius.circular(44),
        border: Border.all(color: KidsPalette.line),
      ),
      child: wide
          ? Row(
              children: [
                Expanded(flex: 5, child: copy),
                const SizedBox(width: 38),
                Expanded(flex: 7, child: preview),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                const SizedBox(height: 24),
                preview,
              ],
            ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
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
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '스스로 생각하는\n초등 수학 튜터',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: compactType ? 36 : 46,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: 22),
        Text(
          '${profile.grade}학년 ${profile.name}에게 맞춘 문제로 오늘의 생각 단계를 확인해요.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: KidsPalette.cocoaSoft,
                fontSize: 19,
                height: 1.55,
              ),
        ),
        const SizedBox(height: 34),
        _HeroStats(
          solved: dailySummary.totalAttempted,
          target: profile.targetDailyCount,
          accuracy: dailySummary.accuracy,
        ),
        const SizedBox(height: 34),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: const Text(
                  '학습 시작',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onCurriculum,
                style: OutlinedButton.styleFrom(
                  backgroundColor: KidsPalette.paper,
                  minimumSize: const Size.fromHeight(58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  '단원에서 고르기',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
    return Row(
      children: [
        _StatPill(label: '오늘', value: '$solved/$target'),
        const SizedBox(width: 10),
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
    required this.recommendation,
    required this.dailySummary,
    required this.targetDailyCount,
  });

  final RecommendedProblem? recommendation;
  final DailySummary dailySummary;
  final int targetDailyCount;

  @override
  Widget build(BuildContext context) {
    final problem = recommendation?.problem;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;

        return AspectRatio(
          aspectRatio: compact ? 0.9 : 1.45,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFEDEBE4),
                    Color(0xFFD8D6CE),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _PreviewGridPainter()),
                  ),
                  if (!compact)
                    Positioned(
                      left: 34,
                      top: 34,
                      bottom: 34,
                      width: 210,
                      child: _StudentSilhouette(
                        grade: problem?.grade ?? 3,
                      ),
                    ),
                  Positioned(
                    left: compact ? 22 : null,
                    right: compact ? 22 : 34,
                    top: compact ? 26 : 48,
                    bottom: compact ? 146 : 58,
                    width: compact ? null : 360,
                    child: _ProblemPreviewCard(problem: problem),
                  ),
                  Positioned(
                    left: compact ? 28 : null,
                    right: compact ? null : 430,
                    bottom: compact ? 24 : 42,
                    child: _ProgressGem(
                      solved: dailySummary.totalAttempted,
                      target: targetDailyCount,
                      compact: compact,
                    ),
                  ),
                  Positioned(
                    left: compact ? 122 : null,
                    right: compact ? 22 : 34,
                    bottom: compact ? 30 : 28,
                    child: _PreviewCaption(
                      text: problem?.title ?? '오늘 풀 문제를 준비하고 있어요.',
                    ),
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

class _ProblemPreviewCard extends StatelessWidget {
  const _ProblemPreviewCard({required this.problem});

  final ProblemSummary? problem;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KidsPalette.paper,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              problem?.unit ?? '오늘의 문제',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: CustomPaint(
                painter: _MiniChartPainter(),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              problem?.title ?? '추천 문제를 불러오는 중입니다.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentSilhouette extends StatelessWidget {
  const _StudentSilhouette({required this.grade});

  final int grade;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFBCB8AE).withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE9DED4),
            ),
            child: const Icon(
              Icons.face_rounded,
              size: 66,
              color: Color(0xFF6E625B),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 150,
            height: 124,
            decoration: BoxDecoration(
              color: const Color(0xFFB8C0D2),
              borderRadius: BorderRadius.circular(40),
            ),
            alignment: Alignment.center,
            child: Text(
              '$grade학년',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressGem extends StatelessWidget {
  const _ProgressGem({
    required this.solved,
    required this.target,
    required this.compact,
  });

  final int solved;
  final int target;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ratio = target == 0 ? 0.0 : (solved / target).clamp(0.0, 1.0);
    final size = compact ? 86.0 : 96.0;
    return Transform.rotate(
      angle: -0.78,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: KidsPalette.sage,
          borderRadius: BorderRadius.circular(compact ? 22 : 26),
          boxShadow: [
            BoxShadow(
              color: KidsPalette.sage.withValues(alpha: 0.24),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Transform.rotate(
          angle: 0.78,
          child: Text(
            '${(ratio * 100).round()}%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewCaption extends StatelessWidget {
  const _PreviewCaption({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1.22,
            ),
          ),
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
        const SizedBox(height: 14),
        SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: units.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
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
      width: 280,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(22),
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
                    Text('$count문제',
                        style: Theme.of(context).textTheme.bodyLarge),
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
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = KidsPalette.ink
      ..strokeWidth = 2;
    final gridPaint = Paint()
      ..color = KidsPalette.line
      ..strokeWidth = 1;
    final pointPaint = Paint()..color = KidsPalette.sage;

    for (double x = 0; x <= size.width; x += size.width / 5) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += size.height / 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), axisPaint);
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), axisPaint);

    final points = [
      Offset(size.width * 0.12, size.height * 0.70),
      Offset(size.width * 0.28, size.height * 0.56),
      Offset(size.width * 0.44, size.height * 0.38),
    ];
    for (final point in points) {
      canvas.drawCircle(point, 6, pointPaint);
    }

    final guidePaint = Paint()
      ..color = KidsPalette.sage.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height * 0.56),
      Offset(size.width, size.height * 0.56),
      guidePaint,
    );
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
