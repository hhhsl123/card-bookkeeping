import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/card_parser.dart';

void main() {
  test('parses clipboard lines and skips duplicates', () {
    final preview = CardParser.preview(
      raw: '1001 aaa 10\n1002 20\n1001 ccc 10\n1003',
      existingLabels: <String, String>{'1002': '旧批次'},
    );

    expect(preview.cards.length, 1);
    expect(preview.cards.first.label, '1001');
    expect(preview.duplicateExisting.keys.single, '1002');
    expect(preview.duplicateWithinInput.single, '1001');
    expect(preview.issues.single.lineNumber, 4);
  });

  test('supports unified face override', () {
    final preview = CardParser.preview(
      raw: '1001 aaa\n1002 bbb',
      existingLabels: const <String, String>{},
      unifiedFace: 25,
    );

    expect(preview.cards.length, 2);
    expect(preview.cards.first.face, 25);
    expect(preview.cards.last.secret, 'bbb');
  });
}
