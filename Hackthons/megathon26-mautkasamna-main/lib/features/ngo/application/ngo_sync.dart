import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/utils/ids.dart';
import '../data/enrolment_repository.dart';
import '../data/ngo_api.dart';
import '../data/outbox_repository.dart';
import '../data/token_store.dart';
import '../domain/enrolment.dart';
import '../domain/progress_report.dart';

/// Result of asking to join with a code.
enum JoinOutcome {
  joined,

  /// Saved on the phone; joins automatically when online.
  savedOffline,
  invalidCode,
  revokedCode,

  /// The server could not be used right now; the code is saved.
  serverBusy,
}

/// Talks to the NGO server for every linked profile on this phone:
/// registers saved codes, uploads queued progress and confirms unlinking.
///
/// Runs only when asked (app start, return to the app, chapter finished,
/// "Sync now"): there is no background service. Overlapping calls share
/// one run, and a call that arrives during a run schedules one more pass,
/// so a double tap never sends anything twice.
class NgoSync {
  NgoSync({
    required this.enrolments,
    required this.outbox,
    required this.api,
    required this.tokens,
    Clock? clock,
    this.onChanged,
  }) : _clock = clock ?? DateTime.now;

  final EnrolmentRepository enrolments;
  final OutboxRepository outbox;
  final NgoApi api;
  final TokenStore tokens;
  final Clock _clock;

  /// Called after anything the UI shows may have changed.
  final VoidCallback? onChanged;

  Future<void>? _running;
  bool _again = false;
  bool _againForced = false;

  final syncing = ValueNotifier<bool>(false);

  static final _random = Random.secure();

  /// 128-bit random key, base64url (no padding).
  static String newRegistrationKey() => base64Url
      .encode(List<int>.generate(16, (_) => _random.nextInt(256)))
      .replaceAll('=', '');

  // ---- Joining ---------------------------------------------------------------

  /// Checks a code with the server without registering.
  Future<CodeInfo> checkCode(String code) =>
      api.validateCode(normaliseEnrolmentCode(code));

  /// Saves the code (with the student's consent) and registers right away
  /// if the server is reachable. The code stays saved if not.
  Future<JoinOutcome> join(int profileId, String rawCode) async {
    final code = normaliseEnrolmentCode(rawCode);
    final existing = await enrolments.get(profileId);
    if (existing != null) await tokens.delete(existing.registrationKey);
    await enrolments.start(
      profileId,
      code: code,
      registrationKey: newRegistrationKey(),
    );
    onChanged?.call();
    final e = (await enrolments.get(profileId))!;
    final outcome = await _register(e);
    if (outcome == JoinOutcome.joined) await sync(force: true);
    onChanged?.call();
    return outcome;
  }

  /// Opt out. The link is removed on the phone at once (no more uploads);
  /// the server is asked to delete its copy now or on the next sync. Game
  /// progress on the phone is not touched.
  Future<void> unlink(int profileId) async {
    final e = await enrolments.get(profileId);
    if (e == null) return;
    if (e.studentId == null || e.status == EnrolmentStatus.rejected) {
      await tokens.delete(e.registrationKey);
      await enrolments.remove(profileId);
    } else {
      await enrolments.setStatus(profileId, EnrolmentStatus.unlinking);
    }
    onChanged?.call();
    await sync(force: true);
  }

  // ---- Syncing ---------------------------------------------------------------

  /// Brings every linked profile up to date. [force] ignores retry backoff
  /// (the student pressed "Sync now").
  Future<void> sync({bool force = false}) {
    if (_running != null) {
      _again = true;
      _againForced |= force;
      return _running!;
    }
    final run = _loop(force);
    _running = run;
    return run;
  }

  Future<void> _loop(bool force) async {
    syncing.value = true;
    onChanged?.call();
    try {
      var forced = force;
      do {
        _again = false;
        await _pass(forced);
        forced = _againForced;
        _againForced = false;
      } while (_again);
    } finally {
      _running = null;
      syncing.value = false;
      onChanged?.call();
    }
  }

  Future<void> _pass(bool force) async {
    for (final e in await enrolments.all()) {
      try {
        switch (e.status) {
          case EnrolmentStatus.pending:
            if (await _register(e) == JoinOutcome.joined) {
              await _upload(e.profileId, force: true);
            }
          case EnrolmentStatus.active:
            await _upload(e.profileId, force: force);
          case EnrolmentStatus.unlinking:
            await _finishUnlink(e);
          case EnrolmentStatus.rejected || EnrolmentStatus.revoked:
            break;
        }
      } on NgoApiException catch (err) {
        if (err.failure == ApiFailure.offline) {
          // Every other profile would fail the same way.
          return;
        }
      } on Object catch (err) {
        // Never let sync break the game; the work stays queued.
        debugPrint('NGO sync error: ${err.runtimeType}');
      }
    }
  }

  Future<JoinOutcome> _register(NgoEnrolment e) async {
    try {
      final r = await api.register(
        code: e.code,
        registrationKey: e.registrationKey,
        appVersion: gullakAppVersion,
      );
      // Token first: if the app stops in between, the retry with the same
      // key returns the same student and a fresh token.
      await tokens.write(e.registrationKey, r.token);
      await enrolments.activate(
        e.profileId,
        registrationKey: e.registrationKey,
        studentId: r.studentId,
        ngoName: r.ngoName,
        centreName: r.centreName,
      );
      await outbox.refresh(e.profileId);
      onChanged?.call();
      return JoinOutcome.joined;
    } on NgoApiException catch (err) {
      switch (err.failure) {
        case ApiFailure.offline:
          await enrolments.setError(e.profileId, 'offline');
          onChanged?.call();
          return JoinOutcome.savedOffline;
        case ApiFailure.server:
          await enrolments.setError(e.profileId, 'server');
          return JoinOutcome.serverBusy;
        case ApiFailure.rejected:
          if (err.code == 'registration_key_conflict') {
            // Practically impossible (random key); start over with a new one.
            await enrolments.start(
              e.profileId,
              code: e.code,
              registrationKey: newRegistrationKey(),
            );
            return JoinOutcome.serverBusy;
          }
          await enrolments.setStatus(
            e.profileId,
            EnrolmentStatus.rejected,
            error: err.code ?? 'rejected',
          );
          onChanged?.call();
          return err.code == 'code_revoked'
              ? JoinOutcome.revokedCode
              : JoinOutcome.invalidCode;
      }
    }
  }

  Future<void> _upload(int profileId, {required bool force}) async {
    // At most a few rounds: renumbering after "stale" needs one more send.
    for (var round = 0; round < 3; round++) {
      final item = await outbox.pending(profileId);
      if (item == null) return;
      if (!force && !item.dueAt(_clock())) return;
      final e = await enrolments.get(profileId);
      if (e == null || e.status != EnrolmentStatus.active) return;
      final token = await tokens.read(e.registrationKey);
      if (token == null) {
        // Secure storage was cleared (e.g. app data restore): link again.
        await enrolments.setStatus(
          profileId,
          EnrolmentStatus.revoked,
          error: 'token_missing',
        );
        return;
      }
      try {
        final result = await api.uploadProgress(
          token,
          reportPayload(
            content: item.content,
            studentId: e.studentId!,
            revision: item.revision,
            generatedAt: _clock(),
          ),
        );
        if (result.status == 'stale') {
          await outbox.renumberAbove(profileId, result.serverRevision);
          continue;
        }
        await outbox.acknowledge(profileId, item.revision, item.content);
        onChanged?.call();
        return;
      } on NgoApiException catch (err) {
        if (err.code == 'revision_conflict' && err.serverRevision != null) {
          await outbox.renumberAbove(profileId, err.serverRevision!);
          continue;
        }
        if (err.status == 401 || err.code == 'student_mismatch') {
          await tokens.delete(e.registrationKey);
          await enrolments.setStatus(
            profileId,
            EnrolmentStatus.revoked,
            error: err.code ?? 'token_revoked',
          );
          onChanged?.call();
          return;
        }
        await outbox.recordFailure(
          profileId,
          serverError: err.failure != ApiFailure.offline,
        );
        await enrolments.setError(
          profileId,
          err.failure == ApiFailure.offline ? 'offline' : 'server',
        );
        onChanged?.call();
        rethrow;
      }
    }
  }

  Future<void> _finishUnlink(NgoEnrolment e) async {
    final token = await tokens.read(e.registrationKey);
    if (token != null) {
      try {
        await api.unlink(token);
      } on NgoApiException catch (err) {
        // 401: the server already forgot this student. Anything else that
        // is not "offline" is retried on the next sync.
        if (err.status != 401) {
          if (err.failure == ApiFailure.offline) rethrow;
          return;
        }
      }
    }
    await tokens.delete(e.registrationKey);
    await enrolments.remove(e.profileId);
    onChanged?.call();
  }

  /// Before every profile is erased: tell the server where possible, then
  /// drop all tokens. Never blocks the erase for long.
  Future<void> forgetAll() async {
    try {
      for (final e in await enrolments.all()) {
        if (e.studentId == null) continue;
        final token = await tokens.read(e.registrationKey);
        if (token == null) continue;
        await api.unlink(token).timeout(const Duration(seconds: 4));
      }
    } on Object {
      // Offline: the NGO keeps the last report until its retention period.
    }
    await tokens.deleteAll();
  }
}
