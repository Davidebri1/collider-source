# Collider web `--dart-define` keys

`tool/build_web.sh` maps `COLLIDER_*` env vars → `--dart-define` without printing values.
Compile-time defaults in `media_gen.dart` apply when an env var is unset.

| Dart define | Env var | Role |
|---|---|---|
| `CRAZYROUTER_KEY` | `COLLIDER_CRAZYROUTER_KEY` | CrazyRouter text + crazy media |
| `NVIDIA_KEY` | `COLLIDER_NVIDIA_KEY` | NVIDIA NIM (needs `COLLIDER_PROXY` in browser, or use Vercel relay) |
| `COMMANDCODE_KEY` | `COLLIDER_COMMANDCODE_KEY` | Command Code |
| `COMMANDCODE_BASE` | `COLLIDER_COMMANDCODE_BASEURL` | Command Code base URL |
| `OPENCODE_KEY` | `COLLIDER_OPENCODE_KEY` | OpenCode (optional) |
| `MINIMAX_KEY` | `COLLIDER_MINIMAX_KEY` | MiniMax direct (Genie + Consensus agent 1) |
| `VERCEL_KEY` | `COLLIDER_VERCEL_KEY` | Vercel AI Gateway CORS relay |
| `COLLIDER_PROXY` | `COLLIDER_PROXY` | Same-origin proxy for non-CORS providers |

OpenRouter and Groq are **removed**.

## Agent assignments

- **Consensus agent 1** (headcount / groups): MiniMax M3.1 Flash via MiniMax direct
- **Consensus agent 2** (logical / link chain analysis): NVIDIA DeepSeek 4.1 Flash (NIM, with Vercel/CR backups)
- **Smart Gen Genie**: MiniMax M3.1 Flash via MiniMax direct
