# Collider web `--dart-define` keys

Production **web** builds must ship **no provider secrets**. The browser calls
`COLLIDER_PROXY` (Cloudflare Worker `collider-keys`), which holds the keys.

`tool/build_web.sh` maps env → `--dart-define` without printing values.
Embedded key dart-defines are gated behind `COLLIDER_ALLOW_EMBEDDED_KEYS=1`
(emergency / non-web only).

| Dart define | Env var | Role |
|---|---|---|
| `COLLIDER_PROXY` | `COLLIDER_PROXY` | Worker base URL. **Default in source:** `https://collider-keys.ebridavid.workers.dev` |
| `COLLIDER_THEMES` | `COLLIDER_THEMES` | Themes/media helper origin (optional) |
| `CRAZYROUTER_KEY` | `COLLIDER_CRAZYROUTER_KEY` | Emergency only — prefer Worker secret `CRAZYROUTER_KEY` |
| `NVIDIA_KEY` | `COLLIDER_NVIDIA_KEY` | Emergency only — Worker `NVIDIA_KEY` |
| `COMMANDCODE_KEY` | `COLLIDER_COMMANDCODE_KEY` | Emergency only — Worker `COMMANDCODE_KEY` |
| `COMMANDCODE_BASE` | `COLLIDER_COMMANDCODE_BASEURL` | Command Code base (Worker `COMMANDCODE_BASE`) |
| `OPENCODE_KEY` | `COLLIDER_OPENCODE_KEY` | Emergency only — Worker `OPENCODE_KEY` |
| `MINIMAX_KEY` | `COLLIDER_MINIMAX_KEY` | Emergency only — Worker `MINIMAX_KEY` |

**Vercel / OpenRouter / Groq are removed** from the app. Vercel may return later
as a Worker secret only (not in the bundle).

## Agent assignments (unchanged)

- **Consensus agent 1** (headcount / groups): MiniMax M3.1 Flash via MiniMax (`mm` → Worker)
- **Consensus agent 2** (logical / link chain): NVIDIA DeepSeek 4.1 Flash (`nv` → Worker)
- **Smart Gen Genie**: MiniMax M3.1 Flash via MiniMax (`mm` → Worker)
