/// Kinds of in-app notification. Each has a translation key `inbox_<name>`
/// whose `{placeholders}` are filled from the message's params.
enum InboxKind {
  checkIn,
  streak,
  weekBonus,
  chapterDone,
  storyDone,
  badge;

  static InboxKind? parse(String name) =>
      values.where((k) => k.name == name).firstOrNull;
}

class InboxMessage {
  const InboxMessage({
    required this.id,
    required this.kind,
    required this.params,
    required this.createdAt,
    required this.read,
  });

  final int id;
  final InboxKind kind;
  final Map<String, Object> params;
  final DateTime createdAt;
  final bool read;
}
