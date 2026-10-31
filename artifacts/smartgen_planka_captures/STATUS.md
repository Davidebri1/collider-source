# Smart Gen planka_app drop-in status

Branch: `smartgen/planka-dropin`
Standalone captures: `artifacts/smartgen_planka_captures/ours/00_home.png` … `12_labels.png` (440×956 @2x)
Sheet: `artifacts/smartgen_planka_captures/sheet/compare_sheet.png`

## Blank-grey cause
- Failing host path: full Collider `flutter build web` + `?app=smartgen` (also Collider home) → solid #C0C0C0 under box Chrome/SwiftShader.
- Working path (same Chrome args as PS): standalone `packages/smartgen_planka` `flutter build web -t lib/standalone_main.dart --base-href=/planka-dropin/` + `?sgcap=1&screen=…` → real UI.
- Not a Smart Gen route console error; ThemeLivingBackdrop video under nested MaterialApp aggravated WebGL — gated off for smartgen. Auth notify wiping ProxyProviders fixed for empty board after seed.

## Fixes in tree
- seedCapturePreview + standalone_main + capture_planka_standalone.mjs
- Auth tryAutoLogin no-op when already local; ProxyProviders `previous ??`
- EasyLocalization errorWidget → blue; FileBlobs load 2s timeout
- ThemeLivingBackdrop not mounted when smartgen; solid #0079BF underlay
- Board menu icon-only Genie/Align; Table/Search text; app_name cleared; Table list names; labelColors dual path
