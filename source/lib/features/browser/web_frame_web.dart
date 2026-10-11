// Browser page surface (web). Made by Claude.
// Pages load through the local Collider server so sites that refuse framing
// still render. Without that server (static hosting, /api 404) the page is
// framed directly instead of showing the host's 404 (v8.3, D41).
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../../core/api/collider_api.dart';

final Set<String> _registered = {};

class WebFrame extends StatelessWidget {
  final String url;
  const WebFrame({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final src = ColliderApi.instance.online ? '/api/page?url=${Uri.encodeComponent(url)}' : url;
    final type = 'collider-frame-${src.hashCode}';
    if (_registered.add(type)) {
      ui_web.platformViewRegistry.registerViewFactory(type, (int _) {
        final f = web.HTMLIFrameElement()
          ..src = src
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.background = 'white';
        return f;
      });
    }
    return HtmlElementView(key: ValueKey(type), viewType: type);
  }
}
