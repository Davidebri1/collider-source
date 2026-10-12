# Worklog — live state

Replaces TASKS.md's stage/phase framing. There are no phases. Items are
grouped by the **view or surface they serve**, so a requirement can be found
from the thing it belongs to, not from a stage number it got filed under.

Everything below passes `npx tsc --noEmit` (0 errors) and `npm test` (60/60).
**Nothing is device-verified.**

---

# WHAT IS LEFT

Read this section only. Everything below it is detail.

## Three "blockers" I reported were stale claims, not facts

Carried forward from TASKS.md without checking. Each was verified false:

| Claimed | Actual |
|---|---|
| "Auth dispatches hardcoded dummy emails" | **Real Supabase OAuth** — Google, Apple, email with signup fallback, `getSession`, and a Sign Out row in Settings → Account. Nothing to build. |
| "`assets/themes/premium/` is empty" | **Four live wallpapers ship** — aurora_drift, nebula_bloom, low_tide, ember_fall, each with an .mp4 loop and .jpg poster, plus 5 ambient tracks. Wired via `require.context` over the .mp4 files. |
| "14 roster slugs are dead" | **All video and image slugs are live.** OpenRouter splits its registry by modality and I judged all three from `/api/v1/models`, which is text-only. |

The lesson is in the WORKLOG's own rules now: **a status line is not evidence.**
Re-verify before repeating a blocker, especially one you inherited.

## Genuinely blocked

| # | Blocker | What it stops | Fix |
|---|---|---|---|
| 1 | **OpenRouter is at $0.131 of $10.** Every paid call returns 402 — verified live. | **All image, video and audio generation.** The media tabs are complete in code and cannot produce one asset. | Top up, or use the Crazyrouter key (wired — `EXPO_PUBLIC_CRAZYROUTER_API_KEY`, slug map populated from its live catalog). |
| 2 | FAL account locked, balance exhausted. | Market image auto-fill falls back to Pollinations (which works); the video seeder can't use `--provider fal`. | Top up FAL, or run the seeder with `--provider gemini`. |
| 3 | `verifyPurchase` returns `true` unconditionally. | Client-trusted receipts are spoofable. **Do not take real money at scale until this is real.** | Supabase edge function → Apple `/verifyReceipt` + Google `purchases.subscriptions.get`. |
| 4 | **A probe row is stranded in live `market_items`.** | One broken tile in the image feed. My error — I verified the insert path by writing to production. | `20260729010000_remove_probe_row.sql`, or the one-line delete in the SQL editor. |

Groq healthy. Pollinations healthy. Supabase live (52 image / 50 video / 0
audio). **Transcription works today** — Groq, not the credit-blocked roster.

## Code work remaining

| # | Item | Note |
|---|---|---|
| 5 | Video restyle / extend / edit-region / upscale | OpenRouter's video API is generate-only. Crazyrouter's catalog is fetched and has no edit endpoints either. |
| 6 | Agent diff review (propose → apply/reject) | `src/services/agent.ts` |
| 7 | Device build | Nothing here has run on hardware. |
| 8 | `withFont()` hides missing style keys from TypeScript | Style references that don't exist typecheck clean and render `undefined`. Affects every file using `StyleSheet.create(withFont({...}))`. |

**Closed this pass:** radii tokenisation (167 values snapped, 303/320 now on
scale), Convert-to provenance, market persistence, agent run UI, automations,
market kind filtering, Files preview + download, lip sync / voice clone /
voice restyle / voice isolate removed by owner decision.

---

## Pricing & credits — the money path

| Item | Status |
|---|---|
| Cost scales with duration / resolution / image count (`src/services/pricing.ts`) | WIRED |
| All 9 spend/refund sites derive from one `costOf()` call so they can't disagree | WIRED |
| Refund on provider failure (4 sites) | DONE (pre-existing, verified correct) |
| Refund on locked-model early return | DONE (pre-existing) |
| Retry charges the same as the original send | DONE (pre-existing) |
| Price shown on **each option** in the settings sheet before selection | WIRED |
| Cost total + basis line in settings sheet | WIRED |
| Composer badge shows basis (`−300  12s`), taps through to settings | WIRED |
| Unverified-pricing disclosure when a model's reference figure isn't confirmed | WIRED |
| `REFERENCE.refQty` confirmed per model against live rate sheets | OPEN — only `vid/veo-3` is confirmed |
| `verifyPurchase` returns `true` unconditionally | OPEN — needs a Supabase edge function |

**Design note.** `model.weight` is now the cost of a *reference output*
(defined per model in `pricing.ts`), not a flat per-call price. Provider-derived
scaling (per-second video, per-image batches) is separated in that file from
app-policy multipliers (resolution tiers), because only the second kind is
open to argument.

---

## Media gen — composer

| Item | Status |
|---|---|
| Image aspect ratios: 7 native ratios, square no longer default or first | WIRED |
| Video aspect ratios | WIRED |
| Video duration = intersection of what the selected models support | WIRED |
| Video resolution 720p/1080p/2K/4K, each priced | WIRED |
| Image batch count (1/2/4), priced | WIRED |
| Audio length (15s–3m), priced | WIRED |
| Audio formats: mp3/wav/opus/flac | WIRED |
| Bitrate explicitly **not** billed (encode setting, not generation) | WIRED |
| `parseGenFlags` carries settings to the provider | DONE (pre-existing) |
| TTS voice picker per model, with unconfirmed-id disclosure | WIRED |
| Input type validation + inline error (not a popup) | WIRED |
| Output format options reach the provider call for audio | WIRED |

## Media gen — modes

Every competitor opens on a mode selector (Runway/Kling/Pika/Luma: Text→Video,
Image→Video, keyframes, extend, restyle; Midjourney/Flux/Firefly: generate,
edit, upscale; ElevenLabs: TTS, STT, voice, dubbing, SFX). This app had none —
each tab did exactly one thing, so image-to-video, keyframes and transcription
were unreachable even where the model supported them.

Modes are listed whether or not a provider is wired. Unroutable ones are
disabled and state what they need. Hiding a capability reads as "can't do
that"; showing it disabled reads as "not connected yet" — the second is true.

| Mode | Category | Status |
|---|---|---|
| Text → Image, Image → Image | image | ROUTABLE |
| **Edit region, Expand canvas** | image | **ROUTABLE** — reference-conditioned, `input_references` |
| **Upscale** | image | **ROUTABLE** on models publishing `resolution` (Gemini, Seedream) |
| **Remove background** | image | **ROUTABLE** on GPT-5 Image Mini (`background: transparent`) |
| Text → Video, Image → Video, Start + End keyframes | video | ROUTABLE |
| Restyle, Extend, Edit region, Upscale | video | OpenRouter's video API is generate-only |
| Lip sync | video | Wan 2.6 supports it; the route doesn't expose it |
| Text → Speech, Text → Music, Sound effect | audio | ROUTABLE |
| **Transcribe** (audio *and* video) | audio | ROUTABLE — Groq Whisper, verified live; demuxes video, so one path serves both |
| **Dub** | audio | ROUTABLE — composed from transcribe → translate → speak, all three already wired |
| Clone voice, Restyle voice, Isolate voice | audio | needs a cloning / s2s / stem endpoint |

- Mode is compiled as `--task` and read first in `sendChat`, before provider
  dispatch — it selects the path, it is not a hint.
- Required inputs are enforced before the send, not after the charge: a mode
  that cannot run disables the send button and says why inline.
- Transcription is priced on Whisper's real rate (~$0.04/hr), not the audio
  model's per-second rate. Billing a 30s transcript as music would have charged
  15 credits instead of 1.

---

## Media gen — results & interaction

The spec's minimum set for a media tab, in one sentence: *"generation column to
hold recent generations, generations as deliverables in chat window, prompt
queue for context injection, action bar with view / use as context / use as
source / delete / share / save to collection / favorite."* All of it, closed:

| Item | Status |
|---|---|
| Tap-to-open preview (exploded view) | WIRED — reachable from chat, rail, and Market |
| Video + audio transport: play/pause, scrub, mute, duration | DONE (`AssetViewer.tsx`) |
| Action bar: view / context / source / favorite / save / share / delete | DONE (`AssetActionBar.tsx`, complete against spec) |
| Generations as deliverables in the chat window | WIRED |
| **Generation column of recent outputs** | WIRED — `GenerationColumn.tsx`, mounted in global view (category-scoped) and card view (model-scoped) |
| **Prompt queue reaches the model** | WIRED |
| **Prompt queue is visible where it is used** | WIRED — injection tray above the composer: images render as thumbnails, video/audio as typed chips, text as its first line. Source is bordered and singular, context plural |
| Rail → source/context in one tap, visible in the tray before send | WIRED |

**Why this was one job, not two.** The generation column, the injection tray
and the action bar are the same loop: generate → see it → push it back in →
verify what is about to be sent. Splitting the column off as "next" broke that
loop in the middle and would have cost a full re-derivation of what it was for.

## Modes — scoping

- **Global view** offers the common minimum: the intersection of what every
  selected model supports. A mode one selected model lacks is not offered,
  because that model would fail while the others succeeded — which reads as a
  bug, not a limit.
- **Card view** is one model, so it gets that model's full set — every mode,
  duration, ratio and resolution it can actually do.
- Modes whose required input no selected model accepts are removed entirely
  (Image → Video disappears when Sora 2 Pro is selected: it takes no input
  image).

## Two bugs the edit modes exposed

Both were the same shape — the composer collected an input and the provider
call dropped it, so the feature "worked" while doing nothing:

1. **`callOpenRouterImage` never sent attachments.** Reference images are the
   roster's entire editing mechanism (16 refs on GPT Image, 14 on
   Gemini/Seedream, 8 and 4 on the FLUX tiers). An "edit" was a fresh
   generation that had never seen the picture it was editing.
2. **`callOpenRouterVideo` never sent frame images.** The registry publishes
   `supported_frame_images` per model, which is what makes Image → Video and
   keyframes possible. Selecting Image → Video produced an ordinary
   text-to-video clip that had never seen the still.

Also never sent: named `resolution` (Gemini, Seedream), `background`
(GPT-5 Image Mini), and `n` for multi-image batches.

`src/services/imageSpecs.ts` holds the fetched per-model image data, same
pattern and same regenerate command as `videoSpecs.ts`.

## Routers

`src/services/wire.ts` — every OpenAI-compatible call reads its base URL and
key from one place. OpenRouter by default; **Crazyrouter** when
`EXPO_PUBLIC_CRAZYROUTER_API_KEY` is set. Crazyrouter carries Suno and Udio,
which OpenRouter does not — that is the standing answer to the thin audio
roster and the unseeded audio market.

`SLUG_OVERRIDES` in that file is deliberately empty. Slugs are per-router, and
filling it with guesses is the exact failure CLAUDE.md warns about. Populate it
from `GET https://crazyrouter.com/v1/models`; unmapped slugs pass through
unchanged, which is right for every name that matches and a clean 404 for any
that doesn't.

## Market

Video and Audio tabs are **omitted by owner decision** — no cheap enough
provider to seed either. Hidden kinds are also filtered out of "All", so
omitting the tab doesn't just relocate unplayable rows into the default view.
The kinds remain in the schema; published items survive and reappear when the
tabs return. Live counts: 52 image, 50 video, 0 audio.

---

## Market

| Item | Status |
|---|---|
| Supabase-backed with real pagination | DONE (pre-existing) |
| Generate only when stored items run out | OPEN |
| Persist new generations back to Supabase | OPEN — this is the blocked write path to diagnose |
| Load in sequence like prior generations | OPEN |
| Video tab populated | OPEN |
| Audio tab populated | OPEN |

---

## Coding & agents

**The finding.** "Agents" were not in. `state.customAgents` is
`{ name, modelId, instructions }` and `activeSkills` splices sentences into the
system prompt — both are *personas*. There was no `tools` array anywhere in
`chat.ts`, no `tool_calls` handling, and no loop. The Coding tab issued one
request and received one block of prose, exactly like General. An "agent" could
describe reading a file and never read one.

| Item | Status |
|---|---|
| Tool-calling loop, multi-step, step ceiling (`src/services/agent.ts`) | WIRED |
| Tool set: list_files, read_file, write_file, create_artifact, create_task, web_search | WIRED |
| Tools bound to real app state (`src/services/agentContext.ts`) | WIRED |
| Coding tab routes to the agent runtime (3 send paths in `App.tsx`) | WIRED |
| Steps stream into the assistant bubble as they happen | WIRED |
| Tool results fenced and labelled untrusted (prompt-injection boundary) | WIRED |
| Retry re-issues through the agent loop, not plain chat | WIRED |
| Dedicated agent UI (step tree, tool approval, stop button) | OPEN |
| Diff proposal + apply/reject | OPEN |

**Parity note.** Against Cursor / Copilot Workspace / Claude Code, this has tool
use, workspace context, and the observe-then-act loop. Diff review is buildable
and open. Agency here is expressed through the app's own surfaces — artifacts,
files, tasks, search — not through a shell.

---

## Provider status — verified by calling, 2026-07-29

Per CLAUDE.md's standing rule. Every line below is an observed response, not a
reading of a roster.

| Provider | Result |
|---|---|
| **OpenRouter roster** | **All 8 video slugs and all 7 image slugs are LIVE.** |
| OpenRouter credit (this key) | `$9.869 / $10.00` used, `$0.131` left. A paid chat call returns **402 Insufficient credits**. |
| Groq | `200` on `/models`. Healthy. |
| Pollinations | `200`. Keyless, working — the market image fallback is sound. |
| **FAL** | **`403` on every model, image and video: "User is locked. Reason: Exhausted balance."** Includes `flux/schnell`. |
| **Supabase project** | **`gmenftvasdbhkbinkdux.supabase.co` returns NXDOMAIN** from both Cloudflare and Google public DNS, with an SOA from `supabase.co`. The hostname does not exist. |
| 3 TTS slugs | Unverified. `kokoro-82m`, `gemini-3.1-flash-tts-preview`, `voxtral-mini-tts-2603` are in no public registry; OpenRouter exposes no audio-model listing. Needs one paid call each. |

### OpenRouter's registry is split by modality
`GET /api/v1/models` returns **text models only**. Video and image live at
`/api/v1/videos/models` and `/api/v1/images/models`. Checking a video slug
against `/api/v1/models` reports it missing when it is live — do not repeat
that mistake when re-verifying.

### What this means for the app
1. **Supabase is unreachable, so every Supabase-backed feature is dead**
   regardless of code: market feed, market persistence, auth, cross-device
   sync, storage. The RLS migration in
   `supabase/migrations/20260729000000_market_write_path.sql` is a correct fix
   for a real second defect, but it needs a project that exists.
2. **FAL is locked**, so market image auto-fill runs entirely on the
   Pollinations fallback, and `scripts/seed-market-videos.mjs --provider fal`
   will 403 on the first call. Use `--provider gemini` with a Google key, or
   top up FAL.
3. **This OpenRouter key cannot pay for a video.** Veo 3.1 at 8s/1080p with
   audio is $3.20; the key has $0.13.

## Other blockers that are not code

1. `assets/themes/premium/` empty — no real live-wallpaper video or audio.
2. Google auth buttons dispatch hardcoded dummy emails.
