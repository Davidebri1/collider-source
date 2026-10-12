// Browser page surface on iOS / Android: the page itself in a WebView
// (webview_flutter). No proxy is needed natively: a WebView is not a frame,
// so sites that refuse framing load as they would in a browser.
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebFrame extends StatefulWidget {
  final String url;
  const WebFrame({super.key, required this.url});

  @override
  State<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends State<WebFrame> {
  late final WebViewController _ctrl;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF14161A))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) {
            setState(() {
              _loading = true;
              _error = null;
            });
          }
        },
        onPageFinished: (_) {
          if (mounted) {
            setState(() => _loading = false);
          }
        },
        // Without this the frame was a blank rectangle: the WebView reported
        // the failure and nothing ever said so.
        onWebResourceError: (e) {
          if (mounted) {
            setState(() {
              _loading = false;
              _error = e.description;
            });
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void didUpdateWidget(covariant WebFrame old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _ctrl.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: WebViewWidget(controller: _ctrl)),
        if (_loading)
          const Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator(minHeight: 2)),
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