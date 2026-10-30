# Live playtest — https://davidebri1.github.io/collider-app/ (v920h sha 4c4b73f5)

Portrait 440×956, fresh Chrome profile, real input.

## AI reliability (Pollinations keyless)

| Probe | Result |
|-------|--------|
| Live multi-model Home send | Many parallel POSTs → **402 Payment Required** (only some 200) |
| Curl burst 10 parallel | **8/10** (1×402, 1×timeout) |
| Curl 10 sequential openai-fast | **7/10** (2×402, 1×timeout) |
| Live Genie (single request) | **PASS** POST 200 + “(2 changes)” |

Root cause: Classic anonymous free tier is one model (`openai-fast`); without keys every Home row falls through to Pollinations and stampedes it.

**v920i fix (committed a312bb0):** serialize `_pollinationsText` + retry 402/429/503 + model `openai-fast`. Still no keys. Remaining unreliability is Pollinations free-tier quota itself — concrete further fix would be a keyed OpenRouter/NVIDIA wire (user keys / proxy), not more Pollinations concurrency.

## Feature table

See report from agent; captures under `artifacts/v920/live/`.
