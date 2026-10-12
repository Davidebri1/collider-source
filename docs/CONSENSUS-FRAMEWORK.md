# Collider — Consensus Map Framework (v3)

> The consensus map is not a chart. It is a spatial argument.
> Size, luminance and distance each encode one claim about the structure of
> agreement. It is read the way a face is read: instantly, without parsing.

**This supersedes v2.** v2 was a lossy paraphrase; every loss pointed the same
direction — toward the arbiter having opinions. What each correction was is
recorded in §12 so the same drift is recognisable if it recurs.

---

## 1. What Consensus Is

**Consensus is a headcount.** How many responses say essentially the same
thing. It is resolved democratically, and the arbiter has no vote.

Logical chain analysis is a *separate axis*. It governs how large each claim
renders and where it sits — never who wins. v2's opening line ("consensus is
logical chain analysis, not polling") collapsed the two, and that single
sentence is the origin of most of what went wrong downstream.

### The process

1. **Read the question. Derive the need.** This is the pull. Everything after
   is framed by it, so intent never has to be re-inferred later.
2. **Reduce each response to its essence** — what it says, as a standalone
   statement, in service of that need. Not a description of the response, and
   never a mention of which model produced it.
3. **Group identical essences.** Largest group = the consensus.
4. **The winning essence *is* the summary.** Copied verbatim. Not rewritten,
   not blended, not re-composed.
5. **Every other essence is a dissenting view.** Also verbatim.
6. **Score = the count.** `3/6` means three said the same thing out of six who
   answered. A count, not a judgment.

### On model identity

The arbiter never sees which model produced which reply. Replies are sent
numbered ("Reply 1", "Reply 2"), not identified. The app maps sequential ids
back to modelIds after parsing — that mapping is system integrity, not
judgment. Mentioning models in the arbiter prompt is bias injection: the
arbiter has no way of knowing why the source matters, and it doesn't. The
meaning is in the content.

### On reduction

Reduction is not a subjective call. It is the ordinary act of reading a
sentence and saying what it means — primitively easy once language is learned.
"What's the point", "what's the takeaway", "summarise this", "reduce this to
its essence" all produce essentially the same output from the same input.

So **do not prescribe a length or a format.** v2 said "2-3 sentences"; that was
never intended and it made verdicts verbose. In practice an essence is one
sentence, occasionally two, and it will usually carry at least one logical
chain — so it will rarely be as bare as a single word.

`aye / nay / huh / maybe` in v2 was an **example** for a yes/no question, not a
schema. Reading it as an enum forced a second, separately-composed `verdict`
field to exist — and anything separately composed is an opinion.

### What consensus is NOT

- Not word similarity (token overlap)
- Not sentiment
- Not topicality
- Not a judgment of correctness — a count of convergence

### Ties

The arbiter's only vote. On a tie it may choose, and state the logical basis in
one line. Nowhere else does its judgment enter.

**Nothing is filtered.** Every reply reaches the arbiter, errors included.

*Reversed 2026-08-08 by the owner.* This previously read "Non-responsive
replies and errors count toward neither side and are filtered out **before**
the arbiter sees them," and that was wrong for the same reason a `verdict`
field was wrong: it decided something before the reading happened.

An error is an observation. "That didn't go through", "error code 400" and
"the model is unavailable right now" all reduce to one essence — *the model is
not available* — and against a need like "which model am I talking to?" that
essence is as informative as a successful identification. It resolves the
user's question to **undefined** rather than **defined**. Both are readings.
Dropping one shrinks the denominator and hides a real state of the board.

The implementation additionally discarded self-identifications and any reply
under 40 characters. That was never authorised here and is also gone.

---

## 2. Logical Chain Counting

A logical chain is every instance of logic — explicit or implied — in a
response: the traceable path from premise to conclusion.

**Counted against the raw response, never against the essence.** These are two
separate passes over two different texts. Counting chains in a gist counts the
chains of the summary, not of the argument.

### What counts

Every explicit connective: *because, so, therefore, thus, hence, consequently,
as a result.*

Every instance of implied logic:
- **Definitions used to support a claim** — "that's about $0.34" translates
  energy into money to serve meaning
- **Clarifications that add meaning** — explanations in service of the argument
- **Preemptive challenges to presumptions** — "even with heavy usage"
  anticipates and dismisses a counterargument

Anything serving explanation, clarification or deeper understanding is a chain.

### The 5 Whys test

After each independent clause, ask "why?". Where the answer is neither given
nor bridged by implied logic, the chain broke. The break coincides with the end
of the claim.

### Worked example

> "Don't bother worrying about leaving your laptop plugged in all day **even**
> with heavy usage. You aren't draining much energy **[because]** your charger
> is only rated 45w, **so** at most you are capped at around 1kWh in one day.
> **That's** about $0.34 a day. **So** you're looking at a negligible impact."

| # | Marker | Type | What it does |
|---|---|---|---|
| 1 | [BECAUSE] | implicit | Bridges claim to reasoning |
| 2 | EVEN | implied | Challenges a presumption |
| 3 | BECAUSE | plain | Establishes the constraint (45W) |
| 4 | SO | plain | Derives the cap (≤1kWh/day) |
| 5 | THAT'S | implied (definition) | Translates energy to money |
| 6 | SO | plain | Derives the conclusion |

**Chain depth: 6.**

### Scale

| Depth | Character |
|---|---|
| 0 | Bare assertion. No traceable logic. |
| 1–2 | Single justification. |
| 3 | Average substantive response. |
| 4–6 | Structured argument with qualification and definition. |
| 7+ | Multi-step, counterargument-aware, nested. |

No upper cap. A 12-step argument is depth 12.

---

## 3. The Two Axes

### Size = chain depth (earned)

```
sphereSize = 14 + chainDepth × 6   (px)
```

Structural mass, earned by reasoning. Not granted by agreeing.

### Luminance = popularity (superficial)

Glow opacity and radius scale with the consensus ratio.

| Ratio | Opacity | Radius |
|---|---|---|
| 2/6 (0.33) | 0.33 | 26px |
| 4/6 (0.67) | 0.52 | 38px |
| 6/6 (1.00) | 0.70 | 50px |

This is the correct physical *and* metaphorical reading: brightness is
popularity, and **popularity is not quality**. Everything that glitters ain't
gold. Brightness claims credit for work the logic did.

**Luminance applies to the nucleus only.** Individual spheres do not glow by
consensus count — they are not the consensus.

---

## 4. The Nucleus

**Size — inherited depth.** The consensus takes the chain depth of its
*deepest* member.

```
nucleusChainDepth = max(chainDepth of each agreeing claim)
nucleusSize       = 14 + nucleusChainDepth × 6
```

Three claims with 0 chains agreeing with one that reasoned four steps produce a
depth-4 nucleus. The assertions piggyback. This is the mechanism of consensus
and the source of its power — it is why people conform: a reliable floor to
fall on.

**Luminance — headcount.** Superficial authority. Brightness, not mass.

| Scenario | Size | Luminance | Read |
|---|---|---|---|
| 5/6 agree, deepest has 4 | 38px | bright | Popular and reasonably deep |
| 5/6 agree, deepest has 1 | 20px | bright | Popular but hollow. Glittering, not gold. |
| 2/6 agree, deepest has 6 | 50px | dim | Deeply reasoned, unpopular |
| 6/6 agree, deepest has 5 | 44px | blazing | Deep and unanimous. The real thing. |

---

## 5. Individual Spheres

Every sphere — agreeing or dissenting — is sized by **its own** chain depth.

```
size = 14 + chainDepth × 6
```

A depth-7 dissenter (56px) orbiting a depth-2 nucleus (26px) is physically
larger than the consensus. It carries more structural reasoning than the entire
majority. That is the alarm signal, and it should be impossible to miss.

A depth-0 dissenter (14px) against a depth-5 nucleus (44px) asserted without
reasoning. Dismissible.

Consensuses are often shallow (~3 chains for a substantive response), which is
exactly what makes a deep dissenter meaningful.

---

## 6. Position

### Clustering

**Matched essences sit together.** Claims saying the same thing cluster,
whatever their depth. This is prior to any force.

### Pull is shared logic

Every claim is matched against every other claim, the consensus included.
**Each shared chain link is a unit of pull between that pair.** Net position is
the sum.

Matching 3 links pulls harder than matching 2 — so a shallow consensus can lose
a dissenter to a deeper dissenter that walked more of the same road.

Attraction is *earned by shared reasoning*. Two claims can reach the same
conclusion having shared no logic; the map must show them apart.

> v2 used `affinity = 1 − |sᵢ − sⱼ|` — similarity of alignment *scores*. That
> drew claims together for scoring alike, not for reasoning alike. It is the
> mechanism this section replaces.

### Zero chains exert nothing

```
y = mx + b
```

`m` is logic. Without it there is only `b` — ego, self-reference. A constant:
static, uninfluential, nonsense.

**A claim with 0 chains exerts no pull and is subject to none.** It is
unsupported, which is to say it is bias. It may sit anywhere relative to the
consensus; its position carries no information because it earned none.

### Counting, not calculating

Position follows from link counts. It should be readable off those counts, not
the output of an opaque solver. **Logic is the only real multiplier**;
everything else here is addition. If a step cannot be shown transparently, it
is probably not needed.

---

## 7. The Data Model

The arbiter reports observations. Every derivation below is arithmetic
performed by the app.

```json
{
  "claims":  [{ "modelId": "<id>", "essence": "<statement>", "chains": 0 }],
  "groups":  [["<id>", "<id>"], ["<id>"]],
  "matches": { "<idA>|<idB>": 0 },
  "tieBreak": { "group": ["<id>"], "because": "<one line>" }
}
```

| Field | Meaning |
|---|---|
| `essence` | The response reduced to a standalone statement. Copied to the UI verbatim. |
| `chains` | Logical chains in the **raw** response. 0 = bare assertion. Uncapped. |
| `groups` | Claims saying essentially the same thing. Largest = consensus. |
| `matches` | Chain links each pair shares. Drives pull. |
| `tieBreak` | Present only on a tie. |

Derived by the app, not the arbiter:

- consensus group = largest group
- **summary = the winning essence, verbatim**
- dissenting views = every other essence, verbatim
- ratio = `group.length / claims.length`
- nucleus depth = max depth within the group
- position = pull from `matches`

> **There is no `verdict` and no `scores`.** v2 had both. `verdict` is a
> ruling — this is a headcount. `scores` was a 0–1 alignment scalar that
> nothing in the system asked for, and it is where judgment re-entered: it let
> the arbiter grade instead of report.

### Fallback

Arbiter unreachable → arithmetic, never another model's opinion.

- essence: first sentence (mechanical)
- chains: **0 for every claim** — unknown means no traceable logic, not a
  mid-range guess. With 0 chains there are no links, so the map honestly shows
  it knows nothing about depth.
- grouping: token overlap, and only because nothing better exists offline

Dissent is **never** spliced into the summary. It has its own field.

---

## 8. The Arbiter Contract

**Told:** the question, and the wire format.

**Not told:** how to sound. What words to avoid. That it is "impartial". What
the user wants to hear. How long the essence should be. How to reduce.

Errors are no longer an exception here either. It is not told "how to handle
errors" because errors need no handling — an error is a reply, it is read like
a reply, and it reduces like a reply.

The one thing likely worth stating is **how a chain is counted** — that
definition is genuinely non-obvious. Everything else in §1 is ordinary reading
comprehension and needs no instruction.

### Immutable

1. No bias injection.
2. No behavioural conditioning — no banned-word lists, no register policing.
3. The arbiter reasons from intent, not from instructions about how to sound.
4. **Nothing is filtered. It sees every reply, errors included.** (Reversed
   2026-08-08; this used to say the opposite. See §1 Ties for why.)
5. Its judgment enters at exactly one point: a tie.
6. **temperature 1** — the reference setting for a reasoning model, and the
   setting this judge is tuned for. Running it colder does not buy
   repeatability (measured 2026-08-08: four runs over identical input returned
   3/4, 1/4, 2/4, 1/4 at temperature 0, and a fixed seed changed nothing), and
   it narrows the reasoning toward the most obvious reading rather than the
   most accurate one — an outside influence on the observation, which is the
   one thing this contract exists to prevent. Consistency between views is
   bought by running the arbiter ONCE per board and sharing the result, not by
   constraining how it thinks.

> Telling a model to be impartial trains it to *perform* impartiality. Every
> rule added to a prompt is usually a symptom of a missing input — the arbiter
> reciting instead of reducing was caused by never being given the question.

---

## 9. Canonical Reads

| Picture | Read |
|---|---|
| Small bright nucleus, large dim dissenter | Popular but hollow; the dissenter has the substance. Investigate. |
| Large bright nucleus, tiny distant dissenter | Strong consensus with structural backing. Dissenter is noise. |
| Roughly equal spheres, dim nucleus | Split field, no winner. Treat the summary as weak. |
| Large blazing nucleus, no dissenters | Deep and unanimous. High confidence. |
| Large blazing nucleus, large *close* dissenter | The dissenter walked the same road and diverged late. **The most important dissent to read.** |

---

## 10. Why It Matters

The user can always investigate further — add a model, remove one, rephrase,
continue. What the map provides is access to clarity that is otherwise
unavailable: you cannot reach these conclusions without being able to see the
shape.

Validation at the press of a button. Not a gimmick — a view that unlocks
meaning, and that you cannot go back to working without.

---

## 11. Implementation Map

| Concept | File | Symbol |
|---|---|---|
| Result contract | `services/chat.ts` | `ConsensusResult`, `ConsensusClaim` |
| Arbiter prompt | `services/chat.ts` | `scoreConsensus` → `sys` |
| Pair key | `services/consensusView.ts` | `matchKey` |
| Fallback (chains 0) | `services/chat.ts` | `fallbackConsensus` |
| Consensus, summary, dissent | `services/consensusView.ts` | `deriveConsensus` |
| Sphere sizing | `services/consensusView.ts` | `sphereSize` |
| Position from matches | `services/consensusView.ts` | `layoutByMatches` |
| Nucleus luminance | `services/consensusView.ts` | `glowOpacity`, `glowRadius` |
| Web scene (reads positions, never re-solves) | `components/consensus-scene-template.ts` | `computePositions` |
| Tests, against the real source | `scripts/tests/consensus.test.mjs` | — |

---

## 12. What v2 Got Wrong

Recorded so the drift is recognisable if it returns. Every one of these moved
authority toward the arbiter.

| v2 said | Correct |
|---|---|
| "Consensus is logical chain analysis, **not polling**" | Consensus **is** a headcount. Chains govern size and position only. |
| Simplify to `aye / nay / huh / maybe` | That was an *example* for a yes/no question. Reduce to the **essence** — a statement. |
| `verdict`: "2-3 sentences" | No length prescription. One sentence, occasionally two, naturally. |
| `verdict` as a composed field | The winning **essence is** the summary, verbatim. |
| `scores`: 0.0–1.0 alignment | No scalar. Group by matched essence and count. |
| Pull from score affinity | Pull from **shared chain links**. |
| — | 0 chains ⇒ no pull, no influence, position uninformative. |
| — | Chains counted from the **raw response**, not the essence. |
