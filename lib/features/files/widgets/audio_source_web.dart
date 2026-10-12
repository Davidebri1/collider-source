import 'dart:js_interop';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart' as ja;
import 'package:web/web.dart' as web;

/// A player for the stored [bytes] (an object URL; freed by [release]).
class AudioSource {
  final ja.AudioPlayer player;
  final String _url;
  AudioSource._(this.player, this._url);

  static Future<AudioSource?> open(String name, Uint8List bytes, String mime) async {
    try {
      final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
      final url = web.URL.createObjectURL(blob);
      final player = ja.AudioPlayer();
      await player.setUrl(url, preload: true);
      return AudioSource._(player, url);
    } catch (_) {
      return null;
    }
  }

  Future<void> release() async {
    try {
      await player.dispose();
    } catch (_) {}
    web.URL.revokeObjectURL(_url);
  }
}