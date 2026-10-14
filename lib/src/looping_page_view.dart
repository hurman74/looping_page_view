import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// How many pages a looping view can travel backwards from where it starts.
///
/// A looping view is an ordinary [PageView] with no last page, whose first
/// item sits this far from the real start of the scrollable. A user would
/// have to swipe back about a million times to reach that start.
const int _kBackwardPages = 1 << 20;

/// Which way round the loop [LoopingPageController.animateToPage] travels.
enum LoopDirection {
  /// Take the shorter way round. When both ways are equally long, go forward.
  shortest,

  /// Always move forward, from the last item on to the first if needed.
  forward,

  /// Always move backward, from the first item on to the last if needed.
  backward,
}

/// A [PageController] for a [LoopingPageView].
///
/// Every page number this controller takes or returns is an item index
/// between zero and the view's item count: [page] goes from `0.0` up to (but
/// not including) `itemCount` and then starts again at `0.0`, and
/// [animateToPage] and [jumpToPage] take the index of an item. Widgets that
/// take a [PageController], such as page indicators, work unchanged.
///
/// Internally the view scrolls through an unbounded run of pages. The
/// attached [position] and the [PageMetrics] in scroll notifications use
/// those internal page numbers, so read [page] or [currentItem] instead.
///
/// Use one controller for one [LoopingPageView] at a time.
class LoopingPageController extends PageController {
  /// Creates a controller for a [LoopingPageView].
  ///
  /// [initialPage] is the index of the item to show first. In a looping view
  /// it wraps around the item count; otherwise it is clamped to the items.
  LoopingPageController({
    super.initialPage,
    super.keepPage,
    super.viewportFraction,
    super.onAttach,
    super.onDetach,
  });

  /// The item index passed to the constructor as `initialPage`.
  int get _initialItem => super.initialPage;

  bool _configured = false;
  int _itemCount = 0;
  bool _looping = false;

  /// The internal page that shows item 0, or any page that is a whole number
  /// of loops away from it.
  int _origin = 0;

  /// Set while [PageController.createScrollPosition] reads [initialPage].
  bool _creatingPosition = false;

  /// Increases each time [_configure] moves the scroll offset.
  ///
  /// Moving the offset during build doesn't schedule a layout, and notifying
  /// listeners during build isn't allowed. The view keys its pages with this
  /// number instead, so a new value replaces them and the viewport lays out
  /// again at the new offset.
  int _offsetGeneration = 0;

  /// The index of the item shown first, as passed to the constructor.
  @override
  int get initialPage =>
      _creatingPosition ? _origin + _clampItem(_initialItem) : _initialItem;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    _creatingPosition = true;
    try {
      return super.createScrollPosition(physics, context, oldPosition);
    } finally {
      _creatingPosition = false;
    }
  }

  /// The number of items in the [LoopingPageView] using this controller.
  ///
  /// Zero until a view has been built with this controller.
  int get itemCount => _itemCount;

  /// Whether the view using this controller currently loops.
  ///
  /// This is false when [LoopingPageView.loop] is false, and also when the
  /// view has fewer than two items.
  bool get isLooping => _looping;

  /// The current item position, including the fraction of a page scrolled.
  ///
  /// In a looping view this is at least `0.0` and less than [itemCount].
  /// Moving forward from the last item, it rises towards [itemCount] and then
  /// continues from `0.0`. In a view that doesn't loop it is the same as
  /// [PageController.page].
  ///
  /// Like [PageController.page], this can only be read while the controller
  /// is attached to exactly one view.
  @override
  double? get page {
    final double? raw = super.page;
    if (raw == null || !_looping) {
      return raw;
    }
    return (raw - _origin) % _itemCount;
  }

  /// The index of the item nearest to the resting position, or null if the
  /// view has not been laid out yet.
  ///
  /// Unlike rounding [page], this always gives a valid index: rounding
  /// `itemCount - 0.3` gives item `0`, not `itemCount`.
  int? get currentItem {
    final double? raw = super.page;
    return raw == null ? null : _itemAt(raw.round());
  }

  /// Animates to the item at index [page].
  ///
  /// In a looping view, [page] is taken modulo [itemCount] and [direction]
  /// decides which way round the loop to travel. In a view that doesn't loop,
  /// this behaves like [PageController.animateToPage] and [direction] is
  /// ignored.
  @override
  Future<void> animateToPage(
    int page, {
    required Duration duration,
    required Curve curve,
    LoopDirection direction = LoopDirection.shortest,
  }) {
    return super.animateToPage(
      _looping ? _rawPageFor(page, direction) : page,
      duration: duration,
      curve: curve,
    );
  }

  /// Jumps to the item at index [page], without animation.
  ///
  /// In a looping view, [page] is taken modulo [itemCount].
  @override
  void jumpToPage(int page) {
    super.jumpToPage(
      _looping ? _rawPageFor(page, LoopDirection.shortest) : page,
    );
  }

  /// Animates to the next item. In a looping view, the item after the last
  /// one is the first one.
  @override
  Future<void> nextPage({required Duration duration, required Curve curve}) {
    if (!_looping) {
      return super.nextPage(duration: duration, curve: curve);
    }
    return super.animateToPage(
      _currentRawPage + 1,
      duration: duration,
      curve: curve,
    );
  }

  /// Animates to the previous item. In a looping view, the item before the
  /// first one is the last one.
  @override
  Future<void> previousPage({
    required Duration duration,
    required Curve curve,
  }) {
    if (!_looping) {
      return super.previousPage(duration: duration, curve: curve);
    }
    return super.animateToPage(
      _currentRawPage - 1,
      duration: duration,
      curve: curve,
    );
  }

  /// The nearest internal page, or the starting page before the first layout.
  int get _currentRawPage =>
      super.page?.round() ?? _origin + _clampItem(_initialItem);

  /// The internal page to travel to in order to show [item].
  int _rawPageFor(int item, LoopDirection direction) {
    final int from = _currentRawPage;
    final int ahead = (item - _itemAt(from)) % _itemCount;
    final int delta = switch (direction) {
      LoopDirection.forward => ahead,
      LoopDirection.backward => ahead == 0 ? 0 : ahead - _itemCount,
      LoopDirection.shortest =>
        ahead * 2 <= _itemCount ? ahead : ahead - _itemCount,
    };
    return from + delta;
  }

  /// The item shown on the internal page [rawPage].
  int _itemAt(int rawPage) {
    if (_looping) {
      return (rawPage - _origin) % _itemCount;
    }
    return _itemCount == 0 ? 0 : rawPage.clamp(0, _itemCount - 1);
  }

  int _clampItem(int item) {
    if (_itemCount == 0) {
      return 0;
    }
    return _looping ? item % _itemCount : item.clamp(0, _itemCount - 1);
  }

  /// The item to treat as current: the one on screen, or the initial one.
  ///
  /// Only valid while no offset correction is waiting for layout, since
  /// [PageController.page] clamps to the scroll extent of the last layout.
  int get _visibleItem {
    if (_hasLaidOutPosition) {
      return _itemAt(super.page!.round());
    }
    return _clampItem(_initialItem);
  }

  bool get _hasLaidOutPosition =>
      positions.length == 1 &&
      positions.single.hasPixels &&
      positions.single.hasViewportDimension;

  /// Applies the item count and looping mode of the view being built.
  ///
  /// The item on screen stays on screen; if it no longer exists, the last
  /// item is shown instead. Returns the current item if anything changed,
  /// or null otherwise.
  int? _configure({required int itemCount, required bool loop}) {
    final bool looping = loop && itemCount > 1;
    if (_configured && itemCount == _itemCount && looping == _looping) {
      return null;
    }
    if (!_configured || !_hasLaidOutPosition) {
      _configured = true;
      _itemCount = itemCount;
      _looping = looping;
      _origin = looping ? _loopOrigin(itemCount) : 0;
      return _clampItem(_initialItem);
    }

    final ScrollPosition position = positions.single;
    final int from = super.page!.round();
    final int item = math.min(_itemAt(from), math.max(itemCount - 1, 0));
    final bool wasLooping = _looping;
    _itemCount = itemCount;
    _looping = looping;
    if (looping && wasLooping) {
      // Re-anchor the loop so that the current page keeps showing [item].
      // The scroll offset doesn't change, so a drag or animation in progress
      // carries on undisturbed.
      _origin = from - item;
      return item;
    }

    _origin = looping ? _loopOrigin(itemCount) : 0;
    final int to = _origin + item;
    if (to != from) {
      final double pageExtent = position.viewportDimension * viewportFraction;
      position.correctPixels(position.pixels + (to - from) * pageExtent);
      _offsetGeneration++;
      if (position.isScrollingNotifier.value &&
          position is ScrollPositionWithSingleContext) {
        // An animation in progress is heading for an offset that is now
        // meaningless. Settle on the nearest page instead.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (positions.contains(position)) {
            position.goBallistic(0.0);
          }
        });
      }
    }
    return item;
  }

  /// A page far from the start, chosen so that internal page numbers modulo
  /// [itemCount] equal item indexes, at least until the item count changes.
  static int _loopOrigin(int itemCount) =>
      (_kBackwardPages + itemCount - 1) ~/ itemCount * itemCount;
}

/// A [PageView] that loops: swiping forward from the last item shows the
/// first one, and swiping back from the first item shows the last one.
///
/// Items are built lazily with [itemBuilder], which always receives an index
/// between zero and [itemCount]. Set [loop] to false to get a bounded page
/// view with the same API, for example when the user turns looping off.
///
/// With fewer than two items the view doesn't loop, since there is nothing
/// to loop through.
///
/// Control the view with a [LoopingPageController]. Its page numbers are
/// item indexes, so it also works with widgets that read a [PageController],
/// such as page indicators.
///
/// When [itemCount] changes, the item on screen stays on screen. If it was
/// removed, the view shows the last remaining item.
class LoopingPageView extends StatefulWidget {
  /// Creates a looping page view whose items are built on demand.
  const LoopingPageView.builder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.loop = true,
    this.onPageChanged,
    this.scrollDirection = Axis.horizontal,
    this.reverse = false,
    this.physics,
    this.pageSnapping = true,
    this.dragStartBehavior = DragStartBehavior.start,
    this.allowImplicitScrolling = false,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.scrollBehavior,
    this.padEnds = true,
  }) : assert(itemCount >= 0);

  /// Creates a looping page view from a fixed list of widgets.
  ///
  /// When several pages are visible at once and there are only a few items,
  /// the same child can appear in more than one place, so the children must
  /// not use [GlobalKey]s. Use [LoopingPageView.builder] in that case.
  LoopingPageView({
    super.key,
    required List<Widget> children,
    this.controller,
    this.loop = true,
    this.onPageChanged,
    this.scrollDirection = Axis.horizontal,
    this.reverse = false,
    this.physics,
    this.pageSnapping = true,
    this.dragStartBehavior = DragStartBehavior.start,
    this.allowImplicitScrolling = false,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.scrollBehavior,
    this.padEnds = true,
  }) : itemCount = children.length,
       itemBuilder = ((BuildContext context, int index) => children[index]);

  /// The number of items. Can be zero.
  final int itemCount;

  /// Builds the item at an index from zero to [itemCount] minus one.
  ///
  /// In a looping view the same index can be built for more than one page,
  /// for example when [PageController.viewportFraction] is small enough to
  /// show the same item twice.
  final IndexedWidgetBuilder itemBuilder;

  /// Controls which item is shown. If null, the view creates its own.
  final LoopingPageController? controller;

  /// Whether swiping past either end continues at the other end.
  ///
  /// Can be changed at any time; the item on screen stays on screen.
  final bool loop;

  /// Called with the index of the item that becomes the current item.
  ///
  /// Like [PageView.onPageChanged], this runs while scrolling, as soon as
  /// another item is nearest to the resting position. It is not called when
  /// a change to [itemCount] or [loop] changes the item on screen.
  final ValueChanged<int>? onPageChanged;

  /// The axis along which the pages scroll. See [PageView.scrollDirection].
  final Axis scrollDirection;

  /// Whether pages go in the reading direction's opposite.
  /// See [PageView.reverse].
  final bool reverse;

  /// How the view responds to user input. See [PageView.physics].
  final ScrollPhysics? physics;

  /// Whether each scroll settles on a whole page. See [PageView.pageSnapping].
  final bool pageSnapping;

  /// When a drag starts. See [PageView.dragStartBehavior].
  final DragStartBehavior dragStartBehavior;

  /// Whether screen readers can move to the neighbouring pages.
  /// See [PageView.allowImplicitScrolling].
  final bool allowImplicitScrolling;

  /// Restoration ID for the scroll offset. See [PageView.restorationId].
  final String? restorationId;

  /// How to clip the pages. See [PageView.clipBehavior].
  final Clip clipBehavior;

  /// Scroll behavior overrides. See [PageView.scrollBehavior].
  final ScrollBehavior? scrollBehavior;

  /// Whether the first and last pages are centred when
  /// [PageController.viewportFraction] is less than one.
  ///
  /// Only applies when the view doesn't loop, since a looping view has no
  /// first or last page. See [PageView.padEnds].
  final bool padEnds;

  @override
  State<LoopingPageView> createState() => _LoopingPageViewState();
}

class _LoopingPageViewState extends State<LoopingPageView> {
  LoopingPageController? _ownController;
  int? _lastReportedItem;

  LoopingPageController get _controller =>
      widget.controller ?? (_ownController ??= LoopingPageController());

  @override
  void didUpdateWidget(LoopingPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _lastReportedItem = null;
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  void _handlePageChanged(int rawPage) {
    final int item = _controller._itemAt(rawPage);
    if (item == _lastReportedItem) {
      return;
    }
    _lastReportedItem = item;
    widget.onPageChanged?.call(item);
  }

  @override
  Widget build(BuildContext context) {
    final LoopingPageController controller = _controller;
    final int? item = controller._configure(
      itemCount: widget.itemCount,
      loop: widget.loop,
    );
    _lastReportedItem = item ?? _lastReportedItem ?? controller._visibleItem;
    final int generation = controller._offsetGeneration;
    return PageView.builder(
      controller: controller,
      itemCount: controller._looping ? null : widget.itemCount,
      itemBuilder: (BuildContext context, int rawPage) => KeyedSubtree(
        key: ValueKey<int>(generation),
        child: widget.itemBuilder(context, controller._itemAt(rawPage)),
      ),
      onPageChanged: _handlePageChanged,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      physics: widget.physics,
      pageSnapping: widget.pageSnapping,
      dragStartBehavior: widget.dragStartBehavior,
      allowImplicitScrolling: widget.allowImplicitScrolling,
      restorationId: widget.restorationId,
      clipBehavior: widget.clipBehavior,
      scrollBehavior: widget.scrollBehavior,
      padEnds: widget.padEnds,
    );
  }
}
