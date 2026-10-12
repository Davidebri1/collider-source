# Figma ↔ MCP Integration Rules — Collider-X

> **Purpose.** A standing reference for integrating Figma designs (via the Model
> Context Protocol) into this React Native / Expo codebase. Read this before
> translating any Figma frame into code. It is the bridge between the Figma
> DesignCode UI Kit and the app's existing RN primitives.

---

## 0. Stack facts that constrain every Figma translation

| Concern | Value | Source |
|---|---|---|
| Framework | React Native 0.81 + **React 19.1** | `package.json` |
| Runtime | Expo SDK 54 (`expo start`, `expo run:ios/android`) | `package.json` |
| Web target | `react-native-web` 0.21 (consensus map is an **iframe** with `srcDoc` HTML) | `ConsensusScene.tsx` |
| Styling | **`StyleSheet.create`** (RN primitives) — **no** CSS Modules, Styled-Components, or Tailwind | `src/styles/theme.ts` |
| Fonts | Instrument Sans + IBM Plex Mono, loaded as static-weight files via `@expo/google-fonts/*` | `App.tsx`, `theme.ts` |
| Glass | Real `BlurView` (`expo-blur`) + `LinearGradient` (`expo-linear-gradient`) | `Glass.tsx`, `Sheet.tsx` |
| Motion | `react-native-reanimated` 4 + `@shopify/react-native-skia` installed; `Press.tsx` is the motion layer (RN `Animated`, not Reanimated worklets) | `Press.tsx`, `CLAUDE.md` |
| Build | Metro (`metro.config.js` — **do not remove**; adds `mjs` ext, disables package exports) | `metro.config.js` |
| State | `useReducer` + AsyncStorage in `src/state.tsx` | `CLAUDE.md` |

**Hard rule:** Figma ships CSS/HTML. This app is RN. You cannot paste Figma's
CSS into a `.tsx`. You must *recreate* each node with RN primitives
(`View`, `Text`, `BlurView`, `LinearGradient`, `PressableScale`). The
`collider (1).html` / `collider-redesign.dc.html` files are **design
references**, not buildable code (custom `<x-dc>` runtime).

---

## 1. Design Token Definitions

**Where:** `src/styles/theme.ts` is the **single canonical token source**.
There is no JSON/YAML token file and no token-transformation pipeline — tokens
are exported TypeScript constants. The root `theme.ts` copy was deleted; this
is the only copy.

**Structure:**
```ts
// src/styles/theme.ts
export const T = {
  bg: "#07080b",
  ink: "#eef1f6",
  inkDim: "rgba(238,241,246,0.6)",
  line: "rgba(255,255,255,0.1)",
  glassLo: "rgba(255,255,255,0.05)",
  aurora: "rgba(60,80,140,0.28)",
  good: "#7ee2a8",      // consensus green
  dissent: "#ff6a5c",    // dissent red
  accent: "#9D6BFF",    // DesignCode violet/blue
  gold: "#f5c34d",      // Pro+ badge ONLY
};

export const RADIUS = { sm: 8, md: 12, lg: 16, xl: 20, xxl: 28, pill: 999 } as const;

export const GLASS_CARD = ["rgba(255,255,255,0.07)","rgba(255,255,255,0.028)","rgba(10,12,18,0.35)"] as const;
export const SHEEN_LINE = "rgba(255,255,255,0.13)"; // inset top highlight
```

**Token transformation:** none. When Figma gives a hex, map it to the nearest
`T.*` token; do **not** hardcode new rgba strings in components (the redesign
explicitly banned ad-hoc values like `13/15/17/22/24` radii — use `RADIUS.*`).

**Figma variable mapping:** Figma `color`/`number` variables → `T.*` /
`RADIUS.*` / `EASING.*`. Figma `fontFamily` → `fontFamilyForWeight()` (see §2).

---

## 2. Typography & Font Resolution

Two families only — **Instrument Sans** (body/display) and **IBM Plex Mono**
(instrument labels: scores, tiers, kickers, timestamps). Inter/JetBrains
Mono/Manrope/Playfair are **removed**.

```ts
// src/styles/theme.ts
export const FONT_REGULAR = "InstrumentSans_400Regular";
export const FONT_BOLD    = "InstrumentSans_700Bold";
export const FONT_MONO    = "IBMPlexMono_500Medium";

// ALWAYS resolve weight through this — never set fontWeight:"900" directly.
export function fontFamilyForWeight(weight?: string | number): string {
  const w = /* parse */;
  if (w >= 700) return FONT_BOLD;
  if (w >= 600) return FONT_SEMIBOLD;
  if (w >= 500) return FONT_MEDIUM;
  return FONT_REGULAR;
}
export const withFont = (raw) => /* injects fontFamily into every style */;
```

**Rule:** Instrument Sans has **no 800/900 face**. `fontWeight:"900"` resolves
to a real 700, not a synthetic ultra-bold. Never "restore" a heavier weight.
Mono labels use `monoFamily(weight)` / `FONT_MONO`.

---

## 3. Component Library

**Where:** `src/components/` (40+ files). Architecture is **flat, presentational
React components** — no Storybook, no component docs site, no `.stories` files.

**Key primitives to reuse (do not rebuild):**
| Component | File | Role |
|---|---|---|
| `Glass` | `src/components/Glass.tsx` | Frosted surface: `BlurView` + `GLASS_CARD` gradient + `SHEEN_LINE` top hairline. `isCard` prop controls blur intensity. |
| `PressableScale` / `FadeUp` / `Floaty` / `Shimmer` | `src/components/Press.tsx` | **Motion layer.** Every interactive surface MUST use `PressableScale` — never a bare `Pressable`. |
| `Sheet` | `src/components/Sheet.tsx` | Slide-in panel primitive (`.drawer` curve `cubic-bezier(0.3,0.9,0.3,1)`, 380ms). Secondary surfaces are panels, **never full-screen routes**. |
| `GlossButton` / `GlossSurface` | `src/components/` | DesignCode gloss variants. |
| `ModelCard` | `src/components/ModelCard.tsx` | Per-model card (glass, no white border, color dot + glow). |
| `CollideButton` | `src/components/CollideButton.tsx` | Breathing radial glow + spark slivers. |
| `ConsensusScene` / `consensus-scene-template.ts` | `src/components/` | Web consensus map (iframe `srcDoc` HTML string). |

**Figma → component mapping rule:** When a Figma node matches a primitive
(`Glass`, `Sheet`, `PressableScale`, `ModelCard`), **use the primitive**, do not
recreate it. The DesignCode overhaul mandates *every* UI element be swapped to a
kit equivalent — but in code that means routing through these primitives, not
inlining new styles.

---

## 4. Frameworks & Libraries (for MCP tooling)

- **UI:** React 19 + React Native 0.81. No web framework (Next/Vite) — RN Web only.
- **Styling:** `StyleSheet` + `expo-linear-gradient` + `expo-blur`. No CSS-in-JS lib.
- **Icons:** `@expo/vector-icons` (`Ionicons`) — see §7.
- **Graphics:** `@shopify/react-native-skia` (2.5D spheres, consensus map), `react-native-svg`.
- **Animation:** `react-native-reanimated` 4 (worklets auto-injected by `babel-preset-expo` — **no `babel.config.js`**), but the app's own motion uses RN `Animated` via `Press.tsx`.
- **Bundler:** Metro. `metro.config.js` is load-bearing (mjs ext, exports disabled).
- **Typecheck/test:** `npm run typecheck` (`tsc --noEmit`), `npm test` (Node test runner, `scripts/tests/*.test.mjs`).

**MCP relevance:** The Figma MCP server (`https://mcp.figma.com/mcp`) returns
design context as code/JSON. Because the target is RN, the generated snippets
must be **translated** to `StyleSheet` + primitives, not emitted as CSS/HTML.

---

## 5. Asset Management

**Where:** `assets/` (root) and referenced by `require` / `uri`.
```
assets/
  bg-default.jpg, icon.png
  themes/free/, themes/premium/   # live wallpapers (premium/ is EMPTY — known gap)
  ui/                             # PNG exports: brain_icon_*.png, collide_btn_*.png
```

**Reference patterns:**
- **Static bundled assets** → `require("../../assets/ui/collide_btn_final.png")`
  (Metro resolves `require` at build time).
- **Remote/user media** → `source={{ uri: asset.url }}` with `resizeMode`.
  Seen in `AssetViewer.tsx`, `GenerationColumn.tsx`, `MarketScreen.tsx`,
  `FilesScreen.tsx`, `SmartGenBoardScreen.tsx`.
- **Wallpapers** drive an app-wide ambient aurora tint via `state.wp`
  (`App.tsx` → `LinearGradient` second layer color).

**Optimization / CDN:** No CDN config in-repo. Remote media uses Supabase
storage URLs (`src/services/supabase.ts`, `market.ts`). Market fallbacks point
at `assets.mixkit.co` (placeholder). No image pipeline/optimizer configured.

**Figma asset rule:** Export Figma bitmaps at 2×/3× and drop into `assets/ui/`
(or `themes/`). Reference via `require` for bundled, `uri` for remote. Do not
inline base64 into components.

---

## 6. Icon System

**Where / how:** `@expo/vector-icons` → `Ionicons`. Imported per-file:
```ts
import { Ionicons } from "@expo/vector-icons";
<Ionicons name="chevron-back" size={20} color={T.ink} />
```
Seen in `ModelCard.tsx`, `Sheet.tsx`, `PromptComposer.tsx`, `App.tsx`.

**Naming:** Ionicons' own kebab names (`"menu"`, `"diamond"`, `"mic"`,
`"globe"`, `"lock-closed"`). There is **no local icon component wrapper** and
**no custom icon font** — Figma glyphs that aren't in Ionicons should be
exported as PNG to `assets/ui/` (e.g. `brain_icon_v5.png`, `collide_btn_v6.png`
already there) and used via `Image`.

**Figma icon rule:** Map Figma icons → Ionicons where a match exists; otherwise
export the Figma icon as PNG to `assets/ui/` and `require` it. Keep the
`assets/ui/` naming convention `<concept>_vN.png`.

---

## 7. Styling Approach

- **Methodology:** RN `StyleSheet.create` objects. No CSS Modules, no
  Styled-Components, no Tailwind, no global CSS (except the iframe `srcDoc`
  HTML for the consensus map, which is real CSS inside a string).
- **Global styles:** `src/styles/theme.ts` `styles` export (`.bg`, `.header`,
  `.titleBar`, `.toolbar`) + `withFont` helper applied to local sheets.
- **Responsive:** No breakpoint system. Layout is flexbox with
  `Dimensions.get("window")` (`SCREEN_W`/`SCREEN_H` in `theme.ts`) and
  `useSafeAreaInsets()`. The redesign mandates **clipping app content to screen
  bounds** (`overflow: hidden` on root) — the HTML prototype overflowed
  horizontally and that bug must not be reproduced.
- **Glass everywhere:** one system — `BlurView` + `GLASS_CARD` gradient +
  `SHEEN_LINE` hairline. Model colors are **glows, not fills**.

**Figma CSS → RN translation table:**
| Figma/CSS | RN equivalent |
|---|---|
| `backdrop-filter: blur(20px)` | `<BlurView intensity={18} tint="dark" />` |
| `linear-gradient(165deg, …)` | `<LinearGradient colors={GLASS_CARD} … />` |
| `box-shadow: inset 0 1px 0 …` | `<View style={{height:1, backgroundColor:SHEEN_LINE}} />` |
| `border-radius: 20px` | `borderRadius: RADIUS.lg` |
| `:active { transform: scale(1.05) }` | `PressableScale scaleTo={1.05}` |
| `transition: .38s cubic-bezier(.3,.9,.3,1)` | `Animated` + `Easing.bezier(0.3,0.9,0.3,1)` (see `Sheet.tsx`) |
| `perspective:700px; rotateX(14deg)` | `transform:[{perspective:700},{rotateX:"14deg"}]` (consensus map) |

---

## 8. Project Structure & Feature Patterns

```
App.tsx                      # Entry. useFonts, providers, root navigator.
src/
  state.tsx                  # useReducer store + AsyncStorage; useCollider(), useDraft()
  models.ts                  # ModelDef {id,label,short,color,tier}; MODELS, CATEGORIES
  styles/theme.ts            # CANONICAL tokens (§1, §2)
  components/                # Flat presentational components (§3)
  screens/                   # Home/Detail/Consensus/Market/Upgrade/Wallpapers/...
  services/                  # chat.ts (ROUTES), consensusView.ts, supabase.ts, fal.ts, …
  legal.ts, tips.ts, skills.ts, motion.tsx, features.tsx
docs/design/                 # Fable's handoff (.dc.html, HANDOFF-SPEC.md) — SOURCE OF TRUTH
docs/DESIGN_OVERHAUL_*.md    # DesignCode Figma kit overhaul spec (CANONICAL)
figma/                       # MCP server guide + figma-power skills
figma-code-connect/          # Code Connect skill + references (api.md, advanced-patterns.md)
scripts/tests/               # Node test runner suites (*.test.mjs)
```

**Feature organization:** Screens compose components; shared state via
`useCollider()`; services are pure-ish modules called from screens/components.
No feature-folder modules (no `features/foo/{components,hooks}`); it's a flat
`components/` + `screens/` split.

**Consensus map (special):** Rendered as a **full-screen** HTML string
(`consensus-scene-template.ts` → `CONSENSUS_SCENE_HTML`) inside an
`iframe` (`ConsensusScene.tsx`) on web; native uses `layoutByMatches` from
`services/consensusView.ts`. This is the one place real CSS/HTML lives — Figma
map nodes must be translated into that HTML template's DOM/CSS, not RN.

---

## 9. MCP / Figma Workflow Rules (operational)

1. **Connect:** Figma MCP at `https://mcp.figma.com/mcp` (VS Code: `MCP:Add Server` → `figma`). Rate-limited by plan.
2. **Source of truth:** `DesignCode UI - Figma Design UI Kit & Design System (Community).fig` is THE design source per the overhaul spec. Pick kit elements by **fit**, ignore their labels.
3. **Code Connect:** For published kit components, map via `.figma.ts`
   (`figma-code-connect` skill). Add `@figma/code-connect/figma-types` to
   `tsconfig.json` `types`. Requires Org/Enterprise + published library.
4. **Translate, don't paste:** Figma → RN primitives using §7 table. Reuse
   `Glass`/`Sheet`/`PressableScale`/`ModelCard`.
5. **Physical realism mandate:** every interaction needs real motion
   (`PressableScale`, `FadeUp`, `Floaty`, `Shimmer`); panes blur the
   background (DoF) when forward; lips open drawers left-to-right.
6. **No-numbers / no-noise:** do not introduce counts or non-label numbers
   into the UI (overhaul rule).
7. **Validate:** `expo start --web` + Playwright (`playwright.config.ts`) for
   visual checks; `npm run typecheck` + `npm test` before done.
8. **Tokens:** every color/radius/easing comes from `theme.ts` (`T.*`,
   `RADIUS.*`, `EASING.*`). No new hardcoded rgba.

---

## 10. Settled decisions that block Figma drift

- Fonts: Instrument Sans + IBM Plex Mono only; no 800/900 synthetic weight.
- One glass system everywhere; model colors as glows not fills.
- Secondary surfaces = `Sheet` panels, never full-screen routes (except Settings gear).
- Consensus map = full-screen; labels are model `short` codes (`models.ts`).
- `metro.config.js` is load-bearing — never remove.
- No `babel.config.js` for Reanimated — `babel-preset-expo` auto-injects worklets.
