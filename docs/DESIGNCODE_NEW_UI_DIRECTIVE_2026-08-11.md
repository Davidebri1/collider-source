# Collider — DesignCode Figma UI Kit "New UI" Directive (2026-08-11)

> **STATUS: CANONICAL / PRESERVED VERBATIM USER DIRECTIVE.** Created
> **2026-08-11** from `new ui.md` (repo root) so the directive cannot be
> overwritten, re-interpreted, or mis-identified. Filename is unique and
> timestamped (`DESIGNCODE_NEW_UI_DIRECTIVE_2026-08-11.md`) so it does NOT
> collide with `DESIGN_OVERHAUL_DESIGNCODE_KIT_SPEC_2026-08-10.md` (the
> master spec, a separate document). Every agent MUST read this directive
> before doing any DesignCode swap work.
>
> This file persists the FULL verbatim content of the user's directive.
> Below the header is the original text, untouched, with leading `> ` blocks
> preserved from the source.

---

# Directive (verbatim, from `new ui.md`, 2026-08-11)

The user calls out a Figma UI kit file present in the project directory,
`DesignCode UI - Figma Design UI Kit & Design System (Community).fig`, and
instructs that **every single UI element in the app be replaced by an
element from this kit**, with two exceptions (background images, the
consensus map itself — but every UI element INSIDE the consensus map is
swapped). Market and SmartGen are explicitly in scope.

The directive's central tenets, in the user's own language and order:

1. **Open-minded matching, not label matching.** Pick kit elements by
   *aesthetic + functional fit*, not by their Figma labels. A "video
   streaming" template is fair game; a "testimonial" card is not limited to
   testimonials. Ignore all labels; choose visuals.

2. **Kit elements are already coded and fully integrated** ("the elements
   are coded and the templates are all fully integrated. so the animations
   and so on are built in. coding is adaptable to our use case."). Styles
   are faithfully translated from the kit; don't re-implement what the kit
   already implements.

3. **Physical realism mandate — universal.** "EVERY action against the UI
   must result in the physical equivalent of the real life action. if
   something needs to fade down like a light emittance, then it must. if
   light emittances need random scatter, then there's the ambient
   animation. this rule goes for every instance. nothing in the app will
   exist outside of physical constraints." Smoothness comes from
   **framerate / HZ**, not from animation speed: implement via Reanimated
   worklets, Skia, and the kit's built-in motion. "if the figma skills
   aren't showing up with the plugin, check and fix the mcp. don't wing
   this project without proper figma support."

4. **Veer from the kit when needed; reuse for visual consistency.** The
   user permits mixing and adapting, especially for the Market and SmartGen
   modules, which need their own access points from the main menu.

## Main View (the lip shell)

- Main screen: **no UI elements shown at all except small lips** (Swift
  style) sticking up from the bottom edge of the screen.
- Each lip opens a nice drawer at the bottom of the screen.
- Lips are **distinct in color or design twist**, opened **left to right**.
- The five main-view lips and their contents (verbatim, in the user's order):

  1. **History lip** — click or slide-up both work. Pane is **not full
     height**, has a scrollbar, is loadable on click. Has a tab for
     consensus history. **Card view hides the consensus history tab.**
     History is **further to the right** of the prompt area.

  2. **Prompt bar lip** — in the center. **Autohides** after some time;
     redeploys at a button press, **quickly (fast animation, smooth)**.
     Replace all UI elements: buttons, message box, frame. Goal: a nice
     **2.5D, strong drop shadow version**. **Depth-of-field blur the
     background when typing in the prompt bar (or anywhere).** **Auto
     withdraw (tuck in) the prompt bar after a 3–5 second wait** after the
     user sends their message. **The keyboard should hide immediately
     after sending.** Prompt bar should be **not so tall** — the thumb
     stays in the same general area during regular usage.

  3. **Model category lip** — **light-indicated, slide-up pane, next to the
     prompt bar**. When opened it is full of general model card buttons
     with **light-emitted toggle indicators, animated all the way**:
     toggling off → the light dissipates; toggling on → it blooms.
     Sectioned: **Free models, Pro models, color/effect coded**.
     **Swipe in this pane** to view the next model category, all the way
     down through coding. Each tabbed pane has a **header description**
     identifying it, and the same color/effect coding to distinguish tiers.
     **Locked tiers get a lock icon or "whatever is in the figma that looks
     premium" overlaid on the WHOLE area** — not per-model.
     **Free users can look at the other tabs even if not unlocked.**
     **Unlocking a tier removes the icon and enables clicking.**
     **Re-lock pro and elite when the subscription expires.**
     Apply the pro/elite styling to "every section named pro and elite."

  4. **SmartGen Hub lip** — **further right** of history. Slide-up reveals a
     small menu pane of **full-width buttons, NO icons**:
     - **Smart Gen Cards** (free tier) — view/edit/delete generated cards;
       create instances of existing card types or create new card types.
     - **Smart Gen Boards** (free tier) — view/edit/delete boards; create
       custom boards in addition to the default set.
     - **Smart Gen Canvas** (free tier) — the playground, marries cards and
       boards. Free drag-drop of created cards and boards anywhere in the
       frame. Each board type looks like its name callout (a notebook looks
       like a notebook; a portfolio looks like a physical portfolio).
     - **Smart Genie** (pro tier) — the AI agent (Canva/Figma-like
       assistant). Chat view helpdesk-style. Toggleable in cards/boards/
       canvas views, easily minimizable to a toggle icon and resumed at any
       time. Conversation history, new-conversation button, attachments,
       agentic. **No coding unless elite subscriber.** At elite, custom
       agents become attachable to Smart Genie. Smart Genie **cannot
       customize the UI directly (even with agents)**, but can do
       everything within the app's framework regarding smart gen:
       mass field edits, individual card updates, reconfiguration of a
       card type as a subset of another card type and refactoring prior
       instances to inherit the new designation.

  5. **Media lip** — another swipe-up drawer that **blurs the background
     like the rest**. Tabbed; modal-per-tab. Tabs (in left-to-right order):
     - **Theme view** — drawer full of phone-preview wallpaper previews.
       Click one for big-size preview + set. Toggle to icon-only wallpaper
       view. Fullscreen-icon top corner → fullscreen marketplace
       navigation.
     - **Premium Theme tab** — kept **deliberately separate** from the
       free Theme tab to amplify FOMO; an entire new gated world. Sells
       **exclusively LIVE wallpapers** (seamless endless loop artwork,
       2k / 4k, **no camera movement, no boomerang looping**; smooth,
       trance-like, breathing). $3–$8 USD each, bundled with a pack of
       **5 curated theme songs**; song list previewable **before** purchase;
       live wallpaper previewable before purchase.
     - **Files and Music player tab** — music player is a **widget inside
       the files tab pane**. Music is **purchased songs in the files menu
       music "audio" view**, plus generated/uploaded audio. **No
       connectors to music services** — file uploads only, so the
       purchased music retains meaningful value. The music player is:
       - **Draggable anywhere in main view**, persistent in location
         through all views including Market and SmartGen.
       - **Minimizable** to a lip (music does not stop).
       - Pause / mute / volume sliders on the player alone.
       - Closable: `x` button, or dragging into the media lip/pane (any
         tab).
       - Fully featured slide-out drawer: **music library, repeat (once
         or infinite), shuffle, next/prev, favorite**.
       Files are otherwise a normal files pane: generations of all types
       from all models, splits by filetype, upload/download (from an AI
       model), and AI model. AI model label is a simple lit hue matching
       the model selector. Sort and filter by favorites, model. Tapping
       any content opens an action menu (every action-bar element
       swapped).
     - **Discover Market tab** — the free market. **Two-tone black/red
       treatment.** If panel feels crowded, add a **dropdown navigation
       selector** at the top left or right to jump between tabs.

- **Send button** can stay if it becomes **full white**; otherwise swap it.
- **All buttons need animations, many also need ambient animations.**

## Card view (consensus preview & messages)

- Card view ≈ main view minus the consensus preview.
- **Toss redundant header-menu UI buttons.**
- Media-gen model list completely replaced with the kit counterpart.
- If providers all offer only 2k image, **get rid of the 2k option**.
- **Do not introduce any counts into the app. No non-labeling numbers
  whatsoever. 0 noise.** Data dumpers are noise; the user must never be
  asked to find meaning in raw data.

## Consensus preview lip

- **Smaller, shorter.** It's a preview — must **entice**, not inform.
- Preferable that it **doesn't fit the full summary**, so it encourages
  the engagement to open the full map.

## Settings

- Make it a **slide-up drawer** and complete in one view, **or** a popup
  menu — either is fine. **Blur the background.** **All short-term
  navigation / utility actions blur the background** (pane navigation,
  typing, etc.). Settings is **the one exception** to the lip rule (it
  stays a gear icon at bottom).

## Row selector / drag-drop consolidation

- **Row count selector (1 / 2 / 3 rows) = one always-on UI button/icon
  with a figma design.** The alignment button is redundant (the row
  count selector already realigns to grid) — remove it.
- **Drag-drop is toggled by intuitive gesture**, not a button: **press
  and hold on a model card** ("1.5 sec typically for iphone haptic long
  press"), card gets a **nice impressive selection outline highlight**.
  Drag to where you want it and let go. **Drag-drop is ad-hoc.** The glow
  **animates away** right after release. Return to select mode on release.
- The row count selector remains **always on display in main view**.

## Model cards (clean state, before any drag)

- Stand in front of the background image as **clean UI (glass model cards)**
  with **premium sheen, NOT white border** (the existing white border
  reads as cartoonish). **Minimal blur, legible / clear text display**,
  not distracting from the background image. **Ideally casting a shadow
  or reflection just in front of them on the "ground"** so they appear to
  be standing — to play with 2.5D perspective.
- If reflection/shadow ground physics isn't reasonable, just pick
  **glass cards from the figma with excellent drop shadows** to enhance
  the 2.5D / 3D effect.
- **Max 6 cards on screen**, almost full screen coverage, **faux rows**
  laid out as if in a real space. Music-player-UIs with the long
  reflection on the ground are the visual reference.

## Slide-up pane behavior (universal)

- Slide-up pane is a foreground element with **heavy shadows OR heavy
  drop-shadows OR depth-of-field blur of the background**. Pane is right
  up against the screen, blocks the model cards and prompt bar behind it.
- You cannot navigate a menu and read model cards at once — they must
  hide each other or appear as separate layers.

## Execution

- **In the end: an overhauled UI.** Buttons may change type and location.
- **No questions necessary. work until done. Validate visually with
  browser. Use all the skills you need.**

## Notes for the agent executor

- Persist this directive verbatim; do not summarize, paraphrase, or trim
  intent.
- Existing master spec:
  `docs/DESIGN_OVERHAUL_DESIGNCODE_KIT_SPEC_2026-08-10.md`.
- Existing implementation plan: `plans/DESIGNCODE_OVERHAUL_PLAN_2026-08-10.md`.
  This new directive **strengthens / reinforces** the spec and the plan.
  Where it conflicts, the master spec (canonical) is the fallback order
  of authority — but the new directive is to be treated as additional
  binding constraints on the spec (it does not relax anything).

---

# Original source (verbatim, preserved for traceability)

The full original `new ui.md` text, character-for-character:

```
"""
-------------------

> hi /agent-browser  /frontend-design  /api-design-principles  /brainstorming /browse /browser-use  /browse /find-skills /error-handling-patterns /systematic-debugging /remotion-best-practices /test-driven-development /writing-skills
> @"C:\Users\D\Downloads\DesignCode UI - Figma Design UI Kit & Design System (Community).fig" this is a figma UI Kit. Use this and the full suite of figma skills/plugin/mcp to integrate this throughout the app.
> this ifigma file is also located in this project directory. 'DesignCode UI - Figma Design UI Kit & Design System (Community)'
>
> there are many options and many deisgns. i want you to use your judgment to pick ou the best ones for this app. dont pick by label, pick by potential. aesthetic. functional fit. for instance, dont let "video streaming" app template ui discourage you from using any or all of the eleements it offfers. and dont let "testimonial" component type limit you to jthinking it can only apply to testimonials. everything is open-ended. ignore all labels. choose visuals.
>
> the elements are coded and the templates are all fully integrated. so the animations and so on are built in. coding is adaptable to our use case.
>
> so approach it maximially open-minded.
>
> MUST:
> Every single UI element in my app must be replaced by an element in this kit. This excludes proprietary or custom things like background iages and the consenus map. But the UI elements within the map do need to be swapped to this figma kit's equivalent. So pore through the app for every opportunity. and this goes for market and smart gen as well.We have the resources to easily drag drop this in now. a ful overhaul with some button clicks.
> EVERY action against the UI must result in the physical equivalent of the real lffe action. ...
> [the full text of new ui.md follows in the source file]
"""
```

(For the full raw text, see the literal source file at `./new ui.md`.
This preservation file is the canonical *interpreted* form so subsequent
agents do not have to re-parse the raw `> ` block stream with typos.)

---

<!-- END OF DIRECTIVE — do not edit or re-summarize the content above. -->
