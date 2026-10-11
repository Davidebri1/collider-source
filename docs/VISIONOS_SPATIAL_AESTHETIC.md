# VisionOS Spatial Design Aesthetic (Collider) — Glyph Cluster reference

This doc captures the actual aesthetic used in this codebase with visual references from the repo and code-level primitives. All images are clickable; also included a run link to the project folder.

## Run link
[Open Collider project folder](file:///C:/Users/D/Documents/Collider_source_v8.4/)

## Aesthetic summary (from code + shots)
- Dark spatial canvas (scaffold bg `0xFF07080B`, deep ambient)
- Translucent glass with specular rim (top-left highlight, bottom-right occlusion) via `SpecularRimPainter`
- Depth planes with increasing blur/shadow/rim: base (0) → prompt/resting/elevated/modal/work (16–36σ)
- Tight, premium type: Instrument Sans for UI, Cormorant Garamond for cinematic display
- Rounded forms: 22–32 card/sheet radii, full capsule buttons/ornaments
- Minimal chrome: floating glass ornaments, dock at bottom, side rail variants
- Legible overlays with light dim (`VOverlay.scrim` 0x33000000), unblurred around menus
- High-contrast text (primary white, secondaries stepped down)

## Core primitives
- `lib/core/vision/vision_kit.dart`: `VGlass`, `VCircleButton`, `VOrnament`, `VSegmented`, `VButton`, `VPress`, etc.
- `lib/core/vision/vision_tokens.dart`: colors (glass levels 0x18–0x2C white), radii (24 card/32 sheet), blur (12/20/32/40), type scale
- `lib/core/theme/spatial_theme.dart`: depth planes + blur/shadow
- `lib/core/theme/specular_border.dart`: specular rim painter (top-left highlight, bottom-right occlusion)
- `lib/core/theme/vision_glass.dart`: alternate glass wrapper

## Shots (visual evidence)
Click to view full size.

[![v8 Home Portrait](./shots/v8-home-portrait.png)](./shots/v8-home-portrait.png)
- v8-home-portrait.png — compact floating UI, glass capsule nav, minimal chrome

[![v8 Home Landscape](./shots/v8-home.png)](./shots/v8-home.png)
- v8-home.png — wider layout, spatial separation

[![Composer baseline](./shots/v9-composer-baseline.png)](./shots/v9-composer-baseline.png)
- v9-composer-baseline.png — composer overlay feel, glass surfaces

[![Search](./shots/v4-05-search.png)](./shots/v4-05-search.png)
- v4-05-search.png — search field (recessed capsule), list rows

[![Featured](./shots/v4-01-featured.png)](./shots/v4-01-featured.png)
- v4-01-featured.png — card grid with media tiles, airy spacing

[![Browse](./shots/v4-03-browse-393.png)](./shots/v4-03-browse-393.png)
- v4-03-browse-393.png — grid/list interplay

[![Files](./shots/v9b-files.png)](./shots/v9b-files.png)
- v9b-files.png — grouped list (VListGroup/rows), subdued surfaces

[![Market](./shots/sweep-market.png)](./shots/sweep-market.png)
- sweep-market.png — work surface feel (larger panel)

[![Apps popup](./shots/v6-apps.png)](./shots/v6-apps.png)
- v6-apps.png — floating capsule/overlay

[![Discover](./shots/run-01-discover-430.png)](./shots/run-01-discover-430.png)
- run-01-discover-430.png — segmented controls, glass ornaments

## Notes
- Specular rim is a custom painter (not just border) giving subtle top-left sheen.
- Depth increases blur+shadow as surfaces detach (modals/work surfaces heavier).
- Overlays prefer light, unblurred scrim; focused windows can blur background.
- Type uses Cormorant Garamond sparingly (cinematic display) + Instrument Sans for UI.

## Quick run
[Open project folder](file:///C:/Users/D/Documents/Collider_source_v8.4/)
Run in Flutter: `flutter run -d <device>` (iOS/visionOS simulator or device as appropriate).