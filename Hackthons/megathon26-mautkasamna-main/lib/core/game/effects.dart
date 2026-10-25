import 'dart:math';

import 'package:flutter/material.dart';

import 'game_style.dart';
import 'props.dart';

/// Coins flying along arcs from [from] to [to] (alignments inside this box),
/// played once. Purely decorative: hidden from screen readers and skipped
/// under reduced motion.
class CoinBurst extends StatefulWidget {
  const CoinBurst({
    super.key,
    required this.from,
    required this.to,
    this.count = 8,
    this.delay = Duration.zero,
  });

  final Alignment from;
  final Alignment to;
  final int count;
  final Duration delay;

  @override
  State<CoinBurst> createState() => _CoinBurstState();
}

class _CoinBurstState extends State<CoinBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && motionEnabled(context)) {
      _started = true;
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!motionEnabled(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) => AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final size = box.biggest;
              final from = widget.from.alongSize(size);
              final to = widget.to.alongSize(size);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < widget.count; i++)
                    _coin(i, from, to, size),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _coin(int i, Offset from, Offset to, Size size) {
    final stagger = i / widget.count * 0.4;
    final t = ((_c.value - stagger) / 0.6).clamp(0.0, 1.0);
    if (t <= 0 || t >= 1) return const SizedBox.shrink();
    final e = Curves.easeInOut.transform(t);
    final spread = (i - widget.count / 2) * 9.0;
    final arc = -60.0 - (i % 3) * 18;
    final p =
        Offset.lerp(from, to, e)! +
        Offset(spread * sin(pi * e), arc * sin(pi * e));
    return Positioned(
      left: p.dx - 14,
      top: p.dy - 14,
      child: Transform.rotate(angle: t * 6, child: const CoinIcon(size: 28)),
    );
  }
}

/// Confetti shower for celebrations, played once.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  final _pieces = List.generate(60, (i) {
    final r = Random(i * 7919);
    return (
      x: r.nextDouble(),
      speed: 0.6 + r.nextDouble() * 0.8,
      sway: r.nextDouble() * 2 * pi,
      color: [Toon.berry, Toon.gold, Toon.teal, Toon.leaf, Toon.clay][i % 5],
      size: 6 + r.nextDouble() * 6,
    );
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionEnabled(context) && !_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!motionEnabled(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_c, _pieces),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.pieces) : super(repaint: t);

  final Animation<double> t;
  final List<({double x, double speed, double sway, Color color, double size})>
  pieces;

  @override
  void paint(Canvas canvas, Size size) {
    if (t.value == 0 || t.value == 1) return;
    for (final p in pieces) {
      final y = (t.value * p.speed * 1.4 - 0.15) * size.height;
      final x = p.x * size.width + sin(t.value * 8 + p.sway) * 18;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t.value * 10 + p.sway);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.6,
        ),
        Paint()..color = p.color.withValues(alpha: 1 - t.value * 0.6),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
