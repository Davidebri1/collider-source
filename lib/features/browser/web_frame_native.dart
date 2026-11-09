// Browser page surface on iOS / Android: the page itself in a WebView
// (webview_flutter). No proxy is needed natively: a WebView is not a frame,
// so sites that refuse framing load as they would in a browser.
//
// The WebView lives for the whole tab. Links, redirects and in-page
// navigation happen inside it and are reported up, so the address bar,
// Back/Forward and History follow the page without reloading it.
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A native tab is always one live WebView that follows its own links.
bool get webFrameIsLive => true;

class WebFrame extends StatefulWidget {
  final String url;

  /// The page moved to a new address on its own (link, form, script). The
  /// browser records it as a new entry for Back and History.
  final ValueChanged<String>? onNavigate;

  /// The page we asked for landed somewhere else while loading (a redirect,
  /// e.g. wikipedia.org -> www.wikipedia.org). Replaces the entry instead of
  /// adding one, so Back never bounces through the redirect.
  final ValueChanged<String>? onRedirect;

  /// The loaded page's own title, for the tab and History.
  final void Function(String url, String title)? onTitle;

  /// Bumped by the Reload control; reloads the WebView in place.
  final int reload;

  const WebFrame({super.key, required this.url, this.onNavigate, this.onRedirect, this.onTitle, this.reload = 0});

  @override
  State<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends State<WebFrame> {
  late final WebViewController _ctrl;
  bool _loading = true;
  String? _error;

  /// Address the WebView is showing (or loading).
  String _current = '';

  /// False from a load we started until its page finished: an address change
  /// in that window is a redirect, not a new page.
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) {
            setState(() {
              _loading = true;
              _error = null;
            });
          }
        },
        onUrlChange: (c) => _moved(c.url),
        onPageFinished: (u) async {
          _moved(u);
          _settled = true;
          if (mounted) setState(() => _loading = false);
          final t = await _ctrl.getTitle();
          if (mounted && t != null && t.trim().isNotEmpty) widget.onTitle?.call(_current, t.trim());
        },
        // Only the page itself failing counts; a broken image or tracker on
        // a page that did load must not cover it with an error.
        onWebResourceError: (e) {
          if (e.isForMainFrame == false) return;
          if (mounted) {
            setState(() {
              _loading = false;
              _error = e.description;
            });
          }
        },
      ));
    _load(widget.url);
  }

  void _load(String url) {
    _current = url;
    _settled = false;
    _ctrl.loadRequest(Uri.parse(url));
  }

  void _moved(String? url) {
    if (url == null || url.isEmpty || url == _current || url == 'about:blank') return;
    _current = url;
    if (_settled) {
      widget.onNavigate?.call(url);
    } else {
      widget.onRedirect?.call(url);
    }
  }

  @override
  void didUpdateWidget(covariant WebFrame old) {
    super.didUpdateWidget(old);
    if (widget.reload != old.reload) {
      _settled = false;
      _ctrl.reload();
    } else if (widget.url != _current) {
      _load(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: WebViewWidget(controller: _ctrl)),
        if (_error != null && !_loading)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFF14161A),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'This page could not be loaded.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFC7CBD1)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
