# Collider branch review

Base: `collider-latest-wip` at `f4cd3fc` (v9.1.7, ticker docked above the composer under tall panes). The earlier review tip was `23f3610`. `f4cd3fc` is that tree plus the seven v9.1.7 commits through the dock. Commits on `collider-latest-wip` after `f4cd3fc` (through `435e06f`, the CPane pass) are not in this branch.
Compared branches are left untouched. `main` was not updated.
`v9.1` and `collider-9.1.6h-live` are the same commit (`cf0d986`), which is exactly the live app.

## How the comparison was made

`v9.1` is a direct parent of the base, so it has nothing the base does not already contain. Every other branch has no merge-base with the base: `deea01d` copied `v9-final`'s `source/` tree into this history instead of merging it. Unique work below is therefore the commits each branch added after it forked, read against the files that actually implement the screen.

Screenshots were taken from `flutter build web --base-href /collider-app/ --dart-define=COLLIDER_PROXY=https://vproxy-sepia.vercel.app` (GLM also with `COLLIDER_DEMO=true`). Headless Chrome, 390×844, device pixel ratio 3, 15 seconds after each screen was up. A local `/api/models` and `/api/history` fixture gave every branch the same six one-line answers so the ticker could be compared. Side-by-side images are in `docs/branch-review/`. The `latest-wip` and `best-of` columns in those images, and the motion clips under those two folders, were captured from `23f3610`, before the dock. The `best-of` column is being recaptured from `f4cd3fc`.

Motion was recorded in the same Chrome at 390×844, device pixel ratio 1, as a 30fps H.264 file. Capture was a CDP screencast (about 30–45fps on the home screen). Glyph and visionOS repainted too rarely for the screencast, so those two were sampled with a screenshot every 33ms instead. Each MP4 is constant 30fps: when a frame did not arrive, the previous one is held and counted as a dropped frame. A strip of the transition, one frame every 50ms, is under `docs/branch-review/motion/<branch>/strips/`. `feat/ticker-isolation-and-budget` still does not build, so it has no video.

## What each branch has that the base does not

| Branch | Unique feature or implementation | Files |
| --- | --- | --- |
| `main` (`bdd0d4e`, v8.5) | Chat-list ticker: a vertical stack of full model cards, not the compact v9 window. MiniMax consensus and restored error text from the v8.5 pass. | `source/lib/main.dart`, `source/lib/features/ticker/widgets/model_pill.dart`, `source/lib/features/ticker/widgets/consensus_row.dart`, `source/lib/features/consensus/consensus_view.dart` |
| `main` | Ambient stardust overlay on the wallpaper. Later removed on purpose. | `source/lib/core/theme/living_stardust_overlay.dart` |
| `main` | Prebuilt web bundle and the Windows launcher. Not app source. | `app/`, `Open Collider.cmd`, `Collider live link.url` |
| `v9-final` (`76ca97c`) | The import source of the v9.1 line. Its own later commits: ticker rows only when an answer exists, one bundled Instrument Sans, anchored side rail, content-first ticker, opaque inset sheets. | `source/lib/main.dart`, `source/lib/features/ticker/widgets/model_pill.dart`, `source/lib/features/ticker/widgets/consensus_row.dart`, `source/lib/features/nav/side_nav_rail.dart`, `source/lib/core/theme/spatial_theme.dart`, `source/assets/fonts/InstrumentSans-*.ttf`, `source/pubspec.yaml` |
| `v9-final` | Collider API server and the Vercel backend stub. The base calls the worker and `COLLIDER_PROXY` instead. | `server/collider-server.mjs`, `server/keys.example.json`, `backend/api/p.js`, `backend/vercel.json` |
| `v9-final` | QA notes and the design-doc set that never moved into the v9.1 tree. | `QA-REPORT.md`, `docs/` |
| `v9.1` (`cf0d986`) | Nothing the base lacks. It is an ancestor. The base adds `23f3610` and the v9.1.7 commits through `f4cd3fc` (docked ticker, wrapped ticker window, composer `+` menu, 65 broken themes hidden, centred History, QA unlock hooks). | — |
| `backup/glm-spatial-consistency` (`852c6d5`) | Ticker rebuilt to a bounded window: provider-tinted rows, white outgoing bubbles, headcount consensus, page dots, category swipe, press-toggle decay, closeable compact answer. | `lib/features/ticker/widgets/figma_ticker.dart`, `lib/features/ticker/widgets/model_pill.dart`, `lib/features/ticker/widgets/consensus_row.dart`, `lib/main.dart` |
| `backup/glm-spatial-consistency` | `COLLIDER_DEMO` canned roster and job for screenshot tours. | `lib/core/api/collider_api.dart` |
| `backup/glm-spatial-consistency` | Conjured-glass primitives, painted VGlass rim, composer depth of field, edge fades on files, browser tabs, and account. | `lib/core/theme/conjured.dart`, `lib/core/theme/vision_glass.dart`, `lib/core/theme/edge_fade.dart`, `lib/features/account/account_sheet.dart`, `lib/features/files/screens/files_screen.dart`, `lib/features/browser/screens/in_app_browser_sheet.dart` |
| `backup/glm-spatial-consistency` | Full Smart Gen board (lanes, type pills, genie) rather than the Figma workspace. | `lib/features/smartgen/widgets/sg_kanban.dart`, `lib/features/smartgen/widgets/sg_card_face.dart`, `lib/features/smartgen/widgets/smart_genie_panel.dart`, `lib/features/smartgen/screens/` (via `lib/features/smartgen/`) |
| `backup/glm-spatial-consistency` | Alternate premium market and the design-story page. | `lib/features/theme/premium_market_alt_view.dart`, `docs/design-story.html`, `docs/GLM-5-WHYS.md` |
| `feat/market-row21-window` (`c9d4b01`) | Discover rebuilt as a floating window to Figma Reference Map row 21, with a header kept on empty views and a varied masonry. | `lib/features/market/screens/market_screen.dart`, `lib/main.dart` |
| `feat/market-row21-window` | Theme Gallery floated as a cluster, with a window rim and the original crop. No blur while browsing. | `lib/features/wallpaper/widgets/windowless_theme_scroller.dart` |
| `feat/market-row21-window` | Five real tracks per premium pack, and the PRD / component catalog. | `lib/features/drawers/music_collection_drawer.dart`, `lib/core/media/theme_media_bundle.dart`, `docs/PRD-REFERENCE.md`, `docs/COMPONENT-CATALOG.md` |
| `feat/ticker-isolation-and-budget` (`5b1791b`) | Isolated models drawn as a separate group (hairline and a left edge) instead of dimmed, and the ticker pane capped at 40% of the screen. Does not build (see below). The 40% cap is already in the base. | `source/lib/features/ticker/widgets/model_pill.dart`, `source/lib/main.dart` |
| `glyph-cluster-visionos-spatial-aesthetic` (`142dd4e`) | Portrait ticker sheet sat on the dock, sized from the wechat window ratios, consensus pinned, thread beside the reel. | `lib/features/ticker/widgets/ticker_sheet.dart`, `lib/main.dart` |
| `glyph-cluster-visionos-spatial-aesthetic` | Collider kit (one glass recipe) and a focus carousel. Rail centred in the field above the lower group. Surfaces sized against their window. | `lib/core/kit/collider_kit.dart`, `lib/core/kit/focus_carousel.dart`, `lib/features/nav/side_nav_rail.dart`, `lib/features/mediagen/figma_media_stage.dart` |
| `glyph-cluster-visionos-spatial-aesthetic` | Reference map of the 27 frames and the spatial-aesthetic note. | `docs/REFERENCE-MAP.md`, `docs/VISIONOS_SPATIAL_AESTHETIC.md`, `docs/map-thumbs/` |
| `qa/e2e-fixes` (`ff9b575`) | Premium carousel reverted to the 3D CoverFlow (per-card matrix, reflection, neighbour peek) after two rewrites left a single card in a void. | `source/lib/features/theme/premium_theme_market_view.dart` |
| `qa/e2e-fixes` | Bundled catalog replaced with the live slug list, composer built at its real width instead of a FittedBox scale, deep link guarded so one bad history record cannot skip `?app=`. | `source/assets/catalog/themes.json`, `source/lib/core/media/theme_catalog.dart`, `source/lib/features/prompt/floating_prompt.dart`, `source/lib/main.dart` |
| `qa/e2e-fixes` | Consensus surface says when there is no job, instead of a blank page with a close button. | `source/lib/features/consensus/consensus_webview.dart` |
| `visionos-portrait-rebuild` (`c7f6df9`) | Rail contract: search first, contextual items wired. Seven-app platter with a scrim. Ticker cinema. Browser rail. Layers separated so panes do not share one stack. | `lib/features/nav/contextual_side_nav.dart`, `lib/features/nav/side_nav_rail.dart`, `lib/features/apps/apps_popup_pane.dart`, `lib/features/ticker/widgets/ticker_sheet.dart`, `lib/features/browser/screens/in_app_browser_sheet.dart`, `lib/main.dart` |

The base already contains the v9.1.6 line those older branches never got: Google Sans Flex, four visible ticker rows inside a 40% window, elevation 0/2/6/12, phone-shaped covers, Discover as the Grok Imagine grid, and the playtest fixes in `23f3610`. From `f4cd3fc` it also docks that ticker, two rows showing, in the band above the composer while Gallery, Premium, Music, or the Browser is open, and the ticker window wraps its rows instead of staying 40% tall with a blank gap.

## Builds

| Branch | Web build |
| --- | --- |
| `main` | Built |
| `v9-final` | Built |
| `v9.1` | Built |
| `collider-latest-wip` | Built |
| `backup/glm-spatial-consistency` | Built (`COLLIDER_DEMO=true`) |
| `feat/market-row21-window` | Built |
| `feat/ticker-isolation-and-budget` | Failed. `source/lib/features/ticker/widgets/model_pill.dart` calls `Border.all(left: ...)`. `Border.all` has no `left` parameter (`Border` does). dart2js exited 1. Not screenshot. |
| `glyph-cluster-visionos-spatial-aesthetic` | Built |
| `qa/e2e-fixes` | Built |
| `visionos-portrait-rebuild` | Built |
| `integration/best-of-branches` | Built. Same Dart sources as the base, so the column matches `latest-wip`. |

## Feature decisions

Judged one feature at a time. A branch can lose the rest of a screen and still win a feature. Type is Google Sans Flex on this branch, so a source screen in another face is not a reason to reject. The base is `collider-latest-wip` at `4304d58`. Close-ups are in `docs/branch-review/closeups/`. The whole-screen table further down is the earlier pass and is not the decision.

`Looks` on the Surfaces sheet (Discover side nav: Search, Library, Looks) is not confirmed. The opened market rail reads Stills, Templates, Cinematic, Night.

| Feature | Source branch | Decision | Reason | Side-by-side |
| --- | --- | --- | --- | --- |
| Search-first side nav | `visionos-portrait-rebuild` | Ported | R14. The home rail opens on Search, then New Chat, Local History, Global History. Semantics on the shot: Search at (39.5, 106). It is the first item on this branch's ticker rail. | `closeups/visionos-rail-search-first.png`, `closeups/base-rail.png` |
| Consensus side-nav entry | `visionos-portrait-rebuild`, and Roundup on the base | Rejected | R14 and R16. Consensus is the pinned ticker row, not a rail tab. The visionOS rail still has Consensus. Roundup is removed from this branch's rail. The pinned count stays. | `closeups/visionos-rail-search-first.png` (Consensus is on that rail), `closeups/base-rail.png` (Roundup was on the base shot) |
| Discover as a centred window | `feat/market-row21-window` | Ported | R36. The shot is a floating panel (Sanctuary Stills, Stills / Templates / Cinematic / Night), not a full-width sheet. The window is ported. The Sanctuary content is not. The base Grok feed (template row, two-column grid) sits inside it. | `closeups/market-discover-window.png` |
| Five tracks per premium pack | `feat/market-row21-window` | Ported | R30. The branch's bundled catalog has five titles on each premium slug. Those slugs are not the live wallpapers, and the opened premium screen is Golden Cloud with no track list. The count is applied to each sold live pack, using real songs from the live catalog. The snapshot is not swapped in. | `closeups/market-premium-tracks.png` |
| Uncropped gallery thumbnails | `feat/market-row21-window` | Ported | R32. A thumbnail shows the whole subject. The letterbox blur stays inside the chip. The room behind the gallery is not blurred. | `closeups/market-gallery-thumbs.png`, `closeups/market-gallery-window.png` |
| Premium CoverFlow | `qa/e2e-fixes` | Skipped | Restored separately from v8.3 on `collider-latest-wip`. Not judged here. | — |
| Isolation hairline and left edge | `feat/ticker-isolation-and-budget` | Ported | R41. An isolated model stays fully lit, in its own block under a hairline, with a left edge. The score counts only models still on the shared query. A general send builds fresh rows, so they come back in. The branch did not compile (`Border.all` has no `left`). That is fixed on the branch as `6a98cf5`. `flutter build web` succeeded and the page painted a ticker (GLM 5.3 Flash, dock, Apps). | `closeups/ticker-runs.png` |
| Ticker height budget | `feat/ticker-isolation-and-budget` | Rejected | R08. The base ticker window is already capped at 40% of its height. The branch only changed the v8.5 sheet from 52% to 40%. | — |

## Decisions

The table above replaces this one. It is kept so the earlier whole-screen pass is still on the page. Judged against David's PRD (`Collider-PRD-2-full`). Every row cites the requirement. The PRD repeats `R03` and `R04` (Account, then Product / Categories); the Area is named when the id is ambiguous. There is no `R38`.

Smart Gen and Files on `glyph` and `visionos-portrait-rebuild` were wallpaper in the first pass: the `?drawer=` link never opened them. Those four shots were retaken by tapping Apps, then the icon. History on those two was retaken by tapping Global History. The new frames are in the Smart Gen, Files, and History side-by-sides.

`v9.1` and the base are the same design. Pixel difference per screen is under 7/255 and is the moving wallpaper, not layout. The base is chosen over `v9.1` because `23f3610` keeps that design and adds the playtest fixes: a stable ticker element so the grey slab cannot come back, the broken Winter Moon loop hidden, a lighter first preload, lighter music glass, the Files player blurring the pane behind it, and premium ambient at 45% so the ticker can show through.

| Feature | PRD | Winner | Why |
| --- | --- | --- | --- |
| Home ticker | R08, R16, R17 | `f4cd3fc` | Bottom window, at most 40% tall, dock width, no card chrome, not draggable. Consensus is a pinned count (`4/6`) and one full line, not a percent. `main` is a full-height card list. `v9-final` and `qa` wrap the line. |
| Row selector | R09 | None | R09 is a 1 / 2 / 3 row selector, and three rows shows 9. The base shows four compact rows and scrolls the rest. No branch has that selector. |
| Side nav search | R14 | `visionos-portrait-rebuild` | Search is the first item on the rail (then New Chat, Local History, Global History). Glyph starts at New Chat. The base rail was New / Local / Global / Roundup, with the search field only after a history item was already open. Search is now the first item on this branch too. Both visionOS and the base still keep a Consensus item, which R14 does not allow. |
| Apps platter | R13 | `f4cd3fc` and visionOS | Seven icons: Smart Gen, Discover, Theme Gallery, Premium, Files, Music, Browser. Opened from Apps. Clicking one closes the platter. |
| Theme browsing | R32, R29 | `f4cd3fc` | While Gallery is open the live wallpaper is not blurred and not dimmed; the preview sits in a window on top. visionOS removed its sigma-28 room blur and still dims the room. Gallery swaps the image only. There is no accent picker. |
| Premium | R30 | `f4cd3fc` | One live wallpaper, price on the button (`$3.99`, inside $2.99–$7.99), not unlocked by tier. The other branches fall back to a Golden Cloud title. |
| Discover | R27 | None | R27 is images only, in this order: a row of pictures, a row of labelled looks, a two-column feed. No template shelf, no clips, no songs. The base is a picture row and a two-column feed, then a shelf titled "Create from template" and tabs Stills / Templates / Night. visionOS and market open a Discover window that is still that shelf. Nobody has the labelled-looks row without the template shelf. |
| Smart Gen | R21, R24 | `visionos-portrait-rebuild` | Opened from Apps, the board is on screen: To Do, Doing, Done, New card. Glyph is the same board. The first shots of both were the home wallpaper. The base opens a different card workspace and does not show that board. Genie-locked-until-Pro (R21) is not visible on either. |
| Files | R33 | `f4cd3fc` | The Files surface opens with category nav and local names (Trip notes, Budget, Pitch, Contract). visionOS and glyph do open Files once tapped (the first shots did not); the list is catalog leftovers (`Gold Glitter Sparkles`, hash titles), which is not the generated-files surface. |
| Music | R31 | None on the shot | R31 is a corner volume after a track has played: tap mutes, long-press opens play and volume. The shots are the collection, and the corner control was not on screen. |
| Browser | R34, D6 | `qa/e2e-fixes` and `v9-final` in code | Home is Google in those two. The base, and `v9.1`, point the home at Bing. The captured page on `qa` and `v9-final` never painted Google (local preview), so the requirement is not met on the shot. Google was not switched on this branch, because the web frame does not show it. |
| History | R19 | `f4cd3fc` | The base shot shows the session list. visionOS and glyph only showed the history panel after Global History was tapped; the list itself stayed empty in that capture. |
| Settings | R02, R35, R37 | `f4cd3fc` | Account and the functional options live in Settings. It is a small overlay, not a cosmetic theme picker. First launch is the ticker, not a sign-in screen (R01). |
| Spring | R36 | `f4cd3fc` | Wallpaper stays visible at rest. Panes materialise (scale, blur, opacity) instead of cutting. No particle field. The motion section is this requirement. |

## Motion

Videos and 50ms strips: `docs/branch-review/motion/<branch>/`. Scores: `docs/branch-review/motion/scores.json`.

A transition counts as **materialise** when the change is spread over at least 160ms and at least four captured frames, with no single frame holding most of the change. **Partial** means it moves across more than one frame and then settles in a step. **Cut** means one frame does the whole change. Stutter is a captured frame inside that burst that did not change. Dropped frames are gaps in the capture longer than 50ms. Grey slab is a flat mid-grey frame. None of the clips produced one.

The spring in `lib/core/vision/materialize.dart` (scale, blur, and opacity on one animation) is what the v9.1 line uses for panes. It is the only implementation that materialises. `v9.1`, `collider-latest-wip`, and `best-of` agree. The others open Settings, Account, and most Apps destinations as a cut. `best-of` is that same spring, so nothing was copied in from another branch.

| Transition | What the wip / best-of clip did | Elsewhere |
| --- | --- | --- |
| Settings | Materialise 367ms in, partial 200ms out. 0 flash, 0 grey, 2 stutter frames on the way in. 36fps, 2 dropped. | Cut, one frame. |
| Apps | Materialise about 450ms in and 300ms out. 0 flash. | `v9-final` opens in 167ms. The rest cut or stop at a short partial. |
| Gallery | Partial 367ms in. Capture fell to 26fps (25 dropped), so the spring is undersampled. | Cut, except `qa`, whose close runs 1100ms with 18 stutter frames. |
| Premium | Open is one step at 18fps (43 dropped). Dissolve is 567ms, with one luminance flicker and 8 stutter frames. | Same open limit. The dissolve is the v9.1 line only. |
| Discover | Two-frame step, about 170ms. 0 flash. 33fps. | Cut. |
| Smart Gen | Two-frame step, about 230ms. | Cut, or a similar short step on `main`. |
| Files | Partial, about 170ms in and 200ms out. | Cut. |
| Music | Partial, 200ms in and 300ms out. One jump on the way out. | `market-row21` opens over 333ms and does not show a close. |
| Browser | The sheet steps in over about 130ms. The page then arrives in one frame (centre change above 170/255). | `main` and `qa` fade the sheet over 200–400ms, then the page still pops. Their pages are the JSON dump and the local preview, so the fade was not taken. |
| History | Materialise 467–500ms in. 0 flash, 0 grey slab. Close is a 67ms step. | `v9-final` flashes 18 times on the way in. `market-row21` flashes 12. |
| Account | Materialise about 430ms in, partial 300ms out. 0 flash. | Cut. |
| Ticker row | Expand is partial, 200–300ms, four moving frames. Collapse is one frame. | `main`, GLM, and market show no expand. `v9.1` landed as a 33ms step on this take. |
| Side nav | Partial 300ms open and 367ms close on wip. `best-of` measured materialise both ways (333ms / 400ms). Same code. | Cut. |
| Free / Premium | Dragging the Free pill downward switches Gallery to Premium. The change is two frames about 100ms apart, about 1.5s after the drag starts. 35fps, 4 dropped, no flash. | `qa`, `main`, `v9-final`, and market did not switch. Glyph and visionOS dropped to about 3fps during the drag. |
| Wallpaper, 10s | Plays. Restarts with a seam every 4.1s (top-of-frame change about 13/255 against a baseline near 1). 0 streaked scanlines. | `main`, `v9-final`, GLM, market, glyph, and visionOS are still. `qa` plays and has no seam inside 10s; its default is Beach Waves, a different wallpaper, so it stayed there. |

`v9.1` matches this table on Settings, Apps, Account, and History. Its ticker expand and a few closes were a single step on this recording. The base keeps the same spring and the ticker key from `23f3610`, which is what stops a pane dissolve from rebuilding the ticker into the grey slab. The slab did not appear in any clip.

## Brought into `integration/best-of-branches`

The branch is cut from `collider-latest-wip` at `4304d58`. Taken from other branches, into this design: the search-first ticker rail (R14, visionOS), Discover as a centred window around the Grok feed (R36, market-row21), at least five tracks on each sold live pack (R30, market-row21), whole-subject gallery thumbnails (R32, market-row21), and the isolation hairline plus left edge (R41, ticker-isolation, after the border fix on that branch). Roundup is off the rail (R14, R16). CoverFlow is skipped. The 40% ticker cap was already here (R08).

Also on this tree:

- the v9 ticker, gallery, premium market, Discover grid, Smart Gen workspace, Files, Music, browser, and History from `v9.1` (`cf0d986`)
- the playtest fixes from `23f3610` (ticker key, blocked Winter Moon, preload, music glass, Files player blur, premium ambient opacity)
- the v9.1.7 dock from `39dbf15` and `f4cd3fc`: under Gallery, Premium, Music, and Browser the pane stops above the ticker, two rows show, and the window is only as tall as those rows
- the same materialise spring those fixes sit on

The visionOS Smart Gen board won the opened shot (R21, R24) and was not copied. It is a different window, and it still does not show Genie locked until Pro. Discover (R27) and the row selector (R09) have no winner to copy.

## Rejected

| Source | Rejected | Why |
| --- | --- | --- |
| `main` | Full-list ticker, stardust overlay, prebuilt `app/` | A full list is the opposite of the v9 window. Stardust was removed on purpose. The bundle is a build output. |
| `v9-final` | Instrument Sans ticker, multi-line consensus, side stack, Golden Cloud premium, `server/` | Type is not Google Sans Flex. Consensus is not one line. Premium is the void. The server is not what the app calls anymore. |
| `v9.1` | Nothing to take | Already contained in the base. |
| GLM | Dotted bounded ticker, conjured glass, alt premium, Smart Gen lane board, demo mode | Dots and a closeable answer fight the v9 ticker. Fonts are not Google Sans Flex. The home ticker does not read as the compact window. Demo mode is a screenshot switch. |
| `feat/market-row21-window` | Floating Discover window, gallery rim, Expand View | Discover shot is the sparse Sanctuary / Stills 21 window, not the black Grok grid. Expand View sits on the image. |
| `feat/ticker-isolation-and-budget` | Group hairline and left edge | Does not compile. The 40% cap and the four-row window are already on the base. Isolation is already a flag on an inline reply, without the broken border. |
| glyph | Docked portrait `TickerSheet`, kit, focus carousel | Inter and Instrument Sans. Home does not show the compact ticker. Gallery still has Expand View. Premium is Golden Cloud. |
| `qa/e2e-fixes` | 3D CoverFlow, bundled catalog swap, FittedBox composer fix | Premium is still Golden Cloud. The base already streams the live R2 catalog and builds the composer at its real width. Consensus wraps to several lines. |
| `visionos-portrait-rebuild` | Search-first rail, 7-app platter, ticker cinema, browser rail | Same portrait stack as glyph, same Expand View, same Golden Cloud premium, History empty. |

## Gaps

- `feat/ticker-isolation-and-budget` has no screenshot column and no motion clip because it does not build (`Border.all` has no `left` parameter).
- Long-press menus were not exercised; the shots are the resting screen and the tap-to-expand ticker.
- Premium’s open and the Gallery’s open drop below 30fps while the live covers and blurs are compositing (about 18fps and 26fps). Those dissolves are judged on the frames that did arrive.
- The Free/Premium drag is the pill on Gallery. On the v9.1 line it does switch. The landing is a short step, later than the finger movement.
- The home loop on this branch has a seam every 4.1s. `qa`’s Beach Waves loop does not, and it was left in place because it is a different wallpaper.
- Music is the collection. The floating player is off unless Settings turns it on, so the shot is the list, not a transport bar.
- The side-by-side columns `best-of` and `latest-wip` were shot from `23f3610`. This branch is now `f4cd3fc`, plus Search as the first side-nav item. The dock is in the tree and is not yet in those two columns. Smart Gen, Files, and History for `glyph` and `visionos` were retaken with the feature actually open.
- `collider-latest-wip` has commits after `f4cd3fc` (Discover rebuild, CPane, through `435e06f`). They were left on that branch.
