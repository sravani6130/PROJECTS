import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// The NGO API base URL is fixed at build time
/// (`--dart-define=GULLAK_API_URL=https://…`); a student can never point
/// the app at another server. The default reaches a backend on the
/// developer's computer from the Android emulator.
const gullakApiUrl = String.fromEnvironment(
  'GULLAK_API_URL',
  defaultValue: 'http://10.0.2.2:8787',
);

/// Plain HTTP is allowed only to the developer's own machine.
const _localHosts = {'10.0.2.2', 'localhost', '127.0.0.1'};

Uri checkedBaseUrl(String raw, {bool release = kReleaseMode}) {
  final uri = Uri.parse(raw);
  final local = _localHosts.contains(uri.host);
  if (uri.scheme == 'https' || (uri.scheme == 'http' && local && !release)) {
    return uri;
  }
  throw ArgumentError.value(
    raw,
    'GULLAK_API_URL',
    'must be https (http only for a local server in debug builds)',
  );
}

enum ApiFailure {
  /// No connection, DNS failure or timeout: try again later.
  offline,

  /// 5xx, 429 or an unreadable reply: back off.
  server,

  /// The server refused this request for good (4xx).
  rejected,
}

class NgoApiException implements Exception {
  NgoApiException(this.failure, {this.status, this.code, this.serverRevision});

  final ApiFailure failure;
  final int? status;

  /// The server's error code, e.g. `code_not_found`, `token_revoked`.
  final String? code;
  final int? serverRevision;

  @override
  String toString() => 'NgoApiException($failure, $status, $code)';
}

class CodeInfo {
  const CodeInfo({
    required this.code,
    required this.ngoName,
    required this.centreName,
  });

  final String code;
  final String ngoName;
  final String centreName;
}

class Registration {
  const Registration({
    required this.studentId,
    required this.token,
    required this.ngoName,
    required this.centreName,
  });

  final String studentId;
  final String token;
  final String ngoName;
  final String centreName;
}

/// `accepted`, `duplicate` (already had it) or `stale` (has a newer one).
class UploadResult {
  const UploadResult(this.status, this.serverRevision);

  final String status;
  final int serverRevision;
}

/// HTTP client for the Gullak NGO API (`/api/v1`). Requests never include
/// the token in URLs, and nothing here logs request or response bodies.
class NgoApi {
  NgoApi({
    http.Client? client,
    Uri? baseUrl,
    // Long enough for a free-tier server that is waking from sleep (about
    // a minute). With no network at all the request fails at once anyway.
    this.timeout = const Duration(seconds: 75),
  }) : _client = client ?? http.Client(),
       _base = baseUrl ?? checkedBaseUrl(gullakApiUrl);

  final http.Client _client;
  final Uri _base;
  final Duration timeout;

  Uri _url(String path) => _base.replace(path: '/api/v1$path');

  Future<CodeInfo> validateCode(String code) async {
    final json = await _send(
      'POST',
      '/enrolment/validate',
      body: {'code': code},
    );
    return CodeInfo(
      code: json['code']! as String,
      ngoName: (json['ngo']! as Map)['name']! as String,
      centreName: (json['centre']! as Map)['name']! as String,
    );
  }

  Future<Registration> register({
    required String code,
    required String registrationKey,
    required String appVersion,
  }) async {
    final json = await _send(
      'POST',
      '/students/register',
      body: {
        'code': code,
        'registration_key': registrationKey,
        'app_version': appVersion,
      },
    );
    return Registration(
      studentId: json['student_id']! as String,
      token: json['token']! as String,
      ngoName: (json['ngo']! as Map)['name']! as String,
      centreName: (json['centre']! as Map)['name']! as String,
    );
  }

  Future<UploadResult> uploadProgress(
    String token,
    Map<String, Object?> report,
  ) async {
    final json = await _send('POST', '/progress', token: token, body: report);
    return UploadResult(
      json['status']! as String,
      json['server_revision']! as int,
    );
  }

  /// Asks the server to delete everything it holds about this student.
  Future<void> unlink(String token) =>
      _send('DELETE', '/students/me', token: token);

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    String? token,
    Map<String, Object?>? body,
  }) async {
    final request = http.Request(method, _url(path))
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on SocketException {
      throw NgoApiException(ApiFailure.offline);
    } on TimeoutException {
      throw NgoApiException(ApiFailure.offline);
    } on http.ClientException {
      throw NgoApiException(ApiFailure.offline);
    } on HandshakeException {
      throw NgoApiException(ApiFailure.server);
    }
    Map<String, Object?> json = const {};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) json = decoded.cast<String, Object?>();
    } on FormatException {
      if (response.statusCode < 300) {
        throw NgoApiException(ApiFailure.server, status: response.statusCode);
      }
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) return json;
    final error = json['error'] is Map
        ? (json['error']! as Map).cast<String, Object?>()
        : const <String, Object?>{};
    throw NgoApiException(
      status >= 500 || status == 429 ? ApiFailure.server : ApiFailure.rejected,
      status: status,
      code: error['code'] as String?,
      serverRevision: error['server_revision'] as int?,
    );
  }
}
