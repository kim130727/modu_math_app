import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../utils/problem_text_sanitizer.dart';

class ProblemSvgViewer extends StatelessWidget {
  const ProblemSvgViewer({super.key, required this.svg});

  final String svg;

  @override
  Widget build(BuildContext context) {
    final displaySvg = sanitizeProblemText(svg);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE3EA)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return InteractiveViewer(
              minScale: 0.6,
              maxScale: 4,
              boundaryMargin: const EdgeInsets.all(80),
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: SvgPicture.string(displaySvg, fit: BoxFit.contain),
              ),
            );
          },
        ),
      ),
    );
  }
}
