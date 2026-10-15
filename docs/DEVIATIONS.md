# v9.1 deviations from v9 (collider-source v9-final 76ca97cd)
Base: /workspace/collider/v91 (git: "v9 import" deea01d, overrides 3550dbe). Rule: David's direct requirements beat v9.

1. Media source: lib/core/media/theme_catalog.dart replaced with the v8.7 version (5f08e2b): theme list from https://collider-themes.ebridavid.workers.dev/ (R2), songs matched to live wallpapers by shared tags, cached copy then bundled catalog as fallback. v9 streamed from davidebri1.github.io/collider-media. Added lib/core/media/first_frame*.dart (posters = each video's first frame) and WallpaperTheme.tags.
2. Default wallpaper removed: assets/wallpapers/default_wallpaper.webp not imported, pubspec asset entry dropped; ThemeCatalog.offlineWallpaperAsset no longer used (theme_def poster fallback = '', ThemeImage fallback = plain dark box). Requirement: no hardcoded default wallpaper/thumbnail.
3. Files screen: lib/features/files/screens/files_screen.dart and widgets/video_player_view.dart replaced with the approved exact v8.4 Files screen (as live in v8.5/v8.6). v9's extra viewers (audio/image/pdf/text/unsupported, thumb codecs) remain in the tree but the v8.4 screen is what is shown.
4. [REVERTED 19:55, David: Instrument Sans was never banned] Font: Instrument Sans dropped (bundled ttf not imported, pubspec fonts block removed). GoogleFonts.instrumentSans -> GoogleFonts.inter; fontFamily 'InstrumentSans' -> Inter (main.dart, side_nav_rail.dart). Per QA rule S-C13 (SF Pro/Inter only).
5. Version 1.0.0+1 -> 9.1.0+91.
6. web/favicon.png taken from v8.7 (binary not fetched).
7. main.dart _onCatalogChanged: unknown/missing theme now falls to ThemeCatalog.defaultTheme (R2 ocean loop) instead of keeping v9's built-in default, so the R2 wallpaper shows on first launch (ported from v8.6).
8. [REVERTED, see 10] Inter self-hosted: assets/google_fonts/Inter-{Light,Regular,Italic,Medium,SemiBold,Bold,ExtraBold}.ttf (rsms/inter v4.1, OFL) declared as assets; google_fonts resolves them locally (v9 already sets allowRuntimeFetching=false), so no Google CDN call.
9. NEXT-v87 port (patch of v8.7 1412447..ab45a22 applied to v9, conflicts hand-merged):
   - Settings: v9's small GlassMenu replaced with the v8.7 Figma 10:2193 panel (1179x877 built at frame size, FittedBox-scaled as one unit to 30 %), suspended frost, no outline. Account opens on its own plane in front; Settings steps back (0.94 scale, slight blur).
   - Keyboard DOF: KeyboardDof installed; while the keyboard is up the room blurs (sigma 14) and the ticker window softens (sigma 4); composer stays sharp.
   - Premium Market: always-on search bar replaced by side nav (categories + Search) and a search popup with DOF blur; tapping the centred asset opens the exploded view with context menu.
   - Theme Gallery: tag ghost menu (centre sharp, neighbours blurred) on the left, filters by R2 tags; window narrowed by 112 to make room.
   - In-app browser (native): loading progress bar removed.
   - GlassMenu (vision_kit): white outline removed.
   - KEPT v9 instead of v8.7: ticker pill layout (v9 content-first ticker; v8.7 narrow-name hunk reverted), consensus row (v9 already has no progress bar and a 40 % ceiling via _TickerWindowLayout), scrollbars (v9 already disables them globally).
10. Font restored to v9: bundled InstrumentSans 400/500/600/700 (pubspec fonts block back, GoogleFonts.instrumentSans everywhere as in v9, Inter removed). The TTFs are Google Fonts' static Instrument Sans v4 cuts (~48 KB each); v9's own files (~38 KB) could not be fetched byte-exact through the connector (binary), so they are the same family but not the identical files.
11. Premium Market carousel: only the centred cover plays its live loop (was centre ±1); reflection fade tween removed so thumbnails have no per-item animation.
12. Painted decorative gradients removed (flat frost colour instead): GlassMenu (vision_kit), Smart Gen backdrop radial, ticker model pill surfaces, consensus row, composer foreground sheen. Approved v8.4 Files glass left exactly as approved.
13. Collision fix: the ticker/composer plane is hidden while Settings is open (it showed through Settings' frost).
14. Ticker pin capped at 40% height; pills use a 74px model-name column + one-line summary (full text on expand).
15. Overlays use one dim (VOverlay.scrim, no blur); blur only for focus. Ticker hidden under History/Music/Account; Market carousel clipped.
16. Spring Materialize/dissolve (lib/core/vision/materialize.dart) on Settings, Account, Market search/exploded, music widget, selection bar.
17. Multi-select: Files (long-press; Rename/Delete), History (long-press; Rename/Delete = local hide), Smart Gen (⋯ > Select; Move/Colour/Delete).
18. Music library lists every R2 song first (art from best tag-matching theme).
19. Market carousel clip REVERTED (David: side nav over the carousel edge is fine).
20. Escape: browser/phone back, Esc and a left-edge swipe close the top view (lib/core/nav/back_guard*.dart).
21. Ambient: still wallpapers drift ~4% over 40 s; a pulse dot on answering ticker rows. No glass shimmer (would be a painted gradient).
22. Labelled "Set as wallpaper" (Market) / "Set" (Gallery). Songs lists fade at the edges, no scrollbar. Names drop stock ids/resolutions; hash subtitles hidden.
23. ?seed=1 test-only sample Files/Smart Gen/History.
19. v9.1.1: font is Google Sans Flex (bundled static 400–700 instances), replacing Instrument Sans.
20. One glass recipe (VFrost: blur 34, 10 % white, no outline/gradient, soft shadow) on every floating panel; SuspendedFrost mask removed (it killed blur on web).
21. Nothing drawn on wallpaper media: Market cover apply button, border and chevrons removed; Gallery Back/Set moved below the preview. Video scrub track invisible.
22. Browser reads the Worker /page proxy (needs Worker redeploy); falls back to the old route.
23. v9.1.2: frost only on temporary surfaces; chrome light blur, no tint. Main view: no dark card, chat bubbles on wallpaper (hidden when empty), thin composer line, receding side rail. Browser home/search = Bing (Google/DDG block the Worker).
24. v9.1.3: no bottom bar (Settings/Home/Apps in a receding left column), no category chips (composer + menu / swipe), consensus bubble hidden until it has text.
25. v9.1.3: one solid glass (dark 48 % tint, blur 14) on every floating surface; work surfaces blur+dim the main view; Settings scrim blurs lightly; composer docked with options row, keyboard stays open on option taps and send; chat button removed.

## v9.1.6 — Home ticker placement (David, Oct 14 12:47 AM: not centred; bottom or sides)
Choice: the bottom area, inset to the right of the side rail, stacked directly above the composer, which docks on the nav bar.
Why: the thumb zone is the bottom third, so rows (tap to expand, long-press menu, toggles) sit where they're reachable one-handed. One vertical stack — rail → composer → nav bar — reads as a single control column and keeps the top two-thirds as open wallpaper (no overlays on wallpaper media). Stacking along the side would make each row narrower and cut the one-line summaries short. All ticker rules are unchanged: it's always present, scrolls past the four rows shown, can't be swiped away, and is blurred and non-interactive under other surfaces.

## v9.1.7 — Composer: + opens the menu (MASTER-LIST #41)
Change: the Attach / Web / Research / Private chip row above the composer is removed (input, attach and send only). The + button, which since v9.1.4 (playtest #5) only attached files, now opens the existing composer menu: Attach file, Create image / video / audio, Internet, Research, Deep Research, Private.
Why: with the chip row gone, Web, Research and Private would otherwise have no control at all, which would break working features. Attach stays the first item in the menu, so + still leads to attaching. Accepted by the lead agent Oct 15.
Evidence: release/v91/v917/shots/composer_before_after.png, c_plusmenu_b_crop.png.

## v9.1.7 — Ticker docks under tall panes (MASTER-LIST #6/#7)
Change: when Gallery, Premium, Music or the Browser is open, the pane ends above a band at the bottom, and the ticker sits in that band directly above the composer, blurred and tap-blocked, with two rows showing (the rest scroll). Gallery and Premium size themselves to the shorter room: the Premium stage scales down as one unit, and Gallery's name/Set row and strip keep a readable width that clears the side rail.
Also fixed: the ticker window was always 40 % of the screen tall, because CustomMultiChildLayout sizes to its constraints, which left a blank gap between the rows and the composer. It now wraps its rows, so on Home the rows sit directly over the composer, as the v9.1.6 placement above intended.
Evidence: release/v91/v917/shots/dock4v.png, dock3v.png, dock_interactions_v.png.

## v9.1.7 — Discover as the Grok Imagine feed in black (MASTER-LIST #18/#19/#121)
Copied literally from briefs/cinematic-refs/grok-imagine (01-masonry-detail, 02-templates-hero): a black stage edge to edge, a floating top bar that the content scrolls under, a "Create from template" portrait row (132 x 196, radius 16), then a flush two-column grid (3 px gaps, square corners, 0.67 aspect).
Deviations from the reference, each because a standing rule wins:
- No "Animate your photos" promo banner (#18: no promo headers).
- No Ask | Imagine toggle (never title it Imagine; discover-imagine-dialect.md). The centre pill reads "Discover" or the feed name.
- No hamburger circle: the feeds (Stills / Looks / Night) are on the overlaying side nav (#24). The top-right circle closes Discover instead of the reference's edit icon.
- No Discover composer ("Type to imagine"): the app keeps one composer (v9.1.4 playtest #12), which sits blurred in the dock band.
- Template labels sit below the image, not on it (David: nothing on top of an image).
- The black continues behind the docked ticker band (#121), as it does under Premium.
The previous file is kept at release/v91/v917/market_screen.v917pre.dart. Evidence: release/v91/v917/shots/disc_sbs2.png (the 3 Collider shots next to the 2 reference shots).
