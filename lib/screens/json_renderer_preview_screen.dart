import 'dart:convert';
import 'package:flutter/material.dart';

import '../models/content_models.dart';
import '../services/content_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/renderer_json_canvas.dart';
import 'problem_list_screen.dart';

class JsonRendererPreviewScreen extends StatefulWidget {
  const JsonRendererPreviewScreen({
    super.key,
    required this.repository,
    required this.progress,
  });

  final ContentRepository repository;
  final SessionProgress progress;

  @override
  State<JsonRendererPreviewScreen> createState() =>
      _JsonRendererPreviewScreenState();
}

class _JsonRendererPreviewScreenState extends State<JsonRendererPreviewScreen> {
  // ignore: unused_field
  static const filePrefix = 'S3_초등_3_008676';

  late final Future<List<String>> prefixesFuture;
  late Future<ProblemJsonBundle> bundleFuture;
  String selectedFilePrefix = 'S3_초등_3_008540';

  @override
  void initState() {
    super.initState();
    prefixesFuture = widget.repository.loadGrade3JsonProblemPrefixes();
    bundleFuture = widget.repository.loadProblemJsonBundle(selectedFilePrefix);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: _StudioBackdrop()),
            SafeArea(
              child: FutureBuilder<ProblemJsonBundle>(
                future: bundleFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _LoadError(error: snapshot.error);
                  }

                  final bundle = snapshot.data!;
                  return Column(
                    children: [
                      _TopBar(
                        bundle: bundle,
                        prefixesFuture: prefixesFuture,
                        selectedFilePrefix: selectedFilePrefix,
                        onSelectPrefix: _selectPrefix,
                        onOpenList: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => ProblemListScreen(
                              repository: widget.repository,
                              progress: widget.progress,
                            ),
                          ),
                        ),
                      ),
                      const _StudioTabs(),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _RenderTab(bundle: bundle),
                            _JsonTab(
                                title: 'semantic.json', data: bundle.semantic),
                            _JsonTab(title: 'layout.json', data: bundle.layout),
                            _JsonTab(
                                title: 'renderer.json', data: bundle.renderer),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectPrefix(String prefix) {
    if (prefix == selectedFilePrefix) {
      return;
    }
    setState(() {
      selectedFilePrefix = prefix;
      bundleFuture = widget.repository.loadProblemJsonBundle(prefix);
    });
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.bundle,
    required this.prefixesFuture,
    required this.selectedFilePrefix,
    required this.onSelectPrefix,
    required this.onOpenList,
  });

  final ProblemJsonBundle bundle;
  final Future<List<String>> prefixesFuture;
  final String selectedFilePrefix;
  final ValueChanged<String> onSelectPrefix;
  final VoidCallback onOpenList;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modu Math Studio', style: textTheme.displaySmall),
                const SizedBox(height: 6),
                Text(
                  'JSON 렌더링과 문제 구조를 한 화면에서 확인합니다.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: KidsPalette.olive,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _ProblemPrefixPicker(
            prefixesFuture: prefixesFuture,
            selectedFilePrefix: selectedFilePrefix,
            onSelectPrefix: onSelectPrefix,
          ),
          const SizedBox(width: 12),
          _RoundIconButton(
            tooltip: '기존 문제 목록',
            icon: Icons.list_alt,
            onPressed: onOpenList,
          ),
        ],
      ),
    );
  }
}

class _ProblemPrefixPicker extends StatelessWidget {
  const _ProblemPrefixPicker({
    required this.prefixesFuture,
    required this.selectedFilePrefix,
    required this.onSelectPrefix,
  });

  final Future<List<String>> prefixesFuture;
  final String selectedFilePrefix;
  final ValueChanged<String> onSelectPrefix;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: prefixesFuture,
      builder: (context, snapshot) {
        final prefixes = snapshot.data ?? <String>[selectedFilePrefix];
        final values = prefixes.contains(selectedFilePrefix)
            ? prefixes
            : <String>[selectedFilePrefix, ...prefixes];
        return DecoratedBox(
          decoration: BoxDecoration(
            color: KidsPalette.paper,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: KidsPalette.line),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedFilePrefix,
                borderRadius: BorderRadius.circular(8),
                icon: const Icon(Icons.expand_more),
                items: values
                    .map(
                      (prefix) => DropdownMenuItem<String>(
                        value: prefix,
                        child: Text(prefix),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onSelectPrefix(value);
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StudioTabs extends StatelessWidget {
  const _StudioTabs();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF1E5C8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const TabBar(
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: KidsPalette.butter,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          tabs: [
            Tab(icon: Icon(Icons.preview), text: 'Render'),
            Tab(icon: Icon(Icons.account_tree_outlined), text: 'Semantic'),
            Tab(icon: Icon(Icons.dashboard_customize_outlined), text: 'Layout'),
            Tab(icon: Icon(Icons.code), text: 'Renderer'),
          ],
        ),
      ),
    );
  }
}

class _RenderTab extends StatelessWidget {
  const _RenderTab({required this.bundle});

  final ProblemJsonBundle bundle;

  @override
  Widget build(BuildContext context) {
    return _RenderTabBody(bundle: bundle);
  }
}

class _RenderTabBody extends StatelessWidget {
  const _RenderTabBody({required this.bundle});

  final ProblemJsonBundle bundle;

  @override
  Widget build(BuildContext context) {
    final metadata = _mapAt(bundle.semantic, 'metadata');
    final answer = _mapAt(bundle.semantic, 'answer');
    final elements = (bundle.renderer['elements'] as List?) ?? const [];
    final viewBox = _mapAt(bundle.renderer, 'view_box');

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final preview = Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroPanel(bundle: bundle, instruction: metadata['instruction']),
              const SizedBox(height: 14),
              Expanded(
                child: _CanvasShell(
                  child: RendererJsonCanvas(
                    renderer: bundle.renderer,
                  ),
                ),
              ),
            ],
          ),
        );

        final details = Padding(
          padding: EdgeInsets.fromLTRB(wide ? 8 : 24, 18, 24, 24),
          child: ListView(
            children: [
              _MetricStrip(
                items: [
                  const _MetricItem(
                    icon: Icons.check_circle,
                    label: '상태',
                    value: '로드 완료',
                    color: Color(0xFFE2F5B5),
                  ),
                  _MetricItem(
                    icon: Icons.widgets_outlined,
                    label: 'Elements',
                    value: '${elements.length}',
                    color: KidsPalette.butter,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _KeyValuePanel(
                title: 'Semantic',
                rows: {
                  '문제 ID': bundle.filePrefix,
                  '유형': bundle.semantic['problem_type']?.toString() ?? '-',
                  '제목': metadata['title']?.toString() ?? '-',
                  '지시문': metadata['instruction']?.toString() ?? '-',
                  '정답': answer['value']?.toString() ?? '-',
                },
              ),
              const SizedBox(height: 12),
              _KeyValuePanel(
                title: 'Renderer',
                rows: {
                  '계약 버전':
                      bundle.renderer['contract_version']?.toString() ?? '-',
                  'Canvas': '${viewBox['width']} x ${viewBox['height']}',
                  '배경': viewBox['background']?.toString() ?? '-',
                },
              ),
            ],
          ),
        );

        if (!wide) {
          return Column(
            children: [
              Expanded(flex: 3, child: preview),
              Expanded(flex: 2, child: details),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 7, child: preview),
            SizedBox(width: 390, child: details),
          ],
        );
      },
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.bundle,
    required this.instruction,
  });

  final ProblemJsonBundle bundle;
  final Object? instruction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KidsPalette.butter,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: KidsPalette.cocoa.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Row(
          children: [
            const _LeafBadge(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bundle.filePrefix, style: textTheme.titleLarge),
                  const SizedBox(height: 5),
                  Text(
                    instruction?.toString() ?? '렌더링 데이터를 확인합니다.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: KidsPalette.cocoaSoft,
                      fontWeight: FontWeight.w800,
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

class _CanvasShell extends StatelessWidget {
  const _CanvasShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KidsPalette.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KidsPalette.line, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: KidsPalette.cocoa.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.items});

  final List<_MetricItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final item in items) ...[
          Expanded(child: item),
          if (item != items.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: KidsPalette.ink, size: 22),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: KidsPalette.olive,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyValuePanel extends StatelessWidget {
  const _KeyValuePanel({
    required this.title,
    required this.rows,
  });

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KidsPalette.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KidsPalette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...rows.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        color: KidsPalette.olive,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.value,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JsonTab extends StatelessWidget {
  const _JsonTab({
    required this.title,
    required this.data,
  });

  final String title;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    const encoder = JsonEncoder.withIndent('  ');
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: KidsPalette.paper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: KidsPalette.line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                encoder.convert(data),
                style: const TextStyle(
                  color: KidsPalette.ink,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: KidsPalette.paper,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: KidsPalette.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'JSON 문제를 불러오지 못했습니다.\n$error',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: KidsPalette.butter,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 54,
            height: 54,
            child: Icon(icon, color: KidsPalette.ink),
          ),
        ),
      ),
    );
  }
}

class _LeafBadge extends StatelessWidget {
  const _LeafBadge();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: KidsPalette.sage,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Icon(Icons.auto_awesome, color: Colors.white),
      ),
    );
  }
}

class _StudioBackdrop extends StatelessWidget {
  const _StudioBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StudioBackdropPainter());
  }
}

class _StudioBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(KidsPalette.cream, BlendMode.src);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..strokeWidth = 1;
    for (double x = 28; x < size.width; x += 56) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 32; y < size.height; y += 56) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final formulaPaint = Paint()
      ..color = KidsPalette.cocoa.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (double x = 18; x < size.width; x += 180) {
      for (double y = 90; y < size.height; y += 150) {
        canvas.drawCircle(Offset(x, y), 22, formulaPaint);
        canvas.drawLine(
            Offset(x - 16, y + 30), Offset(x + 28, y + 30), formulaPaint);
      }
    }

    final glowPaint = Paint()
      ..color = KidsPalette.butter.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 44);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.82, size.height * 0.18),
        width: size.width * 0.28,
        height: size.height * 0.20,
      ),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Map<String, dynamic> _mapAt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  return const {};
}
