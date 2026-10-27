import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'student.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum ScanStatus { matched, newFace, noFace, multipleFaces, tooFar }

class ScanResult {
  const ScanResult({
    required this.status,
    required this.message,
    this.scanToken,
    this.student,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    Student? student;
    final rawStudent = json['student'];
    if (rawStudent is Map<String, dynamic>) {
      try {
        student = Student.fromJson(rawStudent);
      } on FormatException {
        student = null;
      }
    }
    return ScanResult(
      status: switch (json['status']) {
        'matched' => ScanStatus.matched,
        'new' => ScanStatus.newFace,
        'multiple_faces' => ScanStatus.multipleFaces,
        'too_far' => ScanStatus.tooFar,
        _ => ScanStatus.noFace,
      },
      message: json['message'] as String? ?? '',
      scanToken: json['scan_token'] as String?,
      student: student,
    );
  }

  final ScanStatus status;
  final String message;
  final String? scanToken;
  final Student? student;
}

class ScannerApi {
  ScannerApi({String? baseUrl, String? apiKey})
      : baseUrl = baseUrl ?? defaultBaseUrl,
        apiKey = apiKey ?? defaultApiKey;

  /// Override with `--dart-define=API_URL=http://192.168.1.10:8000`.
  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  /// Must match backend `API_KEY`. Override with `--dart-define=API_KEY=...`.
  static const defaultApiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: 'dev-scanner-key',
  );

  static const _timeout = Duration(seconds: 15);

  final String baseUrl;
  final String apiKey;
  final http.Client _client = http.Client();

  Map<String, String> get _authHeaders => {'X-API-Key': apiKey};

  String photoUrl(Student student) => '$baseUrl${student.photoPath}';

  Future<Uint8List> fetchPhoto(Student student) async {
    final response = await _send(
      () => _client.get(Uri.parse(photoUrl(student)), headers: _authHeaders).timeout(_timeout),
    );
    if (response.statusCode >= 200 && response.statusCode < 300 && response.bodyBytes.isNotEmpty) {
      return response.bodyBytes;
    }
    throw ApiException('Rasm yuklanmadi (${response.statusCode})');
  }

  Future<ScanResult> scan(Uint8List jpeg) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/scan'))
      ..headers.addAll(_authHeaders)
      ..files.add(http.MultipartFile.fromBytes('image', jpeg, filename: 'face.jpg'));
    final response = await _send(() async => http.Response.fromStream(
          await _client.send(request).timeout(_timeout),
        ));
    return ScanResult.fromJson(_decode(response));
  }

  Future<Student> register({
    required String scanToken,
    required String fullName,
    required int age,
    required String faculty,
    required String phone,
  }) async {
    final response = await _send(() => _client
        .post(
          Uri.parse('$baseUrl/api/students'),
          headers: {
            ..._authHeaders,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'scan_token': scanToken,
            'full_name': fullName,
            'age': age,
            'faculty': faculty,
            'phone': phone,
          }),
        )
        .timeout(_timeout));
    return Student.fromJson(_decode(response));
  }

  void dispose() => _client.close();

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call();
    } on TimeoutException {
      throw const ApiException('Server javob bermadi');
    } on http.ClientException {
      throw const ApiException("Server bilan aloqa yo'q");
    } on ApiException {
      rethrow;
    } on Object {
      throw const ApiException('Tarmoq xatosi');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      body = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300 && body is Map<String, dynamic>) {
      return body;
    }
    throw ApiException(_errorMessage(body) ?? 'Server xatosi (${response.statusCode})');
  }

  static String? _errorMessage(Object? body) {
    if (body is! Map) return null;
    final detail = body['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty && detail.first is Map) {
      final msg = (detail.first as Map)['msg'];
      if (msg is String) return msg.replaceFirst('Value error, ', '');
    }
    return null;
  }
}
