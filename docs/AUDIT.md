# Initial Audit — Collider vs. docs/SPEC.md

Audit performed at the start of this engagement, before any fixes. Kept here as a historical baseline — see `docs/PROGRESS.md` for what's since been fixed. Don't assume anything below is still broken; cross-check against PROGRESS.md and the current code first.

## Critical / broke the app entirely
- **Native crash**: `MarketScreen.tsx` used raw HTML `<select>` elements (react-native-web only) — crashed on real iOS/Android. **Fixed** (see PROGRESS.md).
- **Metro bundler crash on `@supabase/supabase-js`**: no `metro.config.js`, so Metro couldn't resolve the package's `.mjs` ESM entry points — blocked the entire app from loading once Supabase was added. **Fixed.**

## Monetization — was inverted from spec
- Free tier's 20/day limit was applied to *every category except general* (backwards — free users can't reach non-general categories anyway since no free-tier models exist there). **Fixed**: cap now correctly gates general chat for free tier.
- Credits were a one-time pool, not a daily-resetting allowance. **Fixed**: credits refill to the tier pool on date rollover.

## Model routing honesty
- Several labels promised a specific flagship model while secretly routing elsewhere (e.g. "Grok 2" → `gpt-4o-mini`; several models mislabeled with wrong version numbers vs. their actual route). **Fixed**: routes/labels reconciled; where no real equivalent exists (Sora/Veo/Suno/Udio), copy now says plainly it's an AI-written approximation, not the real API.

## Grid view (biggest named pain point)
- Cards showed only the *last* message, not full history; no scroll. **Fixed** — full scrollable per-model thread with windowed loading.
- Grid card previews rendered messages as bare `<Text>`, no chat bubbles, and unhandled `\n\n` in model replies created large dead-looking gaps. **Fixed** — real bubbles added, internal blank lines collapsed.
- Category selector was a horizontal ribbon, not a dropdown. **Fixed** — dropdown + icon fold-outs added; density (row-count) selector wired up (previously dead state).
- No global search UI existed anywhere in the grid view. **Fixed** — search icon added to grid toolbar, opens cross-type search (conversations/memories/reminders/projects/artifacts) with type + model filters. *Unconfirmed live due to a browser-automation targeting issue this session — verify by tapping it.*
- Responses were not streamed — user saw nothing until the full reply arrived. **Fixed** — real token-by-token SSE streaming on web, graceful full-response fallback on native.

## Consensus feature
- Verdict was literally `replies[0].content` (no synthesis); "agreement" was a naive bag-of-words heuristic. **Fixed** — real LLM arbiter call synthesizes the verdict and scores per-model alignment, with the old heuristic kept only as a fallback if the arbiter call fails.
- Only one dissenter was ever shown, regardless of how many existed. **Fixed** — shows all (capped at 2 detail cards + a "+N more" note to keep the view compact).
- Dissenter horizontal position was even-spacing, not the spec'd net-force layout. **Fixed** — real force simulation (repulsion ∝ disagreement, attraction ∝ affinity, centering pull ∝ consensus alignment).
- Required a "one view, no scroll" full-screen page; original layout overflowed and required scrolling. **Fixed** — score/summary/map sizes reduced to fit typical cases in one screen.
- Consensus close button always wiped the active grid conversation regardless of the `autoWipeOnConsensus` setting sitting right next to it. **Fixed.**
- `CardScreen`'s COLLIDE button set local state but no `<ConsensusModal>` was ever rendered to react to it in card view — the button silently did nothing. **Fixed.**

## Smart Gen
- Artifact type didn't exist at all (one of five required Smart Gen types). **Fixed** — full CRUD, `ArtifactsScreen`, left-drawer nav entry.
- Cross-linking between memories/reminders/projects/artifacts didn't exist. **Fixed** (partial) — a shared `links` bag exists and a `linkItems` action, but "Convert to..." doesn't yet auto-link the new item back to its source (would need reducers to return generated ids — noted as a follow-up, not silently skipped).
- Extraction was regex/keyword-only (only fired on literal phrases like "remind me to..."). **Fixed** (additive) — a background LLM extraction pass now supplements the instant regex pass, including deciding when to generate Artifacts.
- Right drawer showed only generations/outputs, not Smart Gen tools, contradicting the spec (global in grid view, scoped to current model in card view). **Fixed** — right drawer now has Outputs/Projects/Reminders/Memories/Artifacts tabs, model-scoped when opened from card view.
- No Google Calendar/Tasks integration existed. **Fixed** — real OAuth (PKCE) + Calendar/Tasks API wrapper, wired into `RemindersScreen`. See PROGRESS.md for the Google Cloud project details and current limitations (web-only OAuth client so far; Android needs a signing keystore that doesn't exist until a real Android build happens).

## Imagine Market
- Entirely mock/local data: hardcoded seed items, `Math.random()` fake generations reusing 4 static stock video/audio URLs forever, likes/comments/follows lived only in component state and reset on close. **Fixed** — real Supabase backend (schema, RLS, live queries) now backs the feed/likes/comments/publishing. See PROGRESS.md for the project details.
- *Unconfirmed live this session* — several attempts to open the screen via browser automation failed to land on it; unclear if that's a real bug or an automation-targeting problem (same class of issue as the search button). Needs a manual check.

## Visual/AAA polish
- No Android `elevation` on many `shadowOpacity`-only styles (Android silently drops iOS-only shadow props). **Fixed** — elevation added across the flagged styles.
- `alert()`/`confirm()` used ~15-20 times app-wide (native doesn't render these — pure web crutch). **Fixed** — replaced with an in-app `Toast`/`ToastProvider` system.
- A composer mode chip ("Default ▾") rendered with a fixed 34px circular background from a base style, while its text overflowed past it — a react-native-web quirk where `width: undefined` doesn't reliably override a prior fixed width. **Fixed** — explicit `width: "auto"` override.

## Not yet addressed / lower priority
- Market's `#tag` quick-filter pills and "my-assets" tab remain client-side/local-file-based, not backed by the live Supabase schema.
- No real user-auth system for Market — every device gets a random per-install UUID as a pseudo-identity, not real accounts. Likes/publishing are per-device, not per-account.
- Android OAuth client for Google Calendar/Tasks doesn't exist yet (needs a signing keystore from a real Android build first).
- "Convert to..." Smart Gen action creates the new item but doesn't yet back-link it to the source item.
