import 'package:flutter/material.dart';

import '../models/content_models.dart';
import '../services/content_repository.dart';
import '../services/learning_progress_repository.dart';
import '../theme/app_theme.dart';
import '../app/router.dart';

class CurriculumScreen extends StatefulWidget {
  const CurriculumScreen({
    super.key,
    required this.repository,
    required this.progressRepository,
    this.initialUnit,
  });

  final ContentRepository repository;
  final LearningProgressRepository progressRepository;
  final String? initialUnit;

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  late final Future<ProblemManifest> _manifestFuture;

  @override
  void initState() {
    super.initState();
    _manifestFuture = widget.repository.loadManifest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KidsPalette.cream,
      appBar: AppBar(
        title: const Text('단원 학습'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<ProblemManifest>(
          future: _manifestFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('단원 정보를 불러오지 못했습니다.\n${snapshot.error}'),
                ),
              );
            }

            final groups = _CurriculumGroup.fromProblems(
              snapshot.data?.problems ?? const <ProblemSummary>[],
            );
            if (groups.isEmpty) {
              return const Center(child: Text('아직 학습할 문제가 없습니다.'));
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                const _CurriculumHeader(),
                const SizedBox(height: 20),
                ...groups.map(
                  (group) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _CurriculumSection(
                      group: group,
                      initialUnit: widget.initialUnit,
                      onOpenUnit: _openUnit,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openUnit(String unit) async {
    await Navigator.of(context).pushNamed(
      ModuMathRoutes.learningSession,
      arguments: LearningSessionRouteArguments(unit: unit),
    );
    if (mounted) {
      setState(() {});
    }
  }
}

class _CurriculumHeader extends StatelessWidget {
  const _CurriculumHeader();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KidsPalette.butter,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.map_outlined, color: KidsPalette.cocoa, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘 배울 단원을 골라요',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: KidsPalette.ink,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '단원을 고르면 문제 풀이와 튜터가 바로 이어집니다.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: KidsPalette.cocoaSoft,
                        ),
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

class _CurriculumSection extends StatelessWidget {
  const _CurriculumSection({
    required this.group,
    required this.initialUnit,
    required this.onOpenUnit,
  });

  final _CurriculumGroup group;
  final String? initialUnit;
  final ValueChanged<String> onOpenUnit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${group.grade}학년 ${group.semester}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: KidsPalette.ink,
              ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: group.units.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: wide ? 2 : 1,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: wide ? 3.1 : 3.5,
              ),
              itemBuilder: (context, index) {
                final unit = group.units[index];
                return _UnitTile(
                  unit: unit,
                  selected: unit.name == initialUnit,
                  onTap: () => onOpenUnit(unit.name),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({
    required this.unit,
    required this.selected,
    required this.onTap,
  });

  final _CurriculumUnit unit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? KidsPalette.sage : KidsPalette.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    selected ? KidsPalette.sage : KidsPalette.butter,
                foregroundColor: selected ? Colors.white : KidsPalette.cocoa,
                child: Text('${unit.number}'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.topic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${unit.problemCount}문제',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: KidsPalette.cocoaSoft,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: KidsPalette.cocoa),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurriculumGroup {
  const _CurriculumGroup({
    required this.grade,
    required this.semester,
    required this.units,
  });

  final int grade;
  final String semester;
  final List<_CurriculumUnit> units;

  static List<_CurriculumGroup> fromProblems(List<ProblemSummary> problems) {
    final unitBuckets = <String, List<ProblemSummary>>{};
    for (final problem in problems) {
      unitBuckets.putIfAbsent(problem.unit, () => []).add(problem);
    }

    final groupedUnits = <String, List<_CurriculumUnit>>{};
    for (final entry in unitBuckets.entries) {
      final sample = entry.value.first;
      final semester = sample.raw['semester']?.toString() ?? '학기 미정';
      final groupKey = '${sample.grade}|$semester';
      groupedUnits.putIfAbsent(groupKey, () => []).add(
            _CurriculumUnit(
              name: entry.key,
              number: _readInt(sample.raw['unitNumber']) ?? 0,
              topic: sample.raw['unitTopic']?.toString() ?? entry.key,
              problemCount: entry.value.length,
            ),
          );
    }

    final groups = groupedUnits.entries.map((entry) {
      final parts = entry.key.split('|');
      final units = entry.value
        ..sort((a, b) {
          final byNumber = a.number.compareTo(b.number);
          return byNumber == 0 ? a.name.compareTo(b.name) : byNumber;
        });
      return _CurriculumGroup(
        grade: int.tryParse(parts.first) ?? 0,
        semester: parts.length > 1 ? parts[1] : '학기 미정',
        units: units,
      );
    }).toList()
      ..sort((a, b) {
        final byGrade = a.grade.compareTo(b.grade);
        return byGrade == 0 ? a.semester.compareTo(b.semester) : byGrade;
      });

    return groups;
  }
}

class _CurriculumUnit {
  const _CurriculumUnit({
    required this.name,
    required this.number,
    required this.topic,
    required this.problemCount,
  });

  final String name;
  final int number;
  final String topic;
  final int problemCount;
}

int? _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '');
}
