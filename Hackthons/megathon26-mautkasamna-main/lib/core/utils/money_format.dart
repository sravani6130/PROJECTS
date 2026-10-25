/// Formats an integer with Indian digit grouping (12,34,567).
///
/// All amounts in the app are fictional whole rupees or coins, so there is no
/// decimal handling.
String formatAmount(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  if (digits.length <= 3) return negative ? '-$digits' : digits;

  final lastThree = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  final grouped = '${groups.join(',')},$lastThree';
  return negative ? '-$grouped' : grouped;
}

String formatRupees(int value) => '₹${formatAmount(value)}';
