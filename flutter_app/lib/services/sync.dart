import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/data.dart';
import 'storage.dart';

class SyncService {
  static const _timeout = Duration(seconds: 20);

  static Future<Map<String, String>> _headers() async {
    final pin = await StorageService.getPin();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-workspace-id': 'default',
      if (pin != null && pin.isNotEmpty) 'x-workspace-pin': pin,
    };
  }

  static Future<String> _baseUrl() async {
    return await StorageService.getApiUrl();
  }

  /// Check if PIN is configured
  static Future<bool> _hasPinConfigured() async {
    final pin = await StorageService.getPin();
    return pin.isNotEmpty;
  }

  /// Pull latest data from Cloudflare Worker
  static Future<AppData?> pull() async {
    if (!await _hasPinConfigured()) return null;
    try {
      final baseUrl = await _baseUrl();
      final headers = await _headers();
      final resp = await http.get(
        Uri.parse('$baseUrl/api/batches'),
        headers: headers,
      ).timeout(_timeout);

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final data = json['data'] ?? json;
        return _snapshotToAppData(data);
      }
    } catch (_) {}
    return null;
  }

  /// Push local data to Worker, then pull back normalized version
  static Future<AppData?> merge(AppData local) async {
    if (!await _hasPinConfigured()) return null;
    try {
      final baseUrl = await _baseUrl();
      final headers = await _headers();

      // Build snapshot body with workspace fields
      final body = local.toJson();
      body['workspaceId'] = 'default';
      body['workspaceName'] = 'Card Bookkeeping';
      body['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

      final resp = await http.put(
        Uri.parse('$baseUrl/api/workspace/snapshot'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(_timeout);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        // Pull back normalized data
        return await pull();
      }
    } catch (_) {}
    return null;
  }

  /// Overwrite cloud data entirely (same as merge for Worker)
  static Future<bool> overwrite(AppData data) async {
    final result = await merge(data);
    return result != null;
  }

  /// Convert Worker snapshot response to old-format AppData
  static AppData _snapshotToAppData(Map<String, dynamic> data) {
    final persons = (data['persons'] as List?)?.cast<String>() ?? ['星河', '石'];

    final rawBatches = data['batches'] as List? ?? [];
    final batches = rawBatches.map((b) => _batchFromWorker(b)).toList();

    return AppData(
      persons: persons,
      batches: batches,
      deletedBatchIds: [],
      deletedCardIds: [],
    );
  }

  /// Map Worker batch format to old Batch model
  static Batch _batchFromWorker(Map<String, dynamic> b) {
    final cards = (b['cards'] as List? ?? [])
        .map((c) => _cardFromWorker(c as Map<String, dynamic>))
        .toList();

    final rate = (b['rate'] ?? 0).toDouble();
    final totalFace = cards.fold<double>(0, (sum, c) => sum + c.face);

    return Batch(
      id: b['id'] ?? '',
      name: b['name'] ?? '',
      rate: rate,
      batchDate: b['batchDate'] ?? '',
      cost: totalFace * rate,
      date: b['createdAt'] ?? b['updatedAt'] ?? 0,
      cards: cards,
    );
  }

  /// Map Worker card format (status/statusBy/statusAt) to old CardItem (sold/bad/soldBy)
  static CardItem _cardFromWorker(Map<String, dynamic> c) {
    final status = (c['status'] ?? 'available').toString();
    final isSold = status == 'picked';
    final isBad = status == 'bad';

    return CardItem(
      id: c['id'] ?? '',
      label: c['label'] ?? '',
      secret: c['secret'] ?? '',
      face: (c['face'] ?? 0).toDouble(),
      sold: isSold,
      bad: isBad,
      soldBy: c['statusBy']?.toString(),
      soldPrice: (c['actualBalance'] ?? 0).toDouble(),
      soldDate: c['statusAt'],
      soldNote: c['note'] ?? '',
      updatedAt: c['updatedAt'] ?? 0,
    );
  }
}
