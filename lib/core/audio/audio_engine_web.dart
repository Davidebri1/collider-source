// Web audio engine. Made by Claude.
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class AudioEngine {
  web.HTMLAudioElement? _el;
  String _src = '';
  void Function()? onEnded;

  void play(String url) {
    if (_el == null) {
      _el = web.HTMLAudioElement();
      _el!.crossOrigin = 'anonymous';
      _el!.setAttribute('data-collider-audio', '1');
      // Attach so the element is in the document (autoplay + playtests).
      web.document.body?.appendChild(_el!);
      _el!.addEventListener('ended', ((web.Event _) { onEnded?.call(); }).toJS);
    }
    if (_src != url) {
      _src = url;
      _el!.src = url;
      _el!.load();
    }
    // Ignore autoplay rejection; UI still shows playing and a user gesture retries.
    _el!.play().toDart.catchError((_) => null);
  }

  void pause() => _el?.pause();

  void stop() {
    _el?.pause();
    _el?.remove();
    _el = null;
    _src = '';
  }
}
