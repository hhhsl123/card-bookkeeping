import 'dart:js_interop';

@JS('eval')
external JSAny? _jsEval(JSString code);

void doCopy(String text) {
  final escaped = text
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '');

  // Try navigator.clipboard.writeText first (works in iOS PWA with user gesture)
  // Then fallback to execCommand
  _jsEval("""
(function(){
  try {
    navigator.clipboard.writeText('$escaped');
  } catch(e) {}
  try {
    var t=document.createElement('textarea');
    t.value='$escaped';
    t.setAttribute('readonly','');
    t.style.cssText='position:fixed;left:0;top:0;width:1px;height:1px;padding:0;border:none;outline:none;box-shadow:none;opacity:0.01';
    document.body.appendChild(t);
    t.focus();
    t.select();
    try{t.setSelectionRange(0,99999)}catch(e){}
    document.execCommand('copy');
    t.remove();
  } catch(e) {}
})()
""".toJS);
}
