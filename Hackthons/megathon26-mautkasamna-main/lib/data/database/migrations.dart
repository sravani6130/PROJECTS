import 'package:sqflite/sqflite.dart';

/// One forward-only schema change. Migrations run in version order inside the
/// transaction sqflite opens for onCreate/onUpgrade, so a failure leaves the
/// database at its previous version.
class Migration {
  const Migration(this.version, this.description, this.statements);

  final int version;
  final String description;
  final List<String> statements;

  Future<void> apply(DatabaseExecutor db) async {
    for (final sql in statements) {
      await db.execute(sql);
    }
  }
}

/// Runs every migration with `from < version <= to`.
Future<void> runMigrations(
  DatabaseExecutor db, {
  required int from,
  required int to,
  required List<Migration> migrations,
}) async {
  final pending =
      migrations.where((m) => m.version > from && m.version <= to).toList()
        ..sort((a, b) => a.version.compareTo(b.version));
  for (final migration in pending) {
    await migration.apply(db);
  }
}

/// Validates that versions are 1..n with no gaps or duplicates.
void checkMigrations(List<Migration> migrations) {
  for (var i = 0; i < migrations.length; i++) {
    if (migrations[i].version != i + 1) {
      throw StateError(
        'Migration ${i + 1} expected, found ${migrations[i].version}',
      );
    }
  }
}

/// Schema history. Never edit a released migration—append a new one.
///
/// Content (topics, missions, study packs, badges) lives in bundled JSON, so
/// `mission_id`, `topic_id` and `badge_id` are logical references validated by
/// the repositories, not SQL foreign keys. All learner rows belong to a
/// profile and are deleted with it (ON DELETE CASCADE).
const List<Migration> appMigrations = [
  Migration(1, 'Initial schema from the mid-submission ER design', [
    // Local profiles. A single guest row (is_guest = 1, no nickname) holds
    // progress for students who skip personalisation.
    '''
    CREATE TABLE profile (
      profile_id     INTEGER PRIMARY KEY AUTOINCREMENT,
      nickname       TEXT CHECK (nickname IS NULL OR length(nickname) BETWEEN 1 AND 20),
      is_guest       INTEGER NOT NULL DEFAULT 0 CHECK (is_guest IN (0, 1)),
      grade          INTEGER CHECK (grade IS NULL OR grade IN (11, 12)),
      avatar_id      TEXT,
      locale         TEXT NOT NULL DEFAULT 'en' CHECK (locale IN ('en', 'te')),
      start_level    TEXT NOT NULL DEFAULT 'easy'
                       CHECK (start_level IN ('easy', 'medium', 'advanced')),
      created_at     TEXT NOT NULL,
      last_active_at TEXT NOT NULL,
      CHECK ((is_guest = 1 AND nickname IS NULL) OR (is_guest = 0 AND nickname IS NOT NULL))
    )''',
    'CREATE UNIQUE INDEX ux_profile_single_guest ON profile(is_guest) WHERE is_guest = 1',
    'CREATE UNIQUE INDEX ux_profile_nickname ON profile(nickname COLLATE NOCASE) WHERE nickname IS NOT NULL',

    // Device-level state (exactly one row).
    '''
    CREATE TABLE app_state (
      id                INTEGER PRIMARY KEY CHECK (id = 1),
      locale            TEXT NOT NULL DEFAULT 'en' CHECK (locale IN ('en', 'te')),
      notice_accepted   INTEGER NOT NULL DEFAULT 0 CHECK (notice_accepted IN (0, 1)),
      active_profile_id INTEGER REFERENCES profile(profile_id) ON DELETE SET NULL,
      updated_at        TEXT NOT NULL
    )''',

    // One summary row per profile and mission; drives the mission map.
    '''
    CREATE TABLE mission_progress (
      profile_id         INTEGER NOT NULL REFERENCES profile(profile_id) ON DELETE CASCADE,
      mission_id         TEXT NOT NULL,
      status             TEXT NOT NULL CHECK (status IN ('in_progress', 'completed')),
      best_score         INTEGER NOT NULL DEFAULT 0 CHECK (best_score >= 0),
      max_score          INTEGER NOT NULL DEFAULT 0 CHECK (max_score >= 0),
      attempt_count      INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
      completion_count   INTEGER NOT NULL DEFAULT 0 CHECK (completion_count >= 0),
      first_completed_at TEXT,
      last_played_at     TEXT NOT NULL,
      PRIMARY KEY (profile_id, mission_id),
      CHECK (best_score <= max_score),
      CHECK (status <> 'completed' OR first_completed_at IS NOT NULL)
    )''',

    // One row per play-through. finished_at IS NULL marks an interrupted
    // attempt that can be resumed; at most one may be open per mission.
    '''
    CREATE TABLE attempt (
      attempt_id    TEXT PRIMARY KEY,
      profile_id    INTEGER NOT NULL REFERENCES profile(profile_id) ON DELETE CASCADE,
      mission_id    TEXT NOT NULL,
      start_balance INTEGER NOT NULL CHECK (start_balance >= 0),
      end_balance   INTEGER CHECK (end_balance IS NULL OR end_balance >= 0),
      score         INTEGER CHECK (score IS NULL OR score >= 0),
      max_score     INTEGER NOT NULL CHECK (max_score > 0),
      result        TEXT CHECK (result IS NULL OR result IN ('completed', 'abandoned')),
      started_at    TEXT NOT NULL,
      finished_at   TEXT,
      CHECK ((finished_at IS NULL) = (result IS NULL)),
      CHECK (score IS NULL OR score <= max_score)
    )''',
    'CREATE INDEX ix_attempt_profile_mission ON attempt(profile_id, mission_id)',
    'CREATE UNIQUE INDEX ux_attempt_one_open ON attempt(profile_id, mission_id) WHERE finished_at IS NULL',

    // Each submitted decision. The (attempt_id, decision_no) key rejects a
    // duplicate submission of the same decision (e.g. a double tap).
    '''
    CREATE TABLE attempt_decision (
      attempt_id    TEXT NOT NULL REFERENCES attempt(attempt_id) ON DELETE CASCADE,
      decision_no   INTEGER NOT NULL CHECK (decision_no >= 1),
      step_index    INTEGER NOT NULL CHECK (step_index >= 0),
      choice_ids    TEXT NOT NULL,
      verdict       TEXT NOT NULL CHECK (verdict IN ('best', 'okay', 'neutral', 'retry')),
      balance_after INTEGER NOT NULL CHECK (balance_after >= 0),
      decided_at    TEXT NOT NULL,
      PRIMARY KEY (attempt_id, decision_no)
    )''',
    // A finished attempt is immutable.
    '''
    CREATE TRIGGER trg_decision_requires_open_attempt
    BEFORE INSERT ON attempt_decision
    WHEN (SELECT finished_at FROM attempt WHERE attempt_id = NEW.attempt_id) IS NOT NULL
    BEGIN
      SELECT RAISE(ABORT, 'attempt already finished');
    END''',

    '''
    CREATE TABLE study_progress (
      profile_id      INTEGER NOT NULL REFERENCES profile(profile_id) ON DELETE CASCADE,
      topic_id        TEXT NOT NULL,
      theory_done     INTEGER NOT NULL DEFAULT 0 CHECK (theory_done IN (0, 1)),
      flashcards_seen INTEGER NOT NULL DEFAULT 0 CHECK (flashcards_seen >= 0),
      quiz_best       INTEGER CHECK (quiz_best IS NULL OR quiz_best >= 0),
      quiz_max        INTEGER CHECK (quiz_max IS NULL OR quiz_max > 0),
      recap_done      INTEGER NOT NULL DEFAULT 0 CHECK (recap_done IN (0, 1)),
      updated_at      TEXT NOT NULL,
      PRIMARY KEY (profile_id, topic_id),
      CHECK ((quiz_best IS NULL) = (quiz_max IS NULL)),
      CHECK (quiz_best IS NULL OR quiz_best <= quiz_max)
    )''',

    // Every quiz run. Only 'topic_quiz' is written in this build; the other
    // kinds are reserved for the planned level check and end-of-pillar check.
    '''
    CREATE TABLE assessment_result (
      result_id  INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES profile(profile_id) ON DELETE CASCADE,
      kind       TEXT NOT NULL CHECK (kind IN ('topic_quiz', 'level_check', 'end_check')),
      topic_id   TEXT,
      score      INTEGER NOT NULL CHECK (score >= 0),
      max_score  INTEGER NOT NULL CHECK (max_score > 0),
      taken_at   TEXT NOT NULL,
      CHECK (score <= max_score),
      CHECK (kind <> 'topic_quiz' OR topic_id IS NOT NULL)
    )''',
    'CREATE INDEX ix_assessment_profile_topic ON assessment_result(profile_id, topic_id)',

    // The composite key makes badge awards idempotent.
    '''
    CREATE TABLE badge_award (
      profile_id INTEGER NOT NULL REFERENCES profile(profile_id) ON DELETE CASCADE,
      badge_id   TEXT NOT NULL,
      awarded_at TEXT NOT NULL,
      PRIMARY KEY (profile_id, badge_id)
    )''',
  ]),
  Migration(2, 'The Money Diaries: one saved story per profile', [
    // The whole simulation (balances, decisions, checkpoint) is one JSON
    // document, so there is a single source of truth. `revision` rejects a
    // second write made from the same starting point (for example a double
    // tap). `chapter_starts` keeps the state at the start of each chapter so
    // a finished chapter can be replayed for practice without changing the
    // story. Chapter completion and stars reuse `mission_progress` with ids
    // C1..C7.
    '''
    CREATE TABLE story_save (
      profile_id     INTEGER PRIMARY KEY REFERENCES profile(profile_id) ON DELETE CASCADE,
      state_json     TEXT NOT NULL,
      chapter_starts TEXT NOT NULL DEFAULT '{}',
      revision       INTEGER NOT NULL DEFAULT 0 CHECK (revision >= 0),
      updated_at     TEXT NOT NULL
    )''',
  ]),
  Migration(3, 'Read aloud setting per profile', [
    // 'off', or the speaking pace. Defaults to slow narration because the
    // game is meant for students who find long reading hard.
    '''
    ALTER TABLE profile ADD COLUMN read_aloud TEXT NOT NULL DEFAULT 'slow'
      CHECK (read_aloud IN ('off', 'slow', 'normal'))''',
  ]),
  Migration(4, 'Daily check-in, inbox and reminders', [
    // One row per profile per local calendar day; the key makes a second
    // claim on the same day impossible. `streak` is the streak length that
    // day, so the current streak is read from the latest row.
    '''
    CREATE TABLE daily_checkin (
      profile_id INTEGER NOT NULL REFERENCES profile(profile_id) ON DELETE CASCADE,
      day        TEXT NOT NULL CHECK (length(day) = 10),
      reward     INTEGER NOT NULL CHECK (reward >= 0),
      bonus      INTEGER NOT NULL DEFAULT 0 CHECK (bonus >= 0),
      streak     INTEGER NOT NULL CHECK (streak >= 1),
      claimed_at TEXT NOT NULL,
      PRIMARY KEY (profile_id, day)
    )''',
    // In-app notifications. Text is stored as a translation key plus
    // parameters so it follows the language the player picks later.
    '''
    CREATE TABLE inbox (
      inbox_id   INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES profile(profile_id) ON DELETE CASCADE,
      kind       TEXT NOT NULL,
      params     TEXT NOT NULL DEFAULT '{}',
      created_at TEXT NOT NULL,
      read_at    TEXT
    )''',
    'CREATE INDEX ix_inbox_profile ON inbox(profile_id, inbox_id)',
    // Phone reminders are device-wide: NULL hour means off. `reminder_asked`
    // makes the "remind me?" offer appear only once.
    'ALTER TABLE app_state ADD COLUMN reminder_hour INTEGER CHECK (reminder_hour IS NULL OR reminder_hour BETWEEN 0 AND 23)',
    'ALTER TABLE app_state ADD COLUMN reminder_asked INTEGER NOT NULL DEFAULT 0 CHECK (reminder_asked IN (0, 1))',
  ]),
  Migration(5, 'NGO enrolment and progress sync outbox', [
    // Whether this profile has been asked for an NGO code (asked once).
    '''
    ALTER TABLE profile ADD COLUMN ngo_prompt_done INTEGER NOT NULL DEFAULT 0
      CHECK (ngo_prompt_done IN (0, 1))''',
    // A profile's link to an NGO. `pending` = code saved but not yet
    // registered (offline); `rejected` = the server refused the code;
    // `revoked` = the server turned the link off; `unlinking` = the student
    // opted out and the server has not confirmed yet. `registration_key` is
    // resent on retries so the server never creates a second student. The
    // token itself is in the phone's secure storage, never here.
    // `sync_revision` only grows; `acked_content` is the last report the
    // server confirmed, so unchanged progress is not uploaded again.
    '''
    CREATE TABLE ngo_enrolment (
      profile_id       INTEGER PRIMARY KEY REFERENCES profile(profile_id) ON DELETE CASCADE,
      status           TEXT NOT NULL
                         CHECK (status IN ('pending', 'active', 'rejected', 'revoked', 'unlinking')),
      code             TEXT NOT NULL,
      registration_key TEXT NOT NULL UNIQUE,
      student_id       TEXT,
      ngo_name         TEXT,
      centre_name      TEXT,
      sync_revision    INTEGER NOT NULL DEFAULT 0 CHECK (sync_revision >= 0),
      acked_revision   INTEGER NOT NULL DEFAULT 0 CHECK (acked_revision >= 0),
      acked_content    TEXT,
      last_synced_at   TEXT,
      last_error       TEXT,
      consented_at     TEXT NOT NULL,
      updated_at       TEXT NOT NULL,
      CHECK (status NOT IN ('active', 'revoked', 'unlinking') OR student_id IS NOT NULL)
    )''',
    // At most one pending report per profile: a newer snapshot replaces
    // (coalesces) an older one. Written in the same transaction as the
    // progress change; deleted only after the server acknowledges it.
    '''
    CREATE TABLE sync_outbox (
      profile_id      INTEGER PRIMARY KEY REFERENCES profile(profile_id) ON DELETE CASCADE,
      revision        INTEGER NOT NULL CHECK (revision >= 1),
      content         TEXT NOT NULL,
      created_at      TEXT NOT NULL,
      attempts        INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
      next_attempt_at TEXT
    )''',
  ]),
];
