import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// v9.1 escape: the browser/phone back gesture closes the top view instead of
/// leaving the app. One guard history entry is kept in place.
void installBackGuard(void Function() onBack) {
  web.window.history.pushState(null, '', web.window.location.href);
  web.window.addEventListener(
      'popstate',
      ((web.Event _) {
        web.window.history.pushState(null, '', web.window.location.href);
        onBack();
      }).toJS);
}
