# Progress & Decisions Log

Running record of what's been built, key infra/credentials, and open items. Update this as work continues instead of relying on chat history — check here first before re-deriving anything.

## Infrastructure

### Supabase (Imagine Market backend)
- Project: `collider-native`, org "David", project ref `gmenftvasdbhkbinkdux`
- URL: `https://gmenftvasdbhkbinkdux.supabase.co`
- Client config: `src/services/supabase.ts` (publishable/anon key only — safe client-side by design). **Never put the secret key in the app.**
- Schema: `supabase/migrations/20260712000000_market_schema.sql` — `market_items`, `market_likes`, `market_comments`, RLS enabled with permissive policies (anonymous public app, no real auth), trigger keeps `market_items.likes` in sync. **Already run** against the live project (verified: 18 seed rows present, RLS confirmed enabled on all 3 tables).
- App wiring: `src/services/market.ts` (fetch/publish/like/comment functions, per-device pseudo-identity via AsyncStorage UUID), `src/screens/MarketScreen.tsx` (rewritten to use live queries, falls back to local `DEFAULT_MARKET_ITEMS` with a toast if the network call fails).
- Known gaps: no real user auth (device-UUID based identity only), `#tag` filters and "my-assets" tab still client-side, no delete policies for items/comments (no delete UI flow exists yet).

### Google Cloud (Calendar/Tasks integration)
- Project: "Collider AI", project ID `collider-ai-498201`
- Calendar API and Tasks API: **enabled**
- OAuth consent screen: publishing status **"Testing"** — only listed test users can sign in. Test user added: `ebridavid@gmail.com`. To let other accounts sign in, add them at Google Cloud Console → Google Auth Platform → Audience → Test users, or publish the app (requires Google review for sensitive scopes).
- OAuth clients created:
  - **Web application** "Collider Native Web" — Client ID: `936092858710-36a9kiqprhvmg7534pq9c32dkpu4tahh.apps.googleusercontent.com`. Authorized redirect URIs: `http://localhost:8081`, `http://localhost:19006`. **This is the one actually in use** since the only current test path is `expo start --web`.
  - **iOS** "Collider Native iOS" — Client ID: `936092858710-bti8eattr6c405jjq8ce5000gsb1kt2d.apps.googleusercontent.com`, bundle ID `app.collider.native` (matches `app.json`). Ready for when a real dev-client/simulator build exists; not usable from the web test path.
  - **Android**: not created yet. Needs a SHA-1 signing-certificate fingerprint, which only exists once a keystore is generated (happens automatically on the first `eas build -p android` or `expo run:android`). Create this the moment that happens — quick addition once the fingerprint exists.
- Config: `src/services/googleAuthConfig.ts` (picks client ID by `Platform.OS`), `src/services/googleAuth.ts` (PKCE auth flow, token storage/refresh in AsyncStorage key `collider-google-tokens`, separate from app state), `src/services/googleCalendar.ts` (Calendar v3 + Tasks v1 REST wrappers). Wired into `src/screens/RemindersScreen.tsx` (connect/disconnect UI, per-reminder sync-to-Calendar and push-to-Tasks buttons).
- **Fragile point**: `GOOGLE_REDIRECT_URI` is hardcoded to `http://localhost:8081`. If the dev server runs on a different port, sign-in fails with `redirect_uri_mismatch` — either force the server onto 8081 (already set in `.claude/launch.json`) or add the actual port as another redirect URI in Google Cloud Console.

### Local dev server
- `.claude/launch.json` defines `collider-web`: `npx expo start --web --port 8081` (port pinned to match the Google OAuth redirect URI above).
- `metro.config.js` (new) — required for Supabase's ESM dependency chain to resolve at all; adds `mjs` to `resolver.sourceExts` and disables `unstable_enablePackageExports`. **Do not delete this file** — the app fails to bundle without it.

## Feature status (see docs/AUDIT.md for the original gaps each of these closes)

| Area | Status |
|---|---|
| Web/native `<select>` crash | Fixed |
| Metro/Supabase bundler crash | Fixed |
| Monetization logic (free=20/day general-only, daily pro/elite credits) | Fixed |
| Model routing honesty | Fixed |
| Grid: dropdown category selector, density selector, slim cards | Fixed |
| Grid: full scrollable per-model history w/ windowed loading | Fixed |
| Grid: chat bubbles in card previews (was bare text w/ gaps) | Fixed |
| Streaming responses (SSE, web; graceful fallback native) | Fixed |
| Global search (grid toolbar → cross-type search+filters) | Built, **unconfirmed live** — automation couldn't reliably click it this session, needs a manual tap-test |
| Toast system replacing `alert()` | Fixed |
| Android `elevation` on shadow styles | Fixed |
| Consensus: real LLM verdict + per-model scoring | Fixed |
| Consensus: all dissenters shown | Fixed |
| Consensus: force-directed galaxy layout | Fixed |
| Consensus: one-page (no scroll) layout | Fixed |
| Consensus: CardScreen COLLIDE button had no modal wired | Fixed |
| Consensus: wipe-on-close respects the setting | Fixed |
| Smart Gen: Artifacts type + screen + CRUD | Fixed |
| Smart Gen: cross-linking (`links` bag) | Fixed, partial — "Convert to..." doesn't auto-link source↔result yet |
| Smart Gen: LLM extraction pass (background, additive) | Fixed |
| Smart Gen: right-drawer relocation (global/scoped) | Fixed |
| Google Calendar/Tasks integration | Fixed (web OAuth client only; iOS client ready but untested; Android pending a build) |
| Imagine Market real backend (Supabase) | Fixed, **unconfirmed live** — same automation-targeting issue, needs a manual check |
| Composer "Default" chip overflow artifact | Fixed |

## Session 2 additions
- RightDrawer/Smart Gen panel: replaced the horizontal-scroll section ribbon (had a scrollbar, looked cramped) with two dropdowns (type + model filter), both global and per-model-scoped (scoped view defaults the model filter, doesn't lock it).
- Restored tap-to-open full edit modals for Projects/Reminders/Memories in this panel (regression from the earlier Smart Gen agent pass — the modals still existed in code, just weren't wired in here). Artifacts got a real edit modal too (was read-only before): title/content/kind all editable.
- Added a shared `LinkedItemsBlock` (App.tsx) used by all four edit modals: shows attached items, lets you attach more via a picker, and now lets you **detach** them too (new `unlinkItems` reducer action in state.tsx, mirrors `linkItems`).
- Removed "AI Model Context" and "Link to Project" pickers from the Reminder/Memory/Project edit modals — these added user-facing decisions nobody should have to make (which model "owns" a memory, etc). Values are kept (defaulted from creation), just not exposed as UI. `FileEditModal`'s own model-context picker was left alone (different context, not part of this ask).
- `Priority` simplified app-wide to binary (**none/high** only) — no more low/med tiers. Changed in `state.tsx` (added `collapsePriority()` helper, old low/med kept in the type only so stale persisted data doesn't crash), `smartgen.ts` and `llmExtract.ts`'s local Priority types/prompts (both previously had their own separate `Priority` type not import from state.tsx — worth remembering if this comes up again).
- `Picker.tsx` no longer uses a raw HTML `<select>` on web — its open-list styling is OS-chrome and can't be restyled, which read as flat/cheap against the app's dark-glass aesthetic. Now a BlurView + gradient bottom-sheet on every platform (drag handle, glow on selected item) — this is the fix for the "flat cartoony elements" complaint, at least for every dropdown built with this shared component.

## Session 2, part 2 — visual/aesthetic pass
- Header: was a solid opaque `#060608` bar (contradicted the "background must show everywhere" spec) with the category dropdown crammed into the wordmark row, ~2 rows tall. Now a translucent BlurView+gradient (wallpaper visible through it), category dropdown moved down into its own row with the other grid-scoped tools (MODELS/search/OUTPUTS/density/new), overall shorter.
- CardGrid: root cause of "cards aren't portrait" finally fixed — `columns` and `rows` were literally the same variable `n`, dividing both width and height by the density selector. Columns are now fixed (2, or 1 if only one model selected); `rows` only controls height. Cards are now genuinely taller than wide.
- Gold (`#ffd166`, both hex and its rgba decimal form `255,209,102`) removed from every non-model UI surface app-wide (~89 occurrences, 18 files, via `sed`) — kept only in `src/models.ts` (model branding) and `ModelCard.tsx`'s locked-badge (model-card-specific), per explicit exception. Replaced with the app's existing violet `#a78bfa`. Also caught a separate stray orange (`#ff9f1c`) on the floating Collide FAB in App.tsx that the gold sed didn't touch (different hex) — same fix.
- Shadows restored on interactive surfaces that had none: composer `toolBtn`/`send`/`addBtn`/`primaryBtn` (theme.ts), grid toolbar pills (new `localToolbarStyles` in App.tsx). Per direction: black/neutral shadows, not colored glows (model cards were already correct — they use plain black shadows).
- `Picker.tsx` dropdown restyle (BlurView glass sheet) from the previous session already addressed part of the "flat cartoony" complaint; this pass fixed the remaining flat/uncolored buttons and the gold-everywhere issue specifically.
- Note for future "AAA polish" asks: the original `docs/AUDIT.md` flagged the CardGrid rows/columns bug and missing Android elevation, but did **not** do a granular color/shadow/typography audit — most of this session's fixes were regressions or omissions introduced by the grid-UI rewrite earlier in this engagement, not pre-existing issues missed by that audit.
- Not done: custom font (Inter or similar) — flagged by user as "there are better fonts too" but not yet implemented pending confirmation it's worth the added dependency (expo-font + google fonts package). Ask before doing this one, or say "just do it" and it'll be Inter by default.

## Session 2, part 3 — CardGrid aspect ratio, corrected
The part-2 fix (fixed 2 columns, height = gridHeight/rows) was only half right: at density 3, dividing the viewport height three ways made cards *shorter than wide* — landscape again, just differently broken. Real fix in `src/components/CardGrid.tsx`: height is now derived from width via a fixed portrait ratio (`PORTRAIT_RATIO = 1.5`), never from available vertical space. `rows` (the density selector) now sets **column count** instead — more density = more, smaller, still-always-portrait columns. Overflow scrolls instead of squeezing card height. This guarantees portrait cards at every density setting, verified visually at density 3 (previously the broken case).

## Session 2, part 4 — no-scroll grid supersedes strict portrait
User clarified the actual priority: **all selected cards must be visible at once, zero vertical scroll in general navigation** — this conflicts with a fixed portrait ratio once enough models are selected (fixed ratio always eventually overflows). Reworked `CardGrid.tsx` again: `rows` is now the target row count; columns are derived as `ceil(N / effectiveRows)` so all N selected cards fit in exactly that many rows; both width and height are computed to exactly fill the available space (never independently), guaranteeing no scroll by construction. The outer `ScrollView` was removed entirely (replaced with a plain `View`) since content can never exceed the container. Cards still read portrait whenever the row/column split allows it, but fitting everything without scroll now wins over strict portraiture when there are many models selected against a low row count — that's an intentional, known tradeoff. Verified visually with all 6 free general models selected (previously the overflow case) — fits exactly, flush against the composer, no cut-off row.

## Session 2, part 5 — CardGrid final model: fixed N×N page, horizontal overflow
User gave the precise spec, superseding parts 3 and 4: cards are standard objects with a **fixed aspect ratio that never morphs** — they only scale uniformly (shrink/upsize) to fit the viewport, never stretch off-ratio to fill leftover space. `rows` (N) now defines a fixed N×N "page" (3 rows → 3x3 = 9 equal-size cards). Card size = computed once from whichever dimension (available width ÷ N, or available height ÷ N) is more constraining, applying the fixed `CARD_RATIO = 1.5`. Anything beyond the first N² selected models doesn't shrink cards further or cause vertical scroll — it becomes additional columns, revealed by **horizontal** scroll (filled column-major: cards fill top-to-bottom within a column before starting the next one). Rewrote `CardGrid.tsx` around this model (horizontal `ScrollView` of column `View`s, replacing the flex-wrap grid). Verified visually with 6 models selected at rows=3: renders as 2 full columns of 3, empty background correctly visible in the unused 3rd-column space rather than cards stretching into it.

This is the 3rd iteration of CardGrid's sizing logic this session (parts 2/3 tried scroll-then-portrait-ratio, part 4 tried no-scroll-but-flexible-ratio) — if this comes up again, part 5's model (fixed ratio + horizontal overflow) is the one to build on, not the earlier ones.

## Session 2, part 6 — header rework + CardGrid empty-space bug + card labels
- Header reverted to solid black (`#060608`, "cinematic" — user liked the original solid bar, the only problem was crowding). Now strictly: row 1 = wordmark alone, row 2 = menu (moved down, bigger — 38px, with shadow) + category dropdown + models/search/outputs/density/new. Hard `borderBottomWidth` replaced with a `LinearGradient` fade into the grid.
- `CategoryDropdownTrigger` no longer has a colored glow border/shadow tied to the category color ("blue highlight under general") — neutral chrome now, category color only shows on the icon/label text.
- Credits/tier pill removed from the header entirely. Moved to Settings → Account → Subscription row, and made **accurate per-tier** instead of a raw credits number: free tier shows `{daily}/{FREE_DAILY_LIMIT} general messages today`; paid tiers show `unlimited general chat · {credits} daily credits for media/coding`.
- **Real CardGrid bug found via testing at true mobile width**: with fewer than N² cards selected (e.g. 6 cards at rows=3 → only 2 columns needed), width was still divided by N=3, reserving a phantom empty 3rd column — this was the "so much empty space" complaint. Fixed: width now divides by `min(actual columns present, N)`, so cards grow to fill the space that's really there instead of leaving a void for columns that don't exist.
- `ModelCard.tsx` header: name truncation ("LLAM…") fixed — `numberOfLines` 1→2, header row `alignItems: flex-start` so the X-dismiss button doesn't center-align against a wrapped 2-line title.
- Added `marginBottom: 10` to the grid container (App.tsx) so the last row of cards no longer touches the composer.
- Testing note that mattered here: `resize_window` + `read_page`'s reported "Viewport" size were inconsistent with each other in this session (resize claimed 375×812, read_page kept reporting 420×909) — when diagnosing layout bugs, trust `read_page`'s reported viewport over the resize confirmation, and always do a full `navigate` reload after resizing since `SCREEN_W` is captured once via `Dimensions.get("window")` at load and won't update from a resize alone.

## Session 2, part 7 — model description tray on cards
`ModelCard.tsx`: description was previously fully hidden until you tapped the header (no visible hint it existed). Now always renders as a one-line row directly below the header (with a chevron), independently tappable — expands into a small tray showing the full text (`numberOfLines` undefined when expanded), `LayoutAnimation` for a smooth expand/collapse. Header itself no longer toggles it (separate tap targets now: header for nothing/display, X to dismiss, desc row to expand).

## Session 2, part 8 — real collision bug + header/toolbar restructure
- **Real bug, not a testing artifact**: `CardGrid.tsx`'s height math used the full measured `gridHeight` without subtracting its own `ScrollView` `paddingVertical: 6` (×2 = 12px). Cards were sized to fill the whole container, then 12px of padding got added on top, overflowing by exactly that much and clipping the last row against the composer (no vertical scroll exists to reach it). Fixed: `maxHeightFromH` now subtracts `V_PAD * 2` before dividing.
- Header restructured per explicit direction ("black bar was fine for the title, not for these other things"): the solid black bar now holds **only** the COLLIDER wordmark. Menu + search/outputs/density/new moved into their own **transparent** row below it (wallpaper visible through, matching the rest of the app). Category + Models moved further down still, into a small paired row directly above the grid — no longer a "giant" pill.
- `CategoryDropdownTrigger` shrunk (34→28px height) and de-flattened: text is now white with a soft colored `textShadow` glow instead of a flat solid-color fill ("no flat colors — every color should be light, diffused, emitting"). Same treatment applied to the new Models chip beside it (`localToolbarStyles.glowChip`).
- Not done: a full app-wide "no flat colors" pass, and the "review all fonts" ask — both are broad, still-open asks; this pass only touched the category/models chips since those were the specific pieces named. Flag specific remaining flat-color spots if/when noticed rather than expecting a full sweep already happened.

## Session 2, part 9 — CardGrid: drop the fixed ratio (real bug, not a preference)
User: "we gained a lot of real estate and aren't realizing it... spent on bigger cards always, never dead space." Root cause: `cardWidth = min(widthBound, heightBound/CARD_RATIO)` — on a phone, width is essentially always the tighter constraint, so cards were **permanently width-bound**. Every time the header got shorter (several fixes this session), `gridHeight` grew, but the fixed ratio capped card height at `width * 1.5` regardless — all that freed vertical space went completely unused. Fixed: removed `CARD_RATIO` entirely. Cards now fill both dimensions of their N×N grid cell fully (still uniform size across all cards, still capped at N columns visible with horizontal overflow beyond that — that structural model from part 5 is unchanged, only the ratio-lock is gone). Verified: cards are visibly much larger now, descriptions show more text, most model names fit on one line again.

This supersedes the "fixed aspect ratio, cards never widen" instruction from earlier in the session — the user's later, more emphatic direction ("never dead space") is the one to build on if this file gets touched again.

`CardScreen`'s header also brought in line with the grid header's language (solid black `#060608`, gradient fade instead of a hard `borderBottomWidth` line) per "make sure it carries to card view."

## Session 3 — Smart Gen kanban board + MiniMax M3 as the single judge

### Repo sync finding (answers "is the repo up to date?")
Code is fully in sync with origin/main. **Binary assets are not**: 9 files referenced by `src/styles/theme.ts` are absent from the repo (`assets/themes/premium/*.jpg` ×4, `assets/themes/premium/tracks/*.mp3` ×5) — a fresh clone cannot bundle at all until they're added. They exist only on the machine that authored the wallpaper/music feature. **Action needed: upload `assets/themes/premium/` to the repo.** (This session used locally-generated placeholders, deliberately not committed, to be able to run the app.)

### MiniMax M3 — Smart Gen's model (src/services/minimax.ts)
- `minimaxai/minimax-m3` via NVIDIA NIM (`https://integrate.api.nvidia.com/v1/chat/completions`), slug verified live against the key's /v1/models. Key ships in-app (same stance as chat.ts), `EXPO_PUBLIC_NVIDIA_API_KEY` overrides.
- **NVIDIA NIM sends no CORS headers** — browser fetch dies before leaving (verified live). On web the same model falls back to OpenRouter (`minimax/minimax-m3`, slug verified in their catalog) using the app's existing key. Native is unaffected. One judge, two wires.
- Free NVIDIA key rate-limits hard on bursts; `callMiniMax` retries twice paced, then falls to OpenRouter.
- Routed through MiniMax now: LLM extraction (`llmExtract.ts`, Groq llama fallback), consensus arbiter (`chat.ts scoreConsensus`, Sonnet-via-OpenRouter fallback, local heuristic last), and the new board chat.

### Kanban card system (state.tsx + src/screens/SmartGenBoardScreen.tsx)
- All four Smart Gen kinds are now cards on one board. New state: `embeds` (directional card-in-card, any kind into any kind, both directions, self/2-cycle refused), `customFields` on all four types, `Reminder.recurring` (optional by design), `cardTypeFields` (global default attributes per type, user- and model-editable), `smartBoard` config (view/groupBy/sortBy/filter — persisted).
- `convertCard` reducer: full-fidelity type conversion — links, embeds, custom fields, tags, priority, due all carry; content without a native slot in the target lands in `customFields.Notes`; every reference to the old identity (links bags, embeds, projectId pointers) is rewritten. Conversion changes a card's form, never its place in the web around it.
- Board screen: Board (kanban columns, horizontal overflow) / List / Calendar (Overdue/Today/Tomorrow/This week/Later sections) views; group by status/type/priority/project/tag; sort by due/created/priority/title; filter reaches embedded cards; live countdown chips (per-second ticking when anything is due within the hour); card detail modal (attributes, embed picker, convert, quick due/recurring/priority); global per-type attribute manager.
- Embedded cards render nested inside their host and don't double-show at top level (search still finds them).
- Ask tab: MiniMax chat with the full board serialized as context. The model answers from the board AND changes it in the same reply via a fenced `collider-actions` JSON block (create/update/convert/embed/board actions — executed by `executeBoardActions`, shown as an "N changes applied" chip). System prompt bans dangled offers outright. Globe toggle pipes Exa/Tavily search in.
- Nav: `smartboard` screen, "Board" row leads the RightDrawer Smart Gen list. `Page` got a `noScroll` prop (board manages its own scroll surfaces).

### Logic-chain validation (scripts/validate-logic-chain.mjs, docs/VALIDATION_MINIMAX.md)
5-whys convergence harness per the validation spec — record chains, never grade responses. 100-replication live run against the real endpoint was **in progress** at commit time (~3 min/replication; the free key only sustains ~1 request/4s). Preliminary 20-rep readout is in the validation doc; final summary JSON lands in `scripts/out/` and the doc gets updated when the run completes.

### Verified live this session (expo web + Playwright, zero console errors)
App boots; drawer→Board navigates; kanban/calendar render with correct grouping and ticking countdowns; card modal shows type-default + custom attributes; embed picker excludes self/cycles and embedding works; project→reminder conversion works; Ask chat sends, streams, and correctly walks the NVIDIA→OpenRouter fallback (couldn't complete a reply in this container only because no OpenRouter key exists here).

### Open items from this session
1. Upload `assets/themes/premium/` binaries (blocker for fresh clones).
2. Board chat history is session-local (component state) — persist to AppState if continuity across visits matters.
3. `recurring` renders and round-trips but nothing re-schedules a completed recurring reminder yet — needs a "done → advance due by interval" reducer behavior.
4. Imagine-market procedural-generation drop-in from Google AI Studio: not started, user may supply their build.

## Known open items (as of last session)
1. **Manually verify**: tap the search icon (grid toolbar, between MODELS and OUTPUTS) — does it open the search overlay?
2. **Manually verify**: tap "Imagine Market" in the left drawer — does it open correctly?
3. "Convert to..." in Memory/Reminders screens doesn't back-link the converted item to its source.
4. Android OAuth client for Google — create once a real Android build produces a keystore/SHA-1.
5. Market: `#tag` filters, "my-assets" tab, and delete flows are still local-only / not backed by Supabase.

## Notes on testing this app
- User has no physical device or paid Apple developer account — `expo start --web` via the `.claude/launch.json` `collider-web` config is the only viable test path right now.
- When testing via the Claude Browser pane: screenshot pixel coordinates and real click-coordinate space have been observed to mismatch in some sessions — prefer `read_page` → click by `ref` over raw `coordinate` clicks when automating.

## Session 4 — integrity pass + merge with the FAL build (2026-07-27/28)

Everything here was found by running the app and using it. Typecheck is clean
and the app boots with zero console errors after each entry.

### Crashes and wiring
- `AssetActionBar` and Market's `CollectionsPane` destructured `toast` from `useCollider()`, which does not provide it. Favouriting, sharing and saving to a collection all threw `toast is not a function`. Both use `useToast()` now, like the other eight call sites.
- The composer's attachment map and `CATEGORY_META` were keyed `music`; the category is `audio`. Audio-tab attachments resolved to `undefined` and the tab had no icon.
- Creating a project ignored the return key — no `onSubmitEditing`, so the gesture under your thumb on a phone silently dropped the name. `+` on an empty box made a project called "New Project". The empty state said "No projects found" when a *search* had filtered them out.

### Honesty of the Market
Four places presented invented material as authored work: `picsum.photos` stock images seeded on item id; `handleDownload` never reading `item.url` for images (so every image download wrote a stranger's photograph as `market-<id>.png`, with `.png` on video and audio too, and an unconditional success toast); generated video/audio items assigned one of four mixkit clips or ten SoundHelix tracks by id hash under invented authors; and `playAudio` falling back to a fixed SoundHelix song. All removed; both stock pools deleted.

### Interface
- Wallpaper picking is a **panel** (`src/components/WallpaperPanel.tsx`) that opens over the current screen and applies on tap, so the change lands behind it while you watch. Thumbnails are 54px at 1284:2778, the real asset ratio.
- Live tiles had no `posterSource` and only play once owned *and* applied — every paid wallpaper was a black rectangle with a price on it. The posters shipped beside each `.mp4` and were already in `PREMIUM_META`, never passed to the component.
- `addBtn` was the last solid white circle (`borderRadius: 18`, `#ffffff`, glyphs hardcoded `#000`). `ed077b7` moved every other control to rounded-square glass — "instead of solid black circles" — and missed it. Same white-fill/black-text on the buy button. Both dark glass now.
- `GLASS_CARD`'s final stop was `rgba(10,12,18,0.35)`, a 35% wash over the wallpaper from every card. 0.14 was too far (settings rows stopped being readable); it is 0.22.

### Music widget → player
Could not be moved (hardcoded top-right, measured sitting on the Smart Gen button), could not be dismissed (pausing leaves `trackId` set), hid expansion behind a long-press on mute, never named the track, could not skip. Now drags with edge-snapping, refuses gesture termination so a parent ScrollView cannot steal it mid-drag, collapses, closes (stops and unloads), skips, and names the track — position and collapsed state persisted. Adds `stopPlayer`, `setPlayerWidget`.

### Live wallpaper pricing — resolved
Four wallpapers showed $2.99/$4.99/$5.99/$7.99 while all four billed the same non-consumable `collider.wallpaper.pack`. At most one label could be true, and a non-consumable cannot be sold twice — so the first purchase made the other three permanently unbuyable while still showing prices. **One product, one price: $2.99, unlocking all live wallpapers.** `purchaseWallpaper` takes `unlockAll`.

### Merged with the FAL build
The owner's `Collider-X-main-build` zip was **ahead** of this branch in five files never seen here — `src/services/fal.ts` (FAL.ai image + video), `src/services/sync.ts` (cross-device sync), `src/services/auth.ts` (Google/Apple/email), `src/components/SortableTable.tsx`, plus `RADIUS`/`EASING` tokens — and **behind** it by exactly one commit. Merged: their newer tree, with the pricing fix and this log re-applied on top.

**FAL is Market media generation, and it was one step short of working.** `generateMarketAssetUrl` existed, exported, keyed, with a docstring reading "called by the market screen when it wants to upgrade a seed item from a Pollinations placeholder to a real FAL-generated asset" — and **zero callers anywhere in the app**. Generated video items are created with `url: undefined`; nothing ever resolved them, so they were permanently blank tiles. MarketScreen now has that caller: an effect that fills URL-less items two at a time, swallowing failures so an exhausted balance leaves a tile without art rather than an error.

### Verified by measurement, not assumption
| Thing | Result |
|---|---|
| Theme images | 18 on disk, 18 loading, **zero deletions in git history**; all added in `ea9cab5` (David, 07-16). 16 are 1284×2778, two are 1024×1024. |
| Asset/UI resolution | HD. Inter + Ionicons are vector; at `deviceScaleFactor: 3` the render is 1179×2556 and sharp. Earlier screenshots looked crude because they were taken at dsf **1**. |
| The white circle | `git log -L 476,476:src/styles/theme.ts` → one commit, `ea9cab5`, 07-16, never modified since. Not re-added by any later session. |
| **FAL.ai** | key live, **balance exhausted** — `"User is locked. Reason: Exhausted balance."` |
| OpenRouter | $0.13 of $10; paid models **402**. 33 of 34 models route through it. |
| Google, NVIDIA, Groq, Exa, Pollinations | all 200. |
| Supabase | **unverified** — this container's egress proxy 502s on `*.supabase.co`. |

### Still open
1. **Two media paths, both blocked on money, not code.** FAL balance exhausted (Market generation); OpenRouter at $0.13 (33 of 34 models). Nothing in the codebase fixes either.
2. `EXPO_PUBLIC_GOOGLE_API_KEY` lives only in `.env` (gitignored) and `eas.json` has no `env` block, so a production build ships without it. Set it on expo.dev → Environment Variables for the production profile.
3. **GitHub `Collider-X` main has 8 loose files at the repo root** — `AssetActionBar.tsx`, `CollideBanner.tsx`, `ConsensusDrawer.tsx`, `MarketScreen.tsx`, `ModelCard.tsx`, `theme.ts` (dead duplicates of correct copies under `src/`), plus `CollideButton.tsx` and `motion.tsx` (orphans, in no zip, imported by nothing). A drag that lost its folder structure. The zip is cleaner than the repo.
4. Push access: 403 for every credential tried. Work ships as zips.
