import 'dart:convert';

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

List<String> _toStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}

List<double> _toDoubleList(dynamic value) {
  if (value is List) {
    return value.map((item) => _toDouble(item)).where((item) => item > 0).toList();
  }
  return const [];
}

Map<String, dynamic> _toMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, dynamic item) => MapEntry(key.toString(), item));
  return const {};
}

enum CardStatus { available, picked, bad, cleared }

CardStatus cardStatusFromJson(
  dynamic value, {
  bool legacySold = false,
  bool legacyBad = false,
}) {
  if (legacyBad) return CardStatus.bad;
  if (legacySold) return CardStatus.picked;
  switch ((value ?? '').toString()) {
    case 'picked':
      return CardStatus.picked;
    case 'bad':
      return CardStatus.bad;
    case 'cleared':
      return CardStatus.cleared;
    default:
      return CardStatus.available;
  }
}

extension CardStatusX on CardStatus {
  String get wireValue {
    switch (this) {
      case CardStatus.available:
        return 'available';
      case CardStatus.picked:
        return 'picked';
      case CardStatus.bad:
        return 'bad';
      case CardStatus.cleared:
        return 'cleared';
    }
  }

  String get label {
    switch (this) {
      case CardStatus.available:
        return '库存';
      case CardStatus.picked:
        return '已提';
      case CardStatus.bad:
        return '坏卡';
      case CardStatus.cleared:
        return '已清';
    }
  }
}

class CardItem {
  CardItem({
    required this.id,
    required this.label,
    required this.face,
    this.secret = '',
    this.status = CardStatus.available,
    this.statusBy,
    this.statusAt,
    this.actualBalance = 0,
    this.note = '',
    int? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  String id;
  String label;
  String secret;
  double face;
  CardStatus status;
  String? statusBy;
  int? statusAt;
  double actualBalance;
  String note;
  int updatedAt;

  bool get isAvailable => status == CardStatus.available;
  bool get isPicked => status == CardStatus.picked;
  bool get isBad => status == CardStatus.bad;
  bool get isCleared => status == CardStatus.cleared;

  CardItem copy() => CardItem.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'secret': secret,
        'face': face,
        'status': status.wireValue,
        'statusBy': statusBy,
        'statusAt': statusAt,
        'actualBalance': actualBalance,
        'note': note,
        'updatedAt': updatedAt,
      };

  factory CardItem.fromJson(Map<String, dynamic> json) {
    final legacyStatus = cardStatusFromJson(
      json['status'],
      legacySold: json['sold'] == true,
      legacyBad: json['bad'] == true,
    );
    return CardItem(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      secret: (json['secret'] ?? '').toString(),
      face: _toDouble(json['face']),
      status: legacyStatus,
      statusBy: json['statusBy']?.toString() ?? json['soldBy']?.toString(),
      statusAt: json['statusAt'] != null ? _toInt(json['statusAt']) : (json['soldDate'] != null ? _toInt(json['soldDate']) : null),
      actualBalance: json.containsKey('actualBalance') ? _toDouble(json['actualBalance']) : _toDouble(json['soldPrice']),
      note: (json['note'] ?? json['soldNote'] ?? '').toString(),
      updatedAt: json['updatedAt'] != null ? _toInt(json['updatedAt']) : DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class Batch {
  Batch({
    required this.id,
    required this.name,
    this.workspaceId = 'default',
    this.rate = 0,
    String? batchDate,
    this.note = '',
    int? createdAt,
    int? updatedAt,
    this.cleared = false,
    this.clearedAt,
    List<CardItem>? cards,
  })  : batchDate = batchDate ?? DateTime.now().toIso8601String().substring(0, 10),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
        cards = cards ?? <CardItem>[];

  final String id;
  String workspaceId;
  String name;
  double rate;
  String batchDate;
  String note;
  int createdAt;
  int updatedAt;
  bool cleared;
  int? clearedAt;
  List<CardItem> cards;

  List<CardItem> get visibleCards => cards.where((card) => !card.isCleared).toList();
  List<CardItem> get availableCards => visibleCards.where((card) => card.isAvailable).toList();
  List<CardItem> get pickedCards => visibleCards.where((card) => card.isPicked).toList();
  List<CardItem> get badCards => visibleCards.where((card) => card.isBad).toList();
  int get totalCards => visibleCards.length;
  double get totalFace => visibleCards.fold<double>(0, (sum, card) => sum + card.face);
  double get totalCost => totalFace * rate;
  double get availableFace => availableCards.fold<double>(0, (sum, card) => sum + card.face);
  double get pickedRevenue => pickedCards.fold<double>(0, (sum, card) => sum + card.face);
  double get badRecovered => badCards.fold<double>(0, (sum, card) => sum + card.actualBalance);

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspaceId': workspaceId,
        'name': name,
        'rate': rate,
        'batchDate': batchDate,
        'note': note,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'cleared': cleared,
        'clearedAt': clearedAt,
        'cards': cards.map((card) => card.toJson()).toList(),
      };

  factory Batch.fromJson(Map<String, dynamic> json) {
    final cards = (json['cards'] as List<dynamic>? ?? const [])
        .map((item) => CardItem.fromJson(_toMap(item)))
        .toList();
    final legacyDeleted = json['deleted'] == true;
    final createdAt = json['createdAt'] != null
        ? _toInt(json['createdAt'])
        : (json['date'] != null ? _toInt(json['date']) : DateTime.now().millisecondsSinceEpoch);
    final updatedAt = json['updatedAt'] != null ? _toInt(json['updatedAt']) : createdAt;
    return Batch(
      id: (json['id'] ?? '').toString(),
      workspaceId: (json['workspaceId'] ?? 'default').toString(),
      name: (json['name'] ?? '').toString(),
      rate: _toDouble(json['rate']),
      batchDate: (json['batchDate'] ?? DateTime.now().toIso8601String().substring(0, 10)).toString(),
      note: (json['note'] ?? '').toString(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      cleared: json['cleared'] == true || legacyDeleted,
      clearedAt: json['clearedAt'] != null ? _toInt(json['clearedAt']) : null,
      cards: cards,
    );
  }
}

class ActivityLog {
  ActivityLog({
    required this.id,
    required this.type,
    required this.summary,
    required this.actor,
    int? createdAt,
    this.batchId,
    List<String>? cardIds,
    Map<String, dynamic>? meta,
  })  : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        cardIds = cardIds ?? <String>[],
        meta = meta ?? <String, dynamic>{};

  final String id;
  final String type;
  final String summary;
  final String actor;
  final int createdAt;
  final String? batchId;
  final List<String> cardIds;
  final Map<String, dynamic> meta;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'summary': summary,
        'actor': actor,
        'createdAt': createdAt,
        'batchId': batchId,
        'cardIds': cardIds,
        'meta': meta,
      };

  factory ActivityLog.fromJson(Map<String, dynamic> json) => ActivityLog(
        id: (json['id'] ?? '').toString(),
        type: (json['type'] ?? '').toString(),
        summary: (json['summary'] ?? '').toString(),
        actor: (json['actor'] ?? '').toString(),
        createdAt: json['createdAt'] != null ? _toInt(json['createdAt']) : DateTime.now().millisecondsSinceEpoch,
        batchId: json['batchId']?.toString(),
        cardIds: _toStringList(json['cardIds']),
        meta: _toMap(json['meta']),
      );
}

class AppData {
  AppData({
    String? workspaceId,
    String? workspaceName,
    List<String>? persons,
    List<String>? sources,
    List<double>? recentPickAmounts,
    List<Batch>? batches,
    List<ActivityLog>? activities,
    int? updatedAt,
  })  : workspaceId = workspaceId ?? 'default',
        workspaceName = workspaceName ?? 'Card Bookkeeping',
        persons = persons == null || persons.isEmpty ? <String>['星河', '石'] : persons,
        sources = sources ?? <String>[],
        recentPickAmounts = recentPickAmounts ?? <double>[],
        batches = batches ?? <Batch>[],
        activities = activities ?? <ActivityLog>[],
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  String workspaceId;
  String workspaceName;
  List<String> persons;
  List<String> sources;
  List<double> recentPickAmounts;
  List<Batch> batches;
  List<ActivityLog> activities;
  int updatedAt;

  List<Batch> get activeBatches => batches.where((batch) => !batch.cleared).toList()
    ..sort((left, right) => right.createdAt.compareTo(left.createdAt));

  List<Batch> get clearedBatches => batches.where((batch) => batch.cleared).toList()
    ..sort((left, right) => (right.clearedAt ?? right.updatedAt).compareTo(left.clearedAt ?? left.updatedAt));

  List<ActivityLog> get recentActivities => List<ActivityLog>.from(activities)
    ..sort((left, right) => right.createdAt.compareTo(left.createdAt));

  AppData copy() => AppData.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'workspaceId': workspaceId,
        'workspaceName': workspaceName,
        'persons': persons,
        'sources': sources,
        'recentPickAmounts': recentPickAmounts,
        'batches': batches.map((batch) => batch.toJson()).toList(),
        'activities': activities.map((activity) => activity.toJson()).toList(),
        'updatedAt': updatedAt,
      };

  String toJsonString() => jsonEncode(toJson());

  factory AppData.initial() => AppData();

  factory AppData.fromJson(Map<String, dynamic> json) {
    final hasLegacyShape = json.containsKey('deletedBatchIds') || json.containsKey('deletedCardIds');
    final persons = _toStringList(json['persons']);
    final batches = (json['batches'] as List<dynamic>? ?? const [])
        .map((item) => Batch.fromJson(_toMap(item)))
        .toList();
    if (hasLegacyShape) {
      final deletedBatchIds = _toStringList(json['deletedBatchIds']).toSet();
      final deletedCardIds = _toStringList(json['deletedCardIds']).toSet();
      for (final batch in batches) {
        if (deletedBatchIds.contains(batch.id)) {
          batch.cleared = true;
        }
        for (final card in batch.cards) {
          if (deletedCardIds.contains(card.id)) {
            card.status = CardStatus.cleared;
          }
        }
      }
    }
    return AppData(
      workspaceId: (json['workspaceId'] ?? 'default').toString(),
      workspaceName: (json['workspaceName'] ?? 'Card Bookkeeping').toString(),
      persons: persons,
      sources: _toStringList(json['sources']),
      recentPickAmounts: _toDoubleList(json['recentPickAmounts']),
      batches: batches,
      activities: (json['activities'] as List<dynamic>? ?? const [])
          .map((item) => ActivityLog.fromJson(_toMap(item)))
          .toList(),
      updatedAt: json['updatedAt'] != null ? _toInt(json['updatedAt']) : DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory AppData.fromJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return AppData.fromJson(decoded);
      if (decoded is Map) return AppData.fromJson(decoded.map((key, dynamic value) => MapEntry(key.toString(), value)));
    } catch (_) {}
    return AppData.initial();
  }
}

class AppConfig {
  AppConfig({
    this.apiBaseUrl = '',
    this.workspacePin = '',
    this.geminiApiKey = '',
  });

  String apiBaseUrl;
  String workspacePin;
  String geminiApiKey;

  bool get hasRemoteConfigured => apiBaseUrl.trim().isNotEmpty && workspacePin.trim().isNotEmpty;
  bool get hasGeminiConfigured => geminiApiKey.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'apiBaseUrl': apiBaseUrl,
        'workspacePin': workspacePin,
        'geminiApiKey': geminiApiKey,
      };

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        apiBaseUrl: (json['apiBaseUrl'] ?? '').toString(),
        workspacePin: (json['workspacePin'] ?? '').toString(),
        geminiApiKey: (json['geminiApiKey'] ?? '').toString(),
      );
}

class ParsedCardDraft {
  ParsedCardDraft({
    required this.label,
    required this.face,
    required this.lineNumber,
    this.secret = '',
  });

  final String label;
  final String secret;
  final double face;
  final int lineNumber;

  Map<String, dynamic> toJson() => {
        'label': label,
        'secret': secret,
        'face': face,
        'lineNumber': lineNumber,
      };
}

class ImportIssue {
  ImportIssue({
    required this.lineNumber,
    required this.message,
  });

  final int lineNumber;
  final String message;
}

class ImportPreview {
  ImportPreview({
    List<ParsedCardDraft>? cards,
    List<ImportIssue>? issues,
    List<String>? duplicateWithinInput,
    Map<String, String>? duplicateExisting,
    this.totalLines = 0,
  })  : cards = cards ?? <ParsedCardDraft>[],
        issues = issues ?? <ImportIssue>[],
        duplicateWithinInput = duplicateWithinInput ?? <String>[],
        duplicateExisting = duplicateExisting ?? <String, String>{};

  final List<ParsedCardDraft> cards;
  final List<ImportIssue> issues;
  final List<String> duplicateWithinInput;
  final Map<String, String> duplicateExisting;
  final int totalLines;

  bool get hasValidCards => cards.isNotEmpty;
  int get skippedCount => issues.length + duplicateWithinInput.length + duplicateExisting.length;
}

class BatchSettlement {
  BatchSettlement({
    required this.batch,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.availableValue,
    required this.badRecovered,
    required this.badLoss,
  });

  final Batch batch;
  final double revenue;
  final double cost;
  final double profit;
  final double availableValue;
  final double badRecovered;
  final double badLoss;
}

class PersonSettlement {
  PersonSettlement({
    required this.person,
    required this.count,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.cards,
  });

  final String person;
  final int count;
  final double revenue;
  final double cost;
  final double profit;
  final List<CardItem> cards;
}

class SettlementOverview {
  SettlementOverview({
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
    required this.badRecovered,
    required this.badLoss,
    required this.availableValue,
    required this.batches,
    required this.archivedBatches,
    required this.persons,
  });

  final double totalRevenue;
  final double totalCost;
  final double totalProfit;
  final double badRecovered;
  final double badLoss;
  final double availableValue;
  final List<BatchSettlement> batches;
  final List<BatchSettlement> archivedBatches;
  final List<PersonSettlement> persons;
}
