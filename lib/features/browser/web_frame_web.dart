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
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../core/api/collider_api.dart';
import 'page_markup.dart';

// One view type per page load, for the whole app. The old counter lived on
// each frame's State, and the browser builds a new frame (new key) for every
// address, so every frame after the first asked for 'collider-frame-1' again.
// That type was already registered with the first page's markup, so the
// browser kept showing its opening page whatever address was typed (v9.1.1+).
int _frameSeq = 0;

/// The browser's real proxy (Scramjet under <app>/proxy/, see
/// web/proxy/frame.html) is on when web/proxy/config.js names a Wisp server.
/// Then a tab keeps one live frame that follows its own links, like the
/// native WebView; without one, pages come through the page proxy as before.
bool get webFrameIsLive {
  final v = globalContext['COLLIDER_WISP_URL'];
  return v != null && v.isA<JSString>() && (v as JSString).toDart.trim().isNotEmpty;
}

class WebFrame extends StatefulWidget {
  final String url;

  /// A link or form inside the page asked for [url]. The browser opens it as
  /// a new address, so the address bar and Back follow the page.
  final ValueChanged<String>? onNavigate;

  /// Native-only hooks (the WebView reports redirects, titles and reloads in
  /// place); the proxied frame gets a new address for each of those instead.
  final ValueChanged<String>? onRedirect;
  final void Function(String url, String title)? onTitle;
  final int reload;
  const WebFrame({super.key, required this.url, this.onNavigate, this.onRedirect, this.onTitle, this.reload = 0});

  @override
  State<WebFrame> createState() => webFrameIsLive ? _LiveFrameState() : _WebFrameState();
}

/// One tab on the real proxy: an iframe (src, not srcdoc) on
/// <app>/proxy/frame.html, which runs the site through Scramjet and reports
/// where the page went and its title.
class _LiveFrameState extends State<WebFrame> {
  late final String _type;
  web.HTMLIFrameElement? _frame;
  JSFunction? _listener;
  String _current = '';
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _current = widget.url;
    final src = Uri.parse(web.document.baseURI).resolve('proxy/frame.html').toString() + '#' + Uri.encodeComponent(widget.url);
    _type = 'collider-live-${++_frameSeq}';
    ui_web.platformViewRegistry.registerViewFactory(_type, (int _) {
      final f = web.HTMLIFrameElement()
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.background = 'white'
        ..src = src;
      f.setAttribute('allow', 'fullscreen; autoplay; clipboard-write; encrypted-media; picture-in-picture');
      _frame = f;
      return f;
    });
    _listener = ((web.MessageEvent ev) {
      final f = _frame;
      if (f == null || ev.source == null || !identical(ev.source, f.contentWindow)) return;
      final d = ev.data?.dartify();
      if (d is! Map || d['colliderFrame'] != true) return;
      final url = d['url'];
      if (d['nav'] == true && url is String) _moved(url);
      if (d['loaded'] == true) {
        _settled = true;
        final t = d['title'];
        if (url is String && url.isNotEmpty && t is String && t.trim().isNotEmpty) widget.onTitle?.call(url, t.trim());
      }
    }).toJS;
    web.window.addEventListener('message', _listener);
  }

  void _moved(String url) {
    if (url.isEmpty || url == _current || url == 'about:blank') return;
    _current = url;
    if (_settled) {
      widget.onNavigate?.call(url);
    } else {
      widget.onRedirect?.call(url);
    }
  }

  void _post(Map<String, String> m) {
    final w = _frame?.contentWindow;
    if (w != null) w.postMessage(m.jsify(), web.window.location.origin.toJS);
  }

  @override
  void didUpdateWidget(covariant WebFrame old) {
    super.didUpdateWidget(old);
    if (widget.reload != old.reload) {
      _settled = false;
      _post({'colliderCmd': 'reload'});
    } else if (widget.url != _current) {
      _current = widget.url;
      _settled = false;
      _post({'colliderGo': widget.url});
    }
  }

  @override
  void dispose() {
    final l = _listener;
    if (l != null) web.window.removeEventListener('message', l);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _type);
}

class _WebFrameState extends State<WebFrame> {
  String? _html;
  String? _failed;
  String? _pending;
  String? _type;
  web.HTMLIFrameElement? _frame;
  JSFunction? _listener;

  @override
  void initState() {
    super.initState();
    _pending = widget.url;
    _listener = ((web.MessageEvent ev) {
      final f = _frame;
      if (f == null || ev.source == null || !identical(ev.source, f.contentWindow)) return;
      final url = pageNavTarget(ev.data?.dartify());
      if (url != null) widget.onNavigate?.call(url);
    }).toJS;
    web.window.addEventListener('message', _listener);
    _load(widget.url);
  }

  @override
  void dispose() {
    final l = _listener;
    if (l != null) web.window.removeEventListener('message', l);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WebFrame old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _load(widget.url);
  }

  Future<void> _load(String url) async {
    _pending = url;
    _html = null;
    _failed = null;
    final html = await ColliderApi.instance.pageHtml(url);
    // A later navigation has already claimed the frame; drop this reply.
    if (!mounted || _pending != url) return;
    setState(() {
      if (html == null) {
        _failed = url;
        _type = null;
      } else {
        _html = preparePageMarkup(html, url);
        _type = _register(_html!);
      }
    });
  }

  /// Registers a fresh view type for this page's markup and returns it.
  String _register(String html) {
    final type = 'collider-frame-${++_frameSeq}';
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
      f.setAttribute('data-collider-frame', type);
      f.setAttribute('srcdoc', html);
      _frame = f;
      return f;
    });
    return type;
  }

  @override
  Widget build(BuildContext context) {
    final html = _html;
    if (html == null) return _placeholder();

    final type = _type!;
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