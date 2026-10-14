import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:looping_page_view_example/main.dart';

void main() {
  testWidgets('swiping back from the first card shows the last', (
    tester,
  ) async {
    await tester.pumpWidget(const LoopingPageViewExample());
    expect(find.text('Card 1 of 5'), findsOneWidget);

    await tester.drag(find.text('1'), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Card 5 of 5'), findsOneWidget);

    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Card 1 of 5'), findsOneWidget);
  });

  testWidgets('cards can be added and looping turned off', (tester) async {
    await tester.pumpWidget(const LoopingPageViewExample());

    await tester.tap(find.text('Add card'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('Card 1 of 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
