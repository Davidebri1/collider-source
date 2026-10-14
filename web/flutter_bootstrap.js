{{flutter_js}}
{{flutter_build_config}}
// v9.1.6e: the engine's default fallback ("Roboto" from fonts.gstatic.com) is
// served locally and is Google Sans Flex, so Roboto is never fetched.
_flutter.loader.load({
  config: { fontFallbackBaseUrl: "/collider-app/fonts/fallback/" },
});
