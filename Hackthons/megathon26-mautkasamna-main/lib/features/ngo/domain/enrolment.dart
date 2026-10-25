/// Where a profile's NGO link stands (NGO_ENROLMENT.status).
enum EnrolmentStatus {
  /// Code saved on the phone; registers when the phone is online.
  pending,
  active,

  /// The server did not accept the code (unknown or no longer active).
  rejected,

  /// The NGO link was turned off on the server.
  revoked,

  /// The student chose to unlink; waiting to tell the server.
  unlinking;

  static EnrolmentStatus parse(String? value) =>
      EnrolmentStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => EnrolmentStatus.pending,
      );
}

/// A profile's NGO link as stored on the phone. The token is not here; it
/// lives in secure storage under [registrationKey].
class NgoEnrolment {
  const NgoEnrolment({
    required this.profileId,
    required this.status,
    required this.code,
    required this.registrationKey,
    this.studentId,
    this.ngoName,
    this.centreName,
    this.syncRevision = 0,
    this.ackedRevision = 0,
    this.ackedContent,
    this.lastSyncedAt,
    this.lastError,
  });

  factory NgoEnrolment.fromRow(Map<String, Object?> row) => NgoEnrolment(
    profileId: row['profile_id']! as int,
    status: EnrolmentStatus.parse(row['status'] as String?),
    code: row['code']! as String,
    registrationKey: row['registration_key']! as String,
    studentId: row['student_id'] as String?,
    ngoName: row['ngo_name'] as String?,
    centreName: row['centre_name'] as String?,
    syncRevision: row['sync_revision'] as int? ?? 0,
    ackedRevision: row['acked_revision'] as int? ?? 0,
    ackedContent: row['acked_content'] as String?,
    lastSyncedAt: DateTime.tryParse(row['last_synced_at'] as String? ?? ''),
    lastError: row['last_error'] as String?,
  );

  final int profileId;
  final EnrolmentStatus status;
  final String code;
  final String registrationKey;
  final String? studentId;
  final String? ngoName;
  final String? centreName;
  final int syncRevision;
  final int ackedRevision;
  final String? ackedContent;
  final DateTime? lastSyncedAt;

  /// Short machine code of the last failure (`offline`, `server`,
  /// `code_not_found`, …); null after a success.
  final String? lastError;

  /// Progress changes are queued for these statuses.
  bool get collectsProgress =>
      status == EnrolmentStatus.pending || status == EnrolmentStatus.active;

  bool get needsAction =>
      status == EnrolmentStatus.rejected || status == EnrolmentStatus.revoked;
}

/// What the app shows about syncing for one profile.
enum SyncPhase {
  notLinked,

  /// Code saved offline; will join the NGO when online.
  waitingToJoin,
  syncing,

  /// Progress saved on the phone and queued for upload.
  pending,

  /// The last attempt could not reach the server.
  offline,
  synced,

  /// Code refused or link turned off: the student must enter a new code.
  actionNeeded,

  /// Unlinked on the phone; the server is told when online.
  unlinking,
}

class SyncStatus {
  const SyncStatus({
    required this.phase,
    this.enrolment,
    this.hasPending = false,
    this.lastSyncedAt,
  });

  static const notLinked = SyncStatus(phase: SyncPhase.notLinked);

  final SyncPhase phase;
  final NgoEnrolment? enrolment;
  final bool hasPending;
  final DateTime? lastSyncedAt;

  static SyncStatus of(
    NgoEnrolment? e, {
    required bool hasPending,
    required bool syncing,
  }) {
    if (e == null) return notLinked;
    final phase = switch (e.status) {
      EnrolmentStatus.rejected ||
      EnrolmentStatus.revoked => SyncPhase.actionNeeded,
      EnrolmentStatus.unlinking => SyncPhase.unlinking,
      _ when syncing => SyncPhase.syncing,
      EnrolmentStatus.pending =>
        e.lastError == 'offline' ? SyncPhase.offline : SyncPhase.waitingToJoin,
      EnrolmentStatus.active when hasPending =>
        e.lastError == 'offline' ? SyncPhase.offline : SyncPhase.pending,
      EnrolmentStatus.active => SyncPhase.synced,
    };
    return SyncStatus(
      phase: phase,
      enrolment: e,
      hasPending: hasPending,
      lastSyncedAt: e.lastSyncedAt,
    );
  }
}

/// Enrolment codes look like `NGO-HYD-001`: letters/digits in 2–4 groups.
final enrolmentCodePattern = RegExp(r'^[A-Z0-9]{2,10}(-[A-Z0-9]{2,10}){1,3}$');

String normaliseEnrolmentCode(String raw) =>
    raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
