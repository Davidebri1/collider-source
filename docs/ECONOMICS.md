# Economics & feature parity — media generation and coding

Written 2026-07-28. Every figure marked **verified** was obtained by calling
the provider from this session. Figures marked *estimated* could not be
verified here and are flagged individually — do not treat them as settled.

## What you charge

| Tier | Price | Credit pool | Media/coding access |
|---|---|---|---|
| Free | $0 | 0 | none (categorical — `CATEGORY_MIN_TIER` gates image/video/audio/coding to Pro) |
| Pro | $19.99/mo | 3,000 | yes |
| Elite | $49.99/mo | 9,000 | yes |

Pro revenue per credit: **$0.00666**. Elite: **$0.00555**.
At a 30% COGS target, a credit may cost you at most **~$0.0020** (Pro) /
**~$0.0017** (Elite).

## 1. Economic analysis

### Coding — verified, and comfortably profitable

Per-token prices pulled live from `openrouter.ai/api/v1/models`.
Cost model: 4,000 input + 2,000 output tokens per call (generous for a coding turn).

| Model | Credits | $/M in | $/M out | Cost/call | Break-even credits | Verdict |
|---|---|---|---|---|---|---|
| Qwen3 Coder | 4 | 0.30 | 1.00 | $0.0032 | 1.6 | **2.5× margin** |
| DeepSeek V3.2 | 5 | 0.269 | 0.40 | $0.0019 | 1.0 | **5× margin** |
| Codestral 2508 | 6 | 0.30 | 0.90 | $0.0030 | 1.5 | **4× margin** |
| Kimi K2.7 Code | 7 | 0.73 | 3.50 | $0.0099 | 5.0 | **1.4× margin** |

Worst realistic case: an Elite user spends all 9,000 credits on Kimi K2.7 Code —
1,285 calls × $0.0099 = **$12.72 against $49.99**. Coding is safe.

Note this analysis assumed the old 1,024-token output cap. Raising coding to
8,192 (done, same commit) roughly triples worst-case output cost: Kimi's
cost/call rises to ~$0.032, break-even to ~16 credits against a 7-credit
charge. **Kimi K2.7 Code is now underpriced and should move to ~16–20 credits,
or its ceiling should be 4,096 rather than 8,192.** The other three still clear
their weights at 8,192.

### Image — *estimated*, modestly underpriced

OpenRouter's `/models` endpoint does not publish per-image output pricing for
generation models, and the account is credit-blocked so a real generation
could not be run to read back actual usage. **These are published-rate
estimates and need confirmation against one real invoice.**

| Model | Credits | Est. cost/image | Break-even credits | Verdict |
|---|---|---|---|---|
| FLUX (Pollinations) | 1 | $0.00 (keyless) | 0 | free — pure margin |
| Gemini 3.1 Flash Image | 2 | ~$0.02 | ~10 | *underpriced ~5×* |
| GPT-5 Image Mini | 3 | ~$0.02 | ~10 | *underpriced ~3×* |
| FLUX.2 Klein | 2 | ~$0.01 | ~5 | *underpriced ~2.5×* |
| Seedream 4.5 | 5 | ~$0.03 | ~15 | *underpriced ~3×* |
| Gemini 3 Pro Image | 6 | ~$0.13 | ~65 | *underpriced ~11×* |
| FLUX.2 Max | 7 | ~$0.06 | ~30 | *underpriced ~4×* |
| GPT-5.4 Image 2 | 8 | ~$0.17 | ~85 | *underpriced ~11×* |

### Video — *estimated*, and this is where the model breaks

| Model | Credits | Est. cost (5s clip) | Break-even credits | Verdict |
|---|---|---|---|---|
| Grok Imagine Video | 10 | ~$0.50 | ~250 | *25× underpriced* |
| Veo 3.1 Lite | 12 | ~$0.75 | ~375 | *31× underpriced* |
| Seedance 2.0 Fast | 12 | ~$0.50 | ~250 | *21× underpriced* |
| Kling v3.0 std | 14 | ~$0.50 | ~250 | *18× underpriced* |
| Wan 2.6 | 24 | ~$1.00 | ~500 | *21× underpriced* |
| Seedance 2.0 | 26 | ~$1.25 | ~625 | *24× underpriced* |
| Sora 2 Pro | 30 | ~$2.00 | ~1,000 | *33× underpriced* |
| Veo 3.1 | 30 | ~$2.00 | ~1,000 | *33× underpriced* |

**An Elite user spending their whole 9,000-credit pool on Veo 3.1 gets 300
clips at an estimated ~$600 of cost, against $49.99 of revenue — roughly a
12× loss.** A Pro user on Veo 3.1 Lite: 250 clips, ~$187 cost, $19.99 revenue
— roughly 9× loss. The order of magnitude survives even if every estimate
above is wrong by 3×.

### Recommendation — put the balance in your favour

1. **Reprice video to 250–1,000 credits per clip**, or drop per-clip credits
   and sell video as a separate metered add-on. At current weights a single
   engaged Elite user can cost you 12× their subscription.
2. **Reprice images to 10–85 credits** by model, keeping FLUX/Pollinations at
   1 as the free-feeling default that costs nothing.
3. **Cap video per billing period** independently of the credit pool — a
   ceiling, not a rate. Credits alone cannot protect you when one call is
   worth 300 chat calls.
4. **Move Kimi K2.7 Code to ~16 credits** now that coding emits up to 8,192
   tokens, or cap coding at 4,096.
5. **Confirm the estimates.** Fund the account with $5, run one generation per
   image and video model, and read actual usage back. Every video row above is
   an estimate, and the repricing should be done against real invoices.

## 2. Feature parity — what we offer vs what the model offers

### Verified defects, fixed in this pass

- **`deepseek/deepseek-v3` was not a valid model ID** — verified by call
  (HTTP 400 *"not a valid model ID"*, distinct from the 402 a credit-blocked
  but valid model returns). `pro/deepseek-coder-v3` charged 5 credits and
  could never answer. Repointed to `deepseek/deepseek-v3.2`.
- **`openai/gpt-4o-mini-tts-2025-12-15` was retired** — also HTTP 400. The
  dated slug was correct when written; OpenRouter has since removed it and
  lists no `mini-tts` successor. `aud/gpt-4o-mini-tts` charged 3 credits for
  an error. Entry removed rather than silently repointed at a different model
  under the old name; `kokoro-82m` (2 cr) covers the cheap-narration slot.
- **Coding output was capped at 1,024 tokens** — roughly forty lines. Nothing
  raised it for the coding category, so Codestral and Kimi K2.7 Code were
  truncated mid-function at 6–7 credits a call. Now 8,192.

All other roster IDs return 402 rather than 400 — i.e. they are valid models
blocked only by the empty balance.

### Options we do not expose

| Surface | We send | The models accept | Gap |
|---|---|---|---|
| Image (OpenRouter) | `model`, prompt, `modalities` | size / aspect ratio, quality, n images, seed, negative prompt, reference image (img2img), style | **everything but the prompt** |
| Image (Pollinations) | prompt, fixed 1024×1024, random seed | width, height, seed, model, nologo, enhance | no size or seed control; seed is random, so the same prompt never reproduces |
| Video | prompt, duration | duration, aspect ratio, resolution, fps, reference image, camera motion, negative prompt | aspect/resolution/fps/reference all absent |
| TTS | `model`, `input`, `voice`, `response_format` | voice, speed, format, instructions/style | no speed, no style direction |
| Chat/coding | `temperature: 0.7` fixed, `max_tokens` | temperature, top_p, penalties, stop, seed, reasoning effort | temperature is hardcoded; no top_p, no stop, no seed |

**The honest summary: we advertise these as the real models, and functionally
we ship a prompt box.** A user choosing "GPT-5.4 Image 2" over "FLUX.2 Klein"
is choosing a price, not a capability — they cannot set a size, an aspect
ratio, a seed, or a reference image on either. Image aspect ratio is the most
conspicuous: every one of these models supports it, the app hardcodes square,
and a phone-shaped app generating only square images is visibly wrong.

Minimum to claim parity: **aspect ratio + size** on image, **seed** on image
(reproducibility), **aspect ratio + duration** on video, **speed** on TTS, and
**temperature** exposed on chat/coding. That is a small options sheet, not a
rebuild, and it turns eight image models from eight prices into eight genuine
choices.

---

# Repricing applied — 2026-07-28

The estimates above were replaced with **published provider rates** gathered
from vendor and market sources rather than inferred. Sources at the end.

## Where the old numbers came from

`git log -L` on the weight lines: video weights entered in `020c60f`
(2026-07-18, "Add real pro-tier video routes… real video/music generation"),
image and the rest in `ea9cab5` (2026-07-16). **No commit anywhere states a
cost basis, and `weight: number` was undocumented** — there is not one comment
in the codebase tying any weight to a provider price. They were a relative
sense of "expensiveness", which is how a Veo 3.1 clip costing ~$2.00 came to
cost the user the same 30 credits as roughly four chat messages.

## The unit

**1 credit = $0.002 of provider cost.** Every weight is now
`ceil(real cost / $0.002)`. That single rule makes the whole roster
comparable and auditable.

## Pools — reduced

| Tier | Price | Old pool | New pool | Max provider spend | COGS |
|---|---|---|---|---|---|
| Pro | $19.99 | 3,000 | **2,500** | $5.00 | 25% |
| Elite | $49.99 | 9,000 | **6,000** | $12.00 | 24% |

For context, the tier prices themselves are in line with the market — Krea Pro
is $35/mo for 20,000 compute units, Leonardo runs $12/$30/$48, Midjourney
$10/$30/$60. The subscription prices were never the problem; the allowances
and the per-call weights were.

## Weights — raised to match reality

| Model | Real cost | Old | New | Elite pool buys |
|---|---|---|---|---|
| FLUX (Pollinations) | $0 | 1 | **1** | 6,000 |
| GPT-5 Image Mini | $0.003 | 3 | **2** | 3,000 |
| Gemini 3.1 Flash Image | $0.01 | 2 | **5** | 1,200 |
| FLUX.2 Klein | $0.01 | 2 | **5** | 1,200 |
| FLUX.2 Max | $0.02 | 7 | **10** | 600 |
| GPT-5.4 Image 2 | $0.02 | 8 | **10** | 600 |
| Seedream 4.5 | $0.04 | 5 | **20** | 300 |
| Gemini 3 Pro Image | $0.134 | 6 | **67** | 89 |
| Veo 3.1 Lite | $0.25 (5s @ $0.05/s) | 12 | **125** | 48 |
| Kling v3.0 std | $0.50 (5s @ $0.10/s) | 14 | **250** | 24 |
| Grok Imagine Video | ~$0.50 | 10 | **250** | 24 |
| Wan 2.6 | ~$0.50 | 24 | **250** | 24 |
| Seedance 2.0 Fast | $0.75 (5s @ $0.15/s) | 12 | **375** | 16 |
| Seedance 2.0 | $1.51 (5s @ $0.3024/s) | 26 | **755** | 7 |
| Sora 2 Pro | $2.00 (5s @ $0.40/s) | 30 | **1,000** | 6 |
| Veo 3.1 | $2.00 (5s @ $0.40/s) | 30 | **1,000** | 6 |
| Qwen3 Coder | $0.0092 | 4 | **5** | 1,200 |
| DeepSeek V3.2 | $0.0043 | 5 | **3** | 2,000 |
| Codestral 2508 | $0.0084 | 6 | **5** | 1,200 |
| Kimi K2.7 Code | $0.0309 | 7 | **16** | 375 |

Two went **down** — GPT-5 Image Mini and DeepSeek were overcharged relative to
what they actually cost. The point is accuracy, not a uniform increase.

Coding costs assume the new 8,192-token ceiling (4k in + 8k out), which is why
Kimi moves 7 → 16: it is the one model where a long answer is genuinely
expensive.

**No separate video cap is needed.** At 1,000 credits a clip, the pool is the
cap: an Elite user gets 6 Veo 3.1 clips a month, costing $12 against $49.99.
The old weights allowed 300 clips for ~$600 on the same subscription.

## Still unverified

Audio/music rates (Lyria, Voxtral, Kokoro, Gemini TTS) are **not published per
call** by their vendors; those weights are proportional to their token rates
where OpenRouter lists them and scaled by analogy where it does not. Grok
Imagine Video and Wan 2.6 per-second rates were not found in a primary source
and are set at the $0.10/s floor observed across comparable models — if either
is dearer, it is currently underpriced. Confirm both against one real invoice.

## Sources

- Google Veo 3.1 per-second tiers (Lite ~$0.05/s, Fast $0.15/s, Standard $0.40/s): https://www.veo3ai.io/blog/veo-3-1-lite-pricing-guide-2026 and https://costgoat.com/pricing/google-veo
- Sora 2 Pro $0.30–0.50/s, Kling 3.0 $0.10/s, Seedance 2.0 $0.3024/s 720p and Fast $0.15/s: https://devtk.ai/en/blog/ai-video-generation-pricing-2026/ and https://www.atlascloud.ai/blog/case-studies/seedance-2.0-pricing-full-cost-breakdown-2026
- Seedream 4.5 $0.04/image, FLUX.2 $0.02, GPT Image 2 $0.002–0.003, Gemini 3 Pro Image $0.134 (1K/2K): https://api.market/blog/astrosoft/image-generation/best-ai-Image-generation-apis and https://cloud.google.com/gemini-enterprise-agent-platform/generative-ai/pricing
- Coding per-token rates: `openrouter.ai/api/v1/models`, queried live 2026-07-28
- Competitor tier benchmarks (Krea, Leonardo, Midjourney): https://morphed.app/blog/krea-ai-alternatives and https://www.banani.co/blog/midjourney-pricing

---

# Correction and competitive check — 2026-07-28 (second pass)

## The Flow figures, verified

From Google's own support page (support.google.com/labs/answer/16526234):

| Plan | Credits | Period |
|---|---|---|
| No subscription | 50 | **per day** |
| AI Plus | 200 | month |
| **AI Pro ($19.99)** | **1,000** | **month** |
| AI Ultra ($100) | 10,000 | month |
| AI Ultra ($200) | 25,000 | month |

Veo 3.1 per generation: **Lite 10, Fast 20, Quality 100** credits.

So the per-generation costs quoted to me were correct. The pool is **monthly,
not daily** — the daily figure (50/day) belongs to the free, unsubscribed tier.
Google AI Pro at $19.99 therefore buys **10 Veo 3.1 Quality (8s) videos a
month**, or 100 Lite.

## Why that does not mean video is cheap

At the API rate any reseller pays — $0.40/s for Veo 3.1 Standard with audio,
cross-checked between Google's published tiers and fal.ai's listing — one 8s
Quality video costs **$3.20**. Google's own $19.99 plan includes ten of them:

- **$32.00 of API cost sold inside a $19.99 subscription — 1.6× revenue.**
- Veo 3.1 Lite: $0.40 per 8s clip, 100 included = **$40.00 on $19.99, 2.0×**.

**Google sells Flow below the price it charges resellers for the same model,
across the whole range.** That is a first-party subsidy to drive adoption of
Gemini. It is not a rate Collider can obtain, and no repricing makes it
obtainable. Reselling flagship video against Google's own bundle is
structurally unwinnable.

## Corrected pool sizing — margin, not cost recovery

The point of the app is profit, and sizing pools at bare cost recovery was the
wrong frame. Pools are now set for a **70% gross margin**, which is a healthy
SaaS number and still leaves the allowance generous:

| Tier | Price | Pool | Max provider spend | COGS | Gross margin |
|---|---|---|---|---|---|
| Pro | $19.99 | **3,000** | $6.00 | 30% | **70%** |
| Elite | $49.99 | **7,500** | $15.00 | 30% | **70%** |

The earlier 2,500/6,000 was a 75% margin and needlessly stingy. Note the real
tightening came from the weights (up 20–30× on video), not the pools — the
headline allowance stays familiar while the leak is closed.

What Pro's 3,000 credits actually buys per month:

| | Clips/images |
|---|---|
| Veo 3.1 Quality (8s, $3.20) | 1 |
| Veo 3.1 Lite (8s, $0.40) | 15 |
| Kling v3 Pro (5s, $0.25) | 24 |
| FLUX.2 Max images ($0.02) | 300 |
| Qwen3 Coder calls | 600 |

## Where the profit actually is

Do not fight Google on flagship video. The margin lives where you have real
advantage:

1. **Text and coding — 70–95% margin, verified per-token.** Qwen3 Coder costs
   $0.0092 a call against 5 credits (~$0.033 of revenue).
2. **Images — strong margin at the cheap end.** FLUX via Pollinations is
   genuinely free; FLUX.2 Klein and GPT-5 Image Mini are $0.003–0.01.
3. **The multi-model consensus feature, which Google does not sell at all.**
   That is the thing worth paying for and the only part of the roster with no
   first-party competitor undercutting it.
4. **Video as a deliberately premium, occasional feature** — one or two
   flagship clips a month, or sold as a metered add-on at cost plus margin
   rather than bundled. Bundling it at a competitive-looking volume means
   selling dollars for fifty cents.

## Cheaper sourcing is the only lever that moves video

Rates differ substantially by route for the identical model — Kling 3.0
Standard is $0.084/s on fal.ai, **Kling v3 Pro is $0.05/s**, and Veo 3.1 Lite
is $0.05/s versus Standard's $0.40/s. Crazyrouter (crazyrouter.com), an
aggregator across 300–600 models with an OpenAI-compatible endpoint, claims
20–50% below direct provider pricing; its public pages do not publish a per-
model table, so **that claim is unverified and worth testing with one funded
account before committing to it.** If it holds even at 20%, every video weight
above drops by a fifth.

## Sources (second pass)

- Google Flow credit allocations and per-generation costs: https://support.google.com/labs/answer/16526234?hl=en
- Veo 3.1 tiers, Kling 3.0 Standard $0.084/s and Pro $0.112/s, Kling v3 Pro $0.05/s on fal.ai: https://oakgen.ai/blog/veo-vs-kling-vs-wan-2026 and https://www.atlascloud.ai/blog/guides/kling-3.0-review-features-pricing-ai-alternatives
- AI video pricing, APIs vs subscriptions: https://rangy.ai/blog/ai-video-pricing-explained/
- Crazyrouter positioning and discount claim: https://crazyrouter.com/ and https://www.toolify.ai/tool/crazyrouter
