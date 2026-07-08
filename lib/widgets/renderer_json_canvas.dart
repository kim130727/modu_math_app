import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RendererJsonCanvas extends StatelessWidget {
  const RendererJsonCanvas({
    super.key,
    required this.renderer,
  });

  final Map<String, dynamic> renderer;

  @override
  Widget build(BuildContext context) {
    final viewBox = _mapAt(renderer, 'view_box');
    final width = _readDouble(viewBox['width']) ?? 928;
    final height = _readDouble(viewBox['height']) ?? 426;
    final background = _readColor(viewBox['background']) ?? Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: AspectRatio(
            aspectRatio: width / height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: CustomPaint(
                painter: RendererJsonPainter(
                  renderer: renderer,
                  logicalSize: Size(width, height),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class RendererJsonPainter extends CustomPainter {
  const RendererJsonPainter({
    required this.renderer,
    required this.logicalSize,
  });

  final Map<String, dynamic> renderer;
  final Size logicalSize;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / logicalSize.width)
        .clamp(0.0, size.height / logicalSize.height);
    final dx = (size.width - logicalSize.width * scale) / 2;
    final dy = (size.height - logicalSize.height * scale) / 2;

    canvas
      ..save()
      ..translate(dx, dy)
      ..scale(scale);

    final elements = renderer['elements'];
    if (elements is List) {
      for (final element in elements.whereType<Map<String, dynamic>>()) {
        _paintElement(canvas, element);
      }
    }

    canvas.restore();
  }

  void _paintElement(Canvas canvas, Map<String, dynamic> element) {
    final type = element['type']?.toString();
    final attributes = _mapAt(element, 'attributes');
    switch (type) {
      case 'circle':
        _paintCircle(canvas, attributes);
      case 'line':
        _paintLine(canvas, attributes);
      case 'rect':
        _paintRect(canvas, attributes);
      case 'text':
        _paintText(canvas, element, attributes);
    }
  }

  void _paintCircle(Canvas canvas, Map<String, dynamic> attributes) {
    final center = Offset(
      _readDouble(attributes['cx']) ?? 0,
      _readDouble(attributes['cy']) ?? 0,
    );
    final radius = _readDouble(attributes['r']) ?? 0;
    final fill = _readColor(attributes['fill']);
    final stroke = _readColor(attributes['stroke']) ?? Colors.black;
    final strokeWidth = _readDouble(attributes['stroke-width']) ?? 1;

    if (fill != null) {
      canvas.drawCircle(center, radius, Paint()..color = fill);
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  void _paintLine(Canvas canvas, Map<String, dynamic> attributes) {
    final start = Offset(
      _readDouble(attributes['x1']) ?? 0,
      _readDouble(attributes['y1']) ?? 0,
    );
    final end = Offset(
      _readDouble(attributes['x2']) ?? 0,
      _readDouble(attributes['y2']) ?? 0,
    );
    final paint = Paint()
      ..color = _readColor(attributes['stroke']) ?? Colors.black
      ..strokeWidth = _readDouble(attributes['stroke-width']) ?? 1
      ..strokeCap = StrokeCap.round;
    final dashArray = _readDashArray(attributes['stroke-dasharray']);
    if (dashArray == null) {
      canvas.drawLine(start, end, paint);
      return;
    }
    _drawDashedLine(canvas, start, end, paint, dashArray);
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    List<double> dashArray,
  ) {
    final vector = end - start;
    final distance = vector.distance;
    if (distance == 0) {
      return;
    }
    final direction = vector / distance;
    var travelled = 0.0;
    var dashIndex = 0;
    var draw = true;

    while (travelled < distance) {
      final segmentLength = dashArray[dashIndex % dashArray.length];
      final nextTravelled = (travelled + segmentLength).clamp(0.0, distance);
      if (draw) {
        canvas.drawLine(
          start + direction * travelled,
          start + direction * nextTravelled,
          paint,
        );
      }
      travelled = nextTravelled;
      dashIndex += 1;
      draw = !draw;
    }
  }

  void _paintRect(Canvas canvas, Map<String, dynamic> attributes) {
    final rect = Rect.fromLTWH(
      _readDouble(attributes['x']) ?? 0,
      _readDouble(attributes['y']) ?? 0,
      _readDouble(attributes['width']) ?? 0,
      _readDouble(attributes['height']) ?? 0,
    );
    final fill = _readColor(attributes['fill']);
    final stroke = _readColor(attributes['stroke']) ?? Colors.black;
    final strokeWidth = _readDouble(attributes['stroke-width']) ?? 1;

    if (fill != null) {
      canvas.drawRect(rect, Paint()..color = fill);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  void _paintText(
    Canvas canvas,
    Map<String, dynamic> element,
    Map<String, dynamic> attributes,
  ) {
    final text = element['text']?.toString() ?? '';
    final fontSize = _readDouble(attributes['font-size']) ?? 18;
    final fill = _readColor(attributes['fill']) ?? Colors.black;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.poorStory(
          color: fill,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
    )..layout(maxWidth: _readDouble(attributes['max_width']) ?? 860);

    painter.paint(
      canvas,
      Offset(
        _readDouble(attributes['x']) ?? 0,
        (_readDouble(attributes['y']) ?? 0) - fontSize,
      ),
    );
  }

  @override
  bool shouldRepaint(RendererJsonPainter oldDelegate) {
    return oldDelegate.renderer != renderer ||
        oldDelegate.logicalSize != logicalSize;
  }
}

Map<String, dynamic> _mapAt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  return const {};
}

double? _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

List<double>? _readDashArray(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  final values = text
      .split(RegExp(r'[\s,]+'))
      .map(double.tryParse)
      .whereType<double>()
      .where((item) => item > 0)
      .toList();
  if (values.isEmpty) {
    return null;
  }
  return values;
}

Color? _readColor(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text.isEmpty || text == 'none') {
    return null;
  }
  if (text.startsWith('#') && (text.length == 7 || text.length == 9)) {
    final hex = text.substring(1);
    final alpha = hex.length == 8 ? hex.substring(6, 8) : 'FF';
    final rgb = hex.length == 8 ? hex.substring(0, 6) : hex;
    return Color(int.parse('$alpha$rgb', radix: 16));
  }
  return null;
}
