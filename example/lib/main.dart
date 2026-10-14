import 'package:flutter/material.dart';
import 'package:looping_page_view/looping_page_view.dart';

void main() => runApp(const LoopingPageViewExample());

/// A photo-carousel style demo: a looping page view with dots, arrows, a
/// loop switch and buttons to add or remove cards.
class LoopingPageViewExample extends StatelessWidget {
  /// Creates the example app.
  const LoopingPageViewExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'looping_page_view',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const CarouselPage(),
    );
  }
}

/// The example's only screen.
class CarouselPage extends StatefulWidget {
  /// Creates the example's screen.
  const CarouselPage({super.key});

  @override
  State<CarouselPage> createState() => _CarouselPageState();
}

class _CarouselPageState extends State<CarouselPage> {
  static const List<Color> _palette = [
    Colors.indigo,
    Colors.teal,
    Colors.orange,
    Colors.pink,
    Colors.green,
    Colors.purple,
    Colors.brown,
    Colors.blueGrey,
  ];
  static const Duration _duration = Duration(milliseconds: 350);

  final LoopingPageController _controller = LoopingPageController(
    viewportFraction: 0.85,
  );
  int _count = 5;
  bool _loop = true;
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Looping page view'),
        actions: [
          const Text('Loop'),
          Switch(
            value: _loop,
            onChanged: (value) => setState(() => _loop = value),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          SizedBox(
            height: 260,
            child: LoopingPageView.builder(
              controller: _controller,
              itemCount: _count,
              loop: _loop,
              onPageChanged: (item) => setState(() => _current = item),
              itemBuilder: (context, index) =>
                  _Card(index: index, color: _palette[index % _palette.length]),
            ),
          ),
          const SizedBox(height: 16),
          _Dots(controller: _controller, count: _count),
          const SizedBox(height: 8),
          Text('Card ${_current + 1} of $_count'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _controller.previousPage(
                  duration: _duration,
                  curve: Curves.easeOut,
                ),
              ),
              IconButton(
                tooltip: 'Next',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _controller.nextPage(
                  duration: _duration,
                  curve: Curves.easeOut,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _count > 0 ? () => setState(() => _count--) : null,
                child: const Text('Remove last'),
              ),
              TextButton(
                onPressed: () => setState(() => _count++),
                child: const Text('Add card'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.index, required this.color});

  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: Theme.of(
              context,
            ).textTheme.displayLarge?.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Page dots that follow the controller while swiping, including across
/// the wrap from the last card to the first.
class _Dots extends StatelessWidget {
  const _Dots({required this.controller, required this.count});

  final LoopingPageController controller;
  final int count;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.primary;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final bool ready =
            controller.hasClients && controller.position.hasContentDimensions;
        final double page = ready ? controller.page ?? 0 : 0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              Container(
                margin: const EdgeInsets.all(4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: _dotOpacity(page, i)),
                ),
              ),
          ],
        );
      },
    );
  }

  /// How close [page] is to dot [i], from 0.25 (far) to 1 (on it). The
  /// distance wraps, so the first dot lights up as the last card leaves.
  double _dotOpacity(double page, int i) {
    final double distance = (page - i).abs();
    final double wrapped = distance > count / 2 ? count - distance : distance;
    return 1 - 0.75 * wrapped.clamp(0.0, 1.0);
  }
}
