# AI-First Re-Engineering Audit — Collider

Run via the `aifirstify` skill (Re-Engineer mode). The skill's detailed
reference files were not installed in this environment (only `SKILL.md`
shipped), so this audit applies the skill's seven named phases using
established AI-first engineering practice rather than the verbatim TechWolf
checklist. Scores are 0–10.

> Scope note: this audits the **repository as an environment for AI-assisted
> development** (how easily an agent can understand and safely change it) — not
> the Collider product's user-facing "AI-first" UX (that's the Smart Gen work
> tracked in the product spec).

## Scorecard

| # | Dimension | Score | One-line verdict |
|---|-----------|:---:|------------------|
| 1 | Foundation | 4 | `CLAUDE.md` exists but is a single behavioral rule — no architecture map, no build/run/test commands, no pointer to the canonical spec. |
| 2 | De-agentification | 7 | Reasonable: deterministic fallbacks exist (market generator, consensus bag-of-words fallback); LLM used where judgment is genuinely needed. |
| 3 | Skill / module extraction | 3 | No repo-level dev skills or sub-agents; the one installed skill (`aifirstify`) is half-installed; guidance lives in long prose docs, not modular units. |
| 4 | Complexity reduction | 2 | `App.tsx` is 3,533 lines / 164 KB; `MarketScreen.tsx` 1,703; `state.tsx` 1,098. Monoliths force whole-file loads for tiny edits. |
| 5 | Context hygiene | 3 | Four overlapping/contradicting spec docs (root `SPEC.md`, `docs/SPEC.md`, `docs/Functional_Requirements_*`, the new uploaded spec). No single source of truth; the font requirement literally contradicts between them. |
| 6 | Safety hardening | 4 | Provider API keys ride in `EXPO_PUBLIC_*` env → bundled into the shipped JS and extractable from any install (flagged in `chat.ts` itself). No tests, no error-boundary audit. Secrets are gitignored; Supabase key is publishable (fine). |
| 7 | Workflow optimization | 2 | No `test`/`lint` scripts, no CI (`.github/workflows` empty), no SessionStart hook, no typecheck gate. `zip` script points at a host-specific `/mnt` path. |

**Overall ≈ 3.6 / 10.** A working, feature-rich app whose *repository* is not
structured AI-first: monolith files + document drift + zero automated gates
make every agent-assisted change slower and riskier than it should be.

## Findings & fixes, prioritized

### P0 — safe, high-value (no product-behavior risk)
1. **Single source of truth.** Promote the current uploaded spec to the one
   canonical `docs/SPEC.md`; retire the stale `SPEC.md`/`PLAN.md`/`docs/SPEC.md`
   duplicates (already deleted on `main`). Removes the font contradiction and
   the "which doc is real" problem.
2. **Real `CLAUDE.md`.** Rewrite as an index: architecture map, run/typecheck
   commands, canonical-spec pointer, key-file guide, conventions (font resolver,
   glass primitives, theme tokens). This is the file an agent reads first.
3. **Automated gates.** Add `typecheck`/`lint` npm scripts and a SessionStart
   hook that runs `tsc --noEmit` so a broken change is caught before work
   continues (matches the `session-start-hook` pattern).
4. **Key-safety note.** Document that `EXPO_PUBLIC_*` provider keys ship in the
   bundle; the real fix (a thin server proxy so keys never reach the client) is
   required before store launch — logged here, not silently ignored.

### P1 — high-leverage but structural (needs explicit go-ahead)
5. **Decompose `App.tsx`.** Extract the components living inside it —
   `Home`, `CardScreen`, `Drawer`, `RightDrawer`, `AuroraField`/`ThemeBackground`,
   `CollideButton`, `SmartGenMark`, `Shell` — into their own files under
   `src/screens` / `src/components` / `src/background`. Biggest single win for
   complexity + context hygiene, but a large refactor of an app that is
   currently working and being actively shipped, so it is gated on your say-so.
6. **Split `MarketScreen.tsx` and `state.tsx`** along the same lines.

### P2 — later
7. Extract repeated screen scaffolding (header + back button + glass surface)
   into one `Screen` wrapper — the spec's "make a template, change parameters"
   principle, applied to the dev code.
8. Add a minimal test for the pure logic (consensus scoring, market pagination,
   Smart Gen dedup) so those can be changed with confidence.

## Recommendation
Do P0 now (safe, and it directly unblocks the product work by killing the spec
drift). Gate P1 behind explicit approval and sequence it *after* the current
product priorities (Market fix → redesign-to-spec), because a 3,500-line
refactor mid-flight risks destabilizing verified screens.
