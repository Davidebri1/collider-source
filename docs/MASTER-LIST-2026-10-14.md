# Collider master list (created Oct 14, 2026, from qa/full-review-v914.md)
Every requirement carries equal weight. This list is grouped by area, not ranked. Status is as of live v9.1.4, hash 1fe7acb7…a984.

## Ticker rail
- [ ] The ticker is always on screen, with one row per model in the category (lost in v9)
- [ ] Toggle models on and off directly on the rail (lost in v9)
- [ ] The rail scrolls to every model, with blur edge fades and no scrollbar (only 3 of 9 reachable now; capped at 3 rows)
- [ ] It stays visible, blurred, dimmed and tap-blocked under every overlay (removed under Settings, Apps, Themes, Premium, Smart Gen, Market, Files, Music, Browser, History, Account and the side nav)
- [ ] The composer's keyboard blur on the ticker matches the shared blur (now sigma 1.2)
- [ ] Tapping a row opens the expanded answer; long-press opens a context menu (nothing opens now)

## Conversation and history
- [ ] Each new prompt appends to the conversation, and the thread persists and scrolls
- [ ] Every exchange saves to History on both send paths (the static-site path never saves)

## Navigation and escape
- [ ] Home nav bar: Settings · Home · Apps (removed in 9.1.3)
- [ ] Back gesture closes the top layer on every overlay (doesn't work anywhere)
- [ ] Swipe down dismisses every temporary pane (none do)
- [ ] Tap outside closes every pane (Market and Browser don't)
- [ ] Esc/back closes the Browser
- [ ] Account stacks over Settings, with Settings visible behind it

## Motion
- [ ] Physical materialize-in and dissolve-out on every layer (Settings and Apps cut hard; Apps flickers on open)

## Glass and text
- [ ] Dense, defined glass with full-strength text and clear contrast (rows are faded now)
- [ ] Rail labels are readable
- [ ] Only Google Sans Flex is loaded (Roboto not re-checked)

## Composer
- [ ] Input, attach and send only: remove the Attach/Web/Research/Private chip row

## Gallery, Premium and media
- [ ] Gallery hero card restored: title, play/scrub, thumbnail strip, Expand View, with the tag filter above it (regressed in 9.1.x)
- [ ] Premium cover reflections (posters 404 on collider-media)
- [ ] `?drawer=premium` shows real covers and a wallpaper (same 404s)
- [ ] Track and theme names are human, not raw IDs (Music shows UUIDs)
- [ ] Store chips hide format/auto tags and fade at the edges

## Screens vs Figma (build at the frame's size, then scale to width)
- [ ] Smart Gen matches smartgen.png (now an empty board)
- [ ] Files matches files1.png at readable size
- [ ] Browser tabs match tabs.png (a grid of cards)
- [ ] Settings matches settings.png
- [ ] Photo grid matches files2.png
- [ ] Player matches player3.png
- [ ] Browser matches browser.png (close already)

## Models and backend
- [ ] GLM 5.3 Flash and Laguna answer (now "Couldn't reach this model"; 402 in the console)

## Done in v9.1.4 (kept for the record)
- [x] Settings is a small floating pane with ✕
- [x] Blur and dim behind Settings and Apps
- [x] 12-hour times
- [x] Leaving the store keeps the wallpaper
- [x] No second composer in Market
- [x] No ▶ emoji in store titles
- [x] No scrollbar on the ticker

## D. Items added Oct 14 (equal weight)
33. **Done+shot** (n-summary). Each ticker line is a real one-line summary from the Consensus Agent (MiniMax first). It used to be the reply's first line.
34. **Done+shot** (big-gallery, big-market). The Gallery and Market side navs use the visionOS browser sidebar: Title-Case categories, expandable subcategories and counts (ListTile/ExpansionTile), with no lowercase tags and no category carousel. In the Market the sidebar opens from Browse as a temporary panel.
35. **Done** (media-check 0 failures). All media comes from the R2 Worker list. The bundled catalogue is removed. See DATA-SOURCES.md.
36. **Done** (qa/media_check.py). Automated check script for 404 / 0-byte / non-R2 media on every screen.
37. **Done (code).** Back swipe and swipe-down close the top layer everywhere. A raw pointer listener detects them, so the side rail can't take the gesture first. Esc and back now close the Browser.
38. **Done (code).** Tap outside closes the Market (empty room area).
39. **Done (code).** Music titles: UUIDs, stock ids, "medium" and "copy" are removed. Files with no words are named from their tags.
40. **Done.** Store chips show no file-type tags. They've been replaced by the sidebar; the format filter is "Motion → Live / Stills".
41. **Done.** Fixed a Market crash: the restored code asked for the InstrumentSans font, which isn't bundled, and that crashed the Market whenever a panel opened. It now uses Google Sans Flex.
42. **Partial.** The ticker shows through under every screen. The Market room is now 90% opaque. Full-screen Music, Smart Gen and Files still cover it.
43. **Open.** Settings and Apps animation (Apps flickers on open; both close with a hard cut).
44. **Open.** Files built as the Figma frame and scaled to width (still a small, hard-to-read pane).
45. **Open.** Account stacks smaller in front of Settings; it still replaces Settings.
46. **Open.** Smart Gen: seed it or give it a proper empty state; it doesn't match smartgen.png.
47. **Open.** Rebuild Tabs, Settings (Figma frame), the photo grid and the Player to match Figma.
48. **Open.** The Home ticker doesn't match the centred approved layout (app-11).
49. **Blocked.** Pushing the source to collider-source (connector access).
50. **Open.** Market cover peeks under the side-nav buttons on the left.

## E. Items added Oct 14, 12:39–12:48 AM (equal weight)
50. **Done (v9.1.6c, supersedes the 12:48 steer).** Category nav is always visible, like a website's, and never shifts the content. On a phone a side overlay would cover the centred preview, so (per the fallback) it's pinned as a frosted bar along the top of the pane (visionOS browser, Figma 1:101) in both Gallery and Market. The focus item stays dead centre. No hidden "Browse" button.
51. **Done.** Catalog selector: a central Free / Premium switch at the top centre; swipe it up or down (or tap) to switch catalogs.
52. **Superseded by 50** (the nav is no longer behind a button).
53. **Done.** No long vertical sub-lists: the bar is one horizontal row (All, Nature, Ocean, Space, City, Rain, Cozy, Fantasy, Abstract, Live, Stills).
54. **Done.** Tags are searchable subjects, hand-checked against what each R2 item shows: Nature, Ocean, Space, City, Rain, Cozy, Fantasy, Abstract (+ Live/Stills). R2 metadata rewritten (qa/retag.py, qa/subjects.py; old tags backed up in qa/retag-backup.json).
55. **Done.** Home ticker NOT centred: bottom area, right of the side rail, directly above the composer and nav bar (see DEVIATIONS.md).
56. **Done (code).** Premium = the live (video) themes, per PRD "Wallpapers & Music". Stills are Free. Each premium item is priced inside the $2.99–$7.99 band by source quality: 4K $7.99 · 1440p $6.99 · 1080p $4.99 · 720p $3.99 · other $2.99. The starter wallpaper (Ocean Reflection, the Home default) is included free so Home never opens on a locked item. The Gallery shows stills plus owned live themes; the Market shows only premium items.
57. **Done (code).** Expanded conversation: the inline composer is ported back verbatim from collider-source v9-final (`model_pill.dart`). Tapping a row opens the full conversation and history with a composer that sends to that model only.
58. **Process.** For every change, check the whole screen and every related screen against the PRD and the previous version. Anything visibly bad gets a 5-whys and a decision.
59. **Done (code).** Premium Market: the Skip button is removed (the song wheel already moves between songs). The price itself is the buy button ("$3.99", no "Buy ·"). The cover carousel is dead centre: a leftover 76 px side-nav offset is removed.
60. **Done.** Root cause of the black Premium cover: the store opened on the middle item. With all 117 live loops now premium, the middle one was a near-black sparkle clip (average brightness 16/255), so the cover looked empty. The store now opens on a featured, well-lit theme, and posters are captured 1 s in (many loops fade in from black).
61. **Done.** 20 untitled R2 items have hand-written titles based on what they show (R2 tag `title:…`, qa/titles.py). One of them, "7.webp", is a screenshot of an app interface, not a wallpaper. It's flagged for David.
62. **Pending.** Apply /workspace/collider/briefs/CONVENTIONS.md (Visual Playtest) once it exists. It wasn't there at 1:30 AM.

## Premium theme market: necessity and centring (Oct 14, from qa/premium-market-necessity.md)
- [ ] The cover carousel is dead centre: the cover centre at exactly 195 on a 390 wide phone (it's 68 px right now), with equal peeks on both sides
- [ ] The price is the button ("$6.99", no "Buy ·"), becoming "Set as wallpaper" once owned
- [ ] No skip, next or previous control in the market or its detail view; songs play by tapping their row; the market standard's "skip required" rule is removed
- [ ] Detail view: the name shows once, and one centred action pill replaces the Apply, Preview and Close menu plus the duplicate Set as wallpaper
- [ ] Remove the "Wallpaper" and "Webp" filter chips; filters are subjects only
- [ ] Covers, video posters and reflections load (they're blank because the media host is blocking or missing the files)
- [ ] Item 59 is deployed to the live link and retested
- [ ] Every screen follows /workspace/collider/briefs/CONVENTIONS.md (it now exists, which answers item 62)


## Status check, Oct 14 1:50 AM (team's unpublished code, built locally, phone size)
Equal weight, grouped by area. Pictures in qa/: master-status.png, false-done-*.png, still-open-chip-row.png, shadow-sbs.png.

| Area | Requirement | Status | Evidence |
|---|---|---|---|
| Ticker | Always on screen | Not fixed | Live f3e80c3a: blurred under Gallery, Discover, History, Apps, Settings, Account; near black under Smart Gen; gone under the Browser window (declared), Music and Files (undeclared) |
| Ticker | Toggle models on the rail | Fixed in code | Tapping Ling 3.1 Flash turned it on |
| Ticker | Scrolls to every model, fades, no scrollbar | Fixed in code | All 11 models reachable by scrolling |
| Ticker | Blurred and tap-blocked under every overlay | Not fixed | Live 43c6177b: no grey slab after tapping the ticker area in Premium (store closes, ticker clean); still hidden under Premium and Apps. History-restore slab not checkable: History is empty in a fresh session |
| Ticker | Keyboard blur matches shared blur | Can't verify | Needs a value check in a phone build |
| Ticker | Tap a row opens the answer; long-press menu | Not fixed | Tap after a reply opened nothing |
| Conversation | New prompts add to the thread | Can't verify | Models refuse the local copy, so no replies |
| Conversation | Every exchange saves to History | Fixed in code | History lists the prompt per model |
| Navigation | Home bar: Settings, Home, Apps | Not fixed | Only Settings and Apps |
| Navigation | Back gesture closes top layer | Can't verify | No back gesture in the test browser |
| Navigation | Swipe down closes temporary panes | Fixed | Live f3e80c3a: closes Apps, Browser (from address bar), Gallery, Discover, Smart Gen, Files, Premium + detail, Music/Player, History |
| Navigation | Tap outside closes panes | Fixed | Live f3e80c3a: Browser closes on tap below (195,780) and at right edge (385,500); Account closes on tap below |
| Navigation | Escape closes the Browser | Fixed | Live f3e80c3a: Esc with app focus closes it (Esc inside the web page declared open) |
| Navigation | Account opens on top of Settings | Fixed in code | Settings visible behind Account |
| Motion | Materialise and dissolve on every layer | Can't verify | Needs a recording; a white flash showed while Premium closed |
| Glass | Dense glass, full-strength text | Not fixed | Live 43c6177b: off ticker rows still faded; light outline round Premium cover |
| Glass | Rail labels readable | Fixed in code | Readable at phone size |
| Glass | Only Google Sans Flex loaded | Not fixed | Live 43c6177b: Google Sans Flex 400–700 loads, but Roboto is still downloaded |
| Composer | Input, attach, send only | Not fixed | Attach, Web, Research, Private chips still show |
| Gallery and media | Gallery hero card restored | Can't verify | Not reached this round |
| Gallery and media | Premium cover reflections | Fixed | Live 43c6177b in Google Chrome with video codecs: Alley Wet video plays and its reflection shows under the cover |
| Gallery and media | Premium drawer shows real covers | Can't verify | Same block |
| Gallery and media | Human track names | Fixed in code | Music shows real titles |
| Gallery and media | No file-type chips | Fixed in code | Subjects only |
| Figma | Smart Gen matches design | Not fixed | Live 43c6177b: unchanged bare board; close top left |
| Figma | Files readable at design size | Not fixed | Live 43c6177b: unchanged small dense list |
| Figma | Browser tabs grid | Can't verify | Not reached |
| Figma | Settings matches design | Can't verify | Not compared this round |
| Figma | Photo grid | Can't verify | Not reached |
| Figma | Player | Not fixed | Live f3e80c3a: audio Player controls sit in a bar below the list, nothing on artwork; a video Player could not be opened from Premium to verify "below the video" |
| Figma | Browser | Fixed in code | Close to design |
| Models | GLM 5.3 Flash and Laguna answer | Can't verify | Every model refuses the local copy |
| Premium store | Cover dead centre at 195 | Fixed | Live 43c6177b: cover centred, phone-shaped |
| Premium store | Price is the button | Fixed (price) / Can't verify (owned) | Live: button reads $3.99 / $4.99 only; "Set as wallpaper" is in the code but buying can't be done headless |
| Premium store | No skip control | Fixed | Live: no skip/next/previous; only a play button beside the song name |
| Premium store | Detail: name once, one pill | Fixed | Live: "Alley Wet" once, one centred $3.99 button |
| Premium store | No Wallpaper or Webp filters | Fixed | Live chips: All, Nature, Ocean, Space, City, Rain, Cozy, Fantasy, Abstract |
| Gallery | No blur, depth of field or dim before a wallpaper is set | Not fixed | Live 43c6177b: once loaded the wallpaper is untouched, but for about the first 4 seconds the wallpaper is hidden behind black and the preview is an empty frame |
| Gallery | No floating X button | Fixed | Live 43c6177b: no buttons, labels or scrubber on the image; name and Set wallpaper sit below |
| Gallery | No carousel edge blur | Fixed | Live 43c6177b: hard edges |
| Premium store | Covers and posters load | Not fixed | Live 43c6177b: carousel cover sharp, but the detail view cover is a heavy blur; "Too many elements" error gone on live c777da8e; detail cover still smeared |
| Premium store | Fixes published to the live link | Fixed | Live main.dart.js sha256 87d67a96… confirmed Oct 14 |
| Conventions | Every screen follows the conventions | Not fixed | Composer chips, full-width panes remain |
| Shadows | Shadows cast downward from set depth levels | Not fixed | Live c777da8e: Apps icons now cast downward; panes (Settings, Account, History, store cover) still show a faint even edge, not clearly downward |

**Marked done but not fixed:** 37 (swipe down closes nothing), 42 (ticker removed, not blurred, under most screens), 57 (tapping a row opens nothing).

**Shadows (new):** replace every hand-made shadow with elevation levels: base 0, panel 2, floating 6, modal 12. List of every use: /workspace/collider-playtest/visionos-audit-1014/shadows_v91.txt

## David, Oct 14 2:02 AM (equal weight)
- Theme Gallery: no blur, DOF, dim or any alteration of the background image/live wallpaper until a wallpaper is actually set.
- Remove the floating X button; close by swipe or tap outside.
- No carousel edge blur; nothing beyond what the reference has.
- Discover market baseline = Grok Imagine market: match look and function exactly; build the interface even before generation is ready (research layout first, brief).
- Never call anything done until verified (Visual Playtest on live). Report status honestly.


- [ ] Theme Gallery: no overlay buttons of any kind on the image or video (back, Expand View and set controls currently sit on it). Status: Not fixed. My earlier 'no floating X' pass was wrong because it missed these.
- Grading rule: every check re-verifies all standing rules, not just the item changed.
- [ ] Previews are phone-shaped, not square (Market and Gallery). Status: Not fixed.
- [ ] The side nav overlays without offsetting; slim the bottom and side bars; narrow the content rather than shifting it. Status: Not fixed.

## David, Oct 14 2:22 AM (supersedes square covers)
- Market and Gallery side nav floats over the content, never offsets it; content stays exactly centred.
- Slim both nav bars (especially the bottom bar) to fit their buttons.
- If content must clear the nav, narrow it slightly; never shift it.
- Previews and covers are phone-shaped (device portrait aspect), never square.

| Gallery | Theme previews are phone-shaped | Fixed | Live 43c6177b: Gallery and Premium covers are portrait, device ratio |
| Navigation | Side nav floats without moving content | Fixed | Live c777da8e: Home ticker centre at 195; History pane centred |
| Navigation | Nav bars slimmed to their buttons | Fixed (bottom) | Live 43c6177b: bottom bar hugs its two buttons; side nav already narrow |
| Navigation | Close at top right on every pane | Not fixed | Live c777da8e: every close button removed. Swipe down closes all panes except Browser, which now has no escape at all |
| Discover | Looks and works like Grok Imagine market | Not fixed | Live 43c6177b: still Open/Remix hero layout (declared not started) |

## Live 9.1.6d check (c777da8e, Oct 14)
| Area | Item | Status | Evidence (qa/live916d) |
|---|---|---|---|
| Gallery | Cold load shows no black or empty frame | Fixed | t_cold03.png at 0.3s shows wallpaper and preview |
| Gallery | Theme names wrap, never cut off | Fixed | "Ocean Reflection" on two lines |
| Premium store | No "Too many elements" error | Fixed | no such console error |
| Ticker | Blurred under Apps | Fixed | a_apps.png, rows faint behind icons |
| Ticker | Always on screen under overlays | Not fixed | gone under Premium, Premium detail, Gallery, Discover, Browser; Smart Gen near black |
| Browser | Can be escaped | Not fixed (new, undeclared) | swipe, tap outside, Esc all fail |
| Font | Only Google Sans Flex | Not fixed (declared) | Roboto still downloads |

| Gallery | Opens with preview loaded | Not fixed | Live f3e80c3a: 1 of 2 cold runs showed an empty black card and no wallpaper after 4 s (undeclared) |
| Music | No redundant Play buttons, names not cut | Not fixed | Live f3e80c3a: Play on every row; titles truncated (undeclared) |
## Live retest 9.1.6g (main.dart.js 8e369cdf…7ad70, verified), Oct 14 2026 ~4:30 AM ET. Evidence: qa/live916g/
| Area | Requirement | Status | Evidence |
|---|---|---|---|
| Ticker | Off-rows full strength | Fixed | h_home.png: all rows full colour and text |
| Font | Only Google Sans Flex | Fixed | the fallback/roboto woff2 URL is same-origin and byte-identical (sha256 bfe6d8a6…) to GoogleSansFlex-400.ttf; no fonts.gstatic request |
| Music | No per-row play, no cut titles, no duplicates | Fixed | u_screen.png |
| Music | Artwork shown | Not fixed (undeclared) | every row tile is black |
| Premium | Centred cover, price as button, sharp detail cover (no smear) | Fixed | pd_premium.png, pd_detail.png (posters arrive at ~8 s; black at 4 s) |
| Premium | Elevation shadows | Not verified | dark covers on a black stage; the shadow direction can't be read |
| Gallery | Cold load | Fixed (5/5) | thumbs black at 1 s, filled by 4 s in t1–t5 |
| Gallery | Thumbnail strip centred | Not fixed (undeclared) | runs off the right edge |
| Ticker | Under every pane | Not fixed | visible under Apps, Files, Settings, Gallery; hidden under Smart Gen, Music, Browser (declared), Premium |
| Discover | Matches Grok Imagine market | Not fixed (undeclared, GAPS says done) | m_screen.png: almost empty black pane, chips and template row clipped, "Hyper Transit" label on the card |
| Smart Gen | Matches Figma | Not fixed | empty glass body, tab row clipped, ticker hidden |
| Settings | Readable, at design size | Not fixed (undeclared) | tiny scaled window, about 6 px text |
| Files | Shows files; + has a clear purpose | Partly fixed | labelled Upload, no music in the list (empty "Recently Added"); the Upload tap opens no file picker in Chrome |
| Player | Controls below the video | Not verified | can't upload, so no video tile |
| Home | Wallpaper intact after closing panes | Not fixed (undeclared) | black after Premium closes; lower half streaked after other panes (may be headless video decode) |

### 9.1.6g caveat check (run alone, 15 s waits, no 4xx or failed requests), Oct 14 ~4:25 AM ET
| Item | Verdict | Evidence |
|---|---|---|
| Music artwork black | Slow load, not a defect: art shows at 15 s | qa/live916g/c_u_music.png |
| Discover empty | Content is a slow load; the clipped filters and template row and the label on the card are real defects | c_m_discover.png |
| Black Home after Premium | Not reproduced; wallpaper back after closing | c_p_after.png |
| Wallpaper streaking | Present on idle Home before any pane opens, so it comes from the live wallpaper video (declared source smear, or headless decode). Not caused by panes. | c_p_home0.png |
| Upload | Plain click opens no file picker; CDP interception works and test.mp4 appears as a tile | c_v2_tile.png |
| Video Player | Not fixed (undeclared): tapping the video tile closes Files and no Player opens (2/2) | c_v2_player.png |
| Music artwork shown | Fixed (supersedes the earlier row) | c_u_music.png |

## Live retest 9.1.6h (main.dart.js a4171fc0…0b90, verified), Oct 14 2026 ~5 AM ET. Evidence: qa/live916h/
Chrome on the box, 390x844 DPR 3, one session at a time, 80 ms presses, 1 s / 4 s / 15 s shots per pane.
| Area | Requirement | Status | Evidence |
|---|---|---|---|
| Discover | Chips and templates fit, no label on images, no streaked template | Fixed | c_market.png (15 s) |
| Discover | Matches Grok Imagine market | Not verified | layout now hero + 3 templates; no side-by-side against the reference in this run |
| Settings | Readable | Fixed | c_settings.png, 16 px rows |
| Settings | 25–33% pane built at Figma size and scaled | Not fixed (declared as a choice in GAPS) | pane is ~80% of screen width at native size |
| Upload | Opens a file picker on a normal tap | Fixed | up_log.txt: chooser opened from an 80 ms press, test.mp4 tile shown |
| Player | Tapping a video opens the Player, controls below | Not fixed (undeclared; GAPS claims fixed) | up2_player.png, up3_player15.png: tap closes Files, no Player, 2/2 incl. 15 s wait |
| Gallery | Thumbnail strip fits | Fixed | c_themes.png |
| Gallery | Cold load | Fixed (5/5) | c_cold.png, wallpaper and card at 1 s every run |
| Gallery | Video in card plays clean | Not verified | p_themes_15s.png shows block corruption on the water at 15 s; source file decodes clean, may be headless decoder |
| Smart Gen | Tabs fit; empty states | Fixed (tabs) / Partly (Tasks tab shows a blank body with no "Nothing yet") | c_smartgen.png, c_sg.png |
| Smart Gen | Cards | Not verified | no content exists to render a card |
| Files | Filter bar clears composer | Fixed | c_files.png (bar y≈566, composer y≈729) |
| Files | Pane has visible glass and an empty state | Not fixed (undeclared) | empty pane is see-through with no message |
| Home | Wallpaper streaks | Fixed | h_home.png clean; source 0_Reflection_Lake_1280x720.mp4 decodes with no errors, frames clean (src/frames.png) |
| Home | Wallpaper sharp at device resolution | Not fixed (undeclared) | 1280x720 landscape cropped to portrait = ~3x upscale, visibly soft; a 3840x2160 version exists in R2 |
| Ticker | Under every pane | Not fixed | visible blurred under Apps, Discover, Files, Settings; faint under Smart Gen, Music, Premium (declared); gone under Gallery (undeclared) and Browser (declared) |
| Escape | Swipe down closes every pane | Fixed | *_swipe.png for all 8 panes |
| Font | Only Google Sans Flex | Fixed | fallback URL byte-identical to GoogleSansFlex-400 (bfe6d8a6…) |
| Load | Seconds until content | Info | Discover 4 s (blurred placeholder at 1 s), Premium covers 4 s (black at 1 s), Music art 4 s, Browser 4 s, Gallery 1 s, Settings/Files/Smart Gen instant |
