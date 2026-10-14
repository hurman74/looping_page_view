import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:looping_page_view/looping_page_view.dart';

/// Tests for changes that move the scroll offset while the widget builds:
/// turning looping on or off.
void main() {
  late LoopingPageController controller;
  late List<int> reported;

  setUp(() {
    controller = LoopingPageController(initialPage: 1);
    reported = <int>[];
  });

  tearDown(() => controller.dispose());

  Widget build(int count, {required bool loop}) => Directionality(
    textDirection: TextDirection.ltr,
    child: LoopingPageView.builder(
      itemCount: count,
      loop: loop,
      controller: controller,
      itemBuilder: (context, index) => Text('item $index'),
      onPageChanged: reported.add,
    ),
  );

  testWidgets('turning looping on lays out at the new offset at once', (
    tester,
  ) async {
    await tester.pumpWidget(build(6, loop: false));
    expect(controller.position.maxScrollExtent, 5 * 800.0);

    await tester.pumpWidget(build(6, loop: true));
    expect(controller.position.maxScrollExtent, double.infinity);
    expect(controller.page, 1.0);
    expect(find.text('item 1'), findsOneWidget);

    await tester.drag(find.byType(LoopingPageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(controller.page, 2.0);
    expect(reported, [2]);
  });

  testWidgets('turning looping off lays out at the new offset at once', (
    tester,
  ) async {
    await tester.pumpWidget(build(6, loop: true));
    await tester.pumpWidget(build(6, loop: false));
    expect(controller.position.pixels, 800.0);
    expect(controller.position.maxScrollExtent, 5 * 800.0);
    expect(controller.page, 1.0);

    await tester.drag(find.byType(LoopingPageView), const Offset(500, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(LoopingPageView), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(controller.page, 0.0);
    expect(reported, [0]);
  });

  testWidgets('toggling repeatedly keeps the item on screen', (tester) async {
    await tester.pumpWidget(build(6, loop: true));
    for (var i = 0; i < 4; i++) {
      await tester.pumpWidget(build(6, loop: i.isOdd));
      expect(controller.page, 1.0);
      expect(find.text('item 1'), findsOneWidget);
    }
    expect(reported, isEmpty);
  });

  testWidgets('a listener on the controller can rebuild during a toggle', (
    tester,
  ) async {
    var loop = true;
    late StateSetter setOuterState;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StatefulBuilder(
          builder: (context, setState) {
            setOuterState = setState;
            return Column(
              children: [
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final int? item = controller.hasClients
                        ? controller.currentItem
                        : null;
                    return Text('indicator $item');
                  },
                ),
                Expanded(
                  child: LoopingPageView.builder(
                    itemCount: 4,
                    loop: loop,
                    controller: controller,
                    itemBuilder: (context, index) => Text('item $index'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    setOuterState(() => loop = false);
    await tester.pump();
    expect(tester.takeException(), isNull);
    setOuterState(() => loop = true);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('item 1'), findsOneWidget);

    await tester.drag(find.byType(LoopingPageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('indicator 2'), findsOneWidget);
  });
}
