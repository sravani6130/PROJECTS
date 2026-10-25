# Gullak — solution overview

**Practise money decisions safely — make choices, see consequences, try again.**

Gullak is a single-player, offline-first Android game that teaches financial literacy to
Grade 11–12 students (Hyderabad / Telangana). Students play **The Money Diaries**, a
seven-chapter story in English or Telugu: they budget, save, bank, spot scams, weigh credit,
compare savings options and handle an emergency with **pretend money**, and see the
consequences carry forward. There is no login, no real money and no collection of personal
financial information. The game is fully offline; a student may **optionally** link their
profile to their NGO with an enrolment code, after which a small progress summary is shared
with that NGO's dashboard when the phone is online (see
[`NGO_INTEGRATION.md`](NGO_INTEGRATION.md)).

**Repository layout:** the Flutter app (`lib/`, `test/`, `android/`), the shared NGO API
(`backend/`, Python/FastAPI) and the NGO dashboard web app (`ngo-dashboard/`).

Team **MautKaSamna** · Megathon 2026 (Vanguard problem statement).
Design documents: `deliverables/112.pdf` (mid-submission) and
`Mana_Money_Mission_Revised_Product_Plan .docx` (product plan).

---

## Scope of this build

The game is one connected story, **The Money Diaries**. The player follows Asha, a Class 11
student in Hyderabad, who is saving her share of a laptop for the Youth Innovation Fair. Money
and decisions carry from chapter to chapter; nothing is reset in between.

| Area | Status |
|---|---|
| Seven connected chapters (C1–C7) | **Implemented and playable** |
| English + Telugu for all UI and story text | Implemented — **all story text in Telugu is an unreviewed draft** (see *Known limitations*) |
| 2D cartoon game presentation | Implemented — illustrated scenes, recurring cast, dialogue, animated HUD |
| Saved story with checkpoints, resume, practice replays | Implemented |
| Onboarding, local profiles, per-profile reset, delete-all | Implemented (unchanged) |
| Private badges (5), stars per chapter | Implemented |
| Stay Safe (PIN/OTP) guidance on the home screen | Implemented (unchanged) |
| The earlier seven stand-alone missions and their study packs | **Removed** — replaced by the story (still in git history at `c811d35`) |
| Multi-NGO progress sync (enrolment code, SQLite outbox, backend, NGO dashboard) | Implemented — see `docs/NGO_INTEGRATION.md` |
| Sound effects | Not implemented (haptic feedback and read-aloud only) |

### The seven chapters

| Chapter | Learning goals | What the player does |
|---|---|---|
| 1 The First ₹1,000 | Budgeting, needs vs. wants, opportunity cost, tracking | Adds and removes six expenses against ₹1,000 with a live balance; handles a surprise ₹60; sorts the week's spending into needs and wants |
| 2 The Laptop Dream | Savings goals, regular saving, delayed gratification | Picks a target (₹1,000 / ₹1,500 / ₹3,000); decides how much of ₹300 to save in each of four weeks while a jar fills; chooses how to handle a friend's ₹100 treat and a compulsory ₹80 cost |
| 3 Welcome to Digital Money | Balance, deposit, withdrawal, UPI, pending payments | Opens a pretend account; deposits ₹300, withdraws ₹200 and pays ₹150 by UPI in a working bank screen; checks the passbook; handles a payment stuck on "pending" |
| 4 The Scholarship Message | Phishing, impersonation, OTP/PIN safety, reporting | Opens four messages, taps the warning signs, then verifies, reports, ignores or follows each; after an unsafe choice, picks the recovery steps |
| 5 Buy Now or Wait? | Cash/debit vs. credit, statements, minimum payment, interest | Inspects three options, checks out by debit, cash or store credit; reads a statement and tries repayment plans to see the total cost |
| 6 Make Your Money Work | Interest, time, liquidity, comparing products | Compares ₹2,000 at 3% and 6% month by month; locks part of the savings; steps through six months and meets a ₹300 cost in month 3 |
| 7 When Plans Change | Emergency fund, insurance cover, exclusions, deductible | Reads a pretend policy and judges what it pays; rebuilds the household plan to cover a ₹1,000 clinic bill; reaches the fair |

What carries forward: Chapter 1's leftover fills the gullak; an advance from Amma shrinks week 1
of Chapter 2; the gullak becomes the bank balance in Chapter 3; scam losses in Chapter 4 reduce
what can be spent in Chapter 5; the Chapter 2 saving habit becomes the monthly saving in
Chapter 6, where any store credit from Chapter 5 keeps charging interest; the laptop choice,
remaining debt and scam history shape the ending. Poor choices never block the story.

Where the brief's stand-alone numbers conflict with a continuous story, the story wins. For
example the Chapter 3 bank balance is the player's own savings plus ₹200 from Nanna rather than
a fixed ₹1,500; a player who arrives with ₹1,500 ends the three tasks on ₹1,450, as in the brief.

Every outcome is deterministic and uses whole fictional rupees. Interest rates, the store-credit
terms and the insurance policy are invented, labelled as pretend, and stated on screen.

---

## Technology stack

- **Flutter 3.47 / Dart 3.13**, Android target
- **Riverpod 3** (`flutter_riverpod`) for state and dependency injection
- **SQLite via `sqflite`** for learner progress
- **Bundled JSON assets** for all educational content and translations
- Flutter's built-in animations and `CustomPainter` vector art (no Flame — no feature needed a game loop; no image files)
- Bundled font: Baloo Tammudu 2 (Telugu + Latin, SIL OFL 1.1, `assets/fonts/`)
- Tests: `flutter_test`, `sqflite_common_ffi` (real SQLite in memory for host tests), `integration_test`

- **NGO integration** (optional, opt-in per profile): `http`, `flutter_secure_storage`
  (Android Keystore) in the app; `backend/` — Python 3.10+, FastAPI, SQLite locally or
  PostgreSQL when deployed (`render.yaml`); `ngo-dashboard/` — static HTML/CSS/JS served by the
  API. No analytics, ads or third-party trackers.

---

## Prerequisites

- Flutter SDK (stable, 3.47 or newer) — `flutter doctor` should pass for Android
- JDK 17 (required by the Android Gradle plugin)
- Android SDK (platform 35/36, build-tools) and an emulator or device for running the app
- For host-side database tests on Linux: the system `libsqlite3` (present on most distros)

## Setup and run

```bash
flutter pub get
flutter run                 # on a connected device or running emulator
flutter build apk --debug   # → build/app/outputs/flutter-apk/app-debug.apk
```

## Tests

```bash
flutter analyze
dart format --output=none --set-exit-if-changed lib test integration_test
flutter test --concurrency=1                   # unit + database + widget + NGO + e2e tests
flutter test test/e2e                          # app sync code vs the real backend (needs backend/.venv)
flutter test integration_test -d <device>      # on a device; ngo_sync_test needs the backend running
cd backend && .venv/bin/python -m pytest       # backend API tests
```

| Suite | What it covers |
|---|---|
| `test/unit/story_rules_test.dart` | Every chapter's arithmetic (budget totals, weekly income, ₹1,500 → ₹1,450, double payment and refund, scam loss and recovery, minimum payment, 3% monthly interest and a 12-month repayment schedule, ₹30 vs ₹60 simple interest, breaking a deposit, policy payouts), refused inputs, two complete play-throughs (careful and reckless) with no dead ends, balances always equal to the sum of their diary entries, save-format round trip |
| `test/unit/content_validation_test.dart` | Every text key the script and activity screens use exists in both languages, EN/TE key and placeholder parity, no unfilled placeholders along both play-throughs, badges point at real chapters, no real URLs in content |
| `test/database/schema_test.dart` | Schema creation, constraints, cascade deletes, upgrade from version 1 keeping rows, failed migration rolling back |
| `test/database/repositories_test.dart` | Profile CRUD, story save round trip, a second save from the same revision rejected, chapter completion in one transaction, practice replay leaving the story untouched, damaged save falling back, profile isolation, reset, clear-all, persistence across reopen |
| `test/widget/app_flow_test.dart` | Onboarding (EN/TE), locked chapters, Chapter 1 step by step (over budget, missing need, retry decision, double tap applied once, sorting), language switch keeping the story, practice replay, resume after restart, progress and reset |
| `test/widget/story_sweep_test.dart` | All seven chapters through the real UI four times: careful and reckless in English, and both in Telugu at 130% text on a 360×640 screen (any layout overflow fails) |
| `integration_test/app_test.dart` | Real `sqflite` on Android: Chapter 1, direct DB inspection, simulated restart (needs a device; not run in this change) |
| `test/ngo/*`, `test/widget/ngo_flow_test.dart`, `test/e2e/*`, `backend/tests/*` | NGO enrolment, outbox, sync and dashboard API — see `docs/NGO_INTEGRATION.md` |
| `test/shots/shots_test.dart` | Optional: renders a screenshot of every beat for visual review (`flutter test test/shots --update-goldens --dart-define=SHOTS=true`) |

All tests use synthetic data only. No real students were involved.

---

## Architecture

```
Presentation (Flutter widgets)
   ↓ user intents            ↑ watched state
Riverpod providers / controllers   (lib/**/application)
   ↓
Domain — pure Dart          (lib/**/domain: story state, rules and script, badges)
   ↓
Repositories                (lib/**/data: the only code that runs SQL or loads assets)
   ↓
SQLite (sqflite)  +  bundled JSON (rootBundle)
```

```
lib/
  main.dart                     entry point → GullakBootstrap
  app/                          bootstrap (DB + content before first screen), app/root gate, theme, providers
  core/                         localization (AppLanguage, LocalizedText, AppStrings), utils, shared widgets
    game/                       art kit: characters + Gullu mascot, scenes, props, speech bubbles,
                                game buttons, coin counter, coin bursts, confetti
  data/database/                AppDatabase (open, configure, migrate) and the migration list
  features/
    content/                    badge and safety-tip models + ContentRepository (also loads story text)
    story/
      domain/                   StoryState (the one source of truth), StoryRules (every number and
                                state change), story_script (chapters as lists of beats)
      data/                     StoryRepository (save, checkpoint, chapter completion)
      application/              StoryController (applies a beat, saves, guards repeat taps)
      presentation/             ChapterScreen (HUD, dialogue, decisions, lesson, recap, ending),
                                story_widgets, activities/ (one screen per interactive beat)
    profiles/                   Profile/AppState, ProfileRepository, AppSessionController, profile screens
    progress/                   progress models, badge rules, ProgressRepository, progress screen
    onboarding/ home/ settings/ safety/   screens (home is the chapter map)
assets/content/                 story/ (story text), badges, safety tips, translations/ (UI text)
test/  integration_test/
```

Key decisions:

- **One simulation, one state.** `StoryState` holds every balance, decision and the checkpoint.
  Screens preview changes locally and report what the player did; `StoryRules.apply` recomputes
  and validates everything, so no screen keeps its own copy of the money. Every balance change
  is also a diary entry (`Txn`), and a test checks that balances always equal their entries.
- **Chapters are scripts of beats.** `Talk` (dialogue), `Play` (interactive activity), `Pick`
  (decision with consequence), `Teach` (lesson card) and `Recap`. A beat or line with a failing
  `when` test is skipped, which is how earlier decisions change later scenes.
- **Text is data.** All story text is in `assets/content/story/<lang>.json`; the script and
  screens refer to keys, and amounts are filled from the state.
- **Stars reward decisions, not wealth.** Each chapter scores careful choices (planning first
  time, verifying before paying again, reading before claiming); money held is never scored.
- **Repeat taps are harmless.** The controller ignores a tap for a beat that is no longer
  current, and the database rejects a save made from an outdated revision.
- **Replay is practice.** A finished chapter replays from the state saved at its start; stars can
  improve but the saved story and its money are not changed.
- **Startup order.** `GullakBootstrap` opens the database and loads content *before*
  `ProviderScope` is created. A failure shows a retry screen instead of crashing.

---

## Game visuals

Everything is drawn in code with `CustomPainter`, so there are no image assets to download,
license or keep in sync, the APK stays small, and art scales cleanly to any screen.

| Piece | File | Used for |
|---|---|---|
| `CartoonCharacter`, `CartoonFace`, `GullakMascot` | `lib/core/game/characters.dart` | Story characters (idle bob, blink, talking mouth, 6 moods/poses), profile avatars, Gullu the clay-pot guide |
| `SceneBackground` | `lib/core/game/scenes.dart` | 9 backdrops: `college`, `city` (Charminar + Metro), `home`, `classroom`, `park` (kites), `sunrise`, `night`, `shop`, `bank`; drifting clouds |
| `PropIcon` | `lib/core/game/props.dart` | Illustrated budget items and choice icons (bus, metro, tiffin, notebook, chai, ticket, phone, shield, scammer…) |
| `SpeechBubble`, `GameButton`, `CoinCounter`, `PopIn`, `MascotHeader` | `lib/core/game/game_widgets.dart` | Typewriter dialogue, chunky 3D buttons, animated balance HUD |
| `CoinBurst`, `Confetti` | `lib/core/game/effects.dart` | Coins flying into the gullak or to a scammer, celebrations |
| `ItemToken`, `ChoiceTile`, `WalletMeter` | `lib/core/game/game_tokens.dart` | Selectable expense tokens, answer cards, budget bar |
| `JarView`, `MoneyChip`, `Meter`, `BeatLayout`, `GuideStrip` | `lib/features/story/presentation/story_widgets.dart` | Filling savings jar, HUD money counters, shared beat layout, the recurring cast |

Props added for the story: headphones, laptop, bank, lock, card, magnifier, document, medkit,
TV, bulb and gift. The cast (Asha, Amma, Nanna, Ravi, Ms. Farida, Imran bhai, Lakshmi ma'am and
Gullu) is defined once in `story_widgets.dart`.

**Accessibility and performance.** Looping motion (bobbing, clouds, bouncing marker) stops when
Android's *Remove animations* setting is on, and text then appears at once instead of typing out;
every speech bubble can also be tapped to finish. Screen readers get the full text of bubbles,
labelled characters and buttons, and safe/unsafe outcomes always pair colour with an icon and
words. Static scenery is painted once behind a `RepaintBoundary`; only small ambient layers repaint.

## SQLite

`lib/data/database/app_database.dart` opens `gullak.db` once at startup with
`PRAGMA foreign_keys = ON`. Schema changes live in `lib/data/database/migrations.dart` as an
ordered list of `Migration(version, description, statements)`. On first launch every migration
runs in `onCreate`; on upgrade only newer ones run in `onUpgrade`. Both run inside sqflite's
transaction, so a failing migration leaves the old schema and data intact (covered by a test).
**Never edit a released migration — append a new one.**

Tables (schema v5; v1 is the ER diagram in the mid-submission, v2 adds `story_save`, v3 read-aloud, v4 daily check-in/inbox, v5 the NGO tables):

| Table | Key | Purpose / notable constraints |
|---|---|---|
| `profile` | `profile_id` | Optional nickname (1–20 chars, unique ignoring case), grade 11/12, avatar, locale, start level. Exactly one guest row allowed (partial unique index). No real-identity or financial fields exist. |
| `app_state` | `id = 1` | Device language, onboarding done, active profile (`ON DELETE SET NULL`). |
| `story_save` | `profile_id` | The whole story as one JSON document, the state at the start of each chapter (for practice replays) and a `revision` counter; a save is accepted only from the current revision. |
| `mission_progress` | (`profile_id`, `mission_id`) | One row per completed chapter (`C1`–`C7`): best stars, play and completion counts. Drives the map and badges. |
| `attempt` *(unused since v2)* | `attempt_id` | One play-through: start/end balance, score, result `completed`/`abandoned`. `finished_at IS NULL` = interrupted; a partial unique index allows only one open attempt per profile+mission. |
| `attempt_decision` *(unused)* | (`attempt_id`, `decision_no`) | Each submitted choice, verdict and resulting balance (≥ 0). The key rejects double submissions; a trigger blocks writes to finished attempts. |
| `study_progress` *(unused)* | (`profile_id`, `topic_id`) | Theory done, flashcards seen, best quiz score, recap done. |
| `assessment_result` *(unused)* | `result_id` | Every quiz run (`topic_quiz`; `level_check`/`end_check` are reserved for future features). |
| `badge_award` | (`profile_id`, `badge_id`) | Private badges; the key makes awards idempotent. |
| `ngo_enrolment` | `profile_id` | Optional NGO link: code, `registration_key` (idempotent registration), student ID, status (`pending`/`active`/`rejected`/`revoked`/`unlinking`), sync revision and last acknowledged report. The token lives in the Android Keystore, not here. |
| `sync_outbox` | `profile_id` | At most one queued progress report per profile, written in the same transaction as the progress change and deleted only after the server acknowledges it. |

All learner tables reference `profile` with `ON DELETE CASCADE`. `mission_id`, `topic_id` and
`badge_id` are stable IDs from the JSON content, validated by the app — deliberately **not**
SQL foreign keys, because content is not stored in the database.

Finishing a chapter moves the saved story to the next chapter, updates `mission_progress` and
awards badges in **one transaction** (`StoryRepository.completeChapter`).

---

## Content

```
assets/content/
  story/en.json, te.json          every line of dialogue, instruction, feedback and lesson
  translations/en.json, te.json   UI strings for the app shell
  badges.json                     badge definitions and rules (complete_any / complete_all over C1..C7)
  safety_tips.json                Stay Safe screen
```

Story text uses `{name}` placeholders (`{bank}`, `{jar}`, `{debt}`, `{c1_left}` …) filled from the
state. Changing wording or adding a language needs no code change; `flutter test` checks that
both languages have every key and the same placeholders.

To change the story itself: edit the chapter's beat list in `story_script.dart`; put amounts and
state changes in `story_rules.dart` with a unit test; a new kind of activity needs a widget in
`presentation/activities/` registered in `activities.dart`.

---

## Privacy and safety

- No account, email, phone, real name, date of birth, school, address, location, income,
  pocket money or bank data is requested or stored. Nicknames are optional.
- All money, accounts, assets and returns are fictional; nothing can be bought, transferred
  or redeemed. Scam links are plain text and never open.
- The app declares the INTERNET permission **only** for the optional NGO sync. Nothing is
  sent until the student enters an NGO code and ticks the consent box; release builds talk
  only HTTPS to the build-time `GULLAK_API_URL`. Unlinking stops sharing and deletes the
  NGO's copy; local progress stays. Details: `docs/NGO_INTEGRATION.md`.
- "Stay Safe" guidance is one tap from the home screen.

## Known limitations

- **Telugu story text is an unreviewed draft.** Everything in `assets/content/story/te.json`
  (about 540 strings) and the new badge texts were written without a fluent-speaker review, as
  were four changed UI strings (`stat_missions`, `missions_heading`, `practise_pin_safety`,
  `reset_progress_body`) and the earlier `avatar_n`. The rest of the app shell keeps its reviewed
  Telugu.
- The onboarding level screen still offers Easy with Medium and Advanced "coming later", and a
  few shell strings still say "mission"; the story has a single difficulty.
- Chapter length depends on the reader. The 5–10 minutes per chapter target has not been timed
  with students.
- No sound or narration; feedback is visual plus haptics.
- Tables from the removed missions and study packs remain in the schema, unused.
- Profiles can be switched and reset in the app, but deleting a single named profile is only
  available at the repository level (no UI yet).
- Verification uses automated tests and rendered screenshots with synthetic data. No
  real-student testing was done, and educational impact is unmeasured.
- The Android application id is `org.megathon.gullak.gullak`, and release signing is not configured.
