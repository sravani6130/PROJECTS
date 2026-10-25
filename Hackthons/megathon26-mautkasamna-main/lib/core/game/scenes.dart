import 'dart:math';

import 'package:flutter/material.dart';

import 'game_style.dart';

/// Illustrated backdrops. Missions pick one by name in JSON (`"scene"`).
enum SceneKind {
  college,
  city,
  home,
  classroom,
  park,
  sunrise,
  night,
  shop,
  bank;

  static SceneKind parse(String? name) =>
      SceneKind.values.where((s) => s.name == name).firstOrNull ??
      SceneKind.city;

  bool get isIndoor =>
      this == SceneKind.home ||
      this == SceneKind.classroom ||
      this == SceneKind.night ||
      this == SceneKind.shop ||
      this == SceneKind.bank;
}

/// Full-bleed scene: static painting plus a slow ambient layer (drifting
/// clouds or kites) that stops under reduced motion.
class SceneBackground extends StatefulWidget {
  const SceneBackground({super.key, required this.scene, this.child});

  final SceneKind scene;
  final Widget? child;

  @override
  State<SceneBackground> createState() => _SceneBackgroundState();
}

class _SceneBackgroundState extends State<SceneBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionEnabled(context) && !widget.scene.isIndoor) {
      if (!_drift.isAnimating) _drift.repeat();
    } else {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(painter: _ScenePainter(widget.scene)),
        ),
        if (!widget.scene.isIndoor)
          RepaintBoundary(
            child: CustomPaint(painter: _SkyLayerPainter(widget.scene, _drift)),
          ),
        ?widget.child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------

Paint _f(Color c) => Paint()..color = c;
Paint _s(double w, [Color c = Toon.ink]) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

void _outlined(Canvas c, Path p, Color color, [double w = 2.5]) {
  c.drawPath(p, _f(color));
  c.drawPath(p, _s(w));
}

void _rrect(
  Canvas c,
  Rect r,
  Color color, {
  double radius = 6,
  double w = 2.5,
}) => _outlined(
  c,
  Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius))),
  color,
  w,
);

void _sky(Canvas c, Size s, List<Color> colors) {
  c.drawRect(
    Offset.zero & s,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(Offset.zero & s),
  );
}

void _cloud(Canvas c, Offset o, double k) {
  final p = Path()
    ..addOval(Rect.fromCircle(center: o, radius: 16 * k))
    ..addOval(
      Rect.fromCircle(center: o + Offset(18 * k, -8 * k), radius: 20 * k),
    )
    ..addOval(Rect.fromCircle(center: o + Offset(40 * k, 0), radius: 15 * k))
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(o.dx, o.dy - 2 * k, 40 * k, 17 * k),
        Radius.circular(8 * k),
      ),
    );
  c.drawPath(p, _f(Colors.white.withValues(alpha: 0.92)));
}

void _hills(Canvas c, Size s, double y, Color color, {double phase = 0}) {
  final p = Path()..moveTo(0, s.height);
  p.lineTo(0, y);
  for (var x = 0.0; x <= s.width + 40; x += 40) {
    p.quadraticBezierTo(x + 20, y - 22 - 10 * sin(x / 60 + phase), x + 40, y);
  }
  p
    ..lineTo(s.width, s.height)
    ..close();
  _outlined(c, p, color);
}

void _tree(Canvas c, Offset base, double k) {
  _rrect(
    c,
    Rect.fromCenter(
      center: base + Offset(0, -18 * k),
      width: 10 * k,
      height: 36 * k,
    ),
    const Color(0xFF8A5A3B),
    radius: 3,
  );
  final crown = Path()
    ..addOval(
      Rect.fromCircle(center: base + Offset(0, -46 * k), radius: 22 * k),
    )
    ..addOval(
      Rect.fromCircle(center: base + Offset(-16 * k, -36 * k), radius: 15 * k),
    )
    ..addOval(
      Rect.fromCircle(center: base + Offset(16 * k, -36 * k), radius: 15 * k),
    );
  _outlined(c, crown, Toon.leaf);
}

void _building(Canvas c, Rect r, Color color, {int cols = 3, int rows = 4}) {
  _rrect(c, r, color, radius: 4);
  final wW = r.width / (cols * 2 + 1);
  final wH = min(r.height / (rows * 2 + 1), wW * 1.3);
  for (var i = 0; i < cols; i++) {
    for (var j = 0; j < rows; j++) {
      final win = Rect.fromLTWH(
        r.left + wW * (1 + i * 2),
        r.top + wH * (1 + j * 2),
        wW,
        wH,
      );
      if (win.bottom > r.bottom - 4) continue;
      c.drawRect(win, _f(const Color(0xFFFFE9A8)));
      c.drawRect(win, _s(1.5));
    }
  }
}

/// A friendly Charminar silhouette for the Hyderabad skyline.
void _charminar(Canvas c, Offset base, double k) {
  const stone = Color(0xFFE8C9A0);
  final body = Rect.fromLTWH(
    base.dx - 34 * k,
    base.dy - 46 * k,
    68 * k,
    46 * k,
  );
  _rrect(c, body, stone, radius: 2);
  final arch = Path()
    ..moveTo(base.dx - 14 * k, base.dy)
    ..lineTo(base.dx - 14 * k, base.dy - 20 * k)
    ..quadraticBezierTo(
      base.dx,
      base.dy - 38 * k,
      base.dx + 14 * k,
      base.dy - 20 * k,
    )
    ..lineTo(base.dx + 14 * k, base.dy)
    ..close();
  _outlined(c, arch, const Color(0xFFB98B5E));
  for (final dx in [-34.0, 34.0]) {
    final x = base.dx + dx * k;
    _rrect(
      c,
      Rect.fromLTWH(x - 6 * k, base.dy - 92 * k, 12 * k, 92 * k),
      stone,
      radius: 3,
    );
    _outlined(
      c,
      Path()..addOval(
        Rect.fromCircle(center: Offset(x, base.dy - 96 * k), radius: 8 * k),
      ),
      stone,
    );
    c.drawLine(
      Offset(x, base.dy - 104 * k),
      Offset(x, base.dy - 112 * k),
      _s(2),
    );
  }
  c.drawLine(
    Offset(base.dx - 28 * k, base.dy - 52 * k),
    Offset(base.dx + 28 * k, base.dy - 52 * k),
    _s(2),
  );
}

void _road(Canvas c, Size s, double y) {
  c.drawRect(
    Rect.fromLTWH(0, y, s.width, s.height - y),
    _f(const Color(0xFF6E6A73)),
  );
  c.drawLine(Offset(0, y), Offset(s.width, y), _s(2.5));
  for (var x = 10.0; x < s.width; x += 46) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y + (s.height - y) * 0.45, 24, 5),
        const Radius.circular(2),
      ),
      _f(Colors.white70),
    );
  }
}

void _wallRoom(
  Canvas c,
  Size s,
  Color wall,
  Color floor, {
  double floorY = 0.72,
}) {
  c.drawRect(Offset.zero & s, _f(wall));
  // Soft vertical wallpaper stripes.
  for (var x = 0.0; x < s.width; x += 36) {
    c.drawRect(
      Rect.fromLTWH(x, 0, 14, s.height * floorY),
      _f(Colors.white.withValues(alpha: 0.08)),
    );
  }
  final fy = s.height * floorY;
  c.drawRect(Rect.fromLTWH(0, fy, s.width, s.height - fy), _f(floor));
  c.drawLine(Offset(0, fy), Offset(s.width, fy), _s(2.5));
  for (var x = 0.0; x < s.width; x += 60) {
    c.drawLine(
      Offset(x, fy),
      Offset(x - 30, s.height),
      _s(1.2, Colors.black26),
    );
  }
}

void _window(Canvas c, Rect r, List<Color> sky, {bool moon = false}) {
  c.drawRRect(
    RRect.fromRectAndRadius(r, const Radius.circular(8)),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: sky,
      ).createShader(r),
  );
  if (moon) {
    c.drawCircle(
      r.topRight + const Offset(-22, 22),
      10,
      _f(const Color(0xFFFFF1B8)),
    );
    for (var i = 0; i < 6; i++) {
      c.drawCircle(
        r.topLeft +
            Offset(12.0 + i * 17 % r.width, 14.0 + (i * 23) % (r.height - 20)),
        1.6,
        _f(Colors.white),
      );
    }
  }
  c.drawRRect(
    RRect.fromRectAndRadius(r, const Radius.circular(8)),
    _s(4, const Color(0xFF8A5A3B)),
  );
  c.drawLine(r.topCenter, r.bottomCenter, _s(3, const Color(0xFF8A5A3B)));
  c.drawLine(r.centerLeft, r.centerRight, _s(3, const Color(0xFF8A5A3B)));
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene);

  final SceneKind scene;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    switch (scene) {
      case SceneKind.college:
        _sky(c, s, const [Toon.skyTop, Toon.sky, Color(0xFFD9F1FB)]);
        c.drawCircle(
          Offset(w * 0.82, h * 0.12),
          26,
          _f(const Color(0xFFFFE07A)),
        );
        _hills(c, s, h * 0.55, const Color(0xFF9ED38A));
        // College building with a clock.
        _building(
          c,
          Rect.fromLTWH(w * 0.08, h * 0.30, w * 0.5, h * 0.3),
          const Color(0xFFF2D6A8),
          cols: 4,
          rows: 3,
        );
        _outlined(
          c,
          Path()
            ..moveTo(w * 0.05, h * 0.31)
            ..lineTo(w * 0.33, h * 0.22)
            ..lineTo(w * 0.61, h * 0.31)
            ..close(),
          Toon.clay,
        );
        _outlined(
          c,
          Path()..addOval(
            Rect.fromCircle(center: Offset(w * 0.33, h * 0.27), radius: 9),
          ),
          Colors.white,
        );
        _tree(c, Offset(w * 0.72, h * 0.62), 1.1);
        _road(c, s, h * 0.66);
        _bus(c, Offset(w * 0.62, h * 0.70), 1.0);
      case SceneKind.city:
        _sky(c, s, const [
          Color(0xFFFFB27A),
          Color(0xFFFFD49A),
          Color(0xFFFFEBC4),
        ]);
        c.drawCircle(
          Offset(w * 0.2, h * 0.16),
          24,
          _f(const Color(0xFFFFF0A8)),
        );
        _building(
          c,
          Rect.fromLTWH(w * 0.02, h * 0.34, w * 0.2, h * 0.32),
          const Color(0xFFB7A6D9),
        );
        _building(
          c,
          Rect.fromLTWH(w * 0.70, h * 0.28, w * 0.24, h * 0.38),
          const Color(0xFF8FB8D9),
          cols: 2,
          rows: 5,
        );
        _charminar(c, Offset(w * 0.46, h * 0.66), min(w, h) / 360 * 1.15);
        // Metro line on pillars.
        c.drawRect(
          Rect.fromLTWH(0, h * 0.60, w, 10),
          _f(const Color(0xFFD7D2C8)),
        );
        c.drawLine(Offset(0, h * 0.60), Offset(w, h * 0.60), _s(2));
        c.drawLine(Offset(0, h * 0.60 + 10), Offset(w, h * 0.60 + 10), _s(2));
        _road(c, s, h * 0.66);
      case SceneKind.home:
        _wallRoom(c, s, const Color(0xFFF6D7A7), const Color(0xFFC99A6B));
        _window(
          c,
          Rect.fromLTWH(w * 0.56, h * 0.10, w * 0.34, h * 0.24),
          const [Toon.skyTop, Toon.sky],
        );
        // Shelf with books and a little plant.
        _rrect(
          c,
          Rect.fromLTWH(w * 0.06, h * 0.30, w * 0.36, 10),
          const Color(0xFF8A5A3B),
          radius: 3,
        );
        for (var i = 0; i < 4; i++) {
          _rrect(
            c,
            Rect.fromLTWH(
              w * 0.08 + i * 16,
              h * 0.30 - 34 + (i.isOdd ? 6 : 0),
              13,
              34 - (i.isOdd ? 6 : 0),
            ),
            [Toon.berry, Toon.teal, Toon.gold, Toon.leaf][i],
            radius: 2,
            w: 2,
          );
        }
        _rrect(
          c,
          Rect.fromLTWH(w * 0.30, h * 0.30 - 22, 22, 22),
          Toon.clay,
          radius: 4,
          w: 2,
        );
        _outlined(
          c,
          Path()..addOval(
            Rect.fromCircle(
              center: Offset(w * 0.30 + 11, h * 0.30 - 30),
              radius: 11,
            ),
          ),
          Toon.leaf,
          2,
        );
        // Rug.
        c.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.86),
            width: w * 0.8,
            height: h * 0.12,
          ),
          _f(const Color(0xFFD96B5E)),
        );
        c.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.86),
            width: w * 0.8,
            height: h * 0.12,
          ),
          _s(2.5),
        );
      case SceneKind.classroom:
        _wallRoom(c, s, const Color(0xFFCFE3C8), const Color(0xFFB98F67));
        // Blackboard with chalk sums.
        final board = Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.84, h * 0.26);
        _rrect(c, board, const Color(0xFF2F5D4A), radius: 6, w: 4);
        final chalk = _s(2.2, Colors.white70);
        c.drawLine(
          board.topLeft + const Offset(20, 24),
          board.topLeft + const Offset(70, 24),
          chalk,
        );
        c.drawLine(
          board.topLeft + const Offset(20, 44),
          board.topLeft + const Offset(100, 44),
          chalk,
        );
        c.drawCircle(board.topRight + const Offset(-50, 40), 16, chalk);
        c.drawLine(
          board.topRight + const Offset(-60, 40),
          board.topRight + const Offset(-40, 40),
          chalk,
        );
        // Desk.
        _rrect(
          c,
          Rect.fromLTWH(w * 0.55, h * 0.62, w * 0.4, 14),
          const Color(0xFF8A5A3B),
          radius: 3,
        );
        _rrect(
          c,
          Rect.fromLTWH(w * 0.58, h * 0.62 + 14, 10, h * 0.12),
          const Color(0xFF6E4429),
          radius: 2,
        );
        _rrect(
          c,
          Rect.fromLTWH(w * 0.89, h * 0.62 + 14, 10, h * 0.12),
          const Color(0xFF6E4429),
          radius: 2,
        );
      case SceneKind.park:
        _sky(c, s, const [Toon.skyTop, Toon.sky, Color(0xFFE2F6FF)]);
        c.drawCircle(
          Offset(w * 0.15, h * 0.12),
          22,
          _f(const Color(0xFFFFE07A)),
        );
        _hills(c, s, h * 0.52, const Color(0xFF9ED38A), phase: 1);
        _hills(c, s, h * 0.64, Toon.leaf, phase: 2.5);
        _tree(c, Offset(w * 0.12, h * 0.70), 1.0);
        _tree(c, Offset(w * 0.86, h * 0.68), 1.2);
        // Pebbles by the pond.
        c.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.84),
            width: w * 0.6,
            height: h * 0.1,
          ),
          _f(const Color(0xFF7FC8E8)),
        );
        c.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.84),
            width: w * 0.6,
            height: h * 0.1,
          ),
          _s(2.5),
        );
        for (var i = 0; i < 5; i++) {
          _outlined(
            c,
            Path()..addOval(
              Rect.fromCenter(
                center: Offset(w * (0.22 + i * 0.14), h * 0.92),
                width: 22,
                height: 12,
              ),
            ),
            const Color(0xFFB9B2A8),
            2,
          );
        }
      case SceneKind.sunrise:
        _sky(c, s, const [
          Color(0xFFFF9E7A),
          Color(0xFFFFD08A),
          Color(0xFFFFF0C2),
        ]);
        c.drawCircle(
          Offset(w * 0.5, h * 0.56),
          44,
          _f(const Color(0xFFFFE07A)),
        );
        for (var i = 0; i < 9; i++) {
          final a = pi + i * pi / 8;
          c.drawLine(
            Offset(w * 0.5 + cos(a) * 56, h * 0.56 + sin(a) * 56),
            Offset(w * 0.5 + cos(a) * 74, h * 0.56 + sin(a) * 74),
            _s(4, const Color(0xFFFFC94D)),
          );
        }
        _hills(c, s, h * 0.6, const Color(0xFF9ED38A), phase: 0.5);
        // Rows of crops.
        for (var row = 0; row < 4; row++) {
          final y = h * (0.7 + row * 0.07);
          for (var x = 12.0 + row * 8; x < w; x += 30) {
            c.drawLine(
              Offset(x, y),
              Offset(x - 4, y - 12),
              _s(3, Toon.leafDark),
            );
            c.drawLine(
              Offset(x, y),
              Offset(x + 5, y - 10),
              _s(3, Toon.leafDark),
            );
          }
        }
      case SceneKind.night:
        _wallRoom(c, s, const Color(0xFF3D4A7A), const Color(0xFF5A4A6A));
        _window(c, Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.4, h * 0.26), const [
          Toon.nightTop,
          Toon.night,
        ], moon: true);
        // Bed and lamp glow.
        _rrect(
          c,
          Rect.fromLTWH(w * 0.5, h * 0.56, w * 0.48, h * 0.16),
          const Color(0xFF6B8BD6),
          radius: 10,
        );
        _rrect(
          c,
          Rect.fromLTWH(w * 0.52, h * 0.52, w * 0.16, h * 0.06),
          Colors.white,
          radius: 8,
        );
        c.drawCircle(
          Offset(w * 0.82, h * 0.30),
          70,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [const Color(0x66FFE08A), const Color(0x00FFE08A)],
                ).createShader(
                  Rect.fromCircle(
                    center: Offset(w * 0.82, h * 0.30),
                    radius: 70,
                  ),
                ),
        );
        _outlined(
          c,
          Path()
            ..moveTo(w * 0.76, h * 0.30)
            ..lineTo(w * 0.88, h * 0.30)
            ..lineTo(w * 0.85, h * 0.22)
            ..lineTo(w * 0.79, h * 0.22)
            ..close(),
          const Color(0xFFFFD36B),
        );
        c.drawLine(
          Offset(w * 0.82, h * 0.30),
          Offset(w * 0.82, h * 0.42),
          _s(3),
        );
      case SceneKind.shop:
        // Imran bhai's electronics and stationery shop.
        _wallRoom(c, s, const Color(0xFFBFE0E8), const Color(0xFFB98F67));
        for (var row = 0; row < 2; row++) {
          final y = h * (0.20 + row * 0.15);
          _rrect(
            c,
            Rect.fromLTWH(w * 0.06, y, w * 0.88, 9),
            const Color(0xFF8A5A3B),
            radius: 3,
          );
          for (var i = 0; i < 5; i++) {
            final x = w * 0.10 + i * w * 0.17;
            if ((i + row).isEven) {
              // A boxed gadget.
              _rrect(
                c,
                Rect.fromLTWH(x, y - 34, 34, 34),
                [Toon.gold, Toon.berry, Toon.teal][(i + row) % 3],
                radius: 4,
                w: 2,
              );
              c.drawLine(
                Offset(x + 7, y - 17),
                Offset(x + 27, y - 17),
                _s(2, Colors.white),
              );
            } else {
              // A small screen on a stand.
              _rrect(
                c,
                Rect.fromLTWH(x - 2, y - 30, 40, 24),
                const Color(0xFF4A4F63),
                radius: 3,
                w: 2,
              );
              _rrect(
                c,
                Rect.fromLTWH(x + 2, y - 27, 32, 18),
                const Color(0xFFBFE8FF),
                radius: 2,
                w: 1.5,
              );
              c.drawLine(Offset(x + 18, y - 6), Offset(x + 18, y), _s(3));
            }
          }
        }
        // Counter with a sale board.
        _rrect(
          c,
          Rect.fromLTWH(-4, h * 0.60, w + 8, h * 0.12),
          const Color(0xFFD9A066),
          radius: 4,
        );
        _rrect(
          c,
          Rect.fromLTWH(-4, h * 0.58, w + 8, 12),
          const Color(0xFF8A5A3B),
          radius: 4,
        );
        _rrect(
          c,
          Rect.fromLTWH(w * 0.66, h * 0.045, w * 0.28, h * 0.07),
          Toon.gold,
          radius: 8,
        );
        c.drawLine(
          Offset(w * 0.71, h * 0.08),
          Offset(w * 0.89, h * 0.08),
          _s(3, Toon.clayDark),
        );
      case SceneKind.bank:
        // The pretend bank branch: counter windows, a queue rope and a clock.
        _wallRoom(c, s, const Color(0xFFE6DFF5), const Color(0xFFB8B0A6));
        _rrect(
          c,
          Rect.fromLTWH(w * 0.05, h * 0.07, w * 0.58, h * 0.07),
          Toon.teal,
          radius: 8,
        );
        for (var i = 0; i < 4; i++) {
          c.drawCircle(
            Offset(w * 0.12 + i * w * 0.14, h * 0.105),
            5,
            _f(Toon.gold),
          );
        }
        _outlined(
          c,
          Path()..addOval(
            Rect.fromCircle(center: Offset(w * 0.82, h * 0.11), radius: 24),
          ),
          Colors.white,
        );
        c.drawLine(
          Offset(w * 0.82, h * 0.11),
          Offset(w * 0.82, h * 0.11 - 14),
          _s(3),
        );
        c.drawLine(
          Offset(w * 0.82, h * 0.11),
          Offset(w * 0.82 + 10, h * 0.11 + 4),
          _s(3),
        );
        for (var i = 0; i < 3; i++) {
          final r = Rect.fromLTWH(
            w * 0.06 + i * w * 0.31,
            h * 0.20,
            w * 0.26,
            h * 0.20,
          );
          _rrect(c, r, const Color(0xFFBFE8FF), radius: 10);
          c.drawLine(
            r.topLeft + Offset(r.width * 0.25, r.height * 0.7),
            r.topLeft + Offset(r.width * 0.6, r.height * 0.2),
            _s(3, Colors.white),
          );
        }
        _rrect(
          c,
          Rect.fromLTWH(-4, h * 0.40, w + 8, h * 0.10),
          const Color(0xFF8A5A3B),
          radius: 4,
        );
        _rrect(
          c,
          Rect.fromLTWH(-4, h * 0.50, w + 8, h * 0.14),
          const Color(0xFFD9A066),
          radius: 4,
        );
        // Queue posts and rope.
        for (final x in [w * 0.12, w * 0.5, w * 0.88]) {
          c.drawLine(Offset(x, h * 0.80), Offset(x, h * 0.92), _s(6));
          c.drawCircle(Offset(x, h * 0.80), 6, _f(Toon.gold));
          c.drawCircle(Offset(x, h * 0.80), 6, _s(2));
        }
        c.drawPath(
          Path()
            ..moveTo(w * 0.12, h * 0.81)
            ..quadraticBezierTo(w * 0.31, h * 0.87, w * 0.5, h * 0.81)
            ..quadraticBezierTo(w * 0.69, h * 0.87, w * 0.88, h * 0.81),
          _s(4, Toon.berry),
        );
    }
  }

  void _bus(Canvas c, Offset o, double k) {
    final body = Rect.fromLTWH(o.dx, o.dy, 110 * k, 44 * k);
    _rrect(c, body, const Color(0xFFE5483F), radius: 10);
    for (var i = 0; i < 4; i++) {
      _rrect(
        c,
        Rect.fromLTWH(o.dx + 8 * k + i * 24 * k, o.dy + 7 * k, 18 * k, 14 * k),
        const Color(0xFFBFE8FF),
        radius: 3,
        w: 2,
      );
    }
    for (final x in [24.0, 86.0]) {
      _outlined(
        c,
        Path()..addOval(
          Rect.fromCircle(
            center: Offset(o.dx + x * k, o.dy + 44 * k),
            radius: 9 * k,
          ),
        ),
        const Color(0xFF333333),
      );
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.scene != scene;
}

class _SkyLayerPainter extends CustomPainter {
  _SkyLayerPainter(this.scene, this.drift) : super(repaint: drift);

  final SceneKind scene;
  final Animation<double> drift;

  @override
  void paint(Canvas c, Size s) {
    final t = drift.value;
    double wrap(double x) => (x % (s.width + 140)) - 90;
    _cloud(
      c,
      Offset(wrap(s.width * 0.1 + t * (s.width + 140)), s.height * 0.10),
      1.0,
    );
    _cloud(
      c,
      Offset(wrap(s.width * 0.6 + t * 2 * (s.width + 140)), s.height * 0.20),
      0.75,
    );
    if (scene == SceneKind.park) {
      // River kites bob in the wind.
      final colors = [Toon.berry, Toon.gold, Toon.teal];
      for (var i = 0; i < 3; i++) {
        final x = s.width * (0.28 + i * 0.22);
        final y = s.height * (0.22 + 0.05 * sin(t * 2 * pi * 3 + i * 2));
        final kite = Path()
          ..moveTo(x, y - 18)
          ..lineTo(x + 13, y)
          ..lineTo(x, y + 18)
          ..lineTo(x - 13, y)
          ..close();
        _outlined(c, kite, colors[i], 2);
        c.drawLine(
          Offset(x, y + 18),
          Offset(x - 20 + i * 10, s.height * 0.62),
          _s(1, Colors.black38),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SkyLayerPainter old) => old.scene != scene;
}
