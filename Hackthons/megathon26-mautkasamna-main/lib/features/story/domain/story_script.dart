import 'story_state.dart';

typedef StoryTest = bool Function(StoryState s);

/// One step of a chapter. Beats with a failing [when] are skipped, which is
/// how earlier decisions change later scenes.
sealed class Beat {
  const Beat({this.when});

  final StoryTest? when;
}

/// A spoken line. [who] is a cast id, [text] a story text key and [mood] a
/// character expression name.
class Line {
  const Line(this.who, this.text, {this.mood = 'neutral', this.when});

  final String who;
  final String text;
  final String mood;
  final StoryTest? when;
}

/// A short illustrated conversation.
class Talk extends Beat {
  const Talk(this.lines, {this.scene, super.when});

  final List<Line> lines;

  /// Backdrop override; the chapter's scene is used otherwise.
  final String? scene;
}

class Opt {
  const Opt(
    this.id,
    this.label,
    this.result, {
    this.tone = 'okay',
    this.prop,
    this.enabled,
    this.retry = false,
  });

  final String id;
  final String label;

  /// Consequence shown after the player commits.
  final String result;

  /// `best`, `okay` or `risky`: picks the heading and character reaction.
  final String tone;
  final String? prop;
  final StoryTest? enabled;

  /// Shows the consequence but lets the player choose again.
  final bool retry;
}

/// A story decision with a visible consequence.
class Pick extends Beat {
  const Pick(this.id, this.who, this.prompt, this.options, {super.when});

  final String id;
  final String who;
  final String prompt;
  final List<Opt> options;
}

/// An interactive activity, drawn by the widget registered for [id].
class Play extends Beat {
  const Play(this.id, {super.when});

  final String id;
}

/// Gullu explains the idea behind what just happened.
class Teach extends Beat {
  const Teach(this.points);

  final List<String> points;
}

class Fact {
  const Fact(this.text, {this.when});

  final String text;
  final StoryTest? when;
}

/// Chapter summary; finishing it completes the chapter.
class Recap extends Beat {
  const Recap(this.facts);

  final List<Fact> facts;
}

class Chapter {
  const Chapter(this.number, this.scene, this.beats);

  final int number;
  final String scene;
  final List<Beat> beats;

  String get id => 'C$number';
  String get titleKey => 'c${number}_title';
  String get summaryKey => 'c${number}_summary';

  /// Index of the first beat at or after [from] that applies to [s].
  int nextBeat(StoryState s, int from) {
    var i = from;
    while (i < beats.length && !(beats[i].when?.call(s) ?? true)) {
      i++;
    }
    return i;
  }
}

bool _credit(StoryState s) => s.flag('c5_method') == 'credit';
bool _safeOnM3(StoryState s) =>
    s.flag('c4_m3') == 'verify' || s.flag('c4_m3') == 'report';

/// The Money Diaries: seven chapters of one connected story.
final List<Chapter> storyChapters = [
  Chapter(1, 'home', [
    const Talk([
      Line('amma', 'c1_a1', mood: 'happy'),
      Line('asha', 'c1_a2', mood: 'happy'),
      Line('asha', 'c1_a3', mood: 'thinking'),
      Line('asha', 'c1_a4', mood: 'worried'),
      Line('amma', 'c1_a5'),
      Line('gullu', 'c1_a6', mood: 'cheer'),
    ]),
    const Play('c1_budget'),
    Talk([
      Line(
        'asha',
        'c1_b_zero',
        mood: 'worried',
        when: (s) => s.n('c1_left') == 0,
      ),
      Line('ravi', 'c1_b_movie', mood: 'happy', when: (s) => s.has('c1_movie')),
      Line(
        'ravi',
        'c1_b_none',
        mood: 'surprised',
        when: (s) =>
            !s.has('c1_movie') && !s.has('c1_headphones') && !s.has('c1_chaat'),
      ),
      Line(
        'asha',
        'c1_b_phones',
        mood: 'happy',
        when: (s) => s.has('c1_headphones'),
      ),
      const Line('farida', 'c1_b_form'),
    ]),
    Pick('c1_form', 'asha', 'c1_form_prompt', [
      Opt(
        'own',
        'c1_form_own',
        'c1_form_own_r',
        tone: 'best',
        prop: 'coin',
        enabled: (s) => s.wallet >= 60,
      ),
      const Opt(
        'advance',
        'c1_form_advance',
        'c1_form_advance_r',
        prop: 'calendar',
      ),
      const Opt(
        'skip',
        'c1_form_skip',
        'c1_form_skip_r',
        tone: 'risky',
        prop: 'ticket',
        retry: true,
      ),
    ]),
    const Play('c1_sort'),
    const Teach(['c1_teach_1', 'c1_teach_2', 'c1_teach_3', 'c1_teach_4']),
    const Recap([Fact('c1_wrap_1'), Fact('c1_wrap_2')]),
  ]),
  Chapter(2, 'college', [
    const Talk([
      Line('nanna', 'c2_a1', mood: 'happy'),
      Line('asha', 'c2_a2', mood: 'cheer'),
      Line('ravi', 'c2_a3'),
      Line('farida', 'c2_a4', mood: 'happy'),
    ]),
    const Play('c2_goal'),
    Talk([
      const Line('gullu', 'c2_b1', mood: 'happy'),
      Line('amma', 'c2_b_advance', when: (s) => s.n('c1_advance') > 0),
    ]),
    const Play('c2_week1'),
    const Talk([Line('ravi', 'c2_c1', mood: 'cheer')]),
    const Pick('c2_treat', 'asha', 'c2_treat_prompt', [
      Opt('join', 'c2_treat_join', 'c2_treat_join_r', prop: 'tiffin'),
      Opt('small', 'c2_treat_small', 'c2_treat_small_r', prop: 'samosa'),
      Opt('skip', 'c2_treat_skip', 'c2_treat_skip_r', prop: 'jar'),
    ]),
    const Play('c2_week2'),
    const Talk([
      Line('farida', 'c2_d1'),
      Line('asha', 'c2_d2', mood: 'thinking'),
    ]),
    const Play('c2_week3'),
    const Play('c2_week4'),
    const Teach(['c2_teach_1', 'c2_teach_2', 'c2_teach_3', 'c2_teach_4']),
    const Recap([Fact('c2_wrap_1'), Fact('c2_wrap_2'), Fact('c2_wrap_3')]),
  ]),
  Chapter(3, 'bank', [
    const Talk([
      Line('amma', 'c3_a1', mood: 'happy'),
      Line('lakshmi', 'c3_a2', mood: 'happy'),
      Line('nanna', 'c3_a3'),
      Line('lakshmi', 'c3_a4'),
    ]),
    const Play('c3_open'),
    const Talk([Line('lakshmi', 'c3_b1', mood: 'happy')]),
    const Play('c3_bank'),
    const Talk([
      Line('farida', 'c3_c1'),
      Line('asha', 'c3_c2', mood: 'cheer'),
    ], scene: 'college'),
    const Play('c3_pending'),
    Talk([
      Line(
        'lakshmi',
        'c3_d_verify',
        mood: 'happy',
        when: (s) => s.flag('c3_pending') == 'verify',
      ),
      Line(
        'farida',
        'c3_d_double',
        mood: 'surprised',
        when: (s) => s.flag('c3_pending') == 'double',
      ),
      Line(
        'farida',
        'c3_d_cash',
        mood: 'surprised',
        when: (s) => s.flag('c3_pending') == 'cash',
      ),
      Line(
        'gullu',
        'c3_d_lesson',
        when: (s) => s.flag('c3_pending') != 'verify',
      ),
    ]),
    const Teach(['c3_teach_1', 'c3_teach_2', 'c3_teach_3', 'c3_teach_4']),
    const Recap([Fact('c3_wrap_1'), Fact('c3_wrap_2'), Fact('c3_wrap_3')]),
  ]),
  Chapter(4, 'night', [
    const Talk([
      Line('asha', 'c4_a1', mood: 'thinking'),
      Line('gullu', 'c4_a2'),
      Line('asha', 'c4_a3', mood: 'surprised'),
    ]),
    const Play('c4_inbox'),
    Play('c4_recover', when: (s) => s.n('c4_unsafe') > 0),
    Talk([
      Line(
        'ravi',
        'c4_b_ravi_safe',
        mood: 'surprised',
        when: (s) => s.flag('c4_m4') == 'verify',
      ),
      Line(
        'ravi',
        'c4_b_ravi_unsafe',
        mood: 'worried',
        when: (s) => s.flag('c4_m4') == 'proceed',
      ),
      const Line('farida', 'c4_b_farida', mood: 'happy', when: _safeOnM3),
      Line('amma', 'c4_b_amma', when: (s) => s.n('c4_unsafe') > 0),
      Line(
        'gullu',
        'c4_b_clean',
        mood: 'cheer',
        when: (s) => s.n('c4_unsafe') == 0,
      ),
    ]),
    const Play('c4_rules'),
    const Teach(['c4_teach_1', 'c4_teach_2', 'c4_teach_3', 'c4_teach_4']),
    const Recap([Fact('c4_wrap_1'), Fact('c4_wrap_2')]),
  ]),
  Chapter(5, 'shop', [
    const Talk([
      Line('imran', 'c5_a1', mood: 'happy'),
      Line('imran', 'c5_a2'),
      Line('asha', 'c5_a3', mood: 'thinking'),
      Line('imran', 'c5_a4'),
      Line('gullu', 'c5_a5'),
    ]),
    const Play('c5_shop'),
    Talk([
      Line('farida', 'c5_b_wait1', when: (s) => s.flag('c5_item') == 'wait'),
      Line(
        'asha',
        'c5_b_wait2',
        mood: 'happy',
        when: (s) => s.flag('c5_item') == 'wait',
      ),
      Line(
        'asha',
        'c5_b_own',
        mood: 'cheer',
        when: (s) => s.flag('c5_item') != 'wait' && !_credit(s),
      ),
      const Line('imran', 'c5_b_credit', when: _credit),
      Line('imran', 'c5_b_sample', when: (s) => !_credit(s)),
    ]),
    const Play('c5_statement'),
    const Teach(['c5_teach_1', 'c5_teach_2', 'c5_teach_3', 'c5_teach_4']),
    Recap([
      Fact('c5_wrap_wait', when: (s) => s.flag('c5_item') == 'wait'),
      Fact('c5_wrap_lite', when: (s) => s.flag('c5_item') == 'lite'),
      Fact('c5_wrap_nova', when: (s) => s.flag('c5_item') == 'nova'),
      const Fact('wrap_bank'),
      Fact('wrap_debt', when: (s) => s.debt > 0),
    ]),
  ]),
  Chapter(6, 'bank', [
    const Talk([
      Line('lakshmi', 'c6_a1', mood: 'happy'),
      Line('asha', 'c6_a2', mood: 'surprised'),
      Line('lakshmi', 'c6_a3'),
      Line('gullu', 'c6_a4'),
    ]),
    const Play('c6_compare'),
    const Play('c6_fd'),
    Talk([
      const Line('gullu', 'c6_b1', mood: 'happy'),
      Line('gullu', 'c6_b_debt', when: (s) => s.debt > 0),
    ]),
    const Play('c6_time'),
    Talk([
      Line(
        'lakshmi',
        'c6_c_savings',
        mood: 'happy',
        when: (s) => s.flag('c6_event') == 'savings',
      ),
      Line('lakshmi', 'c6_c_break', when: (s) => s.flag('c6_event') == 'break'),
      Line(
        'amma',
        'c6_c_family',
        mood: 'happy',
        when: (s) => s.flag('c6_event') == 'family',
      ),
    ]),
    const Teach(['c6_teach_1', 'c6_teach_2', 'c6_teach_3', 'c6_teach_4']),
    Recap([
      const Fact('c6_wrap_1'),
      const Fact('c6_wrap_2'),
      const Fact('wrap_bank'),
      Fact('wrap_debt', when: (s) => s.debt > 0),
    ]),
  ]),
  Chapter(7, 'home', [
    const Talk([
      Line('asha', 'c7_a1', mood: 'cheer'),
      Line('amma', 'c7_a2', mood: 'worried'),
      Line('nanna', 'c7_a3'),
      Line('asha', 'c7_a4', mood: 'thinking'),
      Line('gullu', 'c7_a5'),
    ]),
    const Play('c7_policy'),
    Talk([
      Line(
        'nanna',
        'c7_b_tried',
        mood: 'worried',
        when: (s) => s.flag('c7_claim') == 'tried',
      ),
      Line(
        'nanna',
        'c7_b_right',
        mood: 'happy',
        when: (s) => s.flag('c7_claim') != 'tried',
      ),
      const Line('amma', 'c7_b_addon', mood: 'thinking'),
    ]),
    const Pick('c7_addon', 'asha', 'c7_addon_prompt', [
      Opt('keep', 'c7_addon_keep', 'c7_addon_keep_r', prop: 'shield'),
      Opt('addon', 'c7_addon_add', 'c7_addon_add_r', prop: 'medkit'),
      Opt(
        'drop',
        'c7_addon_drop',
        'c7_addon_drop_r',
        tone: 'risky',
        prop: 'coin',
      ),
    ]),
    const Talk([Line('amma', 'c7_c1')]),
    const Play('c7_plan'),
    Talk([
      const Line('farida', 'c7_d1', mood: 'cheer'),
      Line(
        'asha',
        'c7_d_nova',
        mood: 'happy',
        when: (s) => s.flag('c5_item') == 'nova',
      ),
      Line(
        'asha',
        'c7_d_lite',
        mood: 'happy',
        when: (s) => s.flag('c5_item') == 'lite',
      ),
      Line(
        'asha',
        'c7_d_wait',
        mood: 'happy',
        when: (s) => s.flag('c5_item') == 'wait',
      ),
      const Line('ravi', 'c7_d2', mood: 'cheer'),
      Line('asha', 'c7_d_debt', mood: 'thinking', when: (s) => s.debt > 0),
      Line(
        'nanna',
        'c7_d_share',
        mood: 'happy',
        when: (s) => s.flag('c5_item') == 'wait' && s.savings >= 3000,
      ),
      Line('amma', 'c7_d_uncle', when: (s) => s.has('c7_uncle')),
      const Line('nanna', 'c7_d3', mood: 'happy'),
      const Line('gullu', 'c7_d4', mood: 'cheer'),
    ], scene: 'college'),
    const Teach(['c7_teach_1', 'c7_teach_2', 'c7_teach_3', 'c7_teach_4']),
    Recap([
      const Fact('c7_wrap_1'),
      const Fact('wrap_bank'),
      Fact('wrap_debt', when: (s) => s.debt > 0),
      Fact('c7_wrap_clear', when: (s) => s.debt == 0),
    ]),
  ]),
];

Chapter chapterByNumber(int number) =>
    storyChapters[(number - 1).clamp(0, storyChapters.length - 1)];
