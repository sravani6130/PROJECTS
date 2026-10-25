import 'money_format.dart';

final _placeholder = RegExp(r'\{(\w+)\}');

/// Replaces `{name}` placeholders. Integer values get Indian digit grouping;
/// the template itself decides whether a ₹ sign or "coins" is shown.
/// Unknown placeholders are left untouched so missing data is visible in QA.
String fillTemplate(String template, Map<String, Object> values) {
  return template.replaceAllMapped(_placeholder, (match) {
    final value = values[match.group(1)];
    if (value == null) return match.group(0)!;
    if (value is int) return formatAmount(value);
    return value.toString();
  });
}
