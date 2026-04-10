import 'dart:math';

final Random _random = Random();
int _counter = 0;

String generateId([String prefix = 'id']) {
  _counter += 1;
  final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final randomPart = _random.nextInt(0x7FFFFFFF).toRadixString(36);
  return '${prefix}_${timestamp}_${_counter.toRadixString(36)}_$randomPart';
}
