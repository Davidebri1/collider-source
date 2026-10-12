# DesignCode Overhaul — Authoritative Implementation Plan

- **Date:** 2026-08-10
- **Status:** Supersedes `plans/REDESIGN_IMPLEMENTATION_PLAN.md` (that doc remains useful only as a file/reference map; every decision here overrides it).
- **Source of truth:** `docs/DESIGN_OVERHAUL_DESIGNCODE_KIT_SPEC_2026-08-10.md` (the Canonical Master Spec). This plan is the executable translation of that spec into the Collider-X codebase.
- **Secondary references:** `CLAUDE.md` (hard constraints), `docs/design/HANDOFF-SPEC.md` (concrete RN values), `src/styles/theme.ts`, `src/motion.tsx`, `src/components/*`, `src/screens/*`, `App.tsx`, `src/state.tsx`, `src/models.ts`.

> **Working principle (from the master spec):** "No questions necessary — work until done." Every UI element is replaced by a DesignCode Figma-kit element — pick by potential/aesthetic/functional fit, ignore kit labels. Exceptions: background images and the consensus map itself; **all UI inside the consensus map swaps**. Applies to the main view, Market, and Smart Gen.

---

## A. Execution Strategy & Work-Breakdown Phases

### Strategy

1. **Foundation before surface.** The motion system (`src/motion.tsx`, `Press.tsx`, `Sheet.tsx`, `CollideButton.tsx`) currently uses RN `Animated`. `react-native-reanimated` (v4) and `@shopify/react-native-skia` are **installed but unused** — the mandate is to use them. Migrate the primitives first (Reanimated worklets + Skia) so every downstream surface inherits the new physics.
2. **No bare `Pressable`.** Every interactive surface must go through `src/components/Press.tsx` primitives (`PressableScale`, `FadeUp`, `Floaty`, `Shimmer`).
3. **Panels, not routes.** Secondary surfaces are panels (via `Sheet.tsx`) over the app — never full-screen routes. Settings is the **one exception** to the lip rule (gear icon, still blurs).
4. **Physical realism.** Every action = a physical equivalent; smoothness comes from framerate/HZ, not speed.
5. **No-numbers / no-noise enforcement is a gate**, not a cleanup pass. Each phase carries its own no-numbers acceptance criteria (Section E).
6. **Per-phase validation** against `expo start --web` + Playwright (Section F). Web first; native parity is a follow-on risk (Section G).

### Phases (execution order)

| Phase | Goal | Files touched (primary) | Depends on | Owning mode | Acceptance criteria |
|---|---|---|---|---|---|
| **P0 — Motion & primitive foundation** | Migrate RN `Animated` to Reanimated + Skia; build the shared `Lip`, `LipDrawer`, `DofBlur` primitives; glass/gloss primitives restyled to DesignCode tokens | `src/motion.tsx`, `src/components/Press.tsx`, `src/components/Sheet.tsx`, `src/components/Glass.tsx`, `src/components/GlossSurface.tsx`, `src/components/GlossButton.tsx`, `src/styles/theme.ts` | — | code | All primitives run on Reanimated worklets; no RN `Animated` in these files; glass = DesignCode recipe (see §B); `npm run typecheck` + `npm test` pass; web renders without redbox |
| **P1 — Lip shell + universal DOF rule** | Every pane becomes a Swift-style lip at bottom, opening a drawer left-to-right; when ANY lip opens, background gets depth-of-field blur | `App.tsx`, `src/components/Sheet.tsx` (or new `Lip.tsx`/`LipDrawer.tsx`), `src/screens/*` | P0 | code | All 5 lips (History, Prompt bar, Model category, SmartGen Hub, Media) open drawers; DOF blur applied on every lip-open; Settings remains a gear panel (blurs) |
| **P2 — Prompt bar autohide + Composer redesign** | Centered prompt bar; autohides 3–5s after send + on keyboard hide; redeploys fast-but-smooth on press; shorter/less tall; 2.5D strong drop shadow; DOF blur on background while typing; send button full white | `src/components/PromptComposer.tsx`, `App.tsx`, `src/styles/theme.ts`, `src/components/Press.tsx` | P0, P1 | code | Autohide timer 3–5s post-send; keyboard-hide triggers autohide; tap redeploys; no credit-count pill (`costForSend`) visible |
| **P3 — Model category pane + light toggles** | Light-emitted toggle indicators (off = light dissipates, on = light blooms); Free/Pro sectioned; swipe between categories; locked tiers lock over whole area; free users browse locked tabs but can't click; relock on subscription expiry | `src/motion.tsx` (`CategoryDeck`/`CategoryRail`), `src/components/ModelTray.tsx`, `src/components/ModelCard.tsx`, `src/models.ts`, `src/state.tsx`, `App.tsx` | P0 | code | Toggle light bloom/dissipate works via Reanimated; swipe commits at threshold; locked overlay covers whole tier; `isCategoryUnlocked`/tier-gating enforced; no tier badge numbers |
| **P4 — Model cards redesign** | Max 6 on screen; near-full-screen coverage; glass w/ sheen but **NO white border**; minimal blur; legible text; optional ground reflection/shadow for 2.5D | `src/components/ModelCard.tsx`, `src/components/Glass.tsx`, `src/styles/theme.ts` | P0, P3 | code | ModelCard has no white-ish border (remove `rgba(238,241,246,0.34)` border); count capped at 6; 2.5D reflection/shadow optional flag |
| **P5 — History pane + consensus preview lip** | History pane right of prompt, not full height, scrollable, loadable on click; consensus-history tab hidden in card view; consensus preview lip smaller/shorter (entice, not inform) | `src/screens/HistoryScreen.tsx`, `App.tsx`, `src/components/CollideBanner.tsx`, `src/components/ConsensusDrawer.tsx`, `src/components/ConsensusScene.tsx` | P0, P1 | code | History opens as pane (not route); consensus preview lip is compact; no counts/numbers in preview |
| **P6 — SmartGen Hub + canvas** | Full-width text buttons (NO icons): cards/boards/canvas (free); Smart Genie (pro tier, chat view, toggleable, minimizable; no coding unless elite; agents attachable at elite). Canvas: free drag-drop of cards/boards; boards look like their names; up to 10 loadable backgrounds/scenes with screen-swipe or numbered-icon nav | `src/screens/SmartGenBoardScreen.tsx`, `src/components/SmartGenKanban.tsx`, `src/components/CardGrid.tsx`, `src/state.tsx` (`BoardConfig.pos`), `App.tsx` | P0, P1 | code | Hub buttons text-only; Smart Genie toggleable/minimizable; canvas drag-drop works; board-name-as-look renders |
| **P7 — Media pane (tabs + premium theme + music)** | Tabbed drawer: Theme view (phone preview wallpapers, toggle icon view, fullscreen expand); **Premium Theme tab** (gated marketplace, $3–8, ONLY live wallpapers, seamless endless loop, 2k/4k, no camera movement, bundled with 5 curated songs, previewable list); Files & Music player tab (**draggable persistent music widget anywhere** incl. market/smartgen, minimizable to lip, shuffle/repeat once-or-infinite/next/prev/favorite, files sorted by filetype/model/upload-download); Discover Market tab (free market, two-tone black/red) | `src/components/WallpaperPanel.tsx`, `src/screens/WallpapersScreen.tsx`, `src/screens/FilesScreen.tsx`, `src/screens/MarketScreen.tsx`, `src/components/GrokMarket.tsx`, `src/services/musicPlayer.ts`, `src/state.tsx` (`musicPlayer.widget`), `App.tsx`, `src/styles/theme.ts` | P0, P1 | code | Media pane is tabbed; premium themes gated (never client-side grant); music widget draggable + persistent across screens; minimizable to lip; no number counts in media pane |
| **P8 — Row selector + long-press drag-drop** | 1/2/3 rows = single always-on button; drag-drop toggled via 1.5s long-press (haptic) + glowing selection outline; glow animates away on release; alignment button redundant (row selector realigns) | `App.tsx` (`RowSelectorModal`), `src/components/ModelCard.tsx`, `src/components/CardGrid.tsx`, `src/components/Press.tsx`, `src/state.tsx` (`setGridRows`, reorder) | P0, P4 | code | Single always-on row button; 1.5s long-press enters drag mode with haptic; glow outline animates away on release; alignment button removed |
| **P9 — Gold badge + no-numbers/no-noise sweep** | Pro+ gold badge (OVERRIDES prior gold/orange accent ban); strip counts/numbers; remove non-working/redundant features + redundant header buttons | `App.tsx` (drawer counts at 4460–4464, 4491–4492), `src/components/*`, `src/screens/*`, `src/styles/theme.ts` | All prior | code | No numeric counts anywhere in UI; gold badge only for Pro+; redundant header buttons removed |
| **P10 — Media-gen model swap + full validation** | Media-gen models completely replaced with Figma counterparts; full validation sweep | `src/models.ts`, `src/components/*`, `src/screens/*`, `src/services/media.ts` | All prior | code / devops | Full Playwright sweep green; native parity spot-checked |

---

## B. Element Mapping Table — DesignCode Kit → Collider Surface

> **Note on the Figma kit:** The Figma MCP connection was blocked/unavailable during planning, so exact kit component names could not be enumerated. Until the Figma file is reachable, apply the **DesignCode design language treatment** (documented aesthetic below) to each Collider surface. When the Figma kit becomes available, swap in the exact kit node by potential/functional fit — implementation can proceed now and refine later.

**DesignCode language treatment (defaults):** dark glassy depth, layered surfaces, SF-Pro-like type (we use Instrument Sans 400–700 via `withFont()`), subtle violet/blue gradients (accent `#9D6BFF`), radii 8/12/16/20/28/pill, soft large-radius shadows, generous spacing, high-contrast text on glass, minimal ornament, soft specular sheen, hairline top light.

| DesignCode kit element / pattern | Collider surface | Implementation notes |
|---|---|---|
| **Lip / tab (bottom-docked pill)** | All panes: History, Prompt bar area, Model category pane, SmartGen Hub, Media | New shared `Lip` primitive (Reanimated): pill docked bottom, distinct color/design twist per lip. Opens a `LipDrawer` left-to-right. Settings = gear, not a lip. |
| **Pane / drawer (slide-in panel)** | Every lip's opened drawer | `Sheet.tsx` (side `bottom|right|left`) restyled to DesignCode: 280px slide, `.38s cubic-bezier(.3,.9,.3,1)`, BlurView 40 + `GLASS_PANEL` gradient. DoF blur on the background whenever any drawer is open. |
| **Depth-of-field (DOF) blur** | Background behind any open lip/pane; prompt bar while typing | New `DofBlur` wrapper: high-intensity blur (`blur(20px) saturate(150%)` equivalent) + dim on everything behind the open pane. Skia or expo-blur based; see §D. |
| **Card (glass card)** | Model cards, consensus cards, Smart Gen cards | `Glass isCard` recipe: gradient `linear-gradient(165deg, rgba(255,255,255,.07), rgba(255,255,255,.028) 40%, rgba(10,12,18,.35))`, border `1px rgba(255,255,255,.1)`, `backdrop-filter: blur(20px) saturate(150%)`, shadow `inset 0 1px 0 rgba(255,255,255,.13), 0 14px 30px rgba(0,0,0,.45)`, radius 20. **Model cards: NO white border** — replace the `rgba(238,241,246,0.34)` border in `ModelCard.tsx`. |
| **Button (filled / tonal / text)** | Collide button, send button, option pills, toolbar buttons | `CollideButton.tsx`: 210×46, radius 23, gradient `#16181f→#0a0b10`, breathing glow + expanding halo; **send button = full white** (swap `#1a1d24` → `linear-gradient(180deg,#fff,#c9d2e0)`); text buttons (SmartGen Hub) full-width, NO icons. |
| **Toggle / switch (light-emitted)** | Model category Free/Pro toggles, Smart Genie toggle | Light-emitted indicator: on = light blooms (glow up), off = light dissipates (glow down). Reanimated worklet-driven; Free/Pro sectioned with color/effect coding. |
| **Segmented control / tabs** | Media pane tabs, model category rail, consensus map tabs | DesignCode segmented control styling; swipe between categories (existing `CategoryDeck` rubber-band logic migrated to Reanimated). |
| **List / table row** | Files list, memory/reminder/project lists, drawer nav rows | Files sorted by filetype/model/upload-download. Drawer nav rows: **remove counts** (e.g. `count: state.projects.length` at App.tsx 4460–4464, 4491–4492). |
| **Slider** | Volume, scrub | Keep existing slider patterns, restyle to DesignCode; CornerVolumeControl stays a panel control. |
| **Badge (gold)** | Pro+ tier badge | **Gold badge OVERRIDES the prior gold/orange accent ban.** Gold only for Pro+. |
| **Map / 2.5D scene** | Consensus map (the exception surface) | Consensus map itself is the exception — but **all UI within the map swaps**: score (keep, restyle to mono), summary card, DISSENT/TOTAL tabs, dissenter list, header/back, labels toggle. `ConsensusScene.tsx` (web iframe) + `ConsensusDrawer.tsx` native. |
| **Background image** | Wallpapers / themes | Exception — background images stay as-is. |
| **Toast / notification** | Toast | Restyle to DesignCode pill toast; keep `Toast.tsx` API. |
| **Empty state** | Model selector, board, files | DesignCode empty-state treatment (icon + headline + hint), no numbers. |
| **Search field** | Inline search, history search | DesignCode input styling (r12, glass, inset hairline). |

---

## C. File-by-File Change Map

### New files

| File | Purpose |
|---|---|
| `src/components/Lip.tsx` | Reanimated lip pill primitive (docked bottom, per-lip color/design twist, press → opens drawer). |
| `src/components/LipDrawer.tsx` | Left-to-right pane drawer wrapping `Sheet.tsx` with DOF blur + per-lip styling. |
| `src/components/DofBlur.tsx` | Depth-of-field blur wrapper (blur + dim + scale on background). Skia-based on web, expo-blur fallback native. |
| `src/components/MediaPane.tsx` | Tabbed media drawer: Theme view / Premium Theme / Files & Music / Discover Market. Owns the draggable music widget surface. |
| `src/components/MusicWidget.tsx` | Draggable persistent music widget (position from `state.musicPlayer.widget{x,y,collapsed}`), minimizable to a lip. |
| `src/components/SmartGeniePane.tsx` | Smart Genie (AI agent, pro tier) chat view, toggleable/minimizable; no coding unless elite; agent attach at elite. |
| `src/components/RowSelector.tsx` | Single always-on 1/2/3 row button replacing the modal; long-press drag mode toggle. |

### Modified files (primary)

| File | What changes | What stays |
|---|---|---|
| `src/motion.tsx` | Migrate `wave`, `useAmbientPhase`, `timing`, `ScreenTransition`, `SinkPresence`, `CategoryDeck`, `CategoryRail` from RN `Animated` to Reanimated worklets + Skia (where needed). Keep single monotonic linear phase for ambient motion; distinct enter (decelerate) / exit (accelerate) curves for transitions. | The exported API/names (call sites unchanged). `DUR`/`EASE` semantics. |
| `src/components/Press.tsx` | Migrate `PressableScale`, `FadeUp`, `Shimmer`, `Floaty` to Reanimated. Add `LongPressDrag` primitive (1.5s long-press + haptic + glowing selection outline that animates away on release). Remove the header comment claiming Reanimated is unsafe (superseded by CLAUDE.md). | Public props/API. `EASE_OUT`/`EASE_SPRING`/`DUR_PRESS`/`DUR_RELEASE` values. |
| `src/components/Sheet.tsx` | Keep as the panel primitive; restyle to DesignCode; ensure it composes with `DofBlur` and `LipDrawer`. | `PANEL_EASE`, `PANEL_IN`/`PANEL_OUT`, overlay + BlurView + gradient recipe, grabber, header. |
| `src/components/Glass.tsx` | Apply exact DesignCode glass recipe (HANDOFF-SPEC values). Keep `isCard` flag. | BlurView + gradient + sheen structure. |
| `src/components/GlossSurface.tsx` / `GlossButton.tsx` | Restyle gloss to DesignCode radii/shadow; used as lip/surface chrome. | Variant/flat props, structure. |
| `src/components/CollideButton.tsx` | Migrate to Reanimated; keep breathing glow + halo + settle; ensure `blocked` state renders. | `CollideState` machine, "COLLIDE" label, gradient, orb. |
| `src/components/PromptComposer.tsx` | Prompt bar: centered, shorter/less tall; autohide 3–5s after send + on keyboard hide; redeploy on press; 2.5D strong drop shadow; DOF blur while typing; **send button full white**; **remove `costForSend` credit-number pill** (no-numbers); option pills restyled. | Compose logic, `--task/--ar/--quality/...` flags, attach/mic/transcribe, InjectionChip, tool row. |
| `src/components/ModelCard.tsx` | Max 6 on screen; near-full-screen coverage; minimal blur; legible text; **NO white border**; optional ground reflection/shadow for 2.5D; long-press drag integration; light-toggle selection. | `LockedVeil`, mini bubbles, windowed history `PAGE=20`, Markdown, model-color title, dismiss X. |
| `src/components/ModelTray.tsx` | Model category pane: light toggles, Free/Pro sections, swipe, locked-over-whole-area, browse-but-not-click for free. | Roster, tier grouping. |
| `src/components/CollideBanner.tsx` / `ConsensusDrawer.tsx` / `ConsensusScene.tsx` | Consensus preview lip smaller/shorter (entice not inform); consensus-history tab hidden in card view; restyle all in-map UI (score, summary, tabs, dissenter list) to DesignCode. | Consensus logic, `ConsensusScene` iframe, `ConsensusModal` API. |
| `src/components/SmartGenKanban.tsx` / `CardGrid.tsx` / `BoardConfig` | Canvas free drag-drop of cards/boards; boards look like their names; up to 10 backgrounds/scenes, screen-swipe or numbered-icon nav (numbered-icon nav conflicts with no-numbers? — use icons, not numerals). | Board data model, kanban logic. |
| `src/components/WallpaperPanel.tsx` / `WallpapersScreen.tsx` | Theme view (phone preview, toggle icon view, fullscreen expand); Premium Theme tab (gated $3–8, live wallpapers only, seamless loop, 2k/4k, no camera movement, 5 bundled songs, previewable list). | Wallpaper apply logic, free/premium data. |
| `src/screens/FilesScreen.tsx` / `MarketScreen.tsx` / `GrokMarket.tsx` | Files sorted by filetype/model/upload-download; Discover Market free tab two-tone black/red. | File/market data + actions. |
| `src/screens/HistoryScreen.tsx` | History as pane right of prompt (not full route), not full height, scrollable, loadable on click. | History data + search. |
| `src/screens/SmartGenBoardScreen.tsx` | Hub full-width text buttons (no icons); Smart Genie integration. | Board screen structure. |
| `src/screens/UpgradeScreen.tsx` | Pro+ gold badge; purchase correctness (never client-side grant). | Upgrade logic, RevenueCat/iap. |
| `App.tsx` | Wire all lips into root; DOF blur on lip-open; remove drawer nav counts; remove redundant header buttons; single row selector; media pane + music widget overlay; consensus-history tab gating; prompt autohide orchestration. | `Screen` union, `screen` state, `nav()` upgrade-panel interception, `ThemeBackground`, `ConsensusModal` overlay, `HomeCategoryRail`, `RowSelectorModal` replaced by `RowSelector`. |
| `src/styles/theme.ts` | Add DesignCode tokens: accent `#9D6BFF`, gold `#f5c34d` (Pro+ only), lip/surface tokens, DOF tokens, radii 28/pill. Update `send` style to full white. | `T` tokens, `GLASS_CARD`/`GLASS_PANEL`, `SHEEN_LINE`, `RADIUS`, `EASING`, `withFont()`, `WALLPAPERS`, `FREE_THEMES`/`PREMIUM_THEMES`. |
| `src/models.ts` | Media-gen models completely replaced with Figma counterparts. | `Tier`, `Category`, `ModelDef`, `MODELS`, `TIER_RANK`, `canUse()`, `modelsForCategory()`. |
| `src/state.tsx` | Possibly extend `musicPlayer`/`BoardConfig` (e.g., premium gating state); no numbers added. | `AppState`, reducer actions, hydration. |
| `src/services/musicPlayer.ts` / `media.ts` / `smartgen.ts` | Music widget: shuffle/repeat once-or-infinite/next/prev/favorite; persistent across screens; minimizable to lip. | expo-av Audio API, track loading, STT, notifications. |

### What stays (no change)

- `metro.config.js` (critical — do not remove).
- No `babel.config.js` added — Reanimated 4 works with `babel-preset-expo@54` auto-injecting `react-native-worklets/plugin`.
- Fonts: Instrument Sans 400–700 (no 800/900; `fontFamilyForWeight()` resolves to 700) + IBM Plex Mono for labels/scores/tiers/timestamps.
- `npm test` (Node test runner, `scripts/tests/`), `npm run typecheck`.
- Supabase + Google Cloud backends, auth, iap, minimax, fal, googleCalendar services — logic unchanged.
- Consensus map itself (the exception surface) stays a 2.5D scene; only its internal UI swaps.

---

## D. Motion Spec — Reanimated/Skia Migration

### D.1 Migration targets

| Current (RN `Animated`) | New (Reanimated / Skia) | Location |
|---|---|---|
| `wave()`, `useAmbientPhase()` | `useSharedValue` + `withRepeat(withTiming(...))` worklet loop; single monotonic linear phase (no ping-pong/inOut turnarounds) | `src/motion.tsx` |
| `timing()`, `ScreenTransition`, `SinkPresence` | `withTiming` / `withSpring` worklets; enter = decelerate curve, exit = accelerate curve | `src/motion.tsx` |
| `CategoryDeck` PanResponder rubber-band | Reanimated `Gesture.Pan()` with rubber-band + `SWIPE_COMMIT=52`/`SWIPE_YIELD=44` thresholds | `src/motion.tsx` |
| `PressableScale`/`FadeUp`/`Shimmer`/`Floaty` | Reanimated press-in/out worklets, `withSpring` scale/lift | `src/components/Press.tsx` |
| `CollideButton` glow/halo/orb | Reanimated `withRepeat` breathing + Skia radial glow (or expo `Svg`) | `src/components/CollideButton.tsx` |

### D.2 Worklet + HZ considerations

- All ambient loops and transitions must be **UI-thread worklets** (no JS-thread hops) to sustain high framerates; keep worklet closures pure (no state reads inside loops).
- `useDerivedValue` for interpolations that feed Skia views or blur radii.
- Blur is expensive: apply DOF blur to a **single background layer** (one `DofBlur` wrapper), not per-surface. Use Skia `ImageFilter` blur on web where available; expo-blur fallback on native.
- Respect `Platform.OS`: Skia web build is a known dead end historically (see musicPlayer.ts comment) — guard Skia usage behind a runtime capability check and fall back to expo-blur/`Svg` on web if the Skia web build regresses. **Re-verify during P0 before committing to Skia for blur.**
- Physical realism: use `withSpring` with low stiffness for drag; `withTiming` + decelerate for enter, accelerate for exit; never fake speed with high durations.

### D.3 Specific transitions

| Interaction | Spec behavior | Reanimated recipe |
|---|---|---|
| **Lip → pane DOF blur** | When ANY lip becomes a pane/drawer, background falls out of focus | `DofBlur` animates blur radius 0 → 20px + dim 0 → 0.5 over PANEL_IN (380ms), reverse over PANEL_OUT (260ms). Drawer slides left-to-right with `EASE move` bezier(0.4,0,0.2,1). |
| **Prompt bar autohide** | 3–5s after send + on keyboard hide; redeploy fast-but-smooth on press | `withDelay(3500, withTiming(0))` on translateY/opacity; redeploy `withSpring` (fast, snappy); DOF blur ramps while typing. |
| **Light-toggle bloom / dissipate** | Off = light dissipates, on = light blooms | `withSpring` on glow opacity + halo scale; color/effect coded per tier (Free vs Pro). |
| **Long-press glow** | 1.5s long-press + haptic; glowing selection outline; glow animates away on release | `withTiming` outline glow ramp-in during press (1.5s), `withSpring`/ease-out away on release; `Haptics` on engage. |
| **Drag physics (canvas/cards)** | Free drag-drop; physical throw | `Gesture.Pan` with `withSpring` on release, velocity-based throw, snap to grid/canvas positions (`BoardConfig.pos`). |
| **Music widget drag persistence** | Draggable anywhere (incl. market/smartgen); persists position; minimizable to lip | `Gesture.Pan` writes `state.musicPlayer.widget{x,y,collapsed}` on release; position restored on remount; collapsed state = lip. |
| **Consensus settle (CollideButton)** | One-shot settle pass 620ms | Keep existing `EASE.enter` timing, migrated to Reanimated `withTiming`. |

### D.4 Shared timing/easing tokens

- `DUR { snap:190, enter:300, exit:240, screen:320 }` — keep, migrate values to Reanimated.
- `EASE { enter, exit, move: bezier(0.4,0,0.2,1), linear }` — keep.
- `PANEL_EASE = Easing.bezier(0.3,0.9,0.3,1)`, `PANEL_IN = 380`, `PANEL_OUT = 260` — keep.
- New: `DOF_BLUR_MAX = 20`, `LIP_DUR_IN = 260`, `LIP_DUR_OUT = 180`, `AUTOHIDE_DELAY_MS = 3500` (configurable 3000–5000), `LONG_PRESS_MS = 1500`, `BLOOM = withSpring(1, {damping: 14, stiffness: 120})`.

---

## E. No-Numbers / No-Noise Enforcement Checklist

> The rule: **no counts, no non-labeling numbers anywhere in the UI.** Gold badge (Pro+) is the sole exception to the gold/orange accent ban. Non-working/unneeded features and redundant header buttons are removed.

### Strip counts / numbers

- [ ] `App.tsx` drawer nav rows: remove `count: state.projects.length + ...` (lines ~4460–4464) and `count: state.files.length` (~4491–4492). Labels only.
- [ ] `PromptComposer.tsx`: remove the `costForSend > 0` credit-number pill (line ~596–617) and the total/afford rows inside the settings modal that render numbers (~966–999). Keep affordability as a plain prose/disabled state, no numerals.
- [ ] `CollideBanner.tsx` / `ConsensusDrawer.tsx`: replace "3/4 MODELS ALIGNED", "7/8", `agreementPct` "NN%", score `84px` mono number with prose/lumens — the consensus score becomes luminance (brightness = popularity), not a displayed integer. (Consensus map is the exception surface, but in-map UI swaps: keep a label, drop ratio numerals.)
- [ ] `ModelTray.tsx` / `ModelCard.tsx`: no tier-badge numbers, no credit pools displayed.
- [ ] `FilesScreen.tsx`: no file-count rows.
- [ ] `HistoryScreen.tsx`: no "N items" counters.
- [ ] `SmartGenBoardScreen.tsx`: no item counts in hub buttons or board headers.
- [ ] `MediaPane.tsx` (Theme/Premium/Files/Music tabs): no counts; music widget shows track title, not track index numerals.
- [ ] `UpgradeScreen.tsx`: no numeric pool figures as decoration (credit amounts are billing data; if shown, only in the purchase context — keep minimum).
- [ ] Numbered-icon scene navigation (canvas): use icons, not numerals, to satisfy no-numbers.
- [ ] Grid sweep: `search_files` for `\.length` rendered into `<Text>` / `{count` and `{state\..*\.length}` — every hit either removed or confirmed non-numeric label.

### Remove non-working / unneeded features

- [ ] Any button/control that dispatches nothing or navigates nowhere — remove (e.g., unused dummy controls).
- [ ] Redundant header buttons — remove; keep one clear path per action.
- [ ] Settings panel stays (gear, blurs) as the ONE non-lip exception.
- [ ] Consensus preview lip: shrink/shorten — entice, not inform (no preview numerals).

### Gold badge

- [ ] Pro+ gets a gold badge. Gold `#f5c34d` allowed ONLY here (overrides prior ban).

---

## F. Validation Plan — `expo start --web` + Playwright

### F.0 Standing checks (every phase)

- `npm run typecheck` (`tsc --noEmit`) passes.
- `npm test` (Node test runner, `scripts/tests/`) passes.
- `expo start --web` boots with no redbox; Playwright loads `localhost:8081`.

### F.1 Per-phase Playwright checks

| Phase | Check |
|---|---|
| **P0** | All primitives render; Reanimated loops animate (screenshot diffs over 2s); no console errors; glass recipe correct color/radius. |
| **P1** | Opening each of the 5 lips shows DOF blur on background; drawers slide left-to-right; Settings gear blurs; close returns focus. |
| **P2** | Send → prompt bar autohides within 3–5s; keyboard-hide autohides; press redeploys fast-but-smooth; typing shows DOF blur; send button is full white; no credit pill. |
| **P3** | Toggle light blooms on / dissipates off; swipe commits at threshold; locked tier overlay covers whole area; free user can browse locked tabs but click is blocked; expiry relocks. |
| **P4** | ≤6 cards; near-full-screen coverage; no white border on model card; text legible; optional reflection/shadow renders. |
| **P5** | History opens as pane right of prompt (not full route); scrollable + loadable; consensus-history tab hidden in card view; consensus preview lip compact. |
| **P6** | Hub buttons full-width text (no icons); Smart Genie toggleable/minimizable; canvas drag-drop moves cards/boards; board renders as its name; ≤10 scenes with icon nav. |
| **P7** | Media pane tabs switch; premium themes gated (no client-side grant); music widget drags anywhere incl. market/smartgen; position persists across screens; minimizable to lip; shuffle/repeat/next/prev/favorite work; files sorted. |
| **P8** | Single always-on row button; 1.5s long-press + haptic enters drag mode; glow outline animates away on release; alignment button gone. |
| **P9** | No numeric counts anywhere (automated text scan of visible DOM for standalone integers); gold badge only Pro+; redundant buttons gone. |
| **P10** | Full regression sweep of all above; media-gen models show Figma counterparts; market two-tone black/red. |

### F.2 Playwright harness notes

- Use `playwright.config.ts` (present at root); target `http://localhost:8081`.
- For autohide timing, use `page.waitForTimeout` / `expect(locator).toBeHidden()` with the configured 3–5s window.
- For no-numbers sweep, evaluate `document.body.innerText` and assert no standalone numeric tokens (whitelist: none by default; gold badge is decorative).
- Screenshot baseline per phase for visual diff against DesignCode reference.

---

## G. Risks + Open Items

| # | Risk / open item | Mitigation / disposition |
|---|---|---|
| 1 | **Figma MCP unavailable** — exact kit node names unknown; kit element identity is guessed by potential/aesthetic/functional fit | Apply DesignCode design-language treatment now (Section B); refine to exact kit nodes when Figma connects. Do not block implementation. |
| 2 | **Native parity** — expo web validated; Skia web build historically a dead end; native (iOS/Android) blur/drag may differ | Guard Skia behind runtime capability check; expo-blur fallback; P0 spike re-verifies Skia web build; native spot-check in P10; ship web first. |
| 3 | **Consensus 2.5D** — map is the exception surface; in-map UI restyle must not regress the v3 framework (no dissent threshold, luminance-only score) | Keep all consensus logic/derivation (`services/consensusView.ts`, `services/chat.ts`) untouched; only restyle presentation; preserve `ConsensusScene` iframe contract. |
| 4 | **RevenueCat / purchase correctness** — `verifyPurchase` currently returns `true` unconditionally (spoofable); premium themes + Pro tier gating depend on it | **Never grant client-side.** Requires Supabase edge function verifying Apple/Google receipts. Until fixed, premium gating must fail-closed (do not ship gated storefront trusting client flag). Flag as release-blocking for paid content. |
| 5 | **Autohide vs usability** — prompt bar auto-hiding 3–5s could frustrate; redeploy must be reliable | Configurable `AUTOHIDE_DELAY_MS`; redeploy on any press in prompt region; Playwright verifies timing + redeploy. |
| 6 | **Blur performance** — DOF blur on every lip-open across devices | Single background-layer blur; blur only while pane open; Skia/expo-blur fallback; perf check in P0/P1. |
| 7 | **No-numbers edge cases** — hidden numerals (credit data, timestamps, prices) | Timestamps/prices are labels, not counts — keep in mono. Sweep targets `.length`/`count`/`ratio` renders only. Prices in Premium Theme ($3–8) are labels. |
| 8 | **Board drag-drop + 2.5D** — canvas free drag-drop with up to 10 scenes is new surface complexity | Reuse `BoardConfig.pos`; incremental: cards first, then boards; scenes last. |
| 9 | **OpenRouter out of credit; TTS voice ids unverified; `collider.app` doesn't resolve; Apple PLA unsigned** | Pre-existing known gaps (CLAUDE.md) — out of scope for the overhaul; do not let them block cosmetic/structural work. |
| 10 | **`assets/themes/premium/` pricing** — `DEFAULT_PREMIUM_PRICE = "$2.99"` applied to all | Per-theme pricing is a content decision; keep default, allow per-theme override later. |

---

## Appendix — Key Reference Values (from HANDOFF-SPEC)

- Glass card: `linear-gradient(165deg, rgba(255,255,255,.07), rgba(255,255,255,.028) 40%, rgba(10,12,18,.35))`; border `1px rgba(255,255,255,.1)`; `backdrop-filter: blur(20px) saturate(150%)`; shadow `inset 0 1px 0 rgba(255,255,255,.13), 0 14px 30px rgba(0,0,0,.45)`; radius 20.
- Composer radius 20 glass + white send FAB (32px): `linear-gradient(180deg,#ffffff,#c9d2e0)`.
- Collide button 210×46 radius 23.
- Bubbles `16 16 4 16` (user) / `16 16 16 4` (model).
- Consensus 2.5D map `perspective:700px` `rotateX(14deg)`.
- Drawers 280px slide `.38s cubic-bezier(.3,.9,.3,1)`.
- Colors: bg `#0b0c10`/`#07080b`, ink `#eef1f6`, consensus green `#7ee2a8`, dissent red `#ff6a5c`, model colors Haiku `#f6a4c9`, Gemini `#7fd8c4`, Llama `#4be6b1`, Mistral `#ffb066`.
- DesignCode accent: `#9D6BFF`; gold (Pro+ badge only): `#f5c34d`.
