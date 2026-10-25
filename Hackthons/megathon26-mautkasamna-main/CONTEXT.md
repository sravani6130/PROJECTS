# CONTEXT.md — handoff notes for the next agent

Read this first, then `docs/OVERVIEW.md` (product scope, architecture, SQLite schema, content format,
"Game visuals", how to add a mission). This file covers what the README does not: history,
environment, decisions, gotchas and open items.

## What this repo is

**Gullak** — offline, single-player Android financial-literacy game for Grade 11–12 students
(Hyderabad/Telangana), English + Telugu, pretend money only. Hackathon project (Megathon 2026,
team MautKaSamna). Source documents in the repo root / `deliverables/`:
- `deliverables/112.pdf` — mid-submission: app name, **mandatory stack**, architecture, ER design, test plan.
- `Mana_Money_Mission_Revised_Product_Plan .docx` — curriculum (21 missions), rules, worked examples.

**Mandatory stack (do not change without the user's approval):** Flutter + Dart, Riverpod,
SQLite via `sqflite`, bundled JSON content, Flutter built-in animations (Flame only if truly needed).
No Firebase, student login, analytics or real money. **Exception approved 2026-10-11:** the user
asked for multi-NGO integration, so there is now an optional backend (`backend/`, FastAPI +
SQLite), an NGO dashboard (`ngo-dashboard/`) and opt-in network sync in the app. The game itself
must stay fully offline.

## Status (as of 2026-10-11)

| Commit | What |
|---|---|
| `7739d3e` | Full Easy-level app: 7 missions, 7 study packs, SQLite layer, EN/TE, tests |
| `5ecd916` | Removed Telugu "Draft" markers — user said a fluent Telugu speaker reviewed the copy |
| `c811d35` | 2D cartoon game redesign (art kit, mission stage, world map, mascot) |
| *(uncommitted working tree)* | **The Money Diaries**: the seven missions and study packs replaced by one seven-chapter connected story (user's choice: "replace the missions") |

The Money Diaries work is **staged (`git add .`, at the user's request) but not committed or
pushed** — the user has not asked for a commit yet. Verified on the Mac: `flutter analyze` clean,
format check clean, 104 host tests pass (unit, database, widget). Screenshots of every beat were
rendered, but only about eight were actually looked at (map, chapter 1 dialogue and budget,
chapter 2 goal, chapter 3 bank, chapter 5 statement, the ending); the rest are unreviewed.

**Not verified:** the debug APK was **not built** (the first attempt stalled on the Gradle
download and the user stopped the retry), and the rewritten on-device integration test has not
been run (no emulator on the Mac). Do not claim either until done.

**Implemented:** chapters C1–C7 (see README), one saved `StoryState` per profile with a
checkpoint after every beat, resume, practice replays, stars, 5 badges, chapter map, progress
screen; onboarding, profiles, settings and Stay Safe are unchanged.

**Removed:** `lib/features/missions`, `lib/features/study`, `topic_screen.dart`,
`assets/content/{missions,study,topics.json}` and their tests.

**Read aloud (2026-10-11, uncommitted):** text-to-speech for slow learners via `flutter_tts`
(the phone's own engine, offline, no audio files). `lib/core/audio/narrator.dart` (`Narrator`,
`TtsNarrator`, `narratorProvider`) and `speak_button.dart` (`SpeakButton`, optional `autoPlay`).
Per-profile setting `profile.read_aloud` ('off' | 'slow' | 'normal', default 'slow', migration 3),
switch + pace in Settings → Profile. Speech bubbles (dialogue, guide strips, mascot headers) and
`ToneBanner` feedback read themselves when they appear; `ChoiceTile`s and lesson cards have a
speaker to tap. Teach/Recap/Completion guides speak the whole panel via `spokenText`. Activity-
specific cards (item tokens, statements etc.) are NOT read except through their guide line.
The emulator has an offline en-IN voice but Telugu only as a network voice, so Telugu is silent
offline; Settings then shows a "download a voice" note (`isLanguageInstalled`). Tests use
`RecordingNarrator` (test_support.dart) — `pumpGullak` injects it, since the plugin is absent on host.

**Daily check-in, streaks, inbox, reminders (2026-10-11, uncommitted):** `lib/features/daily/`.
Check-in is AUTOMATIC (user request): `DailyAutoCheckIn` wraps the home screen in `app.dart`
(keyed by profile) and calls `DailyActions.autoCheckIn()` on first frame and on app resume.
₹5 pretend reward once per local calendar day (`daily_checkin`, PK profile+day; a row dated
after today — clock moved back — counts as today), streak = consecutive days, +₹20 on every
7th streak day (`DailyRules`). Separate from the story wallet. Compact `DailyCard` (streak,
saved total, 7 week pills, bell) at the top of the map.
Notifications go to BOTH the phone's notification shade and the in-app inbox (user request):
every inbox message (`inbox` table: kind + params, text built at display time by `inboxText`)
is also posted with `Reminders.showNow`. No in-app pop-up asks about reminders: on the first
auto check-in Android's own permission prompt is shown once; allowed → daily reminders on at
5 PM (change/turn off in Settings). Reminders: `reminderSyncProvider` re-plans 3 one-shot
reminders whenever check-in/story/language/setting changes (`planReminders`); absolute UTC
instants, no tz database. Android: desugaring, boot receivers, `ic_stat_gullak` (kept via
`res/raw/keep.xml`). Verified on the emulator (airplane mode): first-run permission prompt,
auto check-in, news in the shade, scheduled reminder firing after moving the clock, day-2 streak.
Tests: `FakeReminders` (records `scheduled` and `shown`) and a `clock:` in `pumpGullak`.

**Level screen reachable again (2026-10-11):** after onboarding, the "Easy ›" tag on The Money
Diaries banner and Settings → "Levels: Easy" open `LevelSelectScreen` via `openLevelSelect()`;
choosing Easy just pops back. Medium/Advanced stay locked "Coming later". New key `levels_open`.

**Multi-NGO integration (2026-10-11, uncommitted):** read `docs/NGO_INTEGRATION.md` first.
App: `lib/features/ngo/` (domain: report + enrolment; data: `SnapshotRepository`,
`OutboxRepository`, `EnrolmentRepository`, `NgoApi`, `TokenStore`; application: `NgoSync`,
providers, `NgoSyncTrigger`; presentation: join screen, Settings section, `SyncChip`). Migration 5
adds `profile.ngo_prompt_done`, `ngo_enrolment`, `sync_outbox`. `StoryRepository` and
`ProgressRepository` take an `onProgressChanged` hook that queues the report in the same
transaction. `RootGate` shows the join screen once per profile (tests tap `ngo_skip`;
`onboardAsGuest` does it). `pumpGullak` injects an offline `NgoApi` and `MemoryTokenStore`
(`ngoApi:`/`tokenStore:` params); `test/helpers/fake_ngo_server.dart` mimics the backend.
API URL is compile-time `GULLAK_API_URL` (default `http://10.0.2.2:8787`; debug-only cleartext
for localhost hosts). Backend tests: `cd backend && env -u PYTHONPATH PYTEST_DISABLE_PLUGIN_AUTOLOAD=1
.venv/bin/python -m pytest` (this Linux box has ROS on PYTHONPATH, which breaks pytest).
Demo verified on the emulator (two profiles, two NGOs, airplane-mode chapter, auto sync on resume).

**Not implemented:** sound effects, deleting a single profile from the UI,
release signing. The onboarding level screen is a leftover from the old design.

## User preferences and rules learned

- User wants **working, tested, pushed** code, not plans. Commit with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; push to `main` (repo workflow is
  direct-to-main). Never force-push.
- Older note, now out of date: there used to be an uncommitted rename of the product-plan docx
  that was not to be touched. On 2026-10-11 the tree was clean and only
  `Mana_Money_Mission_Revised_Product_Plan (1).docx` is tracked. Still prefer staging only your
  own files unless the user says otherwise (they ran `git add .` themselves for the story work).
- **Telugu:** the app-shell Telugu was reviewed by a fluent speaker. Any NEW Telugu string is
  unreviewed — tell the user and list it. Currently unreviewed: everything in
  `assets/content/story/te.json`, the badge texts in `badges.json`, and in
  `translations/te.json`: `avatar_n`, `stat_missions`, `missions_heading`,
  `practise_pin_safety`, `reset_progress_body`, the read-aloud keys (`read_aloud*`,
`stop_reading`, `settings_read_aloud`), and the daily/inbox/reminder keys (`daily_*`, `inbox_*`,
`settings_reminders`, `reminders_*`, `reminder_*`, `rem_*`), and the NGO keys (`ngo_*`, `sync_*`,
`time_*`, changed `notice_point_offline`, `about_body`). The user chose "English + draft Telugu" for the story.
- Don't claim things you didn't verify (APK built, tests passed, pushed, offline works).
- Visual requirement (latest): feel like a polished 2D cartoon mobile game, character-driven,
  lightweight for low-end Android, consistent art style, accessible, offline.

## Environment

The SDKs are **not on PATH**. Prefix commands with:

```bash
export PATH=~/development/flutter/bin:$PATH JAVA_HOME=~/development/jdk17 ANDROID_HOME=~/development/android-sdk
```

- Two machines have been used: the original Linux box, and a Mac (arm64) where Flutter stable
  (Dart 3.13.5), Temurin JDK 17 and the Android command-line SDK were installed under
  `~/development` on 2026-10-11. No emulator is set up on the Mac.
- Downloads on the Mac's network stall often. For large files use
  `curl -fL --retry 10 --retry-all-errors --speed-limit 20000 --speed-time 30 -C -`.
- Gradle 9.3.1 is fully downloaded but still named `gradle-9.3.1-all.zip.dl` in
  `~/.gradle/wrapper/dists/gradle-9.3.1-all/<hash>/`. Rename it to `gradle-9.3.1-all.zip` before
  `flutter build apk`, or the wrapper downloads it again. The first build will also fetch
  Gradle dependencies (and possibly the NDK), so expect it to be slow.
- Riverpod 3.4.3, sqflite 2.4.x, sqflite_common_ffi for host tests.
- App id: `org.megathon.gullak.gullak`.

## Commands

```bash
flutter analyze
dart format --output=none --set-exit-if-changed lib test integration_test
flutter test --concurrency=1      # unit, database, widget, NGO, e2e (all at once can OOM with the emulator up)
flutter test integration_test/app_test.dart -d <device>   # needs an emulator or phone
flutter build apk --debug   # → build/app/outputs/flutter-apk/app-debug.apk
FLUTTER_ROOT=~/development/flutter flutter test test/shots --update-goldens --dart-define=SHOTS=true
                            # screenshots of every beat → test/shots/out/ (git-ignored)
                            # add --dart-define=SHOT_LANG=lang_te --dart-define=SHOT_SMALL=true
                            #  or --dart-define=SHOT_RECKLESS=true for the other branches
```

Note: running the integration test overwrites `app-debug.apk` with a test build and uninstalls the
app afterwards — rebuild the normal APK before handing it over.

## Code map (short)

- `lib/app/` — `bootstrap.dart` opens DB + loads JSON **before** `ProviderScope` (providers are
  overridden with ready instances); `app.dart` (`RootGate` picks onboarding / profile picker / home);
  `theme.dart`; `providers.dart`.
- `lib/core/game/` — **art kit** (CustomPainter, no image files): `characters.dart`
  (CartoonCharacter, CartoonFace, GullakMascot, `CharacterLook.avatars`), `scenes.dart` (7 scenes),
  `props.dart`, `game_widgets.dart` (SpeechBubble, GameButton, CoinCounter, RoundGameButton, PopIn,
  MascotHeader), `effects.dart` (CoinBurst, Confetti), `game_style.dart` (palette `Toon`, `motionEnabled`).
- `lib/core/widgets/gullak_scaffold.dart` — standard page (scene + HUD + panel + bottom action);
  `header:` slot for mascot/character.
- `lib/features/story/` — `domain/story_state.dart` (the single source of truth),
  `domain/story_rules.dart` (all amounts and transitions; `apply(state, beatId, result)`),
  `domain/story_script.dart` (chapters as beats: Talk/Play/Pick/Teach/Recap),
  `data/story_repository.dart`, `application/story_controller.dart`,
  `presentation/chapter_screen.dart`, `presentation/activities/*` (one widget per `Play` beat,
  registered in `activities.dart`).
- `lib/core/game/game_tokens.dart` — ItemToken, ChoiceTile, WalletMeter, PhoneMock (moved from the
  old mission stage).
- Other features: `content`, `profiles`, `progress`, `onboarding`, `home` (chapter map), `settings`, `safety`.
- `lib/data/database/` — `app_database.dart`, `migrations.dart` (schema v2 adds `story_save`; append migrations, never edit).
- `assets/content/` — `story/{en,te}.json` (story text), `badges.json`,
  `safety_tips.json`, `translations/{en,te}.json` (shell UI). `assets/fonts/` — Baloo Tammudu 2 (OFL).

Domain stays pure Dart: the script names scenes, cast members, moods and props as strings, and
the UI art kit parses them.

## Gotchas learned the hard way

- **Riverpod 3:** a provider must not `invalidate` a provider that depends on it (circular
  dependency error). That's why progress reset lives in `ProgressActions`, not `AppSessionController`.
  `Override` is imported from `package:flutter_riverpod/misc.dart`. `ProviderScope(retry: (_, _) => null)`
  disables auto-retry.
- **Widget tests:** use `databaseFactoryFfiNoIsolate` + in-memory DB (see `test/helpers/test_support.dart`);
  close the DB in teardown (sqflite reuses in-memory DBs by path). `pumpGullak` enables
  `FakeAccessibilityFeatures(disableAnimations: true)` — without it infinite ambient animations make
  `pumpAndSettle` hang. Content JSON is decoded via `bundle.load` (not `loadString`, which uses an
  isolate for large files and stalls tests).
- **Integration test on device** keeps real animations, so it uses a `settle()` helper (pump frames
  for N ms) instead of `pumpAndSettle`.
- `tester.pageBack()` fails in Telugu (looks for English tooltip) → tests use `goBack()` which taps
  `BackButton` (the HUD wraps a real `BackButton`).
- Small screens + 130% text: the sweep test (`test/widget/all_missions_sweep_test.dart`) plays all
  7 missions in Telugu on 360×640 and fails on any RenderFlex overflow — keep it passing when
  changing layouts. Stage area in `MissionStage` is `Flexible` so it shrinks when space is tight.
- `flutter test` with full concurrency got OOM-killed (exit 137) while the emulator ran; use
  `--concurrency=1`. Starting the emulator with `-gpu swiftshader_indirect` crashed it; use
  `-no-window -no-audio -no-snapshot-save`. After airplane mode, also run `adb shell svc wifi enable`.
- Airplane mode on the emulator breaks `flutter test integration_test` (debug service can't attach);
  verify offline by installing the APK and driving it with `adb shell input tap` / `uiautomator dump`
  (Flutter semantics show up as `content-desc`). Offline play + persistence after process kill were
  verified this way.
- Typewriter speech bubbles keep the full text in the `Text.rich` (unrevealed part transparent), so
  `find.text` / `find.textContaining` still match the whole sentence.

- **Story tests use the real font.** `pumpGullak` loads Baloo so Telugu layouts are measured
  with real glyphs; with the square test font, cards grew taller than the panel and taps missed.
- **Late taps.** In tests a save can finish between two taps before the UI rebuilds, so a stale
  button can fire for a beat that is no longer current. `StoryController.complete/advance`
  ignore anything that is not the current beat — keep that guard.
- **GameButton needs a bounded width** (its row expands). Inside a `Row`, wrap it in
  `Expanded` or a `SizedBox`.
- The story text generator used while writing (`story_text_*.py`) was a scratch script; the JSON
  files in `assets/content/story/` are the source of truth now. Edit them directly.

## Suggested next steps

0. Commit when the user asks; then build the debug APK and confirm it installs and runs.
1. Fluent review of the Telugu story text (`assets/content/story/te.json`) and the other
   unreviewed strings listed above.
2. Run the integration test and a manual pass on a real low-end Android phone.
3. Retire or reword the onboarding level screen and the remaining "mission" wording in the shell.
4. Optional: sound, release build + signing, app icon (currently Flutter default), UI to delete a
   single profile, dropping the unused v1 tables in a new migration.
