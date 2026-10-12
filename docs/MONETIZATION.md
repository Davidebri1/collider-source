# Monetization — what a tier actually buys

Written 2026-07-29 from provider-published rates fetched live from
OpenRouter's video and image registries. Every number is derived, none guessed.

## The correction first

**"Seven videos will eat my entire profit" is not what happens — the credit
pool makes that impossible.** But the real problem is worse for the product,
and it was never disclosed:

- 1 credit is budgeted at **$0.002** of provider cost.
- Pro: **$19.99/mo, 3,000 credits** → provider spend is hard-capped at **$6.00**.
- Elite: **$49.99/mo, 7,500 credits** → capped at **$15.00**.

Margin is structurally safe at 70% because the pool *is* the cap. Seven Veo
3.1 clips would cost 11,200 credits; Pro only has 3,000, so the seventh
generation is refused, not absorbed.

**The actual failure is value, not margin.** At the settings the composer
used to default to, Pro bought fewer than two flagship videos a month.
Someone paying $19.99 and getting 1.8 clips does not renew — and nothing in
the app told them that before they paid.

## Roster rebuilt — video is kept, and it is now cheap

Ranking all 17 live video models by their published per-second rate showed the
**category was never expensive; the roster was.** It led with the two most
expensive models available.

Pro is now the volume tier, Elite the fidelity tier — the split the prices were
always describing:

| Tier | Model | $/s (cheapest res) | 5s clip | Pro/Elite gets |
|---|---|---|---|---|
| Pro | **Veo 3.1 Lite** | $0.030 | 75 cr | **40** |
| Pro | Wan 2.6 | $0.040 | 100 cr | 30 |
| Pro | Grok Imagine | $0.050 | 125 cr | 24 |
| Pro | Kling v3 Std | $0.084 | 211 cr | 14 |
| Elite | Veo 3.1 Fast | $0.080 | 200 cr | 37 |
| Elite | Hailuo 2.3 | $0.082 | 205 cr | 36 |
| Elite | Veo 3.1 | $0.200 | 500 cr | 15 |
| Elite | Sora 2 Pro | $0.300 | 750 cr | 10 |

**Seedance 2.0 and 2.0 Fast were dropped.** ByteDance prices them per video
token and the registry publishes no token rate, so their cost could only ever
be estimated — and a "pricing is derived" disclaimer is not a substitute for
knowing what you are charging someone. Replaced by Veo 3.1 Fast and Hailuo 2.3,
both of which publish per-second rates. **No model in this roster is now priced
by guess**, and `priceEstimated` no longer exists in the codebase.

## What 3,000 credits (Pro) buys, per model

| Model | Setting | Provider cost | Credits | Pro gets |
|---|---|---|---|---|
| Veo 3.1 | 8s · 1080p · audio | $3.20 | 1,600 | **1** |
| Veo 3.1 | 4s · 720p · no audio | $0.80 | 400 | 7 |
| Sora 2 Pro | 8s · 1080p | $4.00 | 2,000 | **1** |
| Kling v3 Std | 5s · 720p · audio | $0.63 | 315 | 9 |
| Veo 3.1 Lite | 6s · 720p · audio | $0.30 | 150 | 20 |
| Grok Imagine | 5s · 480p | $0.25 | 125 | 24 |
| Seedream 4.5 | 1 image | $0.04 | 20 | 150 |
| Gemini 3.1 Flash Image | 1 image · 1K | ~$0.077 | 39 | 76 |
| FLUX.2 Klein | 1 image | ~$0.014 | 7 | 428 |
| Transcribe (Groq Whisper) | 10 min | ~$0.007 | 1 | ~3,000 |

Elite (7,500) is 2.5× each row.

## What this means strategically

1. **This is a strong image product and a weak flagship-video product.** 150
   Seedream images or 428 FLUX images for $19.99 is competitive. One Veo clip
   is not.
2. **Flagship video belongs to Elite, and even there it is 4–5 clips.** Veo
   3.1 and Sora 2 Pro should not be what a Pro user reaches for by default.
3. **Cheap video is the volume play.** Veo 3.1 Lite at 6s/720p gives a Pro
   user 20 clips a month, which is a product. It should be the default video
   model, not the flagship.
4. **Transcription is effectively free** and should be promoted as such — it
   runs on Groq, not on the credit-blocked roster, and 3,000 credits is
   ~500 hours.

## Implemented

- **Affordability is disclosed before spend.** The generation settings sheet
  states "You can make N more at these settings" against the live balance,
  recomputed as duration/resolution/model change. The gap between 1 and 428 is
  the whole point — a credit balance alone communicates nothing.
- Per-option prices on every duration, resolution and quality pill.
- Cost derived from published per-second and per-image rates
  (`videoSpecs.ts`, `imageSpecs.ts`), not a flat per-model weight.
- Batch image count removed — it was the only setting that multiplied the
  bill without adding a distinct capability.

## Still to decide (owner)

- Should Veo 3.1 / Sora 2 Pro be Elite-only rather than Pro-visible? Current
  roster marks them Elite already; confirm the composer never defaults to them.
- Should Pro's pool rise? At 3,000 the image experience is strong and the
  video experience is thin. Raising to 5,000 costs $4.00 more at full burn and
  makes Veo Lite a 33-clip product.
- Credit top-up packs as a second revenue line, priced above $0.002/credit.
