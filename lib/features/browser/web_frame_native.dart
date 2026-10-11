// Browser page surface on iOS / Android: the page itself in a WebView
// (webview_flutter). No proxy is needed natively: a WebView is not a frame,
// so sites that refuse framing load as they would in a browser.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebFrame extends StatefulWidget {
  final String url;
  final double zoom; // applied by the WebView's own text zoom where supported

  /// Find-on-page requests from the browser rail's Find bar. Each value is
  /// one `window.find` call — repeated calls with the same query advance the
  /// selection, which is the next/previous behaviour.
  final ValueListenable<String?>? findRequests;

  /// Cache-clear requests from the browser rail / tabs panel. Each increment
  /// clears the WebView cache once.
  final ValueListenable<int>? clearRequests;

  const WebFrame({
    super.key,
    required this.url,
    this.zoom = 1,
    this.findRequests,
    this.clearRequests,
  });

  @override
  State<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends State<WebFrame> {
  late final WebViewController _ctrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
    widget.findRequests?.addListener(_onFind);
    widget.clearRequests?.addListener(_onClear);
  }

  void _onFind() {
    final raw = widget.findRequests?.value;
    if (raw == null || raw.isEmpty) return;
    // The sheet appends an invisible sequence marker so repeated finds with
    // the same query still notify (ValueNotifier drops same-value sets).
    final q = raw.contains('\u200b') ? raw.substring(0, raw.indexOf('\u200b')) : raw;
    if (q.isEmpty) return;
    // window.find selects the next match; it is a legacy API but it is the
    // only in-page find a WebView offers without injecting per-site CSS.
    _ctrl.runJavaScript('window.find(${jsonEncodeForJs(q)});');
  }

  void _onClear() async {
    await _ctrl.clearCache();
    await _ctrl.clearLocalStorage();
  }

  static String jsonEncodeForJs(String s) =>
      // Minimal JSON string escaping for a JS string literal.
      '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n')}"';

  @override
  void didUpdateWidget(covariant WebFrame old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _ctrl.loadRequest(Uri.parse(widget.url));
    if (old.findRequests != widget.findRequests) {
      old.findRequests?.removeListener(_onFind);
      widget.findRequests?.addListener(_onFind);
    }
    if (old.clearRequests != widget.clearRequests) {
      old.clearRequests?.removeListener(_onClear);
      widget.clearRequests?.addListener(_onClear);
    }
  }

  @override
  void dispose() {
    widget.findRequests?.removeListener(_onFind);
    widget.clearRequests?.removeListener(_onClear);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _ctrl)),
          if (_loading)
            const Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator(minHeight: 2)),
        ],
      );
}
