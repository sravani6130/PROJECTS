import 'dart:math';

final _random = Random.secure();

/// Random 128-bit hex identifier for attempts. Attempt IDs only need to be
/// unique on one device, so no UUID package is needed.
String newAttemptId() {
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i++) {
    buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

/// ISO-8601 UTC timestamp, the format used for every TEXT time column.
String isoNow(Clock clock) => clock().toUtc().toIso8601String();

/// Injectable time source so repositories and tests are deterministic.
typedef Clock = DateTime Function();
