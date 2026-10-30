# Collider build-time dart-defines

Provider keys are **not** shipped in the public GitHub Pages bundle.
They are compiled in at build time via `--dart-define=NAME=value`.

## Exact define names the build expects

| Dart define | Env var (box / CI) | Used by |
|-------------|--------------------|---------|
| `OPENROUTER_KEY` | `COLLIDER_OPENROUTER_KEY` | Home / Genie text via OpenRouter (`media_gen.dart`) |
| `CRAZYROUTER_KEY` | `COLLIDER_CRAZYROUTER_KEY` | CrazyRouter text wire |
| `NVIDIA_KEY` | `COLLIDER_NVIDIA_KEY` | NVIDIA integrate API |
| `COMMANDCODE_KEY` | `COLLIDER_COMMANDCODE_KEY` | CommandCode |
| `OPENCODE_KEY` | `COLLIDER_OPENCODE_KEY` | OpenCode Zen |
| `MINIMAX_KEY` | `COLLIDER_MINIMAX_KEY` | MiniMax |
| `COLLIDER_PROXY` | `COLLIDER_PROXY` | CORS proxy for NVIDIA / OpenCode browser calls |
| `COLLIDER_THEMES` | `COLLIDER_THEMES` | Themes JSON URL (has default) |

Source of truth: `lib/core/api/media_gen.dart` (`String.fromEnvironment(...)`).

## Reliable Home / Genie replies

Without keys, text falls through to the Pollinations keyless floor
(`openai-fast`), which is quota-limited. Drop an OpenRouter key into the
box env and rebuild:

```bash
export COLLIDER_OPENROUTER_KEY='sk-or-...'   # never commit / never echo
./tool/build_web.sh
```

`tool/build_web.sh` maps `COLLIDER_OPENROUTER_KEY` → `--dart-define=OPENROUTER_KEY=...`
(and the other `COLLIDER_*` env vars above) **without printing key values**.

Empty / unset env vars omit the define (same as today's keyless Pages build).
