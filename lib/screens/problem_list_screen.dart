import 'package:flutter/material.dart';

import '../models/content_models.dart';
import '../services/content_repository.dart';
import '../widgets/progress_panel.dart';
import 'problem_solve_screen.dart';

class ProblemListScreen extends StatefulWidget {
  const ProblemListScreen({
    super.key,
    required this.repository,
    required this.progress,
  });

  final ContentRepository repository;
  final SessionProgress progress;

  @override
  State<ProblemListScreen> createState() => _ProblemListScreenState();
}

class _ProblemListScreenState extends State<ProblemListScreen> {
  late final Future<ProblemManifest> manifestFuture;
  String? selectedUnit;

  @override
  void initState() {
    super.initState();
    manifestFuture = widget.repository.loadManifest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(selectedUnit ?? '모두수학'),
        leading: selectedUnit == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => selectedUnit = null),
              ),
      ),
      body: FutureBuilder<ProblemManifest>(
        future: manifestFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '문제 목록을 불러오지 못했습니다.\n${snapshot.error}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }

          final problems = snapshot.data?.problems ?? const <ProblemSummary>[];
          return selectedUnit == null
              ? _UnitOverview(
                  problems: problems,
                  progress: widget.progress,
                  onOpenUnit: (unit) => setState(() => selectedUnit = unit),
                )
              : _UnitJourney(
                  problems: problems
                      .where((problem) => problem.unit == selectedUnit)
                      .toList(),
                  progress: widget.progress,
                  onOpenProblem: _openProblem,
                );
        },
      ),
    );
  }

  Future<void> _openProblem(ProblemSummary problem) async {
    final manifest = await manifestFuture;
    final unitProblems = selectedUnit == null
        ? const <ProblemSummary>[]
        : (manifest.problems.where((item) => item.unit == selectedUnit).toList()
          ..sort((a, b) => a.id.compareTo(b.id)));
    final problemIndex =
        unitProblems.indexWhere((item) => item.id == problem.id);
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProblemSolveScreen(
          repository: widget.repository,
          progress: widget.progress,
          problem: problem,
          unitProblems: unitProblems,
          problemIndex: problemIndex < 0 ? 0 : problemIndex,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }
}

class _UnitOverview extends StatelessWidget {
  const _UnitOverview({
    required this.problems,
    required this.progress,
    required this.onOpenUnit,
  });

  final List<ProblemSummary> problems;
  final SessionProgress progress;
  final ValueChanged<String> onOpenUnit;

  @override
  Widget build(BuildContext context) {
    final unitGroups = <String, List<ProblemSummary>>{};
    for (final problem in problems) {
      unitGroups.putIfAbsent(problem.unit, () => []).add(problem);
    }
    final units = unitGroups.keys.toList()..sort();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final grid = GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: units.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wide ? 3 : 1,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: wide ? 2.4 : 3.2,
          ),
          itemBuilder: (context, index) {
            final unit = units[index];
            final unitProblems = unitGroups[unit] ?? const <ProblemSummary>[];
            return _UnitCard(
              unit: unit,
              count: unitProblems.length,
              onTap: () => onOpenUnit(unit),
            );
          },
        );

        if (!wide) {
          return Column(
            children: [
              ProgressPanel(progress: progress),
              Expanded(child: grid),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 280,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ProgressPanel(progress: progress),
              ),
            ),
            Expanded(child: grid),
          ],
        );
      },
    );
  }
}

class _UnitJourney extends StatelessWidget {
  const _UnitJourney({
    required this.problems,
    required this.progress,
    required this.onOpenProblem,
  });

  final List<ProblemSummary> problems;
  final SessionProgress progress;
  final ValueChanged<ProblemSummary> onOpenProblem;

  @override
  Widget build(BuildContext context) {
    final orderedProblems = [...problems]..sort((a, b) => a.id.compareTo(b.id));
    final firstUnsolved = orderedProblems.indexWhere(
      (problem) =>
          !progress.results.any((result) => result.problem.id == problem.id),
    );
    final startIndex = firstUnsolved == -1 ? 0 : firstUnsolved;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final content = ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _JourneyHeader(
              unit: orderedProblems.isEmpty ? '' : orderedProblems.first.unit,
              count: orderedProblems.length,
              onStart: orderedProblems.isEmpty
                  ? null
                  : () => onOpenProblem(orderedProblems[startIndex]),
              isComplete: firstUnsolved == -1 && orderedProblems.isNotEmpty,
            ),
            const SizedBox(height: 14),
            ...orderedProblems.indexed.map((entry) {
              final index = entry.$1;
              final problem = entry.$2;
              final result = progress.results
                  .where((item) => item.problem.id == problem.id)
                  .firstOrNull;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _JourneyStepTile(
                  stepNumber: index + 1,
                  problem: problem,
                  result: result,
                  onTap: () => onOpenProblem(problem),
                ),
              );
            }),
          ],
        );

        if (!wide) {
          return Column(
            children: [
              ProgressPanel(progress: progress),
              Expanded(child: content),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 280,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ProgressPanel(progress: progress),
              ),
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader({
    required this.unit,
    required this.count,
    required this.onStart,
    required this.isComplete,
  });

  final String unit;
  final int count;
  final VoidCallback? onStart;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(unit, style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'AI 튜터와 $count개의 문제를 차례대로 풀어봅니다.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onStart,
              icon: Icon(isComplete ? Icons.replay : Icons.play_arrow),
              label: Text(isComplete ? '다시 풀기' : '이어 풀기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyStepTile extends StatelessWidget {
  const _JourneyStepTile({
    required this.stepNumber,
    required this.problem,
    required this.result,
    required this.onTap,
  });

  final int stepNumber;
  final ProblemSummary problem;
  final ProblemResult? result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final solved = result != null;
    final color = !solved
        ? colorScheme.secondaryContainer
        : result!.isCorrect
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFFEDD5);
    final icon = !solved
        ? Icons.radio_button_unchecked
        : result!.isCorrect
            ? Icons.check_circle
            : Icons.refresh;
    final label = !solved
        ? '대기'
        : result!.isCorrect
            ? '완료'
            : '다시 풀기';

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                foregroundColor: colorScheme.onSurface,
                child: Text('$stepNumber'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      problem.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'AI 튜터와 함께 풀이',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Chip(
                avatar: Icon(icon, size: 18),
                label: Text(label),
                backgroundColor: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.count,
    required this.onTap,
  });

  final String unit;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(unit, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Text(
                '$count문제',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.forum_outlined,
                    color: colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'AI 튜터로 시작',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
