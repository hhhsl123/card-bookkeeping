import 'dart:js_interop';
import 'dart:js_util' as js_util;

@JS('eval')
external JSAny? _jsEval(JSString code);

Future<void> doCopy(String text) async {
  final escaped = text
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '');

  final promise = _jsEval("""
(async function() {
  try {
    await navigator.clipboard.writeText('$escaped');
    return true;
  } catch (error) {
    try {
      var field = document.createElement('textarea');
      field.value = '$escaped';
      field.setAttribute('readonly', '');
      field.style.cssText = 'position:fixed;left:0;top:0;width:1px;height:1px;opacity:0.01;';
      document.body.appendChild(field);
      field.focus();
      field.select();
      document.execCommand('copy');
      field.remove();
      return true;
    } catch (fallbackError) {
      return false;
    }
  }
})()
""".toJS);

  if (promise != null) {
    await js_util.promiseToFuture<Object?>(promise as Object);
  }
}

Future<String?> doRead() async {
  final promise = _jsEval("""
(async function() {
  try {
    return await navigator.clipboard.readText();
  } catch (error) {
    return null;
  }
})()
""".toJS);

  if (promise == null) return null;
  final value = await js_util.promiseToFuture<Object?>(promise as Object);
  final text = value?.toString() ?? '';
  return text.trim().isEmpty ? null : text;
}
