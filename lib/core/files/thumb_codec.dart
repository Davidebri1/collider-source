// Real thumbnail sources that need a platform codec (zlib inflate, PCM
// waveform, a decoded video frame). Conditional export mirrors
// file_blobs.dart / video_source.dart: web uses the browser APIs, iOS/Android
// use dart:io.
export 'thumb_codec_native.dart' if (dart.library.js_interop) 'thumb_codec_web.dart';