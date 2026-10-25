import 'dart:convert';

/// One line in Asha's fictional money diary. Every change to a balance is
/// recorded here, so screens never keep their own copy of the numbers.
class Txn {
  const Txn({
    required this.chapter,
    required this.account,
    required this.label,
    required this.amount,
    required this.balanceAfter,
  });

  factory Txn.fromJson(Map<String, Object?> json) => Txn(
    chapter: _int(json['c']),
    account: json['a'] is String ? json['a']! as String : 'wallet',
    label: json['l'] is String ? json['l']! as String : 'txn_other',
    amount: _int(json['m']),
    balanceAfter: _int(json['b']),
  );

  final int chapter;

  /// `wallet`, `jar`, `bank`, `fd` or `credit`.
  final String account;

  /// Text key for the description (for example `txn_deposit`).
  final String label;

  /// Signed: positive is money in.
  final int amount;
  final int balanceAfter;

  Map<String, Object?> toJson() => {
    'c': chapter,
    'a': account,
    'l': label,
    'm': amount,
    'b': balanceAfter,
  };
}

int _int(Object? v, [int fallback = 0]) => v is int ? v : fallback;

/// The whole Money Diaries simulation for one profile: the single source of
/// truth for balances, decisions and progress. Immutable; every change goes
/// through `StoryRules`.
class StoryState {
  const StoryState({
    this.chapter = 1,
    this.beat = 0,
    this.wallet = 0,
    this.jar = 0,
    this.bank = 0,
    this.fd = 0,
    this.debt = 0,
    this.creditPlan = 0,
    this.interestPaid = 0,
    this.monthlySave = 0,
    this.goalId,
    this.goalTarget = 0,
    this.hints = 0,
    this.score = 0,
    this.maxScore = 0,
    this.flags = const {},
    this.nums = const {},
    this.txns = const [],
    this.done = const {},
  });

  static const chapterCount = 7;

  /// Tolerant parser: unknown or damaged values fall back to defaults so a
  /// corrupted save can never crash the game.
  factory StoryState.fromJson(Map<String, Object?> json) {
    Map<String, T> map<T>(Object? raw) => raw is Map
        ? {
            for (final e in raw.entries)
              if (e.key is String && e.value is T)
                e.key as String: e.value as T,
          }
        : const {};
    final rawTxns = json['txns'];
    final rawDone = json['done'];
    return StoryState(
      chapter: _int(json['chapter'], 1).clamp(1, chapterCount + 1),
      beat: _int(json['beat']).clamp(0, 999),
      wallet: _int(json['wallet']).clamp(0, 1 << 30),
      jar: _int(json['jar']).clamp(0, 1 << 30),
      bank: _int(json['bank']).clamp(0, 1 << 30),
      fd: _int(json['fd']).clamp(0, 1 << 30),
      debt: _int(json['debt']).clamp(0, 1 << 30),
      creditPlan: _int(json['creditPlan']).clamp(0, 1 << 30),
      interestPaid: _int(json['interestPaid']).clamp(0, 1 << 30),
      monthlySave: _int(json['monthlySave']).clamp(0, 1 << 30),
      goalId: json['goalId'] is String ? json['goalId']! as String : null,
      goalTarget: _int(json['goalTarget']).clamp(0, 1 << 30),
      hints: _int(json['hints']).clamp(0, 1 << 30),
      score: _int(json['score']).clamp(0, 1 << 30),
      maxScore: _int(json['maxScore']).clamp(0, 1 << 30),
      flags: map<String>(json['flags']),
      nums: map<int>(json['nums']),
      txns: [
        if (rawTxns is List)
          for (final t in rawTxns)
            if (t is Map) Txn.fromJson(t.cast<String, Object?>()),
      ],
      done: {
        if (rawDone is Map)
          for (final e in rawDone.entries)
            if (int.tryParse('${e.key}') != null && e.value is int)
              int.parse('${e.key}'): (e.value as int).clamp(1, 3),
      },
    );
  }

  static StoryState decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is Map) return StoryState.fromJson(json.cast<String, Object?>());
    } on FormatException {
      // Fall through to a fresh story.
    }
    return const StoryState();
  }

  /// Chapter being played (1–7); 8 once the story is finished.
  final int chapter;

  /// Index of the current beat in that chapter's script (the checkpoint).
  final int beat;

  /// Cash in hand.
  final int wallet;

  /// The clay gullak at home (chapters 1–2).
  final int jar;

  /// Fictional savings-account balance (chapter 3 onwards).
  final int bank;

  /// Money locked in the fictional fixed deposit.
  final int fd;

  /// Borrowed money still owed on the fictional store credit.
  final int debt;

  /// Monthly repayment the player chose.
  final int creditPlan;
  final int interestPaid;

  /// Saving habit carried from chapter 2 into the month-by-month chapters.
  final int monthlySave;
  final String? goalId;
  final int goalTarget;
  final int hints;

  /// Points for thoughtful decisions in the current chapter (never for the
  /// amount of money held).
  final int score;
  final int maxScore;

  /// Decisions that later dialogue and events react to.
  final Map<String, String> flags;

  /// Numbers shown in feedback text (for example `c1_left`).
  final Map<String, int> nums;
  final List<Txn> txns;

  /// Completed chapters → stars earned in the story run.
  final Map<int, int> done;

  bool get finished => chapter > chapterCount;

  /// Everything Asha has put aside, wherever it is kept.
  int get savings => jar + bank + fd;

  int get stars =>
      maxScore == 0 ? 3 : ((score * 3 / maxScore).round()).clamp(1, 3);

  bool has(String flag) => flags.containsKey(flag);
  String? flag(String key) => flags[key];
  int n(String key) => nums[key] ?? 0;

  StoryState copyWith({
    int? chapter,
    int? beat,
    int? wallet,
    int? jar,
    int? bank,
    int? fd,
    int? debt,
    int? creditPlan,
    int? interestPaid,
    int? monthlySave,
    String? goalId,
    int? goalTarget,
    int? hints,
    int? score,
    int? maxScore,
    Map<String, String>? flags,
    Map<String, int>? nums,
    List<Txn>? txns,
    Map<int, int>? done,
  }) => StoryState(
    chapter: chapter ?? this.chapter,
    beat: beat ?? this.beat,
    wallet: wallet ?? this.wallet,
    jar: jar ?? this.jar,
    bank: bank ?? this.bank,
    fd: fd ?? this.fd,
    debt: debt ?? this.debt,
    creditPlan: creditPlan ?? this.creditPlan,
    interestPaid: interestPaid ?? this.interestPaid,
    monthlySave: monthlySave ?? this.monthlySave,
    goalId: goalId ?? this.goalId,
    goalTarget: goalTarget ?? this.goalTarget,
    hints: hints ?? this.hints,
    score: score ?? this.score,
    maxScore: maxScore ?? this.maxScore,
    flags: flags ?? this.flags,
    nums: nums ?? this.nums,
    txns: txns ?? this.txns,
    done: done ?? this.done,
  );

  StoryState withFlag(String key, String value) =>
      copyWith(flags: {...flags, key: value});

  StoryState withNum(String key, int value) =>
      copyWith(nums: {...nums, key: value});

  StoryState scored(int got, int max) =>
      copyWith(score: score + got.clamp(0, max), maxScore: maxScore + max);

  Map<String, Object?> toJson() => {
    'chapter': chapter,
    'beat': beat,
    'wallet': wallet,
    'jar': jar,
    'bank': bank,
    'fd': fd,
    'debt': debt,
    'creditPlan': creditPlan,
    'interestPaid': interestPaid,
    'monthlySave': monthlySave,
    'goalId': goalId,
    'goalTarget': goalTarget,
    'hints': hints,
    'score': score,
    'maxScore': maxScore,
    'flags': flags,
    'nums': nums,
    'txns': [for (final t in txns) t.toJson()],
    'done': {for (final e in done.entries) '${e.key}': e.value},
  };

  String encode() => jsonEncode(toJson());
}
