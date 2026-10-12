# Collider component catalog

Generated 2026-10-08 from the reference material in `P:\My Drive\Collider Documentation`
plus the exported frames the customer supplied.

> This document records **where each primitive came from**. The customer's 27
> references and what each one was pointed at are in
> [REFERENCE-MAP.md](REFERENCE-MAP.md), grouped by Collider surface.

## The rule

The references are **many different design systems**: Vision OS Design System,
wechat vision os, Vision Pro Spatial UI Kit, Prime Video visionOS, Frosted Micro,
Nimo Spatial OS, Spatial UI/UX, plus Cosmos (a flat iOS app). Reproducing each one
faithfully and separately is how an app ends up looking like fifteen apps.

So: **one kit.** For each primitive, one instance is canonical. Its provenance is
recorded. Every surface uses it. An older per-surface value is a migration, not an
exception. We do not need an export of each reference's exact instance of a fade —
we need the best one, applied everywhere.

Canonical values live in `lib/core/kit/collider_kit.dart`. That file is the contract;
this document is the reasoning.

## Provenance keys

| Key | Source |
|---|---|
| **VOS** | Vision OS Design System (Community) |
| **VPU** | **Vision Pro UI Kit WIP 1.0.4 (Community)** — supplied 2026-10-08, the app-shell reference |
| **WCH** | wechat vision os (Community) |
| **VPK** | Vision Pro Spatial UI Kit (Community) |
| **PQ** | Prime Video visionOS (Community) |
| **FMK** | Frosted Micro UI Kit |
| **RN** | Reference Native — already transcribed into this repo from these nodes |
| **COS** | Cosmos iOS (flat phone app, the port target) |

> **VPU is the shell, not a widget library.** Two zips: one is 5 large 4920×3180
> renders (App Store, Music App, Photos App, Keynote, Menu) and the other 4 small
> white-on-transparent shape masks (Tab, Left menu, Search, Menu Tabs). The small
> files are reusable *shapes* only — a 1104×191 pill with a soft drop shadow, a
> 204×1095 vertical pill, a full-bleed 2442×120 bar. No new tokens in them.
>
> The renders are worth more: they are the canonical **app shell** — every one of
> the five is the same three parts. That shell is what makes visionOS look like
> visionOS, and it is the one thing the earlier landscape Figma frames never
> showed in isolation.

---

## 1. Glass — the substrate

R36: *"visionOS glass: blur or tint separates planes, specular rim."* D8 agrees.
Glass is the whole visual language, so it gets exactly one definition.

| Token | Canonical | Provenance | Note |
|---|---|---|---|
| `glassFill` | `rgba(128,128,128,0.30)` | VOS, RN `FGlass` | Already shipping |
| `blurWindow` | 50 (CSS) | RN `FGlass` | CSS radius; Flutter sigma = N/2 × scale |
| `blurMenu` | 20 (CSS) | RN `GlassMenu` | |
| `blurOrnament` | 28 | RN `VMaterial.elevated` | Dock / floating chrome |
| `rim` | `rgba(255,255,255,0.40)` | RN `FRail`, 1.4px | Load-bearing rims only |
| `rimHairline` | `rgba(255,255,255,0.15)` | derived | **Preferred** for floating planes |

### The border rule (this one was wrong)

A hard 1px pure-white outline on a floating card is **card chrome**, which R08
forbids on the ticker and which reads cheap everywhere else. Removed from
`GlassMenu`. Plane separation is tint + blur first; a rim only catches a specular
edge. If a surface genuinely needs an edge, it uses `rimHairline`, not `rim`.

`FGlass.stroke` still exists for genuine window chrome (the alert, PQ's card),
where the rim is doing real work. Do not add it to decorative planes.

## 2. Elevation

One five-step scale (RN `SpatialDepthPlane`, collapsed to the steps actually used):

| Level | Fill | Blur | Rim | Shadow |
|---|---|---|---|---|
| base | transparent | 0 | — | none |
| resting | `1EFFFFFF` | 24 | 18% | `0.22 / 32 / y12` |
| elevated | `24FFFFFF` | 28 | 24% | `0.28 / 40 / y16` |
| modal | `28FFFFFF` | 32 | 28% | `0.32 / 48 / y20` |
| workSurface | `2CFFFFFF` | 36 | 32% | `0.36 / 56 / y24` |

**base is transparent on purpose** — R36 says the wallpaper stays visible at rest.
Nothing at rest may tint the wallpaper.

## 3. Radii

| Token | Value | Provenance |
|---|---|---|
| `radiusWindow` | 24 | RN `GlassMenu` |
| `radiusCard` | 20 | RN cards / PQ alert |
| `radiusControl` | 12 | RN inputs |
| `radiusThumbnail` | 10 | RN cover + thumb |
| pill / circular | `radius = height / 2` | VOS tab bars, WCH |

Never declare a radius at a call site.

## 4. Controls

| Token | Value | Provenance |
|---|---|---|
| `controlCircle` | 44 | RN `PermanentNavBar`, `FRail` |
| `controlIcon` | 24 | RN `FRail` |
| `selectedDisc` | `2EFFFFFF` + `#5E5E5E` 18% | RN `FRail` |
| `iconIdleOpacity` | 0.4 | RN `FRail` |
| `dockItems` | **3** | R11 / Surfaces — Compose, Settings, Apps |
| `dockWidth` | derived = 156 | never hardcode the sum |

**The dock is three, not five.** R11 and the Surfaces contract both say
Compose (also Home) · Settings · Apps. An earlier five-tab proposal was wrong.

## 5. Input & menu

| Token | Value | Provenance |
|---|---|---|
| `inputHeight` / `inputRadius` | 50 / 12 | RN market search |
| `menuRowHeight` / `menuRowGap` | 40 / 4 | RN `GlassMenu` |
| `menuPad` / `menuWidth` | 16 / 240 | RN `GlassMenu` |

`GlassMenu.heightFor(n) = 32 + n·40 + (n−1)·4`. The 32 is the 16px padding each
side. There is **no border term** — the card has no outline (see §1).

## 6. Motion

D8/R36: **spring, not particles.** Two durations only, so motion reads as one system.

| Token | Value |
|---|---|
| `motionFast` | 160 ms |
| `motionBase` | 280 ms |
| `motionEase` | `cubic-bezier(0.4,0,0.2,1)` |
| `motionEmphasised` | `cubic-bezier(0.23,1,0.32,1)` |

## 7. Type

D11: **"type comes from the visionOS set."** Manrope lost.

- **UI: Inter** (RN `FText` / `FTextStyle` — already every Figma surface).
- **Display: Cormorant Garamond + Instrument Sans** (RN `spatial_theme.dart`),
  for headings and hero prompts only.

The rule that matters: **one surface uses one pairing.** Never Inter body with a
Cormorant heading in the same window.

## 8. The app shell (VPU) — the structural one

This is the part every earlier reference left implicit. All five VPU renders are the
same composition, and the composition is what we are copying:

1. **Window** — a large rounded rect holding one app, sitting in the environment.
   Content clips at the window edge (the App Store's "Get Started" row is cut
   mid-card, which is correct — not a layout bug).
2. **System rail** — a short translucent pill of 6 icons that floats **outside** the
   window, to its left, vertically centred against the window (not the screen).
3. **Transport bar** — Music only: a wide pill that floats at the window's bottom
   edge and **straddles** it, half inside the window, half outside.

Rule that falls out of this, and the reason it matters for phone portrait: **floating
chrome belongs outside the window's bounds.** A window is opaque-edged and clips its
content; the rail and the transport bar are siblings of the window, not children. In
portrait the rail collapses to the top edge and the transport bar to the bottom, but
they stay *outside* the content rect so the content never has to reserve padding for
them.

Where we already match: `FRail` is this rail. `apps_popup_pane.dart` is this Menu
render (4 columns, 3 rows, odd rows offset by half a pitch, circular full-colour
icons, Inter Medium 12 labels).

Where we diverge deliberately: the VPU Menu render puts **Settings in the app grid**.
Our contract puts Settings on the Dock (R11 / Surfaces). PRD beats reference, so
Settings stays out of the platter and the grid is 7 apps.

### Card grid (VPU Music, App Store)

| Token | Value | Note |
|---|---|---|
| `gridColumns` | 4 | landscape scene; portrait uses 2 |
| `cardArtRadius` | `radiusThumbnail` (10) | square art, not a crop strip (R32) |
| `cardTitle` / `cardSubtitle` | 17 / 15, w600 / regular | title above, source below |

---

## Component inventory — what each reference actually offers

| Reference | Usable components | Adopted? |
|---|---|---|
| **VOS** Tab Bars | Vertical pill rails, icon-only and icon+label, selected pill, N=2–8 | **Yes** — `controlCircle`, `selectedDisc`, rail pitch |
| **VOS** Window Controls | Window chrome + close, pill menu rows, state colours (orange record, green shared) | **Yes** — menu rows, close affordance |
| **VOS** Media Controls & Play Bar | Play bar + scrub | Partial — video playback surface only |
| **VOS** Canvas | Canvas / board chrome | For Smart Gen |
| **VOS** Notifications, Temporary Notices | Toast + notice | **Yes** — notice pattern |
| **VOS** Property Page, Home Screen, Map View, Share Sheet, Pickers, Side Bar | Full surfaces | Reference only |
| **WCH** IMAGE (2610×1468) | Ticker: collapsed-answer column, opened-answer window, consensus row | **Yes** — map row 15 frame |
| **WCH** FRIENDS / LIST / VIOCE CHAT | List rows, chat bubbles | **Yes** — row rhythm, tailed bubbles |
| **VPK** | Files rail, Theme Gallery window, depth/blur | **Yes** — rows 5–7 |
| **PQ** | Alert card, premium market | **Yes** — row 22 |
| **FMK** | Frosted micro components, light-emissive icons | Reference only — the emissive icons clash with "no glitter" (D8) |
| **Nimo** | Smart Gen kanban | **Yes** — rows 23–25 |
| **COS** | Flat iOS masonry + tab bar | **Layout reference for phone portrait only** — not its glass |

---

## Genuinely novel — would need an export

Nothing is blocking today. These would be worth an export if we hit them:

1. **Ticker bottom-window anchoring.** The WCH frame gives us a *centred* window.
   R08 wants a *bottom* window. That's new geometry, not a re-measure — I'll derive
   it from `Kit.tickerMaxHeight` / `Kit.tickerWidth`.
2. **Portrait-specimen frames.** Every VOS frame is a landscape scene. If anyone
   has true phone-portrait mockups of these components, those would save a round.

## Migration points (old value → kit)

| File | Was | Now |
|---|---|---|
| `vision_kit.dart` `GlassMenu` | `Border.all(white, 1)` | none; `heightFor` back to 32 |
| `f_rail.dart` | inline 76/44/69/1.4 | `Kit.controlCircle` etc. |
| `figma_stage.dart` `FGlass` | `4D808080`, blur 50 | `Kit.glassFill`, `Kit.blurWindow` |
| `windowless_theme_scroller.dart` | `FilterQuality.medium` | `.high` (retina) |
| `spatial_theme.dart` | 6 depth planes | `Kit.elevation*` (5, base transparent) |

## Still to rule on

- `living_stardust_overlay.dart` — D8/R36 say **no particles**. Needs a decision:
  delete, or keep strictly behind the wallpaper where it reads as scene content
  rather than UI chrome.
- `ambientTracks` is empty, so R30's "≥5 tracks per wallpaper" is unmet and the
  Music Player app is hidden from the platter.