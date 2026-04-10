import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'clipboard_web.dart' if (dart.library.io) 'clipboard_native.dart' as platform;

Future<void> copyToClipboard(String text) async {
  if (kIsWeb) {
    platform.doCopy(text);
  } else {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
