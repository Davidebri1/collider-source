import 'dart:js_interop';

@JS('colliderGoogleSignIn')
external JSPromise<JSString> _colliderGoogleSignIn();

@JS('colliderCalendarToken')
external JSPromise<JSString> _colliderCalendarToken();

/// Google Identity Services ID token. Empty client id or a dismissed prompt
/// returns null. This never calls /auth/dev.
Future<String?> requestGoogleIdToken() async {
  final value = (await _colliderGoogleSignIn().toDart).toDart;
  if (value.isEmpty) return null;
  return value;
}

/// OAuth access token for Google Calendar events. Null when no client id is set.
Future<String?> requestCalendarAccessToken() async {
  final value = (await _colliderCalendarToken().toDart).toDart;
  if (value.isEmpty) return null;
  return value;
}
