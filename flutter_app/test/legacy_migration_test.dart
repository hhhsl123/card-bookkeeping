import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/data.dart';

void main() {
  test('migrates legacy local data into the new snapshot model', () {
    const legacyJson = '''
    {
      "persons": ["星河", "石"],
      "batches": [
        {
          "id": "batch-1",
          "name": "旧批次",
          "rate": 4.0,
          "batchDate": "2026-04-09",
          "date": 10,
          "cards": [
            {"id": "card-1", "label": "1001", "secret": "aaa", "face": 10, "sold": true, "soldBy": "星河", "soldPrice": 10, "soldDate": 20, "updatedAt": 30},
            {"id": "card-2", "label": "1002", "secret": "bbb", "face": 20, "bad": true, "soldPrice": 5, "updatedAt": 40}
          ]
        }
      ],
      "deletedBatchIds": [],
      "deletedCardIds": []
    }
    ''';

    final data = AppData.fromJsonString(legacyJson);

    expect(data.batches.length, 1);
    expect(data.batches.first.pickedCards.length, 1);
    expect(data.batches.first.badCards.length, 1);
    expect(data.batches.first.pickedCards.first.statusBy, '星河');
    expect(data.batches.first.badCards.first.actualBalance, 5);
  });
}
