# GLM 5-Whys — recorded before the redo (2026-10-11)

Written after reading `COLLIDER_MASTER_SPEC.md`, `DEVIATIONS.md`, and
`CONVERSATION_TICKER_SPEC.txt` for the first time — documents that predate this
branch and that I never located before starting. Each chain starts from something
I shipped wrong and ends at the root. Each ends with the corrective law I now
work under.

---

## 1. Why did the ticker render full-width?

1. Why full width? — The ticker is a FigmaStage scene (Row15, 2610×1468) scaled to the device width.
2. Why scene-scaled? — I ported the wechat CHAT frame's geometry verbatim, including its full-canvas composition.
3. Why verbatim instead of bounded? — I treated the *frame* as the contract and never read Master Spec §4.2, which caps the ticker at **≤40% height** and **nav-bar width (240–260 mobile)**, content-hugging, never full-width.
4. Why didn't I read it? — I searched for specs in the repo (`docs/`) and found none; I stopped searching after the first empty result instead of looking for the prior project folder.
5. Why did I stop? — I assumed the repo was the whole project. The prior session's docs lived one directory up, in `collider_flutter__CLAUDE_live-models-consensus_20260927/docs/`.

**Law: The Master Spec's dimensional caps override any Figma frame's canvas composition. A frame gives relationships, not the app's footprint.**

## 2. Why did the Premium Theme Market appear "butchered"?

1. Why did David see the alt instead of his market? — During captures I toggled Settings → Music widget ON, and per map row 4 the alt view shows *in lieu of* the main market while the widget is on; the toggle persists in SharedPreferences.
2. Why did I present the alt as "premium market verified"? — I verified the alt against its own reference (417:1777) and did not check which surface David's map makes primary.
3. Why is that wrong? — DEVIATIONS.md D23 and the map give the alt a *supporting* role (docked music widget + alternative market); the main market (rows 1–3, the Builder.io port) is the product. David had already approved the original "save for browsing animation, rendering, performance, and music."
4. Why did I not know it was approved? — I never read DEVIATIONS.md, which records David's verdicts line by line.
5. Why never read? — Same root as #1: incomplete document discovery.

**Law: The main Premium Theme Market is the default surface. The alt exists only while the music widget is on, and is never presented as the primary. No experiment of mine may persist user-visible state (toggles, positions) after a capture session.**

## 3. Why did text overlays ("Expand View", arrows, playback bar) sit on wallpapers?

1. Why overlaid? — The gallery's preview window carried its controls from the reference frame's chrome.
2. Why kept after D1 struck them? — D1 removed "Expand View" and "more" from the *picker*; the *preview window* kept its own chrome and I never reconciled the two.
3. Why not reconciled? — I audited files by grep, not by looking at the running screens.
4. Why did grep pass? — Overlays are visual, not textual signal in code.
5. Why didn't I look? — The capture habit arrived late; early work had no visual loop.

**Law: Zero permanent text or chrome overlaid on wallpaper media. Controls live outside the frame of any preview, or appear only on explicit intent (tap), never persistently. No progress bars on previewing videos — a preview is ambient.**

## 4. Why is the gallery selector a flat pair of pills instead of a slot-machine carousel?

1. Why flat? — I implemented two static pills with an active dim.
2. Why static? — I read "Free/Premium switch" from the code, not the motion intent David asked for ("floating, embedded in air") plus the reference's vertical conveyor.
3. Why missed? — The reference frame (69:1926) is a still; the motion lived in David's words, which live in the spec files and chat history I hadn't read.
4. Why is the gallery also off-center? — The FigmaStage crop centers the frame's *content*, and my content box was computed for the old layout; nobody visually re-centered it.
5. Why no edge fades on the thumbnail conveyor? — I applied EdgeFade to *my new* surfaces but never re-audited existing surfaces against §4.2 "Faded Edge Masking".

**Law: Every conveyor/carousel gets horizontal edge fades; every vertical picker is a slot machine — focus at center, graduated fade up and down. Centering is verified visually per surface, not assumed from geometry.**

## 5. Why does each theme lack its own music pack previews?

1. Why missing? — I treated music as a player concern (Files → Music), not a per-theme packaging law.
2. Why? — I hadn't read Master Spec §8.2: **every live wallpaper ships exactly 5 curated tracks**, listed with play/pause + animated waveform, duration, mood chip.
3. Why didn't the market's song list satisfy it? — It lists whatever songs exist for a theme; several themes have none, and none present the 5-track template with previews.
4. Why did I accept "no songs" for themes? — The catalog data is thin; I optimized for what rendered instead of flagging the data gap.
5. Why optimize silently? — I hadn't internalized that the spec's "Forever Law" tag means the gap must be surfaced and planned, not smoothed over.

**Law: Every theme gets a 5-track soundscape pack; in the market, each track is clickable play/pause as preview. Missing data is a surfaced gap, never silently rendered around.**

---

## Standing corrections (from the same reading)

- Ticker: ≤40% height, nav-bar width, non-interactive surface, zero chrome,
  tailed bubbles, untruncated summaries, expanded inline (never overlay),
  bounded expansion, internal scroll, ~5 rows visible with scroll for the rest,
  page indicator dots in the left-column holder (David's new instruction
  supersedes D6's struck bar), swipe left/right to change model category,
  press-to-toggle models with animated graduated decay, remove any separate
  "Models" entry.
- Gallery: search + tags per wallpaper (search always lives on the side nav,
  §6.2 Discover/Theme rows); side nav for Theme Selector = quick switch between
  Premium Marketplace, Theme Gallery, Music Collection — extend with search/tags.
- Music widget toggle must be returned to OFF after demo sessions.
