import 'package:flutter/services.dart';

Future<void> doCopy(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}

Future<String?> doRead() async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  return data?.text;
}
