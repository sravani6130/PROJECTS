import 'dart:math';

import 'package:flutter/material.dart';

import 'game_style.dart';

/// Facial expression, also used to pick a body pose.
enum Mood { neutral, happy, cheer, thinking, worried, surprised }

enum HairStyle { short, braid, ponytail, bun, curly, long }

enum Accessory { none, glasses, bindi, cap }

/// How a cartoon character looks. Parsed from mission JSON
/// (`"character": {"look": {...}}`) so new characters need no code.
class CharacterLook {
  const CharacterLook({
    this.skin = const Color(0xFFC68B59),
    this.hair = HairStyle.short,
    this.hairColor = const Color(0xFF2B1B12),
    this.top = const Color(0xFF4E8DD6),
    this.bottom = const Color(0xFF3A3F58),
    this.accessory = Accessory.none,
  });

  factory CharacterLook.fromJson(Map<String, Object?>? json) {
    if (json == null) return const CharacterLook();
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    const d = CharacterLook();
    return CharacterLook(
      skin: parseHexColor(json['skin'] as String?) ?? d.skin,
      hair: pick(HairStyle.values, json['hair'], d.hair),
      hairColor: parseHexColor(json['hairColor'] as String?) ?? d.hairColor,
      top: parseHexColor(json['top'] as String?) ?? d.top,
      bottom: parseHexColor(json['bottom'] as String?) ?? d.bottom,
      accessory: pick(Accessory.values, json['accessory'], d.accessory),
    );
  }

  final Color skin;
  final HairStyle hair;
  final Color hairColor;
  final Color top;
  final Color bottom;
  final Accessory accessory;

  /// Avatars offered for local profiles (ids are stored in the database).
  static const avatars = <String, CharacterLook>{
    'star': CharacterLook(
      hair: HairStyle.braid,
      top: Color(0xFFE5577A),
      accessory: Accessory.bindi,
    ),
    'rocket': CharacterLook(
      skin: Color(0xFFA9714A),
      top: Color(0xFF3F9E6E),
      accessory: Accessory.cap,
    ),
    'leaf': CharacterLook(
      skin: Color(0xFFD9A066),
      hair: HairStyle.ponytail,
      top: Color(0xFF8E6CD8),
    ),
    'book': CharacterLook(
      skin: Color(0xFF8D5A3B),
      hair: HairStyle.curly,
      top: Color(0xFFF0A23A),
      accessory: Accessory.glasses,
    ),
    'music': CharacterLook(
      skin: Color(0xFFBF8156),
      hair: HairStyle.bun,
      top: Color(0xFF2E9CB8),
    ),
    'bolt': CharacterLook(
      skin: Color(0xFF9C6644),
      hair: HairStyle.short,
      top: Color(0xFFD9475B),
      accessory: Accessory.glasses,
    ),
  };
}

/// Shared ambient animation for characters and the mascot: gentle bobbing,
/// blinking and talking. Static (but still drawn) under reduced motion.
abstract class _AnimatedToon extends StatefulWidget {
  const _AnimatedToon({super.key, required this.mood, this.talking = false});

  final Mood mood;
  final bool talking;
}

abstract class _AnimatedToonState<T extends _AnimatedToon> extends State<T>
    with SingleTickerProviderStateMixin {
  late final AnimationController clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionEnabled(context)) {
      if (!clock.isAnimating) clock.repeat();
    } else {
      clock.stop();
    }
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }
}

/// A full-body cartoon student.
class CartoonCharacter extends _AnimatedToon {
  const CartoonCharacter({
    super.key,
    required this.look,
    super.mood = Mood.neutral,
    super.talking,
    this.semanticLabel,
  });

  final CharacterLook look;
  final String? semanticLabel;

  @override
  State<CartoonCharacter> createState() => _CartoonCharacterState();
}

class _CartoonCharacterState extends _AnimatedToonState<CartoonCharacter> {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      image: widget.semanticLabel != null,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: AspectRatio(
          aspectRatio: 120 / 200,
          child: CustomPaint(
            painter: _CharacterPainter(
              look: widget.look,
              mood: widget.mood,
              talking: widget.talking,
              clock: clock,
            ),
          ),
        ),
      ),
    );
  }
}

/// Just the head, for avatars and map markers.
class CartoonFace extends StatelessWidget {
  const CartoonFace({super.key, required this.look, this.mood = Mood.happy});

  final CharacterLook look;
  final Mood mood;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _CharacterPainter(
          look: look,
          mood: mood,
          talking: false,
          headOnly: true,
        ),
      ),
    );
  }
}

/// Gullu, the clay gullak (money pot) mascot who guides the player.
class GullakMascot extends _AnimatedToon {
  const GullakMascot({
    super.key,
    super.mood = Mood.happy,
    super.talking,
    this.semanticLabel,
  });

  final String? semanticLabel;

  @override
  State<GullakMascot> createState() => _GullakMascotState();
}

class _GullakMascotState extends _AnimatedToonState<GullakMascot> {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      image: widget.semanticLabel != null,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(
            painter: _MascotPainter(
              mood: widget.mood,
              talking: widget.talking,
              clock: clock,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painting

Paint _fill(Color c) => Paint()..color = c;
Paint _line(double w, [Color c = Toon.ink]) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

void _shape(Canvas canvas, Path path, Color color, [double outline = 2.4]) {
  canvas.drawPath(path, _fill(color));
  canvas.drawPath(path, _line(outline));
}

void _circle(Canvas canvas, Offset c, double r, Color color) => _shape(
  canvas,
  Path()..addOval(Rect.fromCircle(center: c, radius: r)),
  color,
);

/// Thick limb with outline, drawn as an ink stroke under a coloured stroke.
void _limb(Canvas canvas, List<Offset> points, Color color, double width) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(path, _line(width + 4.8));
  canvas.drawPath(path, _line(width, color));
}

/// Eyes, brows, mouth and cheeks around [c] (the face centre), at scale [s].
void drawFace(
  Canvas canvas,
  Offset c,
  double s,
  Mood mood, {
  double blink = 0,
  bool mouthOpen = false,
}) {
  final eyeY = c.dy - 2 * s;
  for (final dx in [-12.0, 12.0]) {
    final eye = Offset(c.dx + dx * s, eyeY);
    final open = (1 - blink).clamp(0.08, 1.0);
    final rect = Rect.fromCenter(
      center: eye,
      width: 11 * s,
      height: 13 * s * open,
    );
    canvas.drawOval(rect, _fill(Colors.white));
    canvas.drawOval(rect, _line(1.8 * s));
    if (open > 0.3) {
      final look = mood == Mood.thinking
          ? Offset(2.2 * s, -2 * s)
          : Offset.zero;
      canvas.drawCircle(
        eye + look + Offset(0, 1 * s),
        3.4 * s,
        _fill(Toon.ink),
      );
      canvas.drawCircle(
        eye + look + Offset(1.2 * s, -0.6 * s),
        1.1 * s,
        _fill(Colors.white),
      );
    }
    // Eyebrows carry most of the emotion.
    final side = dx.sign;
    final (inner, outer) = switch (mood) {
      Mood.worried => (-13.0, -9.5),
      Mood.surprised => (-14.5, -14.5),
      Mood.thinking => side > 0 ? (-14.0, -15.5) : (-10.5, -10.5),
      Mood.happy || Mood.cheer => (-11.5, -12.5),
      Mood.neutral => (-11.0, -11.0),
    };
    canvas.drawLine(
      Offset(eye.dx - side * 2 * s, eyeY + inner * s),
      Offset(eye.dx + side * 6 * s, eyeY + outer * s),
      _line(2.2 * s),
    );
  }

  // Cheeks.
  final blush = _fill(const Color(0x55FF6F7F));
  canvas.drawCircle(Offset(c.dx - 17 * s, c.dy + 8 * s), 4.5 * s, blush);
  canvas.drawCircle(Offset(c.dx + 17 * s, c.dy + 8 * s), 4.5 * s, blush);

  final m = Offset(c.dx, c.dy + 12 * s);
  final open = mouthOpen || mood == Mood.cheer || mood == Mood.surprised;
  switch (mood) {
    case Mood.worried:
      final path = Path()
        ..moveTo(m.dx - 7 * s, m.dy + 3 * s)
        ..quadraticBezierTo(m.dx, m.dy - 4 * s, m.dx + 7 * s, m.dy + 3 * s);
      canvas.drawPath(path, _line(2.2 * s));
    case Mood.surprised:
      final r = Rect.fromCenter(center: m, width: 8 * s, height: 10 * s);
      canvas.drawOval(r, _fill(const Color(0xFF7A2E2E)));
      canvas.drawOval(r, _line(1.8 * s));
    case Mood.thinking:
      canvas.drawLine(
        Offset(m.dx - 4 * s, m.dy + 1 * s),
        Offset(m.dx + 6 * s, m.dy - 1 * s),
        _line(2.2 * s),
      );
    case Mood.neutral || Mood.happy || Mood.cheer:
      if (open) {
        final w = mood == Mood.cheer ? 10.0 : 8.0;
        final path = Path()
          ..moveTo(m.dx - w * s, m.dy - 2 * s)
          ..quadraticBezierTo(m.dx, m.dy + 14 * s, m.dx + w * s, m.dy - 2 * s)
          ..close();
        canvas.drawPath(path, _fill(const Color(0xFF7A2E2E)));
        canvas.drawCircle(
          Offset(m.dx, m.dy + 5 * s),
          3.2 * s,
          _fill(const Color(0xFFFF8A8A)),
        );
        canvas.drawPath(path, _line(1.8 * s));
      } else {
        final w = mood == Mood.neutral ? 5.0 : 7.0;
        final path = Path()
          ..moveTo(m.dx - w * s, m.dy - 1 * s)
          ..quadraticBezierTo(
            m.dx,
            m.dy + (mood == Mood.neutral ? 3 : 6) * s,
            m.dx + w * s,
            m.dy - 1 * s,
          );
        canvas.drawPath(path, _line(2.2 * s));
      }
  }
}

double _bob(Animation<double>? clock) =>
    clock == null ? 0 : sin(clock.value * 2 * pi) * 2.2;

double _blink(Animation<double>? clock) {
  if (clock == null) return 0;
  final t = clock.value;
  return t > 0.9 && t < 0.95 ? 1 : 0;
}

bool _talkOpen(Animation<double>? clock, bool talking) =>
    talking && clock != null && (clock.value * 26).floor().isEven;

class _CharacterPainter extends CustomPainter {
  _CharacterPainter({
    required this.look,
    required this.mood,
    required this.talking,
    this.clock,
    this.headOnly = false,
  }) : super(repaint: clock);

  final CharacterLook look;
  final Mood mood;
  final bool talking;
  final Animation<double>? clock;
  final bool headOnly;

  @override
  void paint(Canvas canvas, Size size) {
    if (headOnly) {
      // Frame the head inside a square.
      final s = size.width / 80;
      canvas.scale(s);
      canvas.translate(-20, -18);
      _hairBack(canvas);
      _head(canvas, 0);
      return;
    }
    canvas.scale(size.width / 120, size.height / 200);
    final bob = _bob(clock);

    // Shadow on the ground.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(60, 194), width: 70, height: 10),
      _fill(Colors.black.withValues(alpha: 0.15)),
    );

    // Legs and shoes.
    final legBottom = 186.0;
    for (final x in [48.0, 72.0]) {
      _limb(
        canvas,
        [Offset(x, 146 + bob), Offset(x, legBottom)],
        look.bottom,
        13,
      );
      _shape(
        canvas,
        Path()..addOval(
          Rect.fromCenter(
            center: Offset(x + (x < 60 ? -3 : 3), legBottom + 3),
            width: 20,
            height: 10,
          ),
        ),
        Toon.ink,
      );
    }

    canvas.save();
    canvas.translate(0, bob);
    _hairBack(canvas);
    _arms(canvas, behind: true);
    // Torso.
    final torso = Path()
      ..moveTo(38, 94)
      ..quadraticBezierTo(60, 86, 82, 94)
      ..lineTo(90, 150)
      ..quadraticBezierTo(60, 156, 30, 150)
      ..close();
    _shape(canvas, torso, look.top);
    // Collar.
    canvas.drawPath(
      Path()
        ..moveTo(52, 92)
        ..lineTo(60, 102)
        ..lineTo(68, 92),
      _line(2.2),
    );
    _arms(canvas, behind: false);
    _head(canvas, 0);
    canvas.restore();
  }

  void _arms(Canvas canvas, {required bool behind}) {
    final sleeve = look.top;
    final skin = look.skin;
    List<List<Offset>> arms;
    switch (mood) {
      case Mood.cheer:
        arms = [
          [const Offset(38, 100), const Offset(24, 80), const Offset(18, 56)],
          [const Offset(82, 100), const Offset(96, 80), const Offset(102, 56)],
        ];
      case Mood.thinking:
        arms = [
          [const Offset(38, 100), const Offset(30, 124), const Offset(30, 146)],
          [const Offset(82, 100), const Offset(96, 118), const Offset(74, 92)],
        ];
      case Mood.worried:
        arms = [
          [const Offset(38, 100), const Offset(26, 118), const Offset(36, 82)],
          [const Offset(82, 100), const Offset(94, 118), const Offset(84, 82)],
        ];
      case Mood.surprised:
        arms = [
          [const Offset(38, 100), const Offset(20, 112), const Offset(14, 96)],
          [
            const Offset(82, 100),
            const Offset(100, 112),
            const Offset(106, 96),
          ],
        ];
      case Mood.neutral || Mood.happy:
        arms = [
          [const Offset(38, 100), const Offset(30, 124), const Offset(28, 146)],
          [const Offset(82, 100), const Offset(90, 124), const Offset(92, 146)],
        ];
    }
    // Raised hands are drawn in front of the torso; resting arms behind.
    final front = mood != Mood.neutral && mood != Mood.happy;
    if (behind == front) return;
    for (final arm in arms) {
      _limb(canvas, arm, sleeve, 11);
      _circle(canvas, arm.last, 6, skin);
    }
  }

  void _hairBack(Canvas canvas) {
    final h = look.hairColor;
    switch (look.hair) {
      case HairStyle.long:
        _shape(
          canvas,
          Path()..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(28, 46, 64, 58),
              const Radius.circular(18),
            ),
          ),
          h,
        );
      case HairStyle.braid:
        for (var i = 0; i < 4; i++) {
          _circle(canvas, Offset(84 + i * 1.5, 82 + i * 11), 6.5, h);
        }
      case HairStyle.ponytail:
        _shape(canvas, Path()..addOval(Rect.fromLTWH(82, 40, 16, 40)), h);
      case HairStyle.bun:
        _circle(canvas, const Offset(60, 22), 11, h);
      case HairStyle.short || HairStyle.curly:
        break;
    }
  }

  void _head(Canvas canvas, double dy) {
    const c = Offset(60, 58);
    // Neck and ears.
    _shape(
      canvas,
      Path()..addRect(const Rect.fromLTWH(54, 80, 12, 12)),
      look.skin,
    );
    _circle(canvas, const Offset(31, 60), 6, look.skin);
    _circle(canvas, const Offset(89, 60), 6, look.skin);
    _circle(canvas, c, 29, look.skin);

    // Hair on top.
    final h = look.hairColor;
    if (look.hair == HairStyle.curly) {
      for (var i = 0; i < 9; i++) {
        final a = pi + i * pi / 8;
        _circle(canvas, c + Offset(cos(a) * 27, sin(a) * 24 - 4), 9, h);
      }
    } else {
      final top = Path()
        ..moveTo(30, 62)
        ..cubicTo(26, 22, 94, 22, 90, 62)
        ..quadraticBezierTo(82, 46, 66, 44)
        ..quadraticBezierTo(52, 50, 38, 44)
        ..quadraticBezierTo(32, 50, 30, 62)
        ..close();
      _shape(canvas, top, h);
    }

    switch (look.accessory) {
      case Accessory.bindi:
        canvas.drawCircle(const Offset(60, 46), 2.2, _fill(Toon.berry));
      case Accessory.cap:
        final cap = Path()
          ..moveTo(30, 46)
          ..cubicTo(30, 16, 90, 16, 90, 46)
          ..close();
        _shape(canvas, cap, Toon.berry);
        _shape(
          canvas,
          Path()..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(56, 40, 40, 8),
              const Radius.circular(4),
            ),
          ),
          darken(Toon.berry),
        );
      case Accessory.glasses || Accessory.none:
        break;
    }

    drawFace(
      canvas,
      c + const Offset(0, 4),
      1,
      mood,
      blink: _blink(clock),
      mouthOpen: _talkOpen(clock, talking),
    );

    if (look.accessory == Accessory.glasses) {
      final g = _line(2.2);
      canvas.drawCircle(const Offset(48, 60), 9, g);
      canvas.drawCircle(const Offset(72, 60), 9, g);
      canvas.drawLine(const Offset(57, 60), const Offset(63, 60), g);
    }
  }

  @override
  bool shouldRepaint(_CharacterPainter old) =>
      old.look != look || old.mood != mood || old.talking != talking;
}

class _MascotPainter extends CustomPainter {
  _MascotPainter({required this.mood, required this.talking, this.clock})
    : super(repaint: clock);

  final Mood mood;
  final bool talking;
  final Animation<double>? clock;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120, size.height / 120);
    // Hops a little higher when cheering.
    final bob = _bob(clock) * (mood == Mood.cheer ? 2.2 : 1);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(60, 114), width: 64, height: 9),
      _fill(Colors.black.withValues(alpha: 0.15)),
    );
    canvas.translate(0, bob);

    // Little feet.
    _circle(canvas, const Offset(44, 108), 7, Toon.clayDark);
    _circle(canvas, const Offset(76, 108), 7, Toon.clayDark);

    if (mood == Mood.cheer) {
      _limb(canvas, [const Offset(22, 70), const Offset(8, 46)], Toon.clay, 9);
      _limb(
        canvas,
        [const Offset(98, 70), const Offset(112, 46)],
        Toon.clay,
        9,
      );
    } else {
      _limb(canvas, [const Offset(20, 72), const Offset(12, 88)], Toon.clay, 9);
      _limb(
        canvas,
        [const Offset(100, 72), const Offset(108, 88)],
        Toon.clay,
        9,
      );
    }

    // Pot body.
    final body = Rect.fromCenter(
      center: const Offset(60, 70),
      width: 88,
      height: 76,
    );
    _shape(canvas, Path()..addOval(body), Toon.clay);
    // Painted band.
    canvas.save();
    canvas.clipPath(Path()..addOval(body));
    canvas.drawRect(const Rect.fromLTWH(10, 48, 100, 9), _fill(Toon.clayDark));
    for (var x = 18.0; x < 104; x += 12) {
      canvas.drawCircle(Offset(x, 52.5), 2.2, _fill(Toon.gold));
    }
    canvas.drawOval(
      Rect.fromLTWH(26, 40, 22, 12),
      _fill(Colors.white.withValues(alpha: 0.25)),
    );
    canvas.restore();
    canvas.drawOval(body, _line(2.6));

    // Neck, rim and coin slot.
    _shape(
      canvas,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(40, 22, 40, 14),
          const Radius.circular(5),
        ),
      ),
      Toon.clay,
    );
    _shape(
      canvas,
      Path()..addOval(
        Rect.fromCenter(center: const Offset(60, 22), width: 52, height: 12),
      ),
      Toon.clayLight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(60, 22), width: 22, height: 4),
        const Radius.circular(2),
      ),
      _fill(Toon.ink),
    );

    drawFace(
      canvas,
      const Offset(60, 76),
      0.95,
      mood,
      blink: _blink(clock),
      mouthOpen: _talkOpen(clock, talking),
    );
  }

  @override
  bool shouldRepaint(_MascotPainter old) =>
      old.mood != mood || old.talking != talking;
}
