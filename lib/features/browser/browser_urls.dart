// Start page and search for the in-app browser.
// PRD D6: the browser home is Google — DuckDuckGo home lost (X2). A native
// WebView loads pages directly, so Google works there. The web preview frames
// pages, and Google refuses framing, so the frameable engine (DuckDuckGo's
// html view through the server proxy, or Wikipedia without it) serves the
// preview only (v8.3, D41).
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/api/collider_api.dart';

/// The engines the rail's Search Engine control can pick. Native defaults to
/// Google (D6); the web preview starts on the frameable engine.
enum BrowserEngine { google, duckduckgo, wikipedia }

BrowserEngine defaultBrowserEngine() => kIsWeb ? BrowserEngine.duckduckgo : BrowserEngine.google;

String browserStartUrl([BrowserEngine engine = BrowserEngine.google]) {
  if (!kIsWeb) {
    return switch (engine) {
      BrowserEngine.google => 'https://www.google.com/',
      BrowserEngine.duckduckgo => 'https://duckduckgo.com/',
      BrowserEngine.wikipedia => 'https://www.wikipedia.org/',
    };
  }
  // Web preview: only the html view frames; without the server even that
  // refuses, so fall back to Wikipedia (D41).
  return ColliderApi.instance.online && engine != BrowserEngine.wikipedia
      ? 'https://html.duckduckgo.com/html/'
      : 'https://www.wikipedia.org/';
}

String browserSearchUrl(String q, [BrowserEngine engine = BrowserEngine.google]) {
  final encoded = Uri.encodeComponent(q);
  if (!kIsWeb) {
    return switch (engine) {
      BrowserEngine.google => 'https://www.google.com/search?q=$encoded',
      BrowserEngine.duckduckgo => 'https://duckduckgo.com/?q=$encoded',
      BrowserEngine.wikipedia => 'https://en.wikipedia.org/w/index.php?search=$encoded',
    };
  }
  return ColliderApi.instance.online && engine != BrowserEngine.wikipedia
      ? 'https://html.duckduckgo.com/html/?q=$encoded'
      : 'https://en.wikipedia.org/w/index.php?search=$encoded';
}
