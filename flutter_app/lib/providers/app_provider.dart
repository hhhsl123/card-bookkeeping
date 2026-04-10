import 'dart:async';

import 'package:flutter/material.dart';

import '../models/data.dart';
import '../services/api_service.dart';
import '../services/card_picker.dart';
import '../services/card_parser.dart';
import '../services/id.dart';
import '../services/storage.dart';

class AppProvider extends ChangeNotifier {
  AppData data = AppData.initial();
  AppConfig config = AppConfig(apiBaseUrl: kDefaultApiBaseUrl);
  String? myRole;
  bool initialized = false;
  bool syncing = false;
  String syncStatus = '初始化中';
  String? syncMessage;

  Timer? _pushDebounce;

  bool get hasRemoteConfigured => config.hasRemoteConfigured;

  ApiService? get _api => hasRemoteConfigured
      ? ApiService(
          baseUrl: config.apiBaseUrl,
          workspaceId: data.workspaceId,
          workspacePin: config.workspacePin,
        )
      : null;

  Future<void> init() async {
    data = await StorageService.loadData();
    config = await StorageService.loadConfig();
    myRole = await StorageService.getRole();
    if (data.persons.isEmpty) {
      data.persons = <String>['星河', '石'];
    }
    myRole ??= data.persons.isNotEmpty ? data.persons.first : null;
    syncStatus = hasRemoteConfigured ? '待同步' : '本地模式';
    initialized = true;
    notifyListeners();

    if (hasRemoteConfigured) {
      unawaited(refreshFromRemote(silent: true));
    }
  }

  Map<String, String> existingLabels({String? includeBatchId}) {
    final labels = <String, String>{};
    for (final batch in data.activeBatches) {
      if (includeBatchId != null && batch.id == includeBatchId) {
        for (final card in batch.visibleCards) {
          labels[card.label] = batch.name;
        }
        continue;
      }
      for (final card in batch.visibleCards) {
        labels[card.label] = batch.name;
      }
    }
    return labels;
  }

  ImportPreview buildImportPreview(
    String raw, {
    double? unifiedFace,
  }) {
    return CardParser.preview(
      raw: raw,
      unifiedFace: unifiedFace,
      existingLabels: existingLabels(),
    );
  }

  Future<ImportPreview> buildImportPreviewWithAI(
    String raw, {
    double? unifiedFace,
  }) {
    return CardParser.previewWithAI(
      raw: raw,
      unifiedFace: unifiedFace,
      existingLabels: existingLabels(),
      geminiApiKey: config.geminiApiKey,
    );
  }

  Future<void> setRole(String role) async {
    myRole = role;
    await StorageService.setRole(role);
    notifyListeners();
  }

  Future<void> saveGeminiKey(String key) async {
    config.geminiApiKey = key.trim();
    await StorageService.saveConfig(config);
    notifyListeners();
  }

  Future<void> saveConnection({
    required String apiBaseUrl,
    required String workspacePin,
    required String workspaceId,
    required String workspaceName,
  }) async {
    config
      ..apiBaseUrl = apiBaseUrl.trim()
      ..workspacePin = workspacePin.trim();
    data
      ..workspaceId = workspaceId.trim().isEmpty ? 'default' : workspaceId.trim()
      ..workspaceName = workspaceName.trim().isEmpty ? 'Card Bookkeeping' : workspaceName.trim()
      ..updatedAt = DateTime.now().millisecondsSinceEpoch;
    await StorageService.saveConfig(config);
    await StorageService.saveData(data);
    notifyListeners();
    if (hasRemoteConfigured) {
      await syncNow(showMessage: true);
    } else {
      syncStatus = '本地模式';
      notifyListeners();
    }
  }

  Future<void> addSource(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || data.sources.contains(trimmed)) return;
    data.sources.add(trimmed);
    data.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _persistAndScheduleSync('来源已更新');
  }

  Future<void> removeSource(String name) async {
    if (!data.sources.remove(name)) return;
    data.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _persistAndScheduleSync('来源已更新');
  }

  /// Add with source: parse text, create batch with source+date as name.
  Future<String?> addWithSource(String rawText, String source, double rate) async {
    if (rawText.trim().isEmpty) return '剪贴板为空';
    ImportPreview preview;
    if (config.hasGeminiConfigured) {
      preview = await buildImportPreviewWithAI(rawText);
    } else {
      preview = buildImportPreview(rawText);
    }
    if (!preview.hasValidCards) return '无法识别任何卡片';
    final date = DateTime.now().toIso8601String().substring(0, 10);
    await createBatchFromPreview(
      name: '$source $date',
      rate: rate,
      batchDate: date,
      preview: preview,
    );
    return null;
  }

  Future<void> addPerson(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || data.persons.contains(trimmed)) return;
    data.persons.add(trimmed);
    data.updatedAt = DateTime.now().millisecondsSinceEpoch;
    _appendActivity('workspace', '新增成员 $trimmed');
    await _persistAndScheduleSync('成员已更新');
  }

  Future<void> removePerson(String name) async {
    if (!data.persons.contains(name)) return;
    data.persons.remove(name);
    if (myRole == name) {
      myRole = data.persons.isNotEmpty ? data.persons.first : null;
      if (myRole != null) {
        await StorageService.setRole(myRole!);
      }
    }
    data.updatedAt = DateTime.now().millisecondsSinceEpoch;
    _appendActivity('workspace', '移除成员 $name');
    await _persistAndScheduleSync('成员已更新');
  }

  Future<void> createBatchFromPreview({
    required String name,
    required double rate,
    required String batchDate,
    required ImportPreview preview,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = Batch(
      id: generateId('batch'),
      workspaceId: data.workspaceId,
      name: name.trim(),
      rate: rate,
      batchDate: batchDate,
      createdAt: now,
      updatedAt: now,
      cards: preview.cards
          .map(
            (draft) => CardItem(
              id: generateId('card'),
              label: draft.label,
              secret: draft.secret,
              face: draft.face,
              updatedAt: now,
            ),
          )
          .toList(),
    );
    data.batches.insert(0, batch);
    data.updatedAt = now;
    _appendActivity('import', '创建批次 ${batch.name}，导入 ${batch.cards.length} 张卡', batchId: batch.id);
    await _persistAndScheduleSync('批次已创建');
  }

  Future<void> appendCardsToBatch({
    required String batchId,
    required ImportPreview preview,
  }) async {
    final batch = _findBatch(batchId);
    if (batch == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    batch.cards.addAll(
      preview.cards.map(
        (draft) => CardItem(
          id: generateId('card'),
          label: draft.label,
          secret: draft.secret,
          face: draft.face,
          updatedAt: now,
        ),
      ),
    );
    batch.updatedAt = now;
    data.updatedAt = now;
    _appendActivity('import', '向 ${batch.name} 追加 ${preview.cards.length} 张卡', batchId: batch.id);
    await _persistAndScheduleSync('卡片已追加');
  }

  Future<void> markCardBad(
    String batchId,
    String cardId, {
    double actualBalance = 0,
  }) async {
    final card = _findCard(batchId, cardId);
    if (card == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    card
      ..status = CardStatus.bad
      ..statusBy = myRole ?? '未知'
      ..statusAt = now
      ..actualBalance = actualBalance
      ..updatedAt = now;
    _touchBatch(batchId, now);
    _appendActivity('bad', '标记坏卡 ${card.label}', batchId: batchId, cardIds: <String>[cardId]);
    await _persistAndScheduleSync('坏卡状态已更新');
  }

  Future<void> restoreCard(String batchId, String cardId) async {
    final card = _findCard(batchId, cardId);
    if (card == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    card
      ..status = CardStatus.available
      ..statusBy = null
      ..statusAt = null
      ..actualBalance = 0
      ..updatedAt = now;
    _touchBatch(batchId, now);
    _appendActivity('restore', '恢复卡片 ${card.label}', batchId: batchId, cardIds: <String>[cardId]);
    await _persistAndScheduleSync('卡片已恢复');
  }

  Future<void> archiveCard(String batchId, String cardId) async {
    final card = _findCard(batchId, cardId);
    if (card == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    card
      ..status = CardStatus.cleared
      ..statusBy = myRole ?? '未知'
      ..statusAt = now
      ..updatedAt = now;
    _touchBatch(batchId, now);
    _appendActivity('archive_card', '移除卡片 ${card.label}', batchId: batchId, cardIds: <String>[cardId]);
    await _persistAndScheduleSync('卡片已移除');
  }

  List<CardItem>? suggestPick(String batchId, double target) {
    final batch = _findBatch(batchId);
    if (batch == null) return null;
    return CardPicker.exactPick(batch.availableCards, target);
  }

  /// Quick-pick [count] available cards with the given [face] value.
  /// Picks from oldest batches first (FIFO by batchDate).
  /// Returns the picked cards, or empty list if not enough.
  Future<List<CardItem>> quickPick(double face, int count) async {
    final candidates = <({String batchId, String batchDate, CardItem card})>[];
    for (final batch in data.activeBatches) {
      for (final card in batch.availableCards) {
        if ((card.face - face).abs() < 0.001) {
          candidates.add((batchId: batch.id, batchDate: batch.batchDate, card: card));
        }
      }
    }
    candidates.sort((a, b) => a.batchDate.compareTo(b.batchDate));
    final picked = candidates.take(count).toList();
    if (picked.isEmpty) return [];

    // Group by batchId and confirm each group
    final grouped = <String, List<CardItem>>{};
    for (final entry in picked) {
      grouped.putIfAbsent(entry.batchId, () => []).add(entry.card);
    }
    final totalFace = picked.fold<double>(0, (sum, e) => sum + e.card.face);
    for (final entry in grouped.entries) {
      await confirmPick(batchId: entry.key, cards: entry.value, target: totalFace);
    }
    return picked.map((e) => e.card).toList();
  }

  Future<void> confirmPick({
    required String batchId,
    required List<CardItem> cards,
    required double target,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final actor = myRole ?? '未知';
    final seen = cards.map((card) => card.id).toSet();
    final batch = _findBatch(batchId);
    if (batch == null) return;

    for (final card in batch.cards) {
      if (seen.contains(card.id)) {
        card
          ..status = CardStatus.picked
          ..statusBy = actor
          ..statusAt = now
          ..actualBalance = 0
          ..updatedAt = now;
      }
    }

    data.recentPickAmounts = <double>[
      target,
      ...data.recentPickAmounts.where((value) => (value - target).abs() > 0.001),
    ].take(6).toList();
    _touchBatch(batchId, now);
    _appendActivity(
      'pick',
      '提卡 ${cards.length} 张，金额 ${target.toStringAsFixed(target % 1 == 0 ? 0 : 2)}',
      batchId: batchId,
      cardIds: seen.toList(),
    );
    await _persistAndScheduleSync('提卡结果已保存');
  }

  Future<void> seedTestData() async {
    final testCards = '''
iTunes-001 ABC123SECRET 10
iTunes-002 DEF456SECRET 10
iTunes-003 GHI789SECRET 10
iTunes-004 JKL012SECRET 25
iTunes-005 MNO345SECRET 25
iTunes-006 PQR678SECRET 25
iTunes-007 STU901SECRET 25
iTunes-008 VWX234SECRET 50
iTunes-009 YZA567SECRET 50
iTunes-010 BCD890SECRET 100
''';
    final preview = buildImportPreview(testCards);
    await createBatchFromPreview(
      name: '测试批次',
      rate: 4.00,
      batchDate: DateTime.now().toIso8601String().substring(0, 10),
      preview: preview,
    );
  }

  Future<void> updateBatchRate(String batchId, double rate) async {
    final batch = _findBatch(batchId);
    if (batch == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    batch
      ..rate = rate
      ..updatedAt = now;
    _appendActivity('workspace', '修改批次 ${batch.name} 汇率为 ${rate.toStringAsFixed(2)}', batchId: batchId);
    await _persistAndScheduleSync('汇率已更新');
  }

  Future<void> clearBatch(String batchId) async {
    final batch = _findBatch(batchId);
    if (batch == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    batch
      ..cleared = true
      ..clearedAt = now
      ..updatedAt = now;
    for (final card in batch.cards) {
      card
        ..status = CardStatus.cleared
        ..statusBy = myRole ?? '未知'
        ..statusAt = now
        ..updatedAt = now;
    }
    data.updatedAt = now;
    _appendActivity('clear_batch', '清账批次 ${batch.name}', batchId: batchId);
    await _persistAndScheduleSync('批次已清账');
  }

  Future<void> syncNow({bool showMessage = false}) async {
    _pushDebounce?.cancel();
    await _pushSnapshot(showMessage: showMessage);
  }

  Future<void> refreshFromRemote({bool silent = false}) async {
    final api = _api;
    if (api == null) {
      syncStatus = '本地模式';
      notifyListeners();
      return;
    }
    syncing = true;
    syncStatus = '从云端刷新中';
    notifyListeners();
    try {
      final snapshot = await api.fetchSnapshot();
      data = snapshot;
      await StorageService.saveData(data);
      syncStatus = '已刷新';
      if (!silent) {
        syncMessage = '已从云端刷新';
      }
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        syncStatus = '云端未初始化';
      } else {
        syncStatus = '刷新失败';
        if (!silent) syncMessage = '云端刷新失败';
      }
    } catch (_) {
      syncStatus = '刷新失败';
      if (!silent) syncMessage = '云端刷新失败';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  void clearSyncMessage() {
    syncMessage = null;
  }

  Batch? _findBatch(String batchId) {
    for (final batch in data.batches) {
      if (batch.id == batchId) return batch;
    }
    return null;
  }

  CardItem? _findCard(String batchId, String cardId) {
    final batch = _findBatch(batchId);
    if (batch == null) return null;
    for (final card in batch.cards) {
      if (card.id == cardId) return card;
    }
    return null;
  }

  void _touchBatch(String batchId, int updatedAt) {
    final batch = _findBatch(batchId);
    if (batch == null) return;
    batch.updatedAt = updatedAt;
    data.updatedAt = updatedAt;
  }

  void _appendActivity(
    String type,
    String summary, {
    String? batchId,
    List<String>? cardIds,
  }) {
    data.activities.insert(
      0,
      ActivityLog(
        id: generateId('activity'),
        type: type,
        summary: summary,
        actor: myRole ?? '系统',
        batchId: batchId,
        cardIds: cardIds,
      ),
    );
    if (data.activities.length > 50) {
      data.activities = data.activities.take(50).toList();
    }
  }

  Future<void> _persistAndScheduleSync(String successLabel) async {
    await StorageService.saveData(data);
    notifyListeners();
    if (!hasRemoteConfigured) {
      syncStatus = '本地模式';
      syncMessage = successLabel;
      notifyListeners();
      return;
    }
    syncStatus = '待同步';
    notifyListeners();
    _pushDebounce?.cancel();
    unawaited(_pushSnapshot());
  }

  Future<void> _pushSnapshot({bool showMessage = false}) async {
    final api = _api;
    if (api == null) {
      syncStatus = '本地模式';
      notifyListeners();
      return;
    }
    syncing = true;
    syncStatus = '同步中';
    notifyListeners();
    try {
      final remoteData = await api.pushSnapshot(data);
      data = remoteData;
      await StorageService.saveData(data);
      syncStatus = '已同步';
      if (showMessage) syncMessage = '本地数据已同步到云端';
    } catch (_) {
      syncStatus = '同步失败';
      if (showMessage) syncMessage = '同步失败，本地改动已保留';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pushDebounce?.cancel();
    super.dispose();
  }
}
