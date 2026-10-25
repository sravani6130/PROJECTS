import 'package:sqflite/sqflite.dart';

import '../../../core/utils/ids.dart';
import '../domain/enrolment.dart';

/// NGO_ENROLMENT: one NGO link per local profile.
class EnrolmentRepository {
  EnrolmentRepository(this._db, {Clock? clock})
    : _clock = clock ?? DateTime.now;

  final Database _db;
  final Clock _clock;

  String get _now => isoNow(_clock);

  Future<NgoEnrolment?> get(int profileId) async {
    final rows = await _db.query(
      'ngo_enrolment',
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    return rows.isEmpty ? null : NgoEnrolment.fromRow(rows.single);
  }

  Future<List<NgoEnrolment>> all() async {
    final rows = await _db.query('ngo_enrolment', orderBy: 'profile_id');
    return rows.map(NgoEnrolment.fromRow).toList();
  }

  /// Saves a new code for [profileId] before anything is sent, replacing an
  /// earlier rejected or revoked link. The pending outbox and revision are
  /// reset: a new link is a new student on the server.
  Future<NgoEnrolment> start(
    int profileId, {
    required String code,
    required String registrationKey,
  }) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'sync_outbox',
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      await txn.insert('ngo_enrolment', {
        'profile_id': profileId,
        'status': EnrolmentStatus.pending.name,
        'code': code,
        'registration_key': registrationKey,
        'consented_at': _now,
        'updated_at': _now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    return (await get(profileId))!;
  }

  /// The server registered the student.
  Future<void> activate(
    int profileId, {
    required String registrationKey,
    required String studentId,
    required String ngoName,
    required String centreName,
  }) => _db.update(
    'ngo_enrolment',
    {
      'status': EnrolmentStatus.active.name,
      'student_id': studentId,
      'ngo_name': ngoName,
      'centre_name': centreName,
      'last_error': null,
      'updated_at': _now,
    },
    // Guard: a newer code entered meanwhile must not be overwritten.
    where: 'profile_id = ? AND registration_key = ?',
    whereArgs: [profileId, registrationKey],
  );

  Future<void> setStatus(
    int profileId,
    EnrolmentStatus status, {
    String? error,
  }) => _db.update(
    'ngo_enrolment',
    {'status': status.name, 'last_error': error, 'updated_at': _now},
    where: 'profile_id = ?',
    whereArgs: [profileId],
  );

  Future<void> setError(int profileId, String? error) => _db.update(
    'ngo_enrolment',
    {'last_error': error, 'updated_at': _now},
    where: 'profile_id = ?',
    whereArgs: [profileId],
  );

  /// Forgets the link on the phone. Game progress is untouched.
  Future<void> remove(int profileId) => _db.transaction((txn) async {
    await txn.delete(
      'sync_outbox',
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    await txn.delete(
      'ngo_enrolment',
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
  });
}
