import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'clipboard_web.dart' if (dart.library.io) 'clipboard_native.dart' as platform;

Future<void> copyToClipboard(String text) async {
  if (kIsWeb) {
    await platform.doCopy(text);
    return;
  }
  await Clipboard.setData(ClipboardData(text: text));
}

Future<String?> readClipboardText() async {
  if (kIsWeb) {
    return platform.doRead();
  }
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  return data?.text;
}
