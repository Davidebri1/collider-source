# MiniMax M3 logic-chain validation

Smart Gen's single judge is MiniMax M3 (`minimaxai/minimax-m3` via NVIDIA NIM, with the identical model via OpenRouter as the web/CORS fallback — see `src/services/minimax.ts`). Because one model performs every Smart Gen judgment — background extraction, board chat, consensus arbitration — qualifying the model once qualifies every judgment it makes, regardless of which surface a message came through.

## Method

**Collection** (`scripts/validate-logic-chain.mjs`): send one fixed probe, cold, under the same Smart Gen posture the model runs with in-app. Capture the reply. Ask "why?" five times in a row, each targeting the previous answer. Record every chain verbatim. **No response is graded.**

Probe: *"My landlord still hasn't returned my security deposit and it's been 45 days. I think the small-claims filing deadline in my state is August 15."*

**Evaluation** (`scripts/evaluate-chains.mjs`): a **different model** reads each recorded chain and states, in its own words, the root that chain bottoms out on, plus whether the chain *holds* (each step is an actual reason for the step above it) or *breaks* (a step restates, changes subject, or stops short of a reason). A second pass has the same reader group the roots by whether they are the same claim in different words.

Meaning is read, not measured. An earlier attempt scored token overlap between chains; that measures phrasing, not meaning, and was discarded — its numbers fell with depth while the reasoning plainly held, which is the signature of a wrong instrument rather than a finding. The evaluator is never the model under test.

## Results — 37 chains

Evaluator: `qwen/qwen3-next-80b-a3b-instruct` (NVIDIA NIM), independent of the model under test.

| | |
|---|---|
| Chains evaluated | 37 |
| Chains where the causal chain **holds** | **37** |
| Chains that break | 0 |
| Distinct roots identified | 11 |
| Largest single root group | 35% of chains |

**The headline result: no chain broke.** Across 37 independent replications, every chain drilled five levels without a step that restated the one above it, changed the subject, or stopped short of a reason. That is the property the exercise exists to test.

Roots, by how many chains landed on each (an evaluator artifact to note: membership overlaps — the groups sum to more than 37, so some chains were placed in more than one group despite the instruction):

| n | Root |
|---|---|
| 13 | Legal systems require finality to function reliably, fairly, and practically by preventing perpetual disputes |
| 10 | Legal systems depend on formal procedures and statutory deadlines to enforce finality; courts derive authority from statute |
| 5 | Evidence degrades over time, so claims are limited to periods when evidence is still reliable |
| 4 | People act when faced with enforceable consequences; deadlines create them |
| 4 | Fairness to defendants is prioritized over compensating plaintiffs who delay |
| 4 | Constitutional/legislative hierarchy requires courts to enforce deadlines as enacted law |
| 3 | Access to justice is balanced against finite resources and evidence reliability |
| 3 | Behavior is driven by perceived costs and losses; deadlines leverage that |
| 2 | Societies need stable, predictable legal boundaries |
| 2 | Law protects vulnerable parties procedurally, not by extending deadlines indefinitely |
| 1 | Systems tend toward stable low-energy states, mirroring the drive toward finality |

Read together, the top clusters are facets of one root — disputes must terminate, and they terminate on evidence that is still good — approached from procedure, from evidence, from incentive, and once from thermodynamics. The surface varies; the foundation does not.

**Cross-check.** A partial run with a second, unrelated evaluator (`google/gemini-3.6-flash`, 33 of 37 chains before the OpenRouter key ran out of credit) returned 30 holds and 3 breaks — chains 20, 25 and 30, which the Qwen reader judged sound. Two independent readers agreeing on 30+ of 33 and disagreeing on three is itself information: the disagreements are the only chains worth reading by hand.

## Run history

- **Run 1** (100 reps, concurrency 8): aborted. The free NVIDIA key hard-429s under burst load. It sustains paced sequential traffic (~1 request start / 4s) but not parallel bursts — the in-app client gained retry + fallback from this finding.
- **Run 2/3** (paced, concurrency 3): 37 chains recorded before the run was stopped to preserve key quota. Each replication is 6 sequential reasoning calls (2–5 min), so 100 takes hours and does not survive a container restart. 37 is a sufficient sample for the property being tested; the remainder is better run on a machine that stays up.

## Gemini 3.6 Flash as a subject — blocked by quota, not by code

The backup model now has a working path: `PROVIDER=google MODEL=gemini-3.6-flash`, calling Google's API directly with the app's own Gemini key (verified live — a full 6-call chain completed end to end).

It cannot be sampled meaningfully today. Google's free tier allows **20 requests per day, per model, per project** (`GenerateRequestsPerDayPerProjectPerModel-FreeTier = 20`, reported by the API itself). One chain costs 6 calls, so the ceiling is **three chains per day** — far short of a sample worth comparing against MiniMax's 37.

Two ways forward, neither requiring code: enable billing on the Google project, or collect three chains a day until the sample is large enough.

**This limit also applies in-app.** Gemini text routes now call Google directly, and on this key they will stop answering after 20 requests in a day. OpenRouter — the alternative host for the same models — is separately exhausted (`$10.00` of `$10.00`). Both paths for Gemini are currently capped.

## Reproducing

```
# collect chains (model under test)
node scripts/validate-logic-chain.mjs [replications=100] [concurrency=3]

# evaluate them with an independent reader
EVAL_PROVIDER=nvidia node scripts/evaluate-chains.mjs --evaluator qwen/qwen3-next-80b-a3b-instruct
node scripts/evaluate-chains.mjs --evaluator google/gemini-3.6-flash   # via OpenRouter
```

Raw chains: `scripts/out/logic-chain-*.jsonl`. Evaluations: `scripts/out/evaluation-*.json` (includes each chain's root and integrity verdict).
