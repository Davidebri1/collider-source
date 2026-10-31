import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Plays [url] muted and looping with BoxFit.cover via a real HTML <video>
/// platform view. Texture-grabbing at 20fps (previous path) caused stutter
/// and soft frames; the browser's own decoder paints at full quality.
///
/// The element stays CSS-hidden until it has a decoded frame so the poster
/// underneath is never covered by a black video rectangle.
class LiveCoverVideo extends StatefulWidget {
  final String url;
  const LiveCoverVideo({super.key, required this.url});

  @override
  State<LiveCoverVideo> createState() => _LiveCoverVideoState();
}

class _LiveCoverVideoState extends State<LiveCoverVideo> {
  late final String _viewType;
  web.HTMLVideoElement? _v;

  @override
  void initState() {
    super.initState();
    _viewType = 'collider-live-cover-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final v = web.document.createElement('video') as web.HTMLVideoElement;
      v.muted = true;
      v.defaultMuted = true;
      v.loop = true;
      v.autoplay = true;
      v.playsInline = true;
      v.preload = 'auto';
      v.setAttribute('muted', '');
      v.setAttribute('playsinline', '');
      v.setAttribute('autoplay', '');
      v.crossOrigin = 'anonymous';
      final s = v.style;
      s.width = '100%';
      s.height = '100%';
      s.objectFit = 'cover';
      s.border = '0';
      s.display = 'block';
      s.background = 'transparent';
      // Hide until a frame is ready — otherwise a black <video> blanks the poster.
      s.opacity = '0';
      s.transition = 'opacity 280ms ease-out';
      void reveal(web.Event _) {
        if (v.style.opacity == '1') return;
        v.style.opacity = '1';
      }
      v.addEventListener('loadeddata', reveal.toJS);
      v.addEventListener('playing', reveal.toJS);
      v.addEventListener('canplay', reveal.toJS);
      v.src = widget.url;
      v.play().toDart.catchError((_) => null);
      _v = v;
      return v;
    });
  }

  @override
  void dispose() {
    final v = _v;
    if (v != null) {
      v.pause();
      v.removeAttribute('src');
      v.load();
    }
    _v = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
