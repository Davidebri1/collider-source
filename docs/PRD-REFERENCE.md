# Collider PRD — working reference

Source: `P:\My Drive\Collider Documentation\Collider-PRD.xlsx` (account: pharcydeancient).
Sheets: Index, Requirements (R01–R41), Surfaces, Tiers, Decisions, Out, Sources.
Read 2026-10-08. This file is my working copy; the sheet is authoritative.

**Every UI decision gets checked against this.** The acceptance column ("Done when")
is the test, not the requirement column.

---

## Scope (Index B26)

Native mobile app. Up to nine models in view, compared without leaving. Guest open.
Five categories. Discover is the market of made pieces. Premium themes are live
wallpapers, sold one at a time. **The wallpaper stays the star. Windows, not
full-screen sheets.**

Language (Index B10, R40, D7): user-facing words are **message, response, Smart Gen,
Discover**. **Not "prompt". Not "Workspaces".** Those two words must not appear in the
interface. (Note: `floating_prompt.dart`, `onSendPrompt`, `_onSendPrompt` are internal
names — acceptable. User-facing strings are not.)

---

## Surfaces — the window contract

| Surface | Opens from | What it is | Side nav | Rule |
|---|---|---|---|---|
| Ticker | Compose / Home | The conversation. Bottom window, **max 40% height, dock width** | local history, global history, new conversation, category swipe, model select | Not draggable. **No card chrome.** Consensus row pinned here only |
| Composer | Swipe up on dock | One message to selected models in active category | None | Arrow shows tucked state |
| Apps platter | Apps | **Seven icons**, centered, background dimmed | None | Click away or close. Not buttons |
| Smart Gen | Apps | Cards, boards, canvas, Genie | Cards, Boards, Canvas, Genie. Active/Urgent/All. New card | Genie is Pro+; cards/boards/canvas free |
| Discover Market | Apps | **Images only.** Imagine layout: picture row, labeled looks, two-column feed | Search. Library. Looks. Images only | Not the wallpaper store. Not a prompt shelf |
| Theme Gallery | Apps | Free background swap | Switch to Premium Marketplace, Theme Gallery, Music Collection | **Image only. Glass does not change.** |
| Premium Theme Marketplace | Apps | Live wallpapers, one at a time, **≥5 tracks** | Same theme switcher | Not unlocked by tier. $2.99–$7.99 |
| Music Player | Apps + corner control | Plays tracks that ship with a wallpaper | Music Collection on theme switcher | Corner volume after a track has played |
| Files | Apps + card | Generated files. Category nav | All, artifacts, attachments, model outputs | A card opens that model's files |
| Browser | Apps + card | One browser. Tabs. Google home | Browser settings and tabs | Same instance always |
| Settings | Dock | Functional options + account. Upgrade. Logout | Account, models, settings. **Small. Looping if needed** | No cosmetic theme system |
| Consensus map | Tap the pinned row | Agreement and dissent | None | Not an app. Not a nav tab |
| Message zoom | Tap a message | Message larger: copy, branch, save, share | None | **No frame.** Faded edges. Blur/dim behind |

**Seven apps** = Smart Gen, Discover Market, Theme Gallery, Premium Theme Marketplace,
Files, Music Player, Browser. Workspaces, History, Consensus, Models, Skills are NOT apps (D4).

---

## Requirements (condensed, with acceptance tests)

**Product / account**
- R01 Native iOS+Android. Guest account, no login wall. *Done when: first launch is the ticker, not a sign-in screen.*
- R02 Sign in with Google/Apple/email. Account, usage, logout, upgrade in Settings. *Guest reaches account actions without a dedicated login screen.*
- R03 Up to **9 models in one view**. Tap a row opens that model's thread. Conversation continues. *Nine show at once; returns to same thread.*
- R04 Categories: General, Image, Video, Music, Coding. Each keeps its own models, thread, tools. *Switching doesn't mix threads or selections.*

**Tiers**
- R05 Free: 20 messages/day counted across every model in the send. No image/video/music/coding. Two coding models shown, locked. *11th message refused.*
- R06 Pro + Elite: unlimited General. Image/video/music/coding open. Media spends credits, daily/weekly/monthly caps.
- R07 Pro **$19.99**, Elite **$49.99**. Enterprise = contact form emailing person + owner.

**Home / ticker**
- R08 Ticker **is** the conversation. Bottom window. **≤40% screen height. Width matches dock. No card chrome. Not draggable. Not full width.**
- R09 Row count is 1, 2, or 3. **Three rows shows 9.** Horizontal scroll inside the window. Never >9.
- R10 A new reply **anchors to the top of that reply**, in the ticker and in the card. *Top of new message in view, not bottom of thread.*

**Nav**
- R11 Dock: **Compose (also Home), Settings, Apps.** Swipe up opens composer, swipe down tucks it, arrow shows tucked state.
- R12 Any nav tap closes every other open pane. Menu and work surface never show together.
- R13 Apps platter: seven icons, centered, background dimmed.
- R14 Side nav follows the surface. **Search lives on the side nav.** On ticker: local history, global history, new conversation, category swipe, model select. **No Consensus tab.**

**Composer / consensus / card**
- R15 One message goes to selected models in active category. Chips show who receives it.
- R16 Consensus: **pinned row on the ticker** — a count such as **4/7**, then **one full line**. Tap opens consensus map. Not an app, not on dock/side nav. *The line is not cut off.*
- R17 Score is a **count, never a percent**. Incomplete shows an **empty** score. No partial wording. Which models count = the isolation rule.
- R18 Card: that model's thread, local files, local history, that model's browser. Message zoom: copy, branch, save, share. **Tailed bubbles. Faded edges. No window on the zoom.**
- R41 Direct reply to a subset **takes those models out of consensus**, shown as **excluded, not dropped quietly**. Score and line use only the shared query. A general send returns them.

**History / search**
- R19 New conversation archives, names, stamps the current thread **for the selected models only**. Tap loads it and opens the card. Both lists.
- R20 Search filters by type and model. Live. *A miss shows nothing, not a message.*

**Smart Gen**
- R21 Projects, tasks, reminders, memories, artifacts. Cards/boards/canvas free to view, edit, create, delete. Genie Pro+.
- R22 Creates the item when the conversation contains it, **unless it exists for same project+type+model**. Timed reminder also lands on calendar. Auto-create/auto-update toggles. *Second ask doesn't duplicate.*
- R23 Items convert between types, custom fields, embed in each other. A list shows every field as sortable/filterable column.
- R24 Board looks like the thing named: notebook, portfolio, kanban, calendar, album, storyboard. Canvas places freely. **Up to 10 canvases**, by swipe or named chip. Backgrounds swap in view.
- R25 Genie is a chat on Smart Gen. Mass-edit fields, refactor a card type. **Cannot restyle the app.** Elite attaches coding agent.
- R26 Editing is on the card. Columns/types/fields managed there. **No separate setup screen.**

**Discover / media**
- R27 **Images only for now.** Imagine layout: row of pictures → row of labeled looks → **two-column feed** of made images. Like, remix, save to library, use as context, use as source. Made image stored and returns in feed. **Not clips, not songs, not a prompt shelf, not the wallpaper store.** *No video tab. No music tab.*
- R28 Image/video/music threads keep a generation column, a queue, an action bar: view, context, source, favorite, save, share, delete. Source stays single; context can stack.

**Themes / music**
- R29 Theme Gallery swaps the background. **Glass stays glass. No color-theme system. No accent picker.**
- R30 Premium Theme Market: live wallpapers one at a time, **$2.99–$7.99**. **Not unlocked by tier.** Each includes **at least 5 tracks**. Own, then play. *A Pro account without the purchase cannot play that wallpaper.*
- R31 Corner volume **after a track has played**. Tap mutes. Long-press opens play + volume. A track can be turned off on its own.
- R32 **Theme browsing does not blur the wallpaper.** Thumbnails show the whole subject, portrait, recognizable. *Live wallpaper stays sharp while browsing. A thumbnail is not a cropped strip.*

**Files / browser / settings**
- R33 Generated files for the active model + Files surface with category nav.
- R34 Browser: Google home. Tabs. **One instance, even in background.** Side panel is browser settings.
- R35 Settings: functional options and account only. Upgrade. Logout. A locked category shows **one lock over the whole group**. *No accent picker.*

**Visual + windows**
- R36 **Wallpaper is the star and stays visible at rest. Windows, not full-screen sheets.** visionOS glass: blur or tint separates planes, **specular rim**. **Spring motion. No particles.** Type from the visionOS set.
- R37 A popup is only as large as the job. **Two ways out: click away, and a close icon.**
- R38 Leaving a surface with a draft or live reply asks first. Stay keeps surface; Switch keeps draft.
- R40 Language: message, response, Smart Gen, Discover. Not prompt. Not Workspaces.

---

## Tiers matrix

| Category | Free | Pro | Elite | Gate |
|---|---|---|---|---|
| General | 8 | 4 | 4 | Free cap 20 msg/day across models in send; Pro/Elite unlimited |
| Image | 0 | 4 | 4 | Credits; daily/weekly/monthly caps |
| Video | 0 | 4 | 4 | Credits; caps |
| Music | 0 | 4 | 4 | Credits; caps |
| Coding | 0 (two shown) | 4 | 4 | Agentic + customizable. No named agent product |
| Smart Genie | Locked | Open | Open | Cards/boards/canvas stay free; coding attach Elite |
| Premium themes | Buy | Buy | Buy | Per wallpaper $2.99–$7.99, not in tier |
| Enterprise | — | — | Contact | Form emails person + owner; no price listed |

---

## Decisions — what LOST. Do not reintroduce.

| ID | Call | Lost |
|---|---|---|
| D1 | Coding is its own category, agentic + customizable | A named agent product as a model |
| D2 | Discover is **images only**, Imagine layout | Clips, songs, prompt shelf |
| D3 | Premium Theme Market is the live-wallpaper store, separate from Discover | Unlocked in bulk by tier |
| D4 | **Seven apps** | Older drawer-as-app notes |
| D5 | Consensus = pinned row (score + one line), tap opens map. Not a drawer, not a nav tab | Full-screen drawer. **Celestial map** |
| D6 | Browser home is Google. One instance. Tabs | Another home page |
| D7 | Language: message, response, Smart Gen, Discover | A ban-and-replace sentence |
| D8 | visionOS glass. Wallpaper is the star. Windows not sheets. **Spring, not particles** | Invented physics. **Glitter icons** |
| D9 | Dock + side nav replace the old left history drawer and right tools drawer | Functional-spec drawers. Layout 2.0 center ball and card drag |
| D10 | Pro **and** Elite both open image, video, music, coding | General spec 2 split putting video/coding on Elite only |
| D11 | **Type comes from the visionOS set** | **Manrope**, from the functional note |
| D13 | Four surfaces hold five item types. Inline edit. Genie Pro+ | A separate setup screen. A hub layer |
| D14 | Direct reply to a subset leaves consensus, shown as excluded. Only shared query counts | A silent drop, or a follow-up that still moves the score |

## Out — explicitly dropped

X1 Workspaces as a label · X2 DuckDuckGo browser home · X3 Devin as an Elite model ·
X4 Celestial consensus map · X5 Prompt category in Discover · X6 Session ports and
preview identification · X7 Icon allow-list and file-path catalog · X8 Full-screen
consensus drawer · X9 *(see sheet)*

---

## Conflicts found in the code while checking this (2026-10-08)

1. **White card outline** on `GlassMenu` (`core/vision/vision_kit.dart`) — violates R08
   "no card chrome". Removed. `heightFor` back to 32 (border inset no longer applies).
   **Resolved.**
2. **Theme browsing blurs the wallpaper** — `windowless_theme_scroller.dart` applies
   `ImageFilter.blur(sigma 28)` to the room and uses `BoxFit.cover` thumbnails. R32 says
   browsing must not blur and a thumbnail is "not a cropped strip".
   **Resolved (2026-10-08).** Room layer is now a light dim only (no ImageFilter);
   thumbnails are whole-subject: poster contained and sharp over a blurred letterbox
   fill inside the chip (`_WholeSubject`).
3. **Thumbnail filter quality** — same file passes `FilterQuality.medium`, which
   downsamples. Wrong for a retina-only product. Should be `FilterQuality.high`.
   **Resolved.** `.high` everywhere, including `ThemeImage` defaults and the offline
   fallback.
4. **`ambientTracks` is empty** in the live catalog, and R30 requires ≥5 tracks per
   wallpaper. Music Player / Music Collection surfaces have nothing to show.
   **Resolved (2026-10-08).** The media host ships 5 real ambient tracks
   (`tracks/ambient-01..05.mp3`, 0:40 each). All 17 premium packs now carry 5 titled
   tracks and `ambientTracks` carries the 5-collection Music Collection list, in both
   the bundled and the live catalog (media repo `f90eb7a`). Note: the same 5 audio
   files are shared across packs for now — per-pack audio is a pure content update
   (publish files, re-point paths in themes.json), no app rebuild.
5. **Font** — D11 says the visionOS type set. `FText`/`FTextStyle` in `figma_stage.dart`
   hardcode **Inter**. `spatial_theme.dart` uses Cormorant Garamond + Instrument Sans.
   Needs a ruling.
   **Ruled (see COMPONENT-CATALOG §7):** Inter = UI; Cormorant Garamond + Instrument
   Sans = display, headings/hero only; one surface never mixes the pairings.
6. **`living_stardust_overlay.dart`** — D8/R36 say **no particles**. Needs review.
   **Resolved:** deleted. The wallpaper is the ambient; a drifting particle field is
   a screensaver, not a visionOS idiom, and it cost a full-viewport repaint per frame.
7. **Apps platter count** — Music app is hidden when the catalog has no songs
   (`apps_popup_pane.dart`, D46), so the platter shows 6, not the 7 R13/Surfaces require.
   **Resolved:** the platter is always 7; an app's place in the launcher does not
   depend on transient content, and the surface degrades to "No songs found". v8.4
   supersedes D46.