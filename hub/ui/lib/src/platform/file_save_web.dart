// BuildBeacon UI — Saving a file in the browser: a download.
// Version 1.0 (2026-11-12)

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool saveTextFile(String name, String text, String type) {
  final blob = web.Blob(
    <JSAny>[text.toJS].toJS,
    web.BlobPropertyBag(type: type),
  );
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = name
    ..click();
  // Released a bit later: some browsers read it after the click returns.
  Timer(const Duration(seconds: 5), () => web.URL.revokeObjectURL(url));
  return true;
}
