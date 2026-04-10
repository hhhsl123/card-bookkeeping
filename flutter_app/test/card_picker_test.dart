import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/data.dart';
import 'package:flutter_app/services/card_picker.dart';

void main() {
  test('finds the smallest exact combination', () {
    final result = CardPicker.exactPick(
      <CardItem>[
        CardItem(id: 'a', label: 'A', secret: '', face: 50),
        CardItem(id: 'b', label: 'B', secret: '', face: 20),
        CardItem(id: 'c', label: 'C', secret: '', face: 20),
        CardItem(id: 'd', label: 'D', secret: '', face: 10),
      ],
      40,
    );

    expect(result, isNotNull);
    expect(result!.length, 2);
    expect(result.fold<double>(0, (sum, card) => sum + card.face), 40);
  });

  test('returns null when amount cannot be matched exactly', () {
    final result = CardPicker.exactPick(
      <CardItem>[
        CardItem(id: 'a', label: 'A', secret: '', face: 50),
        CardItem(id: 'b', label: 'B', secret: '', face: 20),
      ],
      30,
    );

    expect(result, isNull);
  });
}
