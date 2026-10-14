import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:looping_page_view/looping_page_view.dart';

const Duration _duration = Duration(milliseconds: 300);

Widget _item(BuildContext context, int index) =>
    SizedBox.expand(child: Center(child: Text('item $index')));

Widget _view({
  required int itemCount,
  LoopingPageController? controller,
  bool loop = true,
  ValueChanged<int>? onPageChanged,
  Axis scrollDirection = Axis.horizontal,
  bool reverse = false,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: LoopingPageView.builder(
      itemCount: itemCount,
      itemBuilder: _item,
      controller: controller,
      loop: loop,
      onPageChanged: onPageChanged,
      scrollDirection: scrollDirection,
      reverse: reverse,
    ),
  );
}

/// Swipes one page towards higher indexes.
Future<void> _swipeForward(WidgetTester tester) async {
  await tester.drag(find.byType(LoopingPageView), const Offset(-500, 0));
  await tester.pumpAndSettle();
}

/// Swipes one page towards lower indexes.
Future<void> _swipeBack(WidgetTester tester) async {
  await tester.drag(find.byType(LoopingPageView), const Offset(500, 0));
  await tester.pumpAndSettle();
}

void main() {
  group('looping', () {
    testWidgets('starts at the initial item', (tester) async {
      final controller = LoopingPageController(initialPage: 2);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 5, controller: controller));

      expect(find.text('item 2'), findsOneWidget);
      expect(controller.page, 2.0);
      expect(controller.currentItem, 2);
      expect(controller.initialPage, 2);
      expect(controller.itemCount, 5);
      expect(controller.isLooping, isTrue);
    });

    testWidgets('swiping back from the first item shows the last', (
      tester,
    ) async {
      final controller = LoopingPageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 5, controller: controller));

      await _swipeBack(tester);
      expect(find.text('item 4'), findsOneWidget);
      expect(controller.page, 4.0);

      await _swipeBack(tester);
      expect(find.text('item 3'), findsOneWidget);
      expect(controller.page, 3.0);
    });

    testWidgets('swiping forward from the last item shows the first', (
      tester,
    ) async {
      final controller = LoopingPageController(initialPage: 4);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 5, controller: controller));

      await _swipeForward(tester);
      expect(find.text('item 0'), findsOneWidget);
      expect(controller.page, 0.0);
    });

    testWidgets('loops many times in both directions', (tester) async {
      final controller = LoopingPageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 3, controller: controller));

      for (var i = 1; i <= 7; i++) {
        await _swipeForward(tester);
        expect(controller.currentItem, i % 3);
      }
      for (var i = 6; i >= -7; i--) {
        await _swipeBack(tester);
        expect(controller.currentItem, i % 3);
        expect(find.text('item ${i % 3}'), findsOneWidget);
      }
    });

    testWidgets('page stays in range while dragging across the wrap', (
      tester,
    ) async {
      final controller = LoopingPageController(initialPage: 4);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 5, controller: controller));

      final pages = <double>[];
      controller.addListener(() => pages.add(controller.page!));
      final gesture = await tester.startGesture(const Offset(400, 300));
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(-50, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(pages, isNotEmpty);
      for (final page in pages) {
        expect(page, greaterThanOrEqualTo(0.0));
        expect(page, lessThan(5.0));
      }
      // The drag went from item 4 into item 0.
      expect(pages.any((page) => page > 4.0), isTrue);
      expect(pages.any((page) => page < 1.0), isTrue);
      expect(controller.currentItem, 0);
    });

    testWidgets('currentItem wraps when page is nearly itemCount', (
      tester,
    ) async {
      final controller = LoopingPageController(initialPage: 4);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 5, controller: controller));

      final gesture = await tester.startGesture(const Offset(400, 300));
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-600, 0));
      await tester.pump();
      expect(controller.page, inExclusiveRange(4.5, 5.0));
      expect(controller.currentItem, 0);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('shows neighbours on both sides of the first item', (
      tester,
    ) async {
      final controller = LoopingPageController(viewportFraction: 0.5);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 5, controller: controller));

      final double first = tester.getCenter(find.text('item 0')).dx;
      final double last = tester.getCenter(find.text('item 4')).dx;
      final double second = tester.getCenter(find.text('item 1')).dx;
      expect(first, 400.0);
      expect(last, 0.0);
      expect(second, 800.0);
    });

    testWidgets('can show the same item twice', (tester) async {
      final controller = LoopingPageController(viewportFraction: 0.25);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 2, controller: controller));

      expect(find.text('item 0'), findsWidgets);
      expect(find.text('item 1'), findsWidgets);
      expect(
        tester.widgetList(find.text('item 0')).length +
            tester.widgetList(find.text('item 1')).length,
        greaterThanOrEqualTo(4),
      );
    });

    testWidgets('loops vertically and in reverse', (tester) async {
      final controller = LoopingPageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _view(
          itemCount: 4,
          controller: controller,
          scrollDirection: Axis.vertical,
          reverse: true,
        ),
      );

      // Dragging up moves a reversed vertical view back by one page.
      await tester.drag(find.byType(LoopingPageView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(controller.currentItem, 3);
      expect(find.text('item 3'), findsOneWidget);
    });
  });

  group('without looping', () {
    testWidgets('stops at both ends when loop is false', (tester) async {
      final controller = LoopingPageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _view(itemCount: 3, controller: controller, loop: false),
      );
      expect(controller.isLooping, isFalse);

      await _swipeBack(tester);
      expect(controller.page, 0.0);
      expect(find.text('item 0'), findsOneWidget);

      await _swipeForward(tester);
      await _swipeForward(tester);
      await _swipeForward(tester);
      expect(controller.page, 2.0);
      expect(find.text('item 2'), findsOneWidget);
    });

    testWidgets('a single item does not loop', (tester) async {
      final controller = LoopingPageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 1, controller: controller));
      expect(controller.isLooping, isFalse);

      await _swipeBack(tester);
      await _swipeForward(tester);
      expect(controller.page, 0.0);
      expect(find.text('item 0'), findsOneWidget);
    });

    testWidgets('no items builds nothing', (tester) async {
      final controller = LoopingPageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 0, controller: controller));

      expect(find.byType(Text), findsNothing);
      expect(controller.isLooping, isFalse);
      expect(controller.currentItem, 0);
      await _swipeForward(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clamps an initial page that is out of range', (tester) async {
      final controller = LoopingPageController(initialPage: 9);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _view(itemCount: 3, controller: controller, loop: false),
      );
      expect(find.text('item 2'), findsOneWidget);
      expect(controller.page, 2.0);
    });
  });

  group('controller', () {
    testWidgets('wraps an initial page that is out of range', (tester) async {
      final controller = LoopingPageController(initialPage: 7);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 5, controller: controller));
      expect(find.text('item 2'), findsOneWidget);
      expect(controller.page, 2.0);
    });

    testWidgets('nextPage and previousPage wrap around', (tester) async {
      final controller = LoopingPageController(initialPage: 2);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 3, controller: controller));

      controller.nextPage(duration: _duration, curve: Curves.linear);
      await tester.pumpAndSettle();
      expect(controller.page, 0.0);
      expect(find.text('item 0'), findsOneWidget);

      controller.previousPage(duration: _duration, curve: Curves.linear);
      await tester.pumpAndSettle();
      controller.previousPage(duration: _duration, curve: Curves.linear);
      await tester.pumpAndSettle();
      expect(controller.page, 1.0);
    });

    testWidgets('nextPage moves forward with two items', (tester) async {
      final controller = LoopingPageController(initialPage: 1);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 2, controller: controller));

      final double before = controller.position.pixels;
      controller.nextPage(duration: _duration, curve: Curves.linear);
      await tester.pumpAndSettle();
      expect(controller.position.pixels, before + 800.0);
      expect(controller.page, 0.0);
    });

    testWidgets('nextPage stops at the end without looping', (tester) async {
      final controller = LoopingPageController(initialPage: 2);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _view(itemCount: 3, controller: controller, loop: false),
      );

      controller.nextPage(duration: _duration, curve: Curves.linear);
      await tester.pumpAndSettle();
      expect(controller.page, 2.0);
    });

    testWidgets('animateToPage takes the shortest way by default', (
      tester,
    ) async {
      final controller = LoopingPageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 10, controller: controller));

      final double start = controller.position.pixels;
      controller.animateToPage(9, duration: _duration, curve: Curves.linear);
      await tester.pumpAndSettle();
      expect(controller.page, 9.0);
      expect(controller.position.pixels, start - 800.0);

      controller.animateToPage(3, duration: _duration, curve: Curves.linear);
      await tester.pumpAndSettle();
      expect(controller.page, 3.0);
      expect(controller.position.pixels, start + 3 * 800.0);
    });

    testWidgets('animateToPage goes forward on a tie', (tester) async {
      final controller = LoopingPageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 4, controller: controller));

      final double start = controller.position.pixels;
      controller.animateToPage(2, duration: _duration, curve: Curves.linear);
      await tester.pumpAndSettle();
      expect(controller.position.pixels, start + 2 * 800.0);
    });

    testWidgets('animateToPage follows an explicit direction', (tester) async {
      final controller = LoopingPageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 10, controller: controller));

      final double start = controller.position.pixels;
      controller.animateToPage(
        9,
        duration: _duration,
        curve: Curves.linear,
        direction: LoopDirection.forward,
      );
      await tester.pumpAndSettle();
      expect(controller.page, 9.0);
      expect(controller.position.pixels, start + 9 * 800.0);

      controller.animateToPage(
        1,
        duration: _duration,
        curve: Curves.linear,
        direction: LoopDirection.backward,
      );
      await tester.pumpAndSettle();
      expect(controller.page, 1.0);
      expect(controller.position.pixels, start + 1 * 800.0);

      controller.animateToPage(
        1,
        duration: _duration,
        curve: Curves.linear,
        direction: LoopDirection.backward,
      );
      await tester.pumpAndSettle();
      expect(controller.position.pixels, start + 1 * 800.0);
    });

    testWidgets('animateToPage wraps indexes beyond the item count', (
      tester,
    ) async {
      final controller = LoopingPageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 5, controller: controller));

      controller.animateToPage(12, duration: _duration, curve: Curves.linear);
      await tester.pumpAndSettle();
      expect(controller.page, 2.0);

      controller.animateToPage(-1, duration: _duration, curve: Curves.linear);
      await tester.pumpAndSettle();
      expect(controller.page, 4.0);
    });

    testWidgets('jumpToPage shows the item', (tester) async {
      final controller = LoopingPageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 10, controller: controller));

      controller.jumpToPage(13);
      await tester.pump();
      expect(controller.page, 3.0);
      expect(find.text('item 3'), findsOneWidget);
    });

    testWidgets('jumpToPage works without looping', (tester) async {
      final controller = LoopingPageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _view(itemCount: 10, controller: controller, loop: false),
      );

      controller.jumpToPage(7);
      await tester.pump();
      expect(controller.page, 7.0);
      expect(controller.position.pixels, 7 * 800.0);
    });

    testWidgets('notifies listeners with item positions', (tester) async {
      final controller = LoopingPageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 3, controller: controller));

      final pages = <double>[];
      controller.addListener(() => pages.add(controller.page!));
      controller.previousPage(duration: _duration, curve: Curves.linear);
      await tester.pumpAndSettle();
      expect(pages.first, greaterThan(2.0));
      expect(pages.last, 2.0);
    });
  });

  group('onPageChanged', () {
    testWidgets('reports item indexes across the wrap', (tester) async {
      final reported = <int>[];
      await tester.pumpWidget(_view(itemCount: 3, onPageChanged: reported.add));

      await _swipeBack(tester);
      await _swipeBack(tester);
      await _swipeForward(tester);
      await _swipeForward(tester);
      await _swipeForward(tester);
      expect(reported, [2, 1, 2, 0, 1]);
    });

    testWidgets('is not called by a change in item count or loop', (
      tester,
    ) async {
      final reported = <int>[];
      final controller = LoopingPageController(initialPage: 1);
      addTearDown(controller.dispose);
      Widget build(int count, bool loop) => _view(
        itemCount: count,
        controller: controller,
        loop: loop,
        onPageChanged: reported.add,
      );
      await tester.pumpWidget(build(4, true));

      await tester.pumpWidget(build(6, true));
      await tester.pumpWidget(build(6, false));
      await tester.pumpWidget(build(6, true));
      await _swipeForward(tester);
      await _swipeForward(tester);
      expect(reported, [2, 3]);
    });

    testWidgets('reports once per item when a swipe settles', (tester) async {
      final reported = <int>[];
      await tester.pumpWidget(_view(itemCount: 4, onPageChanged: reported.add));

      await _swipeBack(tester);
      expect(reported, [3]);
    });
  });

  group('changing items', () {
    testWidgets('adding items keeps the current item on screen', (
      tester,
    ) async {
      final controller = LoopingPageController(initialPage: 2);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 5, controller: controller));

      await tester.pumpWidget(_view(itemCount: 8, controller: controller));
      expect(find.text('item 2'), findsOneWidget);
      expect(controller.page, 2.0);
      expect(controller.itemCount, 8);

      controller.jumpToPage(0);
      await tester.pump();
      await _swipeBack(tester);
      expect(find.text('item 7'), findsOneWidget);
      expect(controller.page, 7.0);
    });

    testWidgets('removing the current item shows the last remaining item', (
      tester,
    ) async {
      final controller = LoopingPageController(initialPage: 4);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 5, controller: controller));

      await tester.pumpWidget(_view(itemCount: 3, controller: controller));
      expect(find.text('item 2'), findsOneWidget);
      expect(controller.page, 2.0);

      await _swipeForward(tester);
      expect(find.text('item 0'), findsOneWidget);
    });

    testWidgets('removing items without looping clamps the page', (
      tester,
    ) async {
      final controller = LoopingPageController(initialPage: 4);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _view(itemCount: 5, controller: controller, loop: false),
      );

      await tester.pumpWidget(
        _view(itemCount: 2, controller: controller, loop: false),
      );
      expect(find.text('item 1'), findsOneWidget);
      expect(controller.page, 1.0);
    });

    testWidgets('going down to one item and back up', (tester) async {
      final controller = LoopingPageController(initialPage: 3);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 5, controller: controller));

      await tester.pumpWidget(_view(itemCount: 1, controller: controller));
      expect(controller.isLooping, isFalse);
      expect(find.text('item 0'), findsOneWidget);
      expect(controller.page, 0.0);

      await tester.pumpWidget(_view(itemCount: 4, controller: controller));
      expect(controller.isLooping, isTrue);
      expect(find.text('item 0'), findsOneWidget);
      await _swipeBack(tester);
      expect(find.text('item 3'), findsOneWidget);
    });

    testWidgets('changing the count during an animation keeps going', (
      tester,
    ) async {
      final controller = LoopingPageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 5, controller: controller));

      controller.nextPage(duration: _duration, curve: Curves.linear);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_view(itemCount: 6, controller: controller));
      await tester.pumpAndSettle();
      expect(controller.page, 1.0);
      expect(find.text('item 1'), findsOneWidget);
    });

    testWidgets('turning looping off and on keeps the current item', (
      tester,
    ) async {
      final controller = LoopingPageController(initialPage: 3);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 5, controller: controller));
      await _swipeForward(tester);
      await _swipeForward(tester);
      expect(controller.page, 0.0);

      await tester.pumpWidget(
        _view(itemCount: 5, controller: controller, loop: false),
      );
      expect(controller.isLooping, isFalse);
      expect(find.text('item 0'), findsOneWidget);
      expect(controller.position.pixels, 0.0);
      await _swipeBack(tester);
      expect(controller.page, 0.0);
      await _swipeForward(tester);
      await _swipeForward(tester);
      expect(controller.page, 2.0);

      await tester.pumpWidget(_view(itemCount: 5, controller: controller));
      expect(controller.isLooping, isTrue);
      expect(controller.page, 2.0);
      expect(find.text('item 2'), findsOneWidget);
      controller.jumpToPage(0);
      await tester.pump();
      await _swipeBack(tester);
      expect(find.text('item 4'), findsOneWidget);
    });

    testWidgets('turning looping off during an animation settles on a page', (
      tester,
    ) async {
      final controller = LoopingPageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(itemCount: 5, controller: controller));

      controller.animateToPage(2, duration: _duration, curve: Curves.linear);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(
        _view(itemCount: 5, controller: controller, loop: false),
      );
      await tester.pumpAndSettle();
      final double page = controller.page!;
      expect(page, page.roundToDouble());
      expect(page, inInclusiveRange(0.0, 4.0));
    });
  });

  group('widget', () {
    testWidgets('children constructor', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LoopingPageView(
            children: const [Text('a'), Text('b'), Text('c')],
          ),
        ),
      );
      expect(find.text('a'), findsOneWidget);
      await _swipeBack(tester);
      expect(find.text('c'), findsOneWidget);
    });

    testWidgets('works without a controller', (tester) async {
      await tester.pumpWidget(_view(itemCount: 3));
      await _swipeBack(tester);
      expect(find.text('item 2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('switching controllers keeps the item on screen', (
      tester,
    ) async {
      final first = LoopingPageController(initialPage: 1);
      final second = LoopingPageController(initialPage: 3);
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      await tester.pumpWidget(_view(itemCount: 5, controller: first));
      expect(find.text('item 1'), findsOneWidget);

      // Like PageView, the new controller takes over the current offset.
      await tester.pumpWidget(_view(itemCount: 5, controller: second));
      expect(find.text('item 1'), findsOneWidget);
      expect(second.page, 1.0);
      expect(first.hasClients, isFalse);

      for (var i = 0; i < 4; i++) {
        await _swipeForward(tester);
      }
      expect(second.page, 0.0);

      await tester.pumpWidget(_view(itemCount: 5));
      expect(tester.takeException(), isNull);
    });
  });
}
