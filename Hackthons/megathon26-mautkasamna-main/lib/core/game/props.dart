import 'dart:math';

import 'package:flutter/material.dart';

import 'game_style.dart';

/// Small illustrated objects. Content refers to them by name
/// (`"prop": "bus"`); unknown names fall back to a coin.
enum PropKind {
  bus,
  metro,
  tiffin,
  notebook,
  pen,
  samosa,
  chai,
  ticket,
  geometry,
  phone,
  shield,
  coin,
  pebble,
  kite,
  jar,
  calendar,
  thief,
  headphones,
  laptop,
  bank,
  lock,
  card,
  magnifier,
  document,
  medkit,
  tv,
  bulb,
  gift;

  static PropKind parse(String? name) =>
      PropKind.values.where((p) => p.name == name).firstOrNull ?? PropKind.coin;
}

class PropIcon extends StatelessWidget {
  const PropIcon(this.kind, {super.key, this.size = 48});

  final PropKind kind;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: PropPainter(kind)),
  );
}

/// A gold rupee coin, used in the HUD and coin animations.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: PropPainter(PropKind.coin)),
  );
}

Paint _f(Color c) => Paint()..color = c;
Paint _s(double w, [Color c = Toon.ink]) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

void _o(Canvas c, Path p, Color color, [double w = 2.4]) {
  c.drawPath(p, _f(color));
  c.drawPath(p, _s(w));
}

Path _rr(double l, double t, double w, double h, double r) => Path()
  ..addRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r)),
  );

Path _ov(double cx, double cy, double w, double h) =>
    Path()
      ..addOval(Rect.fromCenter(center: Offset(cx, cy), width: w, height: h));

/// Paints a prop in a 48×48 box scaled to the canvas.
class PropPainter extends CustomPainter {
  const PropPainter(this.kind);

  final PropKind kind;

  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 48, size.height / 48);
    switch (kind) {
      case PropKind.coin:
        _o(c, _ov(24, 24, 40, 40), Toon.gold);
        c.drawCircle(const Offset(24, 24), 14, _s(2, Toon.goldDark));
        final tp = TextPainter(
          text: const TextSpan(
            text: '₹',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Toon.goldDark,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, Offset(24 - tp.width / 2, 24 - tp.height / 2));
      case PropKind.bus:
        _o(c, _rr(4, 10, 40, 26, 7), const Color(0xFFE5483F));
        for (var i = 0; i < 3; i++) {
          _o(c, _rr(8 + i * 11.5, 14, 9, 9, 2), const Color(0xFFBFE8FF), 1.8);
        }
        _o(c, _ov(14, 37, 10, 10), const Color(0xFF333333));
        _o(c, _ov(34, 37, 10, 10), const Color(0xFF333333));
      case PropKind.metro:
        _o(c, _rr(4, 10, 40, 26, 10), const Color(0xFF7A5CC8));
        _o(c, _rr(9, 15, 30, 10, 3), const Color(0xFFBFE8FF), 1.8);
        c.drawLine(
          const Offset(4, 30),
          const Offset(44, 30),
          _s(2, Colors.white),
        );
        c.drawLine(const Offset(8, 42), const Offset(40, 42), _s(3));
      case PropKind.tiffin:
        for (var i = 0; i < 3; i++) {
          _o(c, _rr(9, 14 + i * 9.0, 30, 9, 3), const Color(0xFFC9D3DB));
        }
        c.drawArc(Rect.fromLTWH(15, 4, 18, 18), pi, pi, false, _s(3));
      case PropKind.notebook:
        _o(c, _rr(10, 6, 28, 36, 3), Toon.teal);
        _o(c, _rr(15, 12, 18, 8, 2), Colors.white, 1.6);
        for (var y = 10.0; y < 40; y += 6) {
          c.drawLine(Offset(8, y), Offset(12, y), _s(2));
        }
      case PropKind.pen:
        c.save();
        c.translate(24, 24);
        c.rotate(-pi / 4);
        _o(c, _rr(-4, -20, 8, 32, 3), const Color(0xFF3F7DD6));
        _o(
          c,
          Path()
            ..moveTo(-4, 12)
            ..lineTo(4, 12)
            ..lineTo(0, 20)
            ..close(),
          Toon.cream,
        );
        c.restore();
      case PropKind.samosa:
        _o(
          c,
          Path()
            ..moveTo(6, 38)
            ..quadraticBezierTo(24, 0, 42, 38)
            ..close(),
          const Color(0xFFE0A646),
        );
        c.drawLine(
          const Offset(14, 30),
          const Offset(22, 22),
          _s(1.6, Toon.goldDark),
        );
        c.drawLine(
          const Offset(26, 22),
          const Offset(34, 30),
          _s(1.6, Toon.goldDark),
        );
      case PropKind.chai:
        _o(
          c,
          Path()
            ..moveTo(10, 16)
            ..lineTo(34, 16)
            ..lineTo(31, 42)
            ..lineTo(13, 42)
            ..close(),
          Colors.white,
        );
        _o(c, _rr(12, 16, 20, 7, 2), const Color(0xFFB9783F), 1.6);
        c.drawArc(
          const Rect.fromLTWH(30, 20, 12, 14),
          -pi / 2,
          pi,
          false,
          _s(2.6),
        );
        for (final x in [17.0, 25.0]) {
          c.drawPath(
            Path()
              ..moveTo(x, 12)
              ..quadraticBezierTo(x - 3, 8, x, 4),
            _s(1.6, Colors.black45),
          );
        }
      case PropKind.ticket:
        c.save();
        c.translate(24, 24);
        c.rotate(-0.25);
        _o(c, _rr(-20, -12, 40, 24, 4), const Color(0xFFF6C443));
        c.drawLine(const Offset(6, -12), const Offset(6, 12), _s(1.6));
        c.drawCircle(const Offset(-6, 0), 5, _s(2));
        c.restore();
      case PropKind.geometry:
        _o(c, _rr(6, 12, 36, 24, 4), const Color(0xFF4AA3DF));
        _o(
          c,
          Path()
            ..moveTo(12, 32)
            ..lineTo(24, 16)
            ..lineTo(36, 32)
            ..close(),
          Colors.white,
          1.8,
        );
        c.drawLine(const Offset(10, 40), const Offset(38, 40), _s(2.4));
      case PropKind.phone:
        _o(c, _rr(13, 4, 22, 40, 5), const Color(0xFF2E2E3A));
        _o(c, _rr(16, 9, 16, 28, 2), const Color(0xFF9FD8FF), 1.6);
        c.drawCircle(const Offset(24, 40), 1.8, _f(Colors.white));
      case PropKind.shield:
        _o(
          c,
          Path()
            ..moveTo(24, 4)
            ..lineTo(40, 10)
            ..quadraticBezierTo(40, 34, 24, 44)
            ..quadraticBezierTo(8, 34, 8, 10)
            ..close(),
          Toon.teal,
        );
        c.drawPath(
          Path()
            ..moveTo(16, 24)
            ..lineTo(22, 30)
            ..lineTo(33, 17),
          _s(3.5, Colors.white),
        );
      case PropKind.pebble:
        _o(c, _ov(24, 28, 38, 26), const Color(0xFFB9C3CC));
        c.drawCircle(const Offset(18, 26), 2.4, _f(Toon.ink));
        c.drawCircle(const Offset(30, 26), 2.4, _f(Toon.ink));
        c.drawArc(
          const Rect.fromLTWH(19, 27, 10, 6),
          0.2,
          pi - 0.4,
          false,
          _s(1.8),
        );
      case PropKind.kite:
        _o(
          c,
          Path()
            ..moveTo(24, 4)
            ..lineTo(40, 20)
            ..lineTo(24, 36)
            ..lineTo(8, 20)
            ..close(),
          Toon.berry,
        );
        c.drawLine(const Offset(24, 4), const Offset(24, 36), _s(1.5));
        c.drawLine(const Offset(8, 20), const Offset(40, 20), _s(1.5));
        c.drawPath(
          Path()
            ..moveTo(24, 36)
            ..quadraticBezierTo(18, 42, 26, 46),
          _s(1.6),
        );
      case PropKind.jar:
        _o(
          c,
          _rr(10, 14, 28, 30, 8),
          const Color(0xFFBFE8FF).withValues(alpha: 0.9),
        );
        _o(c, _rr(13, 8, 22, 7, 2), Toon.clay);
        for (var i = 0; i < 3; i++) {
          _o(c, _ov(24, 38 - i * 5.0, 16, 6), Toon.gold, 1.4);
        }
      case PropKind.calendar:
        _o(c, _rr(8, 10, 32, 32, 4), Colors.white);
        _o(c, _rr(8, 10, 32, 9, 4), Toon.berry);
        for (var i = 0; i < 3; i++) {
          for (var j = 0; j < 2; j++) {
            c.drawCircle(Offset(15 + i * 9.0, 26 + j * 8.0), 2, _f(Toon.ink));
          }
        }
      case PropKind.thief:
        // Hooded scammer silhouette (no real-world identity).
        _o(
          c,
          Path()
            ..moveTo(8, 46)
            ..quadraticBezierTo(24, 20, 40, 46)
            ..close(),
          const Color(0xFF3A3346),
        );
        _o(c, _ov(24, 18, 26, 28), const Color(0xFF3A3346));
        _o(c, _ov(24, 20, 16, 16), const Color(0xFF1E1A26), 1.6);
        c.drawCircle(const Offset(20, 20), 1.8, _f(const Color(0xFFFFE07A)));
        c.drawCircle(const Offset(28, 20), 1.8, _f(const Color(0xFFFFE07A)));
      case PropKind.headphones:
        c.drawArc(const Rect.fromLTWH(8, 8, 32, 36), pi, pi, false, _s(5));
        c.drawArc(
          const Rect.fromLTWH(8, 8, 32, 36),
          pi,
          pi,
          false,
          _s(2, Toon.clayLight),
        );
        _o(c, _rr(4, 24, 11, 18, 5), Toon.berry);
        _o(c, _rr(33, 24, 11, 18, 5), Toon.berry);
      case PropKind.laptop:
        _o(c, _rr(8, 8, 32, 24, 3), const Color(0xFF4A4F63));
        _o(c, _rr(11, 11, 26, 18, 2), const Color(0xFFBFE8FF), 1.6);
        c.drawLine(
          const Offset(15, 24),
          const Offset(22, 17),
          _s(1.6, Colors.white),
        );
        _o(
          c,
          Path()
            ..moveTo(8, 32)
            ..lineTo(40, 32)
            ..lineTo(45, 41)
            ..lineTo(3, 41)
            ..close(),
          const Color(0xFFC9D3DB),
        );
        c.drawLine(const Offset(19, 37), const Offset(29, 37), _s(2));
      case PropKind.bank:
        _o(
          c,
          Path()
            ..moveTo(4, 18)
            ..lineTo(24, 5)
            ..lineTo(44, 18)
            ..close(),
          Toon.clayLight,
        );
        _o(c, _rr(6, 18, 36, 5, 1), Toon.cream);
        for (var i = 0; i < 4; i++) {
          _o(c, _rr(9 + i * 9.0, 23, 5, 14, 1), Colors.white, 1.8);
        }
        _o(c, _rr(4, 37, 40, 6, 2), Toon.cream);
        c.drawCircle(const Offset(24, 13), 2.4, _f(Toon.goldDark));
      case PropKind.lock:
        c.drawArc(const Rect.fromLTWH(14, 5, 20, 24), pi, pi, false, _s(5));
        c.drawArc(
          const Rect.fromLTWH(14, 5, 20, 24),
          pi,
          pi,
          false,
          _s(2, const Color(0xFFC9D3DB)),
        );
        _o(c, _rr(9, 20, 30, 23, 5), Toon.gold);
        c.drawCircle(const Offset(24, 29), 3.2, _f(Toon.ink));
        c.drawLine(const Offset(24, 30), const Offset(24, 37), _s(3));
      case PropKind.card:
        _o(c, _rr(4, 11, 40, 26, 5), const Color(0xFF7A5CC8));
        c.drawRect(const Rect.fromLTWH(5, 17, 38, 5), _f(Toon.ink));
        _o(c, _rr(9, 26, 9, 6, 2), Toon.gold, 1.4);
        c.drawLine(
          const Offset(24, 30),
          const Offset(38, 30),
          _s(2, Colors.white),
        );
      case PropKind.magnifier:
        c.drawLine(const Offset(30, 30), const Offset(42, 42), _s(7));
        c.drawLine(
          const Offset(31, 31),
          const Offset(41, 41),
          _s(3, Toon.clay),
        );
        _o(c, _ov(20, 20, 28, 28), const Color(0xFFBFE8FF));
        c.drawArc(
          const Rect.fromLTWH(11, 11, 14, 14),
          pi,
          pi / 2,
          false,
          _s(2, Colors.white),
        );
      case PropKind.document:
        _o(
          c,
          Path()
            ..moveTo(10, 4)
            ..lineTo(30, 4)
            ..lineTo(38, 12)
            ..lineTo(38, 44)
            ..lineTo(10, 44)
            ..close(),
          Colors.white,
        );
        c.drawPath(
          Path()
            ..moveTo(30, 4)
            ..lineTo(30, 12)
            ..lineTo(38, 12),
          _s(2),
        );
        for (var y = 19.0; y < 34; y += 6) {
          c.drawLine(Offset(15, y), Offset(33, y), _s(2, Toon.clayLight));
        }
        _o(c, _ov(30, 38, 8, 8), Toon.berry, 1.4);
      case PropKind.medkit:
        c.drawArc(const Rect.fromLTWH(16, 5, 16, 14), pi, pi, false, _s(3));
        _o(c, _rr(5, 12, 38, 30, 6), Colors.white);
        c.drawRect(const Rect.fromLTWH(20, 18, 8, 18), _f(Toon.berry));
        c.drawRect(const Rect.fromLTWH(15, 23, 18, 8), _f(Toon.berry));
      case PropKind.tv:
        c.drawLine(const Offset(18, 3), const Offset(24, 11), _s(2.4));
        c.drawLine(const Offset(31, 3), const Offset(24, 11), _s(2.4));
        _o(c, _rr(4, 11, 40, 28, 6), const Color(0xFF8A5A3B));
        _o(c, _rr(8, 15, 26, 20, 4), const Color(0xFFBFE8FF), 1.8);
        c.drawCircle(const Offset(39, 20), 1.8, _f(Toon.gold));
        c.drawCircle(const Offset(39, 27), 1.8, _f(Toon.gold));
        c.drawLine(const Offset(13, 43), const Offset(35, 43), _s(3));
      case PropKind.bulb:
        _o(c, _ov(24, 19, 26, 28), const Color(0xFFFFE07A));
        _o(c, _rr(18, 31, 12, 9, 2), const Color(0xFFC9D3DB));
        c.drawLine(const Offset(20, 43), const Offset(28, 43), _s(3));
        c.drawPath(
          Path()
            ..moveTo(20, 24)
            ..lineTo(24, 18)
            ..lineTo(28, 24),
          _s(1.8, Toon.goldDark),
        );
      case PropKind.gift:
        _o(c, _rr(7, 20, 34, 23, 3), Toon.berry);
        _o(c, _rr(4, 13, 40, 9, 3), const Color(0xFFE5577A));
        c.drawRect(const Rect.fromLTWH(21, 13, 6, 30), _f(Toon.gold));
        _o(c, _ov(18, 10, 10, 8), Toon.gold, 1.8);
        _o(c, _ov(30, 10, 10, 8), Toon.gold, 1.8);
    }
  }

  @override
  bool shouldRepaint(PropPainter old) => old.kind != kind;
}
