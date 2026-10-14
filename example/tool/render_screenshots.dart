// Renders the README GIF into ../doc/. Run from the example directory:
//
//   flutter test tool/render_screenshots.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:looping_page_view_example/main.dart';

import 'readme_shots.dart';

void main() {
  setUpAll(loadShotFonts);

  testWidgets('demo gif', (WidgetTester tester) async {
    final GlobalKey boundary = await pumpShot(
      tester,
      const Size(400, 740),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          caption(
            'Next on the last card loops to the first',
            detail: 'The dots and the index follow the wrap.',
          ),
          phone(const CarouselPage(), height: 600),
        ],
      ),
    );
    final GifRecorder gif = GifRecorder(tester, boundary);

    await gif.frame(80);
    // Cards 1 → 5, then past the last card back to 1 and on to 2.
    for (int step = 0; step < 6; step++) {
      await tester.tap(find.byTooltip('Next'));
      for (int t = 0; t < 8; t++) {
        await tester.pump(const Duration(milliseconds: 50));
        await gif.frame(5);
      }
      await tester.pumpAndSettle();
      // Linger on the wrap from 5 to 1.
      await gif.frame(step == 4 ? 150 : 60);
    }
    gif.save('demo.gif');
  });
}
