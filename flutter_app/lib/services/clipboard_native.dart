import 'package:flutter/services.dart';

void doCopy(String text) {
  Clipboard.setData(ClipboardData(text: text));
}
