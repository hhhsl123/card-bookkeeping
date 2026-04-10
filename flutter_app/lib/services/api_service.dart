import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/data.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({
    required this.baseUrl,
    required this.workspaceId,
    required this.workspacePin,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String workspaceId;
  final String workspacePin;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse(baseUrl).resolve(path);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'x-workspace-id': workspaceId,
        'x-workspace-pin': workspacePin,
      };

  Future<Map<String, dynamic>> _send({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, _uri(path));
    request.headers.addAll(_headers);
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _client.send(request).timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 400) {
      throw ApiException(response.body.isEmpty ? 'API 请求失败' : response.body, statusCode: response.statusCode);
    }
    if (response.body.isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.map((key, dynamic value) => MapEntry(key.toString(), value));
    return const {};
  }

  Future<AppData> fetchSnapshot() async {
    final response = await _send(method: 'GET', path: '/api/batches');
    final payload = response['data'] ?? response;
    return AppData.fromJson(payload is Map<String, dynamic> ? payload : <String, dynamic>{});
  }

  Future<AppData> pushSnapshot(AppData data) async {
    final response = await _send(
      method: 'PUT',
      path: '/api/workspace/snapshot',
      body: data.toJson(),
    );
    final payload = response['data'] ?? response;
    return AppData.fromJson(payload is Map<String, dynamic> ? payload : <String, dynamic>{});
  }

  Future<Map<String, dynamic>> previewImport({
    required String raw,
    double? unifiedFace,
  }) {
    return _send(
      method: 'POST',
      path: '/api/import/preview',
      body: {
        'raw': raw,
        'unifiedFace': unifiedFace,
      },
    );
  }

  Future<Map<String, dynamic>> suggestPick({
    required String batchId,
    required double target,
  }) {
    return _send(
      method: 'POST',
      path: '/api/picks/suggest',
      body: {
        'batchId': batchId,
        'target': target,
      },
    );
  }

  Future<Map<String, dynamic>> settlementOverview() {
    return _send(
      method: 'GET',
      path: '/api/settlements/overview',
    );
  }
}
