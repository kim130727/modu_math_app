import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modu_math_app/widgets/renderer_json_canvas.dart';

void main() {
  testWidgets('renders text_box elements from renderer json', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 220,
            child: RendererJsonCanvas(
              renderer: {
                'view_box': {
                  'width': 500,
                  'height': 220,
                  'background': '#FFFFFF',
                },
                'elements': [
                  {
                    'type': 'text_box',
                    'attributes': {
                      'x': 20,
                      'y': 20,
                      'width': 460,
                      'height': 120,
                      'fill': '#202124',
                      'font-size': 24,
                      'data-text-align': 'left',
                      'data-vertical-align': 'top',
                      'data-line-height': 1.45,
                    },
                    'text': 'problem text',
                  },
                ],
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byType(RendererJsonCanvas), findsOneWidget);
    expect(find.text('problem text'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
