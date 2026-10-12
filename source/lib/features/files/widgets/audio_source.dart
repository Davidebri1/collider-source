// Where a stored audio file plays from (conditional export, mirroring
// video_source.dart): a blob: URL on web, a file in the app cache on iOS/Android.
export 'audio_source_native.dart' if (dart.library.js_interop) 'audio_source_web.dart';