# Collider master list
Rewritten Oct 15, 2026, from MASTER-LIST-2026-10-14.md, the pending task list and David's Oct 15 messages. Every row carries equal weight. The # is the working order only, not a ranking. A row counts as "Fixed on live" only with live evidence. Evidence paths are relative to /workspace/collider/. Live build at time of writing: v9.1.6h, main.dart.js a4171fc0…0b90.

| # | Area | Requirement | Status | Evidence |
|---|---|---|---|---|
| 1 | Premium | Premium live wallpapers can be set and checked on Home. Today they can't be set on the live link: purchases are disabled (`ThemePackStore.purchasesAvailable` is false), so no premium wallpaper has ever been set and checked on Home. The team needs a QA-only unlock, at least 10 premium wallpapers (every 4K one included) set on Home at 390x844 DPR 3 with 1 s / 4 s / 15 s shots, and a check that sets every live theme and flags black, frozen, streaked or soft results | Fixed in code, not live | QA-only unlock (dart-define COLLIDER_QA_UNLOCK, absent from prod main.dart.js). Set-wallpaper check over all 118 live themes: release/v91/v917/setwall/report.json; real UI set path release/v91/v917/shots/ui_set2.png. Live users still cannot buy (purchases disabled), which is not changed |
| 2 | Ticker | The v9 ticker restored exactly: compact one-line Consensus summaries, about 4 rows shown, scrolls to the rest, quick on/off model selector, never a full list | Fixed in code, not live | commit e795402: ~4 compact rows, rest scroll; release/v91/v917/shots/ticker3.png |
| 3 | Ticker | Tapping a row expands the full conversation inline, with an inline composer that sends to that model only (briefs/conversation-ticker.md) | Fixed in code, not live | release/v91/v917/shots/ticker3.png (tap opens conversation with inline composer) |
| 4 | Ticker | Long-pressing a row opens a context menu | Fixed in code, not live | release/v91/v917/shots/ticker3.png (long-press menu) |
| 5 | Ticker | Remove the unnecessary surface behind the grey block over the ticker, and remove the 1px scroll-nudge workaround | Fixed in code, not live | commit e795402 removed noguard/freshsc/scSig switches and VScrim clip branch; release/v91/v917/shots/slab2.png |
| 6 | Ticker | The ticker is always on screen, one row per model in the category | Fixed in code, not live | Ticker docks in the band above the composer under Gallery, Premium, Music and Browser (the pane ends above it), blurred and tap-blocked, 2 rows showing, rest scroll: release/v91/v917/shots/dock4v.png, release/v91/v917/shots/dock3v.png. Home tap / tap-outside / long-press still work, no grey slab: release/v91/v917/shots/dock_interactions_v.png. Logged in DEVIATIONS.md |
| 7 | Ticker | The ticker stays visible, blurred, dimmed and tap-blocked under every pane: Music, Premium, Premium detail, Smart Gen, Gallery, Discover, Browser, History, Account, Files, Settings, Apps, side nav | Fixed in code, not live | Visible, blurred and tap-blocked under Gallery, Premium, Premium detail, Music, Browser, Discover (release/v91/v917/shots/dock4v.png, release/v91/v917/shots/dock3v.png); History, Files, Settings, Apps, Smart Gen (release/v91/v917/shots/hist_kbd.png, release/v91/v917/shots/under4.png) |
| 8 | Ticker | Toggle models on and off directly on the rail | Fixed in code, not live | Local build Oct 14 1:50 AM: tapping Ling 3.1 Flash turned it on |
| 9 | Ticker | The rail scrolls to every model, with blur edge fades and no scrollbar | Fixed in code, not live | Local build Oct 14 1:50 AM: all 11 models reachable |
| 10 | Ticker | No scrollbar on the ticker | Fixed on live | v9.1.4 review, briefs/qa/full-review-v914.md |
| 11 | Ticker | Each line is a real one-line summary from the Consensus Agent (MiniMax first), not the reply's first line | Fixed in code, not live | MASTER-LIST-2026-10-14 item 33; no live shot with replies |
| 12 | Ticker | Off rows are full strength, not faded | Fixed on live | briefs/qa/live916g/h_home.png |
| 13 | Ticker | The composer's keyboard blur on the ticker matches the shared blur (it was sigma 1.2) | Fixed in code, not live | commit 1a45732: keyboard path uses shared _tickerBlur; release/v91/v917/shots/hist_kbd.png (right) |
| 14 | Ticker | Home ticker placement: bottom area, right of the side rail, directly above the composer and nav bar; not top, not centre | Fixed in code, not live | DEVIATIONS.md; no live side-by-side |
| 15 | Ticker | The Home ticker doesn't match the centred approved layout (app-11) | Open | Rows now sit directly over the composer (the 40 % blank gap was a layout bug, fixed): release/v91/v917/shots/dock4v.png (1st). Closes when #14 is verified live |
| 16 | Conversation | Each new prompt appends to the conversation; the thread persists and scrolls | Open | Not verifiable: models refused the local copy |
| 17 | Conversation | Every exchange saves to History on both send paths | Fixed in code, not live | Local build: History lists the prompt per model |
| 18 | Discover | Discover is a literal copy of the Grok Imagine market plus David's Figma: black, centred, with the side nav, no promo headers, no grey faded backdrop | Open | briefs/qa/live916h/c_market.png: hero + 3 templates, no side-by-side against the reference |
| 19 | Discover | Build the Discover interface in full even before generation works (layout researched first, brief written) | Open | Same as #18; brief: briefs/discover-imagine-dialect.md |
| 20 | Discover | Chips and templates fit; no labels on images; no streaked template | Fixed on live | briefs/qa/live916h/c_market.png |
| 21 | Discover | PRD Media Gen Market: browse and generate image/video/audio, remix, insert-as-source and insert-as-context, real pagination, credit-gated | Open | functional-spec.txt "Media Gen Market" |
| 22 | Panes | Every pane is centred by default (or anchored toward the thumb), never top-shifted | Open | History centred in 1a45732 (release/v91/v917/shots/hist_kbd.png left); other panes not yet re-checked |
| 23 | Navigation | Home nav bar: Settings · Home · Apps. Restore the missing Home icon | Fixed in code, not live | commit e795402 restores v9 Settings · Home · Apps; release/v91/v917/shots/hist_kbd.png |
| 24 | Navigation | Side nav overlays on every screen with sections: Gallery and Market categories, Discover feeds, Files types, Music collections, Smart Gen tools, Settings sections. Persistent, like a website's nav | Open | Only Gallery and Market have it (top bar) |
| 25 | Navigation | Side nav overlays and never shifts content; the centre item stays centred; if it can't overlay, pin it to the top of the pane or above the home nav bar (visionOS) | Fixed on live | Live c777da8e: Home ticker centre at 195, History pane centred |
| 26 | Navigation | Subcategories cascade horizontally | Open | — |
| 27 | Navigation | Category nav is always visible in Gallery and Market and never shifts the content (pinned frosted bar, visionOS browser Figma 1:101) | Fixed in code, not live | MASTER-LIST-2026-10-14 item 50; no live shot cited |
| 28 | Navigation | Gallery and Market sidebars use Title-Case categories with expandable subcategories and counts; no lowercase tags; no category carousel | Fixed in code, not live | MASTER-LIST-2026-10-14 item 34 (big-gallery, big-market shots) |
| 29 | Navigation | Nav bars slimmed to fit their buttons | Fixed on live | Live 43c6177b: bottom bar hugs its buttons |
| 30 | Navigation | Back gesture closes the top layer on every pane | Fixed in code, not live | No back gesture in the test browser |
| 31 | Navigation | Swipe down closes every temporary pane | Fixed on live | briefs/qa/live916h/p_*_swipe.png (8 panes) |
| 32 | Navigation | Tap outside closes every pane, including Market and Browser | Fixed on live | briefs/qa/live916f/b3_tapout.png, b4_tapright.png |
| 33 | Navigation | Esc/back closes the Browser | Fixed on live | briefs/qa/live916f/b2_esc.png |
| 34 | Navigation | Every pane has one obvious way out; no floating close buttons (David Oct 14 2:02 AM) | Fixed on live | briefs/qa/live916h/p_*_swipe.png; Browser escapes (live916f) |
| 35 | Navigation | Account stacks smaller over Settings, with Settings visible behind it | Fixed in code, not live | Local build: Settings visible behind Account |
| 36 | Motion | Physical materialize-in and dissolve-out on every layer; Settings and Apps don't cut hard; Apps doesn't flicker on open | Open | Needs a recording; a white flash showed while Premium closed |
| 37 | Glass | Dense, defined glass with full-strength text and clear contrast | Open | Live 43c6177b: light outline round the Premium cover |
| 38 | Glass | Rail labels are readable | Fixed in code, not live | Readable at phone size locally |
| 39 | Glass | Only Google Sans Flex is loaded | Fixed on live | briefs/qa/live916h: fallback URL byte-identical to GoogleSansFlex-400 (bfe6d8a6…) |
| 40 | Glass | Shadows come from elevation levels (base 0, panel 2, floating 6, modal 12) and cast downward; no hand-made shadows | Open | Live c777da8e: panes still show a faint even edge; list of uses: /workspace/collider-playtest/visionos-audit-1014/shadows_v91.txt |
| 41 | Composer | The composer has input, attach and send only: remove the Attach/Web/Research/Private chip row | Fixed in code, not live | commit (this batch): chip row removed; + now opens the menu with Attach file, Create image/video/audio, Internet, Research, Deep Research, Private. release/v91/v917/shots/composer_before_after.png, release/v91/v917/shots/c_plusmenu_b_crop.png. Note: reverses v9.1.4 playtest #5 ("+ only attaches") because the options had to stay reachable; logged in DEVIATIONS.md |
| 42 | Gallery | The Gallery hero card restored: title, play/scrub, thumbnail strip, Expand View, tag filter above it, with no controls on the image itself | Open | Not reached since 9.1.x; must respect #43 |
| 43 | Gallery | No overlay buttons, labels or scrubber of any kind on a theme image or video | Fixed on live | Live 43c6177b; static check in qa/media_check.py |
| 44 | Gallery | No blur, depth of field, dim or other change to the wallpaper until a wallpaper is actually set | Fixed on live | briefs/qa/live916h/c_cold.png |
| 45 | Gallery | No carousel edge blur | Fixed on live | Live 43c6177b: hard edges |
| 46 | Gallery | Previews and covers are phone-shaped (portrait), never square, in Gallery and Market | Fixed on live | Live 43c6177b: device-ratio covers |
| 47 | Gallery | Cold load shows the wallpaper and preview, never a black or empty frame | Fixed on live | briefs/qa/live916h/c_cold.png (5/5) |
| 48 | Gallery | Theme names wrap, never cut off | Fixed on live | briefs/qa/live916d/t_cold03.png |
| 49 | Gallery | Thumbnail strip fits on screen and is centred | Fixed on live | briefs/qa/live916h/c_themes.png |
| 50 | Gallery | The video in the Gallery card plays clean (no block corruption) | Open | briefs/qa/live916h/p_themes_15s.png |
| 51 | Gallery | The Gallery shows stills plus owned live themes; the Market shows only premium items | Fixed in code, not live | Code: windowless_theme_scroller.dart |
| 52 | Premium | Premium = live (video) themes, each priced inside $2.99–$7.99 by source quality (4K $7.99 · 1440p $6.99 · 1080p $4.99 · 720p $3.99 · other $2.99); stills free | Fixed on live | Live 43c6177b: buttons read $3.99 / $4.99 |
| 53 | Premium | The starter wallpaper is free, so Home never opens on a locked item | Fixed in code, not live | — |
| 54 | Premium | The cover carousel sits dead centre (195 on a 390 phone) with equal peeks | Fixed on live | Live 43c6177b |
| 55 | Premium | The price is the button ("$6.99", no "Buy ·"), and it becomes "Set as wallpaper" once owned | Fixed in code, not live | Owned state seen for the first time via the QA unlock: pill reads "Set as wallpaper" (release/v91/v917/shots/under4.png, 2nd; release/v91/v917/shots/ui_set2.png). Live users can't own a pack yet (#1) |
| 56 | Premium | No skip, next or previous control in the market or detail view; songs play by tapping their row | Fixed on live | Live 43c6177b |
| 57 | Premium | Detail view: the name shows once, one centred action pill | Fixed on live | Live 43c6177b |
| 58 | Premium | No "Wallpaper" or "Webp" filter chips; filters are subjects only | Fixed on live | Live 43c6177b chips: All, Nature, Ocean, Space, City, Rain, Cozy, Fantasy, Abstract |
| 59 | Premium | Covers, posters and reflections load; the detail cover is sharp | Fixed on live | briefs/qa/live916g/pd_premium.png, pd_detail.png |
| 60 | Premium | `?drawer=premium` shows real covers and a wallpaper | Fixed in code, not live | release/v91/v917/shots/u_premium.png: ?drawer=premium shows real R2 covers over the wallpaper (QA build) |
| 61 | Premium | The store opens on a featured, well-lit theme, not a near-black clip | Fixed in code, not live | MASTER-LIST-2026-10-14 item 60 |
| 62 | Premium | No "Too many elements" console error | Fixed on live | Live c777da8e |
| 63 | Premium | Leaving the store keeps the wallpaper | Fixed on live | v9.1.4 |
| 64 | Premium | No second composer in the Market | Fixed on live | v9.1.4 |
| 65 | Premium | No ▶ emoji in store titles | Fixed on live | v9.1.4 |
| 66 | Premium | The Market cover doesn't peek under the side-nav buttons on the left | Open | — |
| 67 | Premium | Item 59 (price button, no skip, centred cover) deployed and retested | Fixed on live | main.dart.js 87d67a96… confirmed Oct 14 |
| 68 | Catalog | Catalog selector: a central control showing "Free"; swipe up or down to "Premium"; separate from the category selector | Fixed in code, not live | No live shot cited |
| 69 | Catalog | Tags are a minimal set of searchable subjects: Nature, Ocean, Space, City, Rain, Cozy, Fantasy, Abstract, plus Live and Stills | Fixed on live | Live 43c6177b chips |
| 70 | Catalog | Store chips hide format and auto tags and fade at the edges | Fixed on live | Live 43c6177b chips |
| 71 | Media | Remove broken or streaked videos (Ocean Reflection, Beach Waves, Winter Moon and any others media_check finds), backed up first | Fixed in code, not live | commit 169a6ea hides 65 broken/streaked themes (list + reasons in tool/qa/blocked-themes.json; R2 files untouched = backup); release/v91/v917/setwall/report.json |
| 72 | Media | All theme media comes from the R2 Worker list; no bundled catalogue | Fixed in code, not live | DATA-SOURCES.md; media_check 0 failures on a local build |
| 73 | Media | qa/media_check.py fails on any 404, 0-byte or non-R2 media on every screen | Fixed in code, not live | qa/media_check.py |
| 74 | Media | Track and theme names are human, not raw IDs | Fixed on live | briefs/qa/live916g/u_screen.png |
| 75 | Media | Descriptive names for untitled themes (R2 tag title:…) | Fixed in code, not live | qa/titles.py |
| 76 | Media | "7.webp" is a screenshot of an app interface, not a wallpaper: remove it (backed up first) | Fixed in code, not live | 7.webp added to the blocklist (theme_catalog.dart, tool/qa/blocked-themes.json); R2 file untouched as backup; what it was: release/v91/v917/shots/removed_7webp.png |
| 77 | Media | Process the assets for Collider backgrounds (stabilise, loop, pick the best stills) and add them as themes | Open | bg-assets/ |
| 78 | Media | Content shows without long black waits (Discover, Premium covers and Music art took 4 s on live) | Open | briefs/qa/live916h load timings; v9.1.7 QA: both 4K wallpapers are still black at 1 s on Home and play by 4 s (release/v91/v917/shots/4k_set_1_4_15.png) |
| 79 | Home | Home uses the 3840x2160 copy of the wallpaper (highest resolution everywhere), not a 1280x720 upscale | Open | The 4K copy of the default (Reflection Lake 4K) has h264 decode errors and freezes on Home (release/v91/v917/setwall/report.json), so the 1280x720 copy stays the default. Needs a re-encoded 4K source |
| 80 | Home | The wallpaper is intact after closing panes | Fixed on live | briefs/qa/live916g/c_p_after.png |
| 81 | Home | The idle Home wallpaper is clean, not streaked | Fixed on live | briefs/qa/live916h/h_home.png |
| 82 | Music | No per-row play buttons, no cut-off titles, no duplicates | Fixed on live | briefs/qa/live916g/u_screen.png |
| 83 | Music | Music artwork shows | Fixed on live | briefs/qa/live916g/c_u_music.png |
| 84 | Files | The Player opens from Files on live, with controls below the video, matching player3.png | Fixed in code, not live | release/v91/v917/shots/f_player8_s.png: Player opens from Files and plays, controls below |
| 85 | Files | Files has visible glass and an empty state | Fixed in code, not live | release/v91/v917/shots/empty2.png: denser glass + "No files yet" empty state |
| 86 | Files | Files matches files1.png, built at the frame's size and scaled to width, readable | Open | Live 43c6177b: small dense list |
| 87 | Files | The photo grid matches files2.png | Open | — |
| 88 | Files | Upload opens a file picker on a normal tap | Fixed on live | briefs/qa/live916h/up_log.txt |
| 89 | Files | The filter bar clears the composer | Fixed on live | briefs/qa/live916h/c_files.png |
| 90 | Files | Real thumbnails for every file type, with magic-byte type sniffing | Open | — |
| 91 | Files | Players and editors: video, PDF edit, docs, spreadsheet with Solver, 3D/STL | Open | — |
| 92 | Smart Gen | Smart Gen matches smartgen.png | Open | Live 43c6177b: bare board |
| 93 | Smart Gen | The Tasks tab has an empty state | Fixed in code, not live | release/v91/v917/shots/empty2.png: single empty state with one add button |
| 94 | Smart Gen | Card text sits below the picture, never on it | Open | Code moved labels below in 9.1.6h; never seen with content |
| 95 | Smart Gen | Tabs fit, nothing clipped | Fixed on live | briefs/qa/live916h/c_smartgen.png |
| 96 | Smart Gen | Swipeable media-gen categories with full options: context tray, quantity, negative prompt, seed, edit and manage | Open | — |
| 97 | Settings | Settings is the Figma 10:2193 pane scaled to 25–33% of the screen, with dense glass | Open | briefs/qa/live916h/c_settings.png: ~80% wide |
| 98 | Settings | Settings is readable | Fixed on live | briefs/qa/live916h/c_settings.png (16 px rows) |
| 99 | Settings | Settings is a small floating pane | Fixed on live | v9.1.4 |
| 100 | Settings | Blur and dim behind Settings and Apps | Fixed on live | v9.1.4; briefs/qa/live916d/a_apps.png |
| 101 | Settings | 12-hour times | Fixed on live | v9.1.4 |
| 102 | Browser | Browser tabs match tabs.png (a grid of cards) | Open | — |
| 103 | Browser | The Browser matches browser.png | Fixed in code, not live | Local build: close to design |
| 104 | Market | Market Artifacts: templates and Collider widgets | Open | — |
| 105 | Figma | v8.4: the 7 remaining visual-map rows built as scaled Figma copies, with zoom PNGs and proxy alignment | Open | release/figma-map |
| 106 | Figma | Every screen meets the competitor floor in briefs/AUDIT-2026-10-05.md | Open | — |
| 107 | Models | GLM 5.3 Flash and Laguna answer (now "Couldn't reach this model", 402) | Open | — |
| 108 | Models | Deploy the proxy on Cloudflare (needs David's Cloudflare sign-in) and put in working keys | Open | — |
| 109 | Conventions | Every screen follows briefs/CONVENTIONS.md (every element earns its place, price is the button, compact menus, measured centring) | Open | Composer chips, full-width panes remain |
| 110 | Process | Work this list top to bottom in order; never pick a batch from the latest message | Open | Standing rule, Oct 15 |
| 111 | Process | Every batch: run the QA scripts, write GAPS.md and side-by-sides against the reference for each changed screen, update this list, commit, push to collider-latest-wip | Open | Standing rule |
| 112 | Process | Nothing is called done until Visual Playtest verifies it on live; every check re-verifies every standing rule, not only the item changed | Open | Standing rule |
| 113 | Process | Independent QA grade, publish via the Action, large per-screen before/after for David | Open | release/PUBLISH.md |
| 114 | Process | For every change, check the whole screen and every related screen against the PRD and the previous version; anything visibly bad gets a 5 whys and a decision | Open | Standing rule |
| 115 | Premium | After a swipe, the cover overlaps the theme name and the Set pill | Open | Seen Oct 15 in the QA build |
| 116 | Files | Files tile names are cut off; show the full name (wrap to two lines) | Open | Seen Oct 15 in the QA build |
| 117 | Navigation | The side rail (New / Local / Global / Roundup; Market / Gallery / Music) is too faint to read | Open | release/v91/v917/shots/dock4v.png, release/v91/v917/shots/hist_kbd.png |
| 118 | History | History has no empty state | Open | release/v91/v917/shots/hist_kbd.png (left): Search over a blank pane |
| 119 | Glass | Menu rows read faint: inactive rows are 60 % white per Figma 1:3 (+ menu, long-press menu) | Open | release/v91/v917/shots/c_plusmenu_b_crop.png, release/v91/v917/shots/dock_interactions_v.png (3rd) |
| 120 | Premium | Premium detail (expanded cover) works with the docked ticker and the shorter pane | Fixed in code, not live | release/v91/v917/shots/dock3v.png (3rd): cover, name and Set as wallpaper fit above the docked ticker |
| 121 | Discover | Under Discover the top ticker rows sit partly behind the Discover card (the card is not a tall pane, so it does not dock) | Open | release/v91/v917/shots/dock3v.png (2nd) |
