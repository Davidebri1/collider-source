# Canonical Master Spec — Collider DesignCode Figma UI Kit Full Overhaul

> **STATUS: CANONICAL / SOURCE OF TRUTH.** This document persists the FINAL design overhaul
> spec for the Collider React Native (Expo) app, verbatim and in complete detail. It must
> NOT be lost, overwritten, summarized, or re-interpreted. Any agent or mode working on this
> overhaul MUST read this file first. The filename is unique and timestamped
> (`2026-08-10`) so it cannot collide with existing docs. See the pointer sections in
> [`AGENTS.md`](../AGENTS.md) and [`CLAUDE.md`](../CLAUDE.md).
>
> Creation date: 2026-08-10. Full spec follows verbatim below.

---

# Collider — DesignCode Figma UI Kit Full Overhaul Spec (Final, 2026-08-10)

The user has a `.fig` file in the project directory: `DesignCode UI - Figma Design UI Kit & Design System (Community).fig`. It is now THE design source. Every single UI element in the app must be replaced by an element from this Figma kit. Exceptions: proprietary/custom things — background images, and the consensus map itself — but ALL UI elements WITHIN the map must be swapped. This applies to Market and Smart Gen too. Do not pick kit elements by label; pick by potential, aesthetic, and functional fit. Ignore all labels. Approach it maximially open-minded. All kit elements are coded and fully integrated (animations built-in). The user can change button types and move them into better locations.

## Physical realism mandate
EVERY action against the UI must result in the physical equivalent of the real life action. Nothing in the app will exist outside of physical constraints. Use this opportunity to implement the smoothest animations ever seen. Speed isn't what drives fluidity — framerate/HZ does. Use Figma motion/implement-motion capabilities. Do not wing this project without proper Figma support (check/fix MCP if Figma skills don't show up).

## Main view
- No UI elements shown except small lips (Swift-style) at various bottom locations, opening drawers left-to-right. Each lip distinct in color/design twist.
- ALL panes are lips: History (click or slide-up), Prompt bar area, Model category pane, SmartGen Hub, Media. Each is a small Swift-style lip at a bottom location, distinct in color/design twist, opening its drawer left-to-right.

## Pane background blur (universal rule)
- When ANY lip is turned into its pane/drawer, the background gets a depth-of-field blur (physical realism — the background falls out of focus as the pane comes forward). This applies to ALL panes — History, Prompt bar area, Model category pane, SmartGen Hub, Media, and every other lip-turned-pane — not just Settings. The blur is part of the physical realism mandate: panes come forward, background falls out of focus.

## Prompt bar
- Centered. Autohides after 3–5 seconds after sending; redeploys on button press (fast but smooth). Keyboard hides immediately on send. Shorter/less tall. 2.5D strong drop shadow version. Depth-of-field blur on background when typing. Send button can stay if full white, else swap.

## Model category pane
- Light-emitted toggle indicators (off = light dissipates, on = light blooms). Sectioned by Free/Pro models (color/effect coded). Swipe between categories. Locked tiers show a lock over the whole area (not per-model). Free users can browse locked tabs but cannot click. Relock on subscription expiry.

## History pane
- Right of prompt area, not full height, scrollable, loadable on click. Has a consensus-history tab (hidden in card view).

## SmartGen Hub lip
- Small menu pane with full-width buttons, no icons: Smart Gen cards, Smart Gen boards, Smart Gen canvas, Smart Genie. First three are free tier; Smart Genie is an AI agent, pro tier, chat view, Canva/Figma-like assistant, toggleable in cards/boards/canvas views, minimizable. No coding unless elite; agents attachable at elite.

## Canvas
- Free drag-drop of cards/boards. Boards look like their names (notebook looks like notebook, portfolio looks like portfolio — the "word meaning" philosophy). Customizable backgrounds/scenes, up to 10 loadable, screen-swipe or numbered-icon navigation.

## Media pane
- Tabbed drawer with: Theme view (phone preview wallpapers, toggle to icon view, fullscreen expand); Premium Theme tab (separate marketplace gated by subscription to amplify FOMO, sells ONLY live wallpapers, seamless endless loop, 2k/4k, no camera movement, $3–8 USD bundled with 5 curated theme songs with previewable list); Files and Music player tab (music player widget draggable anywhere in main view, persists through all views including market and smart gen, minimizable to lip, shuffle/repeat once-or-infinite/next/prev/favorite, files sorted by filetype/model/upload-download); Discover Market tab (free market, two-tone black/red treatment).
- Media pane may have a dropdown navigation selector if crowded.

## Settings
- Settings is the ONE exception — it is NOT a lip. It can remain a gear icon (e.g., a settings gear at bottom-left), opening a slide-up drawer or popup menu. All short-term navigation/utility actions blur background. It still blurs the background like every pane (see "Pane background blur (universal rule)" above).

## Row count selector / drag-drop
- Row count selector (1/2/3 rows) = single always-on button. Drag-drop toggled via 1.5s long-press (haptic) with glowing selection outline, ad-hoc; glow animates away on release. Alignment button redundant (row selector realigns).

## Model cards
- Max 6 on screen, near-full-screen coverage, glass cards with sheen but NOT the white border (looks cartoonish), minimal blur, legible text, not distracting from background. Optionally casting reflection/shadow on "ground" for 2.5D.

## Consensus preview lip
- Smaller/shorter; does not need full text — entice, not inform.

## No-numbers/no-noise rule
- Do not introduce any counts into the app. Don't add any non-labeling numbers whatsoever. Remove non-working/unneeded features ("you want to give them freedom... I want 0 noise"). Remove redundant header buttons.

## Card view
- Card view ≈ main view minus consensus preview. Toss redundant header buttons. Media gen models completely replaced with figma counterparts.

## Settings/icons/generic elements
- All swapped to Figma equivalents. Action context bars in grid/card/message views updated.

## Gold badge
- User confirmed: gold badge for "Pro+" = "OF COURSE". Use gold (overrides prior gold/orange accent ban).

## Applies to
- All screens, including Market and Smart Gen (in scope thanks to a Figma design the user found).

## Execution
- Validate work visually with browser (`expo start --web` + Playwright). Use all needed skills. No questions necessary — work until done.

---

<!-- END OF SPEC — do not edit or summarize the content above. -->
