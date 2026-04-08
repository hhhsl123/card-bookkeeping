import 'dart:convert';

class CardItem {
  String id;
  String label;
  String secret;
  double face;
  bool sold;
  bool bad;
  String? soldBy;
  double soldPrice;
  int? soldDate;
  String soldNote;
  int updatedAt;

  CardItem({
    required this.id,
    required this.label,
    this.secret = '',
    this.face = 0,
    this.sold = false,
    this.bad = false,
    this.soldBy,
    this.soldPrice = 0,
    this.soldDate,
    this.soldNote = '',
    int? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'secret': secret,
    'face': face,
    'sold': sold,
    'bad': bad,
    'soldBy': soldBy,
    'soldPrice': soldPrice,
    'soldDate': soldDate,
    'soldNote': soldNote,
    'updatedAt': updatedAt,
  };

  factory CardItem.fromJson(Map<String, dynamic> j) => CardItem(
    id: j['id'] ?? '',
    label: j['label'] ?? '',
    secret: j['secret'] ?? '',
    face: (j['face'] ?? 0).toDouble(),
    sold: j['sold'] ?? false,
    bad: j['bad'] ?? false,
    soldBy: j['soldBy'],
    soldPrice: (j['soldPrice'] ?? 0).toDouble(),
    soldDate: j['soldDate'],
    soldNote: j['soldNote'] ?? '',
    updatedAt: j['updatedAt'] ?? 0,
  );
}

class Batch {
  final String id;
  String name;
  double rate;
  String batchDate;
  double cost;
  int date;
  List<CardItem> cards;

  Batch({
    required this.id,
    required this.name,
    this.rate = 0,
    String? batchDate,
    this.cost = 0,
    int? date,
    List<CardItem>? cards,
  })  : batchDate = batchDate ?? DateTime.now().toIso8601String().substring(0, 10),
        date = date ?? DateTime.now().millisecondsSinceEpoch,
        cards = cards ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rate': rate,
    'batchDate': batchDate,
    'cost': cost,
    'date': date,
    'cards': cards.map((c) => c.toJson()).toList(),
  };

  factory Batch.fromJson(Map<String, dynamic> j) => Batch(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    rate: (j['rate'] ?? 0).toDouble(),
    batchDate: j['batchDate'] ?? '',
    cost: (j['cost'] ?? 0).toDouble(),
    date: j['date'] ?? 0,
    cards: (j['cards'] as List?)?.map((c) => CardItem.fromJson(c)).toList() ?? [],
  );
}

class AppData {
  List<String> persons;
  List<Batch> batches;
  List<String> deletedBatchIds;
  List<String> deletedCardIds;

  AppData({
    List<String>? persons,
    List<Batch>? batches,
    List<String>? deletedBatchIds,
    List<String>? deletedCardIds,
  })  : persons = persons ?? ['星河', '石'],
        batches = batches ?? [],
        deletedBatchIds = deletedBatchIds ?? [],
        deletedCardIds = deletedCardIds ?? [];

  Map<String, dynamic> toJson() => {
    'persons': persons,
    'batches': batches.map((b) => b.toJson()).toList(),
    'deletedBatchIds': deletedBatchIds,
    'deletedCardIds': deletedCardIds,
  };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
    persons: (j['persons'] as List?)?.cast<String>() ?? ['星河', '石'],
    batches: (j['batches'] as List?)?.map((b) => Batch.fromJson(b)).toList() ?? [],
    deletedBatchIds: (j['deletedBatchIds'] as List?)?.cast<String>() ?? [],
    deletedCardIds: (j['deletedCardIds'] as List?)?.cast<String>() ?? [],
  );

  String toJsonString() => jsonEncode(toJson());

  factory AppData.fromJsonString(String s) {
    try {
      return AppData.fromJson(jsonDecode(s));
    } catch (_) {
      return AppData();
    }
  }
}
