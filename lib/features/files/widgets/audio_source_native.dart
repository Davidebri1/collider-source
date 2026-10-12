import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';

/// A player for the stored [bytes] (written to the cache; removed by
/// [release]).
class AudioSource {
  final ja.AudioPlayer player;
  final File _file;
  AudioSource._(this.player, this._file);

  static Future<AudioSource?> open(String name, Uint8List bytes, String mime) async {
    try {
      final tmp = await getTemporaryDirectory();
      final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final f = File('${tmp.path}${Platform.pathSeparator}play_$safe');
      await f.writeAsBytes(bytes, flush: true);
      final player = ja.AudioPlayer();
      // The container is declared explicitly as the source tag: a mislabelled
      // extension should not stop the file playing.
      await player.setAudioSource(
        ja.AudioSource.file(f.path, tag: _tagFor(name)),
        preload: true,
      );
      return AudioSource._(player, f);
    } catch (_) {
      return null;
    }
  }

  static String _tagFor(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'mp3' => 'mp3',
      'm4a' || 'm4b' || 'mp4' || 'aac' => 'aac',
      'wav' || 'wave' => 'wav',
      'flac' => 'flac',
      'ogg' || 'oga' || 'opus' => 'ogg',
      _ => 'any',
    };
  }

  Future<void> release() async {
    try {
      await player.dispose();
    } catch (_) {}
    try {
      await _file.delete();
    } catch (_) {}
  }
}