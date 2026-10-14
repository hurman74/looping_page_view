# looping_page_view

A Flutter `PageView` that **loops**. Swipe forward from the last page to reach the first,
and back from the first to reach the last, for as long as you like.

Its controller speaks in real item indexes: `page` runs from `0.0` up to the item count and
wraps around, and `animateToPage(2)` takes the shortest way round. So page indicators and
other widgets that take a `PageController` keep working. You can also turn looping off and
on, or add and remove items, while the view is on screen.

## Install

```sh
flutter pub add looping_page_view
```

## Usage

```dart
import 'package:looping_page_view/looping_page_view.dart';

final controller = LoopingPageController(viewportFraction: 0.85);

LoopingPageView.builder(
  controller: controller,
  itemCount: photos.length,
  itemBuilder: (context, index) => PhotoCard(photos[index]),
  onPageChanged: (index) => setState(() => _current = index),
)
```

`itemBuilder` and `onPageChanged` always get an index from `0` to `itemCount - 1`.

### Moving with the controller

```dart
controller.nextPage(duration: duration, curve: Curves.easeOut); // last → first
controller.previousPage(duration: duration, curve: Curves.easeOut); // first → last

controller.animateToPage(7, duration: duration, curve: curve); // shortest way round
controller.animateToPage(
  7,
  duration: duration,
  curve: curve,
  direction: LoopDirection.forward, // or LoopDirection.backward
);
controller.jumpToPage(3);

controller.page; // e.g. 4.6 while moving from the last of 5 items to the first
controller.currentItem; // 0 in that case: always a valid index
```

### Page indicators

Because `controller.page` stays between `0` and the item count, an indicator that reads a
`PageController` works as is. Moving forward from the last item, `page` rises towards the item
count and then continues from `0.0`. An indicator that should glide from the last dot to the
first can treat the distance between dots as circular, as the example app does.

### Turning looping off

```dart
LoopingPageView.builder(
  loop: settings.loopCarousel,
  // ...
)
```

With `loop: false` the view behaves like a normal `PageView` with the same API. Changing `loop`
at runtime keeps the current item on screen. A view with fewer than two items never loops.

### Changing the items

Change `itemCount` whenever you like. The item on screen stays on screen; if it was removed,
the view shows the last remaining item. In a looping view, adding or removing items doesn't
interrupt a swipe or animation in progress.

### API at a glance

| Member | Purpose |
| --- | --- |
| `LoopingPageView.builder(itemCount, itemBuilder)` | Builds items lazily. |
| `LoopingPageView(children)` | Uses a fixed list of widgets. |
| `loop` | Turns looping on (default) or off. |
| `onPageChanged(index)` | Called when another item becomes the current one. |
| `LoopingPageController` | A `PageController` whose pages are item indexes. |
| `animateToPage(index, direction:)` | Picks the way round with `LoopDirection`. |
| `currentItem`, `itemCount`, `isLooping` | Read the view's state. |

The other `PageView` options (`scrollDirection`, `reverse`, `physics`, `pageSnapping`,
`padEnds`, `allowImplicitScrolling`, `clipBehavior`, `scrollBehavior`, `restorationId`,
`dragStartBehavior`) are passed through.

## Why this package

Flutter's `PageView` has no loop mode
([flutter/flutter#49537](https://github.com/flutter/flutter/issues/49537)). The usual
workaround is to leave out `itemCount`, start at a large `initialPage` and use
`index % length` everywhere. It works until you need any of the following:

- **Indicators and `onPageChanged`.** Both see the large page numbers, so every reader has to
  apply the same modulo.
- **`animateToPage`.** You have to work out which nearby large page shows the item you want,
  and which way round is shorter.
- **Swiping back from the first page.** With `initialPage: 0` there is nothing before it, so
  the trick needs a large start offset.
- **Changing the number of items.** The modulo changes, so the page on screen suddenly shows a
  different item.
- **Turning looping off.** You need a second, different widget setup.

This package does all of that bookkeeping once, inside a real `PageView`, so dragging,
snapping, physics and implicit scrolling behave as they do in Flutter's own widget.

Compared with existing loop packages, it reports item indexes from the controller itself (so
indicators that take a `PageController` work), keeps the item on screen when items are added
or removed, and can turn looping off.

## Limitations

- The loop is built from a very long run of real pages. A user can swipe backwards about a
  million pages from where the view started before reaching an end. Forwards there is no end.
- The attached `ScrollPosition` and the `PageMetrics` in scroll notifications use the internal
  page numbers. Read `controller.page` or `controller.currentItem` instead.
- Item state is tied to a page slot, as in `PageView`. Adding or removing items, or turning
  looping on or off, can rebuild the pages on screen with fresh state. Keep state that must
  survive this outside the pages.
- In a looping view the same item can be built more than once at the same time, for example
  with two items and a small `viewportFraction`. Don't give items `GlobalKey`s.
- Use one `LoopingPageController` per view at a time.
- When you replace the view's controller, the new controller takes over the current scroll
  offset, as with `PageView`. Its `initialPage` is not applied.

## License

MIT
