// Browser page surface (web).
//
// The page markup comes from the server's /api/page proxy, which answers with
// JSON `{ html }`. The old frame pointed the iframe's src straight at that
// endpoint, so the browser rendered the raw JSON body instead of the page --
// which is why the browser "did not work at all". Now the client reads the
// documented JSON and puts the markup in the frame itself.
//
// The frame is sandboxed without allow-same-origin, so a page's scripts run on
// an opaque origin: they can never reach Collider's storage, cookies or /api.
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../core/api/collider_api.dart';

final Set<String> _registered = {};

class WebFrame extends StatefulWidget {
  final String url;
  /// Address-bar zoom. The page still loads through the JSON proxy; the
  /// factor is kept so the glyph window can pass it without a second frame.
  final double zoom;
  const WebFrame({super.key, required this.url, this.zoom = 1});

  @override
  State<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends State<WebFrame> {
  String? _html;
  String? _failed;
  String? _pending;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _pending = widget.url;
    _load(widget.url);
  }

  @override
  void didUpdateWidget(covariant WebFrame old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.zoom != widget.zoom) _load(widget.url);
  }

  Future<void> _load(String url) async {
    _pending = url;
    _html = null;
    _failed = null;
    final html = await ColliderApi.instance.pageHtml(url);
    // A later navigation has already claimed the frame; drop this reply.
    if (!mounted || _pending != url) return;
    setState(() {
      _gen++;
      if (html == null) {
        _failed = url;
      } else {
        _html = _withBase(html, url);
      }
    });
  }

  /// Relative links, images and stylesheets are written against the real site,
  /// so the markup has to say which site it came from.
  static String _withBase(String html, String target) {
    final safe = target.replaceAll('"', '%22').replaceAll('<', '%3C');
    final tag = '<base href="$safe">';
    final stripped = html.replaceAll(RegExp(r'<base[^>]*>', caseSensitive: false), '');
    final head = RegExp(r'<head[^>]*>', caseSensitive: false).firstMatch(stripped);
    if (head != null) return stripped.replaceRange(head.end, head.end, tag);
    final open = RegExp(r'<html[^>]*>', caseSensitive: false).firstMatch(stripped);
    if (open != null) return stripped.replaceRange(open.end, open.end, tag);
    return '$tag$stripped';
  }

  @override
  Widget build(BuildContext context) {
    final html = _html;
    if (html == null) return _placeholder();

    final type = 'collider-frame-$_gen';
    if (_registered.add(type)) {
      ui_web.platformViewRegistry.registerViewFactory(type, (int _) {
        final f = web.HTMLIFrameElement()
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.background = 'white';
        // allow-scripts without allow-same-origin: the page runs, on an origin
        // of its own, and cannot read or call anything belonging to Collider.
        f.setAttribute('sandbox', 'allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox');
        f.setAttribute('referrerpolicy', 'no-referrer');
        f.setAttribute('scrolling', 'auto');
        f.setAttribute('srcdoc', html);
        return f;
      });
    }
    return HtmlElementView(key: ValueKey(type), viewType: type);
  }

  Widget _placeholder() {
    return ColoredBox(
      color: const Color(0xFF14161A),
      child: Center(
        child: _failed == null
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9AA0A6)))
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 22, color: Color(0xFF9AA0A6)),
                    const SizedBox(height: 10),
                    Text(
                      'This page could not be loaded.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFC7CBD1)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _failed!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF7A8087)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}