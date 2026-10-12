# REDESIGN IMPLEMENTATION PLAN

**Product:** Collider (proposed rename → see §C)
**Mode of execution:** Code mode (this file is the source-of-truth brief)
**Date authored:** 2026-08-07
**Author:** Architect mode (planning only — no source files were modified)

---

## 0. Inputs Read

| File | Purpose | Local ref |
| --- | --- | --- |
| `docs/design/HANDOFF-SPEC.md` | Primary design spec ("uidesign.md") | docs/design/HANDOFF-SPEC.md:1 |
| `docs/SPEC.md` | Broader product spec | docs/SPEC.md:1 |
| `collider (1).html` | Visual & interaction reference | collider (1).html:1 |
| `design_handoff_collider_redesign/README.md` | Redesign package overview | design_handoff_collider_redesign/README.md:1 |
| `design_handoff_collider_redesign/ios-frame.jsx` | iOS motion/layout primitives | design_handoff_collider_redesign/ios-frame.jsx:1 |
| `design_handoff_collider_redesign/support.js` | Reducer / animator library | design_handoff_collider_redesign/support.js:1 |
| `design_handoff_collider_redesign/Collider Redesign.dc.html` | Doubloon design canvas | design_handoff_collider_redesign/Collider Redesign.dc.html:1 |
| `App.tsx` | Current app root (4470 lines) | App.tsx:1 |
| `src/styles/theme.ts` | Current token sheet | src/styles/theme.ts:1 |
| Components under audit | See §E | n/a |

**Conflict resolution rule** (per user): if `HANDOFF-SPEC.md` and `collider (1).html` disagree, the spec wins and the conflict is flagged in §H.

---

## A. Aesthetic Extraction

### A.1 Color tokens (target — from `collider (1).html` + redesign)

| Token | Value | Usage |
| --- | --- | --- |
| `surface.base` | `#0A0814` | Deep purple-black app canvas |
| `surface.raised` | `#14101F` | Glass card bases |
| `surface.raisedHi` | `#1B1528` | Pressed/highlighted surfaces |
| `surface.scrim` | `rgba(8,5,16,0.72)` | Drawer/sheet scrim |
| `surface.divider` | `rgba(255,255,255,0.06)` | Hairlines |
| `accent.violet` | `#9D6BFF` | Primary CTA gradient stop A |
| `accent.violetHi` | `#B98CFF` | Top highlight of CTA gradient |
| `accent.magenta` | `#E54CFF` | Secondary gradient stop |
| `accent.cyber` | `#5BE9FF` | Cool accent / pressed glow |
| `accent.lime` | `#C8FF5E` | Consensus check, ready state |
| `accent.amber` | `#FFB547` | Live indicator, streaming |
| `accent.rose` | `#FF5C8A` | Error / destructive |
| `text.primary` | `#F4F1FF` | High-contrast headline |
| `text.secondary` | `rgba(244,241,255,0.74)` | Body |
| `text.tertiary` | `rgba(244,241,255,0.50)` | Meta / captions |
| `text.disabled` | `rgba(244,241,255,0.32)` | Disabled |
| `glass.border` | `rgba(255,255,255,0.08)` | Glass strokes |
| `glass.inner` | `rgba(255,255,255,0.04)` | Inner highlight |
| `glass.shadow` | `0 8px 32px rgba(0,0,0,0.45)` | Surface elevation |
| `glow.violet` | `0 0 24px rgba(157,107,255,0.45)` | CTA bloom |
| `glow.cyan` | `0 0 18px rgba(91,233,255,0.35)` | Streaming/active |

### A.2 Typography

| Role | Family | Weight | Size | Tracking |
| --- | --- | --- | --- | --- |
| Display | SF Pro Display / system | 700 | 32 | -0.02em |
| Title | SF Pro Display | 600 | 22 | -0.015em |
| Body | SF Pro Text | 400 | 15 | 0 |
| Body Strong | SF Pro Text | 600 | 15 | 0 |
| Caption | SF Pro Text | 500 | 12 | 0.04em |
| Mono | SF Mono / Menlo | 500 | 13 | 0 |

(Use `Fonts.system()` fallback — no custom font file required for v1 unless a redesign-package font is added; flag in §H.)

### A.3 Radii / Shadow / Motion

- Radii: `8 / 12 / 16 / 20 / 28` (surface tiers); buttons `999` (pill), sheet top corners `28`.
- Shadow spec for glass surfaces: `0 1px 0 ${glass.inner} inset, 0 1px 0 ${glass.border}, 0 12px 36px rgba(0,0,0,0.55)`.
- Motion durations (ms): `120` press, `220` drawer, `260` sheet, `420` scene rebuild, `800` hero bloom.
- Easings: `cubic-bezier(0.22, 1, 0.36, 1)` for springs, `cubic-bezier(0.4, 0, 0.2, 1)` for material.
- Spacing scale (px): `4 8 12 16 20 24 32 40 56 72`.

### A.4 Component vocabulary

- **Glass surfaces** — subtle inner highlight stroke + 1px hairline border + drop-shadow above.
- **Pressed primary CTA** — vertical gradient `accent.violetHi → accent.violet`, 1px inner `rgba(255,255,255,0.28)` sheen, soft `glow.violet` while pressed/active.
- **Secondary button** — translucent `surface.raisedHi` surface, hairline border, white text.
- **Destructive button** — `accent.rose` gradient, same shape language.
- **Badge / chip** — pill 999 radius, 12px caption, `rgba(157,107,255,0.18)` bg, hairline.
- **Wordmark** — SF Pro 700; a small monochrome "◐" glyph prefix, display weight, breathing-room `letterSpacing: 0.04em` for caption use.
- **Avatar tiles (model cards)** — square 12-radius, 1px accent-tinted border per provider, 8% accent inner glow on hover.

### A.5 Asset-style rules

- **Iconography** — line icons, 1.5px stroke, rounded line caps (see redesign `ios-frame.jsx` icon factory).
- **Primary CTAs** — pill buttons, gradient fill, on-press transform `scale(0.97)`.
- **Screen headings** — left-aligned, 32/22 display + title, with thin (`surface.divider`) underline of `paddingTop + 8` height.
- **Drawer / sheet** — top-rounded 28, scrim `surface.scrim`, scrolling content uses `surface.base` with 1px hairline above the handle.

---

## B. Delta Analysis (current `src/` vs target)

### B.1 At-a-glance gaps

| Area | Current (`src/`) | Target | Action |
| --- | --- | --- | --- |
| Wordmark | `src/components/Wordmark.tsx` (47 lines, monogram + "COLLIDER" letter-spaced) | Friendly 22pt wordmark with small glyph | See §C.5 rename + §E.P1 |
| Theme tokens | `src/styles/theme.ts` (1 big `StyleSheet.create`; mixed hex/rgba + hardcoded Tailwind-style colors) | Centralized typed token tree (colors / type / radius / space / motion / shadows) | Rewrite §D |
| Background | `App.tsx` wraps in linear gradient `['#0b0a14','#0d0b1f']` pulled from inline `theme.ts` background tokens | Stays gradient but driven by token names that match the redesign palette | Adjust palette in `theme.ts` and re-bind gradient in `App.tsx` |
| Glass surfaces | `Glass.tsx` uses `surface.card`, `border.subtle`, hard-coded hex | Migrate to token-based glass (`glass.surface`, `glass.border`) | §E.P0 |
| Buttons | `GlossButton.tsx`, `GlossSurface.tsx`, `CollideButton.tsx` all use bespoke gradients | Converge on a single `<PrimaryButton>` per §E.P0 | §E.P0 |
| Consensus scene | `ConsensusScene.tsx` + `consensus-scene-template.ts` are fully procedural (chevrons/diamond/snap) | Keep logic but apply new palette + tokenized radii | §E.P1 |
| Drawer/sheet | `ConsensusDrawer.tsx`, `Sheet.tsx` use older backdrop opacity & radius | Adopt redesign scrim + radius | §E.P1 |
| Panels | `WallpaperPanel.tsx`, `ModelCard.tsx` use `surface.base/raised/raisedHi` directly | Replace with token accessors | §E.P1 |
| Toast | `Toast.tsx` uses `colors.danger`, plain background | New "Sent/Error" pastel chip on translucent surface | §E.P2 |
| Press affordance | `Press.tsx` is a thin wrapper | No visual change to component; ensure consumers use token-driven colors | §E.P2 |
| Asset references | `assets/ui/brain_icon_v*` and `collide_btn_v*` referenced in `CollideButton.tsx` and `Wordmark.tsx` | See §F (keep `brain_icon_v5.png` + `collide_btn_final.png`; replace red-tinted chrome with chrome icon) | §F |
| Renaming | "Collider" hard-coded in `Wordmark.tsx`, `app.json`, `package.json`, `eas.json` and at least `App.tsx` chrome | Rename per §C | §C |

### B.2 Per-file deltas (top-down component tree)

| File | Lines | Concrete gap | Priority |
| --- | --- | --- | --- |
| `App.tsx` | 4470 | Root background gradient + status bar; uses inline hex tokens; brand copy "Collider" hard-coded | P1 |
| `src/styles/theme.ts` | 917 | Single mega-StyleSheet; no typed token tree; inconsistent radii | P0 |
| `src/components/Glass.tsx` | ~58 | Hard-coded `#FFFFFF` alpha, `surface.card` | P0 |
| `src/components/GlossSurface.tsx` | 38 | `colors.gold` references | P1 |
| `src/components/GlossButton.tsx` | 38 | Single gradient button variant only | P0 |
| `src/components/CollideButton.tsx` | 211 | Uses `assets/ui/collide_btn.png` & PNG icons | P1 |
| `src/components/CollideBanner.tsx` | 308 | Status banner styling | P1 |
| `src/components/ConsensusScene.tsx` | ~106 | Pure-procedural geometry; colors literal | P1 |
| `src/components/ConsensusDrawer.tsx` | 736 | Sheet chrome/radius/scrim hard-coded | P1 |
| `src/components/ModelCard.tsx` | ~429 | Card surface + provider color literal | P1 |
| `src/components/WallpaperPanel.tsx` | 124 | Uses `surface.base` literal in inline | P1 |
| `src/components/Sheet.tsx` | 167 | Top radius 28 already; tweak scrim | P1 |
| `src/components/Page.tsx` | 57 | Status-bar + safe-area, no visual change needed | P2 |
| `src/components/Wordmark.tsx` | ~98 | "COLLIDER" letter-spaced caps + monogram; brand copy | P0 |
| `src/components/Press.tsx` | ~207 | Generic wrapper, no visuals | P2 |
| `src/components/Toast.tsx` | ~107 | Pastel chip redesign | P2 |
| `src/screens/*.tsx` (11 screens) | — | All screens render `Page`; visually verified when components above are unified | P2 |

### B.3 Assets reconciliation (preview; full plan in §F)

- `assets/ui/brain_icon_v5.png` — keep as-is; matches redesign.
- `assets/ui/collide_btn_final.png` — keep; matches redesign.
- `assets/ui/collide_core_final.png` — keep for consensus hero.
- `assets/ui/smartgen_brain.png` + `smartgen_brain_chrome.png` — keep both; wire to `LockedVeil.tsx` for upsell screen.
- Older `_v1`–`_v4` icons and `core_v1.png` — archive under `assets/ui/_legacy/` (do not delete — preserve for diffing).

---

## C. Renaming / Branding Plan

> Brand name decision from `docs/design/HANDOFF-SPEC.md` is the canonical "uidesign.md". If the spec has not yet chosen a final name, default to the placeholder **"Synapse"** (used below). The user can replace `Synapse` with whatever the spec commits to; the diff in the rename pass becomes a one-shot, name-only find-and-replace.

### C.1 `app.json`

| Field | From | To |
| --- | --- | --- |
| `expo.name` | `"Collider"` | `"Synapse"` |
| `expo.slug` | `"collider"` | `"synapse"` |
| `expo.scheme` | `"collider"` | `"synapse"` |
| `expo.splash.backgroundColor` | `"#07040d"` | `"#0A0814"` |
| `expo.android.adaptiveIcon.backgroundColor` | `"#07040d"` | `"#0A0814"` |
| `expo.ios.bundleIdentifier` | `"app.collider.native"` | `"app.synapse.native"` |
| `expo.android.package` | `"app.collider.native"` | `"app.synapse.native"` |

(Must stay lowercase, dot-separated bundle IDs per Apple/Google policy.)

### C.2 `package.json`

| Field | From | To |
| --- | --- | --- |
| `name` | `"collider-expo-native"` | `"synapse-expo-native"` |
| `description` | `"..."` (replace with the user-supplied 1-liner from spec) | — |

### C.3 `eas.json`

| Field | From | To |
| --- | --- | --- |
| `cli.version` | unchanged | unchanged |
| `submit.production.ios.appIdentifier` (if present) | `app.collider.native` | `app.synapse.native` |
| `submit.production.android.applicationIdentifier` (if present) | `app.collider.native` | `app.synapse.native` |

### C.4 `.env.example`

- Existing keys (`GOOGLE_CLIENT_ID_IOS`, `GOOGLE_CLIENT_ID_ANDROID`, `GOOGLE_CLIENT_ID_WEB`, `REVENUECAT_PUBLIC_SDK_KEY`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, etc.) keep their semantic names — do **not** prefix with the brand name (avoids breaking Supabase / RevenueCat backends).
- Add one comment header: `# Synapse (formerly Collider) — env. Names kept for backend compatibility.`

### C.5 Hard-coded copy

| File | Text | Replace with |
| --- | --- | --- |
| `src/components/Wordmark.tsx` | "COLLIDER" (letter-spaced caps) | "Synapse" (Title-case, normal tracking — see §E.P0) |
| `App.tsx` | "Collider" / "COLLIDER" references in banners | "Synapse" |
| `src/screens/*.tsx` | Banner copy | TBD by spec; do a textual audit pass during code-exec |

**Backward-compatible note:** keep technical IDs (`bundleIdentifier`, `applicationIdentifier`, scheme path) rename-safe by adding the new values **alongside** the old in a single commit with a migration note in `docs/LAUNCH_CONFIG.md`. Apple's "same bundle ID" requirement is preserved by leaving the old IDs as aliases during the App Store transition window if/when the brand changes again.

---

## D. Theme & Token Migration

### D.1 Target structure of `src/styles/theme.ts`

```
// pseudo
export const tokens = {
  surface: { base, raised, raisedHi, scrim, divider },
  accent:  { violet, violetHi, magenta, cyber, lime, amber, rose },
  text:    { primary, secondary, tertiary, disabled },
  glass:   { border, inner, shadow, glow: { violet, cyan } },
  radii:   { sm: 8, md: 12, lg: 16, xl: 20, xxl: 28, pill: 999 },
  space:   [4,8,12,16,20,24,32,40,56,72],
  type:    { display, title, body, bodyStrong, caption, mono },
  motion:  { duration: { press, drawer, sheet, scene, hero },
             easing: { spring, material } },
  z:       { navBar: 50, sheet: 80, toast: 90, modal: 100 },
};
export type Tokens = typeof tokens;
export const theme = tokens;
export const t = tokens; // convenience alias
export const SPACING = tokens.space;
export const RADIUS  = tokens.radii;
export const FONTS   = tokens.type;
export const COLORS  = { ...tokens.surface, ...tokens.accent, ...tokens.text };
```

### D.2 What stays in StyleSheet blocks

Only **composite** `StyleSheet.create` definitions belong near the component (e.g., `<ScreenContainer>` paddings). Every color/radius/space literal in any other component file is replaced with `theme.*` references.

### D.3 Migration mapping table (excerpt)

| Old (current `theme.ts`) | New token |
| --- | --- |
| `colors.bg` (`#0b0a14`) | `tokens.surface.base` |
| `colors.bg2` (`#0d0b1f`) | `tokens.surface.raised` |
| `colors.card` (`#11101f`) | `tokens.surface.raised` |
| `colors.text` (`#e6e3ff`) | `tokens.text.primary` |
| `colors.muted` (`#8a87a6`) | `tokens.text.secondary` |
| `colors.subtle` (`#aea9c4`) | `tokens.text.tertiary` |
| `colors.danger` (`#f8578a`) | `tokens.accent.rose` |
| `colors.gold` (`#f4d27a`) | `tokens.accent.amber` |
| `radius.lg` | `tokens.radii.lg` |
| (all `space*.`) | `tokens.space[i]` |

### D.4 What changes vs current

- One exported `tokens` object (deep-frozen) replaces ~15 separate const exports.
- `StyleSheet` blocks in `theme.ts` shrink to **only** structural styles (no raw colors).
- All components import `theme` and reference it inline (no prop drilling).

---

## E. Component Remediation List

> Order = top-down in the render tree. Each row: file → issue → change → priority.

### P0 — must land first

1. `src/styles/theme.ts` — see §D. Rewrite into `tokens` tree.
2. `src/components/GlossButton.tsx` — replace bespoke gradient with `<PrimaryButton>` that uses `tokens.accent.violentHi → violet` and `tokens.glow.violet` on press.
3. `src/components/Glass.tsx` — pull `glass.surface`, `glass.border`, `glass.inner`, `glass.shadow` from `tokens`. Drop hard-coded `#FFFFFF` `rgba(255,255,255,0.06)` etc.
4. `src/components/Wordmark.tsx` — new copy ("Synapse"), small `◐` glyph prefix; remove "COLLIDER" 1px-stroke rendering. Use `tokens.text.primary`.

### P1 — surfaces, scene, drawer, panels

5. `src/components/GlossSurface.tsx` — replace `colors.gold` refs with `tokens.accent.amber`; keep geometry.
6. `src/components/CollideButton.tsx` — confirm `collide_btn_final.png` is used; remove legacy `collide_btn.png` reference; add `<PrimaryButton>`-style gradient fallback if the PNG is missing.
7. `src/components/CollideBanner.tsx` — convert color literals to `tokens`; swap live dot to `tokens.accent.amber`.
8. `src/components/ConsensusScene.tsx` + `consensus-scene-template.ts` — move every literal hex in scene template to `tokens`; ensure check state uses `tokens.accent.lime`.
9. `src/components/ConsensusDrawer.tsx` — sheet chrome radius `tokens.radii.xxl`, scrim `tokens.surface.scrim`, internal padding `tokens.space[4]`.
10. `src/components/Sheet.tsx` — same radius/scrim parity.
11. `src/components/ModelCard.tsx` — border tokens per provider (5-provider map in §F.3), background `tokens.surface.raised`, on-hover/press add `tokens.glow.violet`.
12. `src/components/WallpaperPanel.tsx` — overlay color from `tokens.surface.scrim` (replaces ad-hoc `rgba(0,0,0,0.35)`).
13. `App.tsx` — root gradient bound to `tokens.surface.base → tokens.surface.raised`; status bar `light-content`; update brand copy.

### P2 — polish, screens, low-impact

14. `src/components/Press.tsx` — no visual change required, but audit callers to ensure no literals leak in.
15. `src/components/Toast.tsx` — adopt chip pill, error uses `tokens.accent.rose` at 18% bg, hairline border.
16. `src/screens/*.tsx` (11 screens) — render audit only; no logical changes expected.

---

## F. Asset & Wallpaper Plan

### F.1 `assets/ui/`

- Keep: `brain_icon_v5.png`, `collide_btn_final.png`, `collide_core_final.png`, `smartgen_brain.png`, `smartgen_brain_chrome.png`.
- Archive (move to `assets/ui/_legacy/`, do NOT delete): `brain_icon_v2.png` … `v4.png`, `collide_btn.png` … `v5.png`, `collide_core_v1.png`.
- Do not introduce new icon files in this pass. Reuse redesign-package SVGs transcribed into a future `src/components/icons/` only if a Code-mode pass needs vector precision; otherwise, stay on `brain_icon_v5.png`.

### F.2 `assets/themes/free/` and `assets/themes/premium/`

- All wallpapers retained.
- CSS overlays currently applied in `WallpaperPanel.tsx` are pulled into `tokens` as `tokens.surface.scrim` and `tokens.surface.raised`.
- The premium video MP4s and audio MP3s are unmodified.

### F.3 Provider color map (`ModelCard.tsx`)

| Provider | Token | Hex |
| --- | --- | --- |
| OpenAI | `tokens.accent.cyber` | `#5BE9FF` |
| Anthropic | `tokens.accent.rose` | `#FF5C8A` |
| Google | `tokens.accent.violet` | `#9D6BFF` |
| xAI (Grok) | `tokens.accent.amber` | `#FFB547` |
| Meta | `tokens.accent.lime` | `#C8FF5E` |

(If a sixth provider is added later, fall back to `tokens.surface.raised`.)

### F.4 From `design_handoff_collider_redesign/`

- Do not import the redesign folder wholesale; treat as a visual reference.
- Pull `support.js` reducer patterns only if `consensus-scene-template.ts` needs motion refactors beyond the token pass.
- Pull `ios-frame.jsx` only as a *documentation* of motion / radii — the React Native port of those primitives already lives in `src/motion.tsx` and `src/components/Page.tsx`.

---

## G. Verification Checklist for Code Mode

### G.1 Visual (against `collider (1).html` reference)

- [ ] App background gradient matches reference.
- [ ] All CTAs gradient + glow consistent.
- [ ] Sheet scrim + radii match reference top corners.
- [ ] Wordmark correct shape and copy.
- [ ] ModelCard provider tints match the map in §F.3.
- [ ] ConsensusScene check state uses lime accent.
- [ ] Toast chips pill-shaped.

### G.2 Functional

- [ ] Every screen reachable from the nav renders without color regressions.
- [ ] Press affordance still triggers `onPress` with haptic.
- [ ] Drawer open/close animations land within ±10ms of the new durations.
- [ ] Wallpapers still selectable; `setWallpaper` persists.

### G.3 Naming (post-rename)

- [ ] `grep -ri "Collider" --include="*.tsx" --include="*.ts" --include="*.json" --include="*.md" src/ App.tsx app.json package.json eas.json` returns **0 hits** in user-facing artifacts (CSS classes / bundle identifiers exempt).
- [ ] All bundle IDs migrated (App Store Connect + Google Play pending; tracked separately).

### G.4 Build / test

- [ ] `npm install` clean.
- [ ] `npm run start` (Expo) launches the redesigned bundle without redbox.
- [ ] `npm test` (Jest config present) green — at minimum [`__tests__/App.test.tsx`](__tests__/App.test.tsx:1) still mounts.
- [ ] `npx playwright test` (if quick) green for `tests/example.spec.ts`.
- [ ] TypeScript: `tsc --noEmit` returns 0 (with the new `theme.ts` typed surface).

---

## H. Risks / Open Questions

### H.1 Risks

- **Asset fallback drift**: If `assets/ui/brain_icon_v5.png` is later swapped, the legacy archive in `assets/ui/_legacy/` is the only place to roll back to. Keep that directory intact across releases.
- **Bundle ID rename in the wild**: Apple's and Google's store configs do not accept in-place bundle ID changes. Plan a "new listing, deprecate old" product decision; for v1, do **not** flip the bundle IDs in `app.json` until the App Store decision is signed off (see Open Questions).
- **Supabase row relationships**: nothing in `supabase/migrations/` references "Collider" by name, so the rename is safe at the DB layer. **Verify** with `git grep collider supabase/` before merging.
- **IAP product IDs**: `src/services/iap.ts` may reference products like `collider_pro_monthly` — these IDs are App Store Connect objects and **cannot be renamed** without a new IAP product. Keep them as `collider_pro_*` (technical ID) while the user-facing brand is "Synapse".
- **Wordmark styling**: Spec implies a hand-drawn wordmark. Until a designer ships it, this plan keeps `Wordmark.tsx` text-only with a glyph prefix. Flag if a designer-rendered SVG is expected to replace it.

### H.2 Open questions to confirm with user

1. **Final brand name** — is the placeholder "Synapse" accepted, or should we use the spec's literal decision?
2. **Should the bundle ID rename ship in v1**, or stage in a follow-up release? (Affects §C.1 / §C.3.)
3. **Custom font** — is the SF Pro fallback acceptable, or do you have a font asset from `design_handoff_collider_redesign/` to bundle? (Affects §A.2 and `expo-font` plugin.)
4. **Wordmark asset** — text-only acceptable for v1, or do you want a designer-provided SVG to replace `Wordmark.tsx`?
5. **Iconography** — ship line icons as a future `src/components/icons/` directory, or stay on PNGs?
6. **Old wallpaper assets** — keep all 17 free + 4 premium assets for the v1 launch?

### H.3 Backward compatibility summary

| Surface | Safe to rename | Notes |
| --- | --- | --- |
| Bundle IDs (`app.collider.native` → `app.synapse.native`) | Not silently | Requires App Store / Play Store decision |
| `package.json` `name` | Yes | Local-only effect; CI scripts must be re-checked |
| `expo.slug` / `expo.scheme` (`collider` → `synapse`) | Yes for scheme; slug affects deep links — coordinate with marketing |
| Supabase tables | Yes | No name collisions in migrations |
| RevenueCat / IAP product IDs | No | Keep as-is |
| Asset filenames (`assets/ui/*.png`) | No | Don't rename; only archive |

---

## I. Execution Order for Code Mode

1. **Rename files first** (`app.json`, `package.json`, `eas.json`, `.env.example`, `Wordmark.tsx`, root copy). Verify §C and §G.3.
2. **Rewrite `src/styles/theme.ts`** per §D. Ship as one PR; verify TS compiles.
3. **Token-migrate components in P0** (§E items 2–4).
4. **Token-migrate components in P1** (§E items 5–13) one file per commit for clean diff review.
5. **P2 polish** (§E items 14–16) and screen visual audit.
6. **Asset & wallpaper pass** (§F).
7. **Verification pass** (§G) and update `docs/PROGRESS.md` with the new milestone.

---

## J. Quick-Reference Map (file → change bucket)

| Bucket | Files |
| --- | --- |
| Rename | `app.json`, `package.json`, `eas.json`, `.env.example`, `src/components/Wordmark.tsx`, `App.tsx` |
| Theme | `src/styles/theme.ts` |
| Glass / Surface / Buttons (P0) | `src/components/Glass.tsx`, `GlossButton.tsx`, `Wordmark.tsx` |
| Scene / Drawer / Sheet (P1) | `CollideButton.tsx`, `CollideBanner.tsx`, `ConsensusScene.tsx`, `consensus-scene-template.ts`, `ConsensusDrawer.tsx`, `Sheet.tsx` |
| Cards / Panels (P1) | `ModelCard.tsx`, `WallpaperPanel.tsx`, `GlossSurface.tsx` |
| Polish (P2) | `Press.tsx`, `Toast.tsx`, `Page.tsx` |
| Screens — visual audit only | `src/screens/*.tsx` (11 files) |
| Assets | `assets/ui/_legacy/` archive + provider color map |

End of plan.
