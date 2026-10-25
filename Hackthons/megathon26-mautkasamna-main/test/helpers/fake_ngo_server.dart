import 'dart:convert';

import 'package:gullak/features/ngo/data/ngo_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory stand-in for the NGO backend, following the same contract as
/// `backend/app` (codes, idempotent registration, revision rules, revoked
/// tokens). Used for host tests; `test/e2e` runs against the real server.
class FakeNgoServer {
  final codes = <String, (String ngo, String centre)>{
    'NGO-HYD-001': ('Green Futures Foundation', 'Ameerpet Learning Centre'),
    'NGO-WGL-001': ('Udaan Learning Trust', 'Warangal Study Centre'),
  };
  final revokedCodes = {'NGO-HYD-000'};

  /// registration_key → student id
  final byKey = <String, String>{};

  /// student id → NGO name
  final ngoOf = <String, String>{};

  /// token → student id (only valid tokens)
  final tokens = <String, String>{};

  /// student id → accepted reports, by revision
  final reports = <String, Map<int, Map<String, Object?>>>{};
  final requests = <String>[];

  bool offline = false;

  /// Fail the next N requests with 503.
  int failNext = 0;
  int _ids = 0;

  int get progressPosts => requests.where((r) => r == 'POST /progress').length;

  Map<String, Object?>? latest(String studentId) {
    final all = reports[studentId];
    if (all == null || all.isEmpty) return null;
    return all[all.keys.reduce((a, b) => a > b ? a : b)];
  }

  void revokeStudent(String studentId) =>
      tokens.removeWhere((_, s) => s == studentId);

  NgoApi api() => NgoApi(
    client: MockClient(_handle),
    baseUrl: Uri.parse('http://localhost:8787'),
  );

  http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  http.Response _error(int status, String code, [Map<String, Object?>? x]) =>
      _json(status, {
        'error': {'code': code, 'message': code, ...?x},
      });

  Future<http.Response> _handle(http.Request req) async {
    if (offline) throw http.ClientException('offline');
    final path = req.url.path.replaceFirst('/api/v1', '');
    requests.add('${req.method} $path');
    if (failNext > 0) {
      failNext--;
      return _error(503, 'unavailable');
    }
    final body = req.body.isEmpty
        ? const <String, Object?>{}
        : (jsonDecode(req.body) as Map).cast<String, Object?>();
    String? student() {
      final auth = req.headers['Authorization'] ?? '';
      return tokens[auth.replaceFirst('Bearer ', '')];
    }

    switch ('${req.method} $path') {
      case 'POST /enrolment/validate' || 'POST /students/register':
        final code = body['code']! as String;
        if (revokedCodes.contains(code)) return _error(410, 'code_revoked');
        final info = codes[code];
        if (info == null) return _error(404, 'code_not_found');
        if (path == '/enrolment/validate') {
          return _json(200, {
            'valid': true,
            'code': code,
            'ngo': {'name': info.$1},
            'centre': {'name': info.$2},
          });
        }
        final key = body['registration_key']! as String;
        final existing = byKey[key];
        final id =
            existing ?? 'STU-TEST-${(++_ids).toString().padLeft(4, '0')}';
        byKey[key] = id;
        ngoOf[id] = info.$1;
        tokens.removeWhere((_, s) => s == id);
        final token = 'gst_${id}_${tokens.length}_$_ids';
        tokens[token] = id;
        return _json(existing == null ? 201 : 200, {
          'student_id': id,
          'token': token,
          'ngo': {'name': info.$1},
          'centre': {'name': info.$2},
        });
      case 'POST /progress':
        final id = student();
        if (id == null) return _error(401, 'token_revoked');
        if (body['student_id'] != id) return _error(403, 'student_mismatch');
        final rev = body['revision']! as int;
        final mine = reports.putIfAbsent(id, () => {});
        final top = mine.isEmpty
            ? 0
            : mine.keys.reduce((a, b) => a > b ? a : b);
        if (rev < top) {
          return _json(200, {'status': 'stale', 'server_revision': top});
        }
        if (rev == top) {
          final same =
              jsonEncode({...mine[top]!}..remove('generated_at')) ==
              jsonEncode({...body}..remove('generated_at'));
          if (!same) {
            return _error(409, 'revision_conflict', {'server_revision': top});
          }
          return _json(200, {'status': 'duplicate', 'server_revision': top});
        }
        mine[rev] = body;
        return _json(200, {'status': 'accepted', 'server_revision': rev});
      case 'DELETE /students/me':
        final id = student();
        if (id == null) return _error(401, 'token_invalid');
        tokens.removeWhere((_, s) => s == id);
        reports.remove(id);
        ngoOf.remove(id);
        return _json(200, {'unlinked': true});
    }
    return _error(404, 'not_found');
  }
}
