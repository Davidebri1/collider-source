# Account sync inventory

Source tip: `smartgen/planka-dropin` @ `0546adb`, branch `account-sync`.
Every place Collider persists user state today, and where it must go through AccountSync.

## Legend

- **User data** — must sync to the account server when signed in.
- **Cache** — regenerable; stays local via AccountSync with `sync: false`.
- **Temp** — playback scratch; never syncs.
- **Auth UI** — Account sheet; no real session yet.

---

## 1. Auth / Account

| Store | File:line | Shape | Class |
|-------|-----------|-------|-------|
| Account sheet | `lib/features/account/account_sheet.dart:72-73` | Tap "Sign in" → alert "Sign in with Apple is unavailable" | Auth UI |
| Settings → Account | `lib/features/drawers/settings_drawer.dart:129-254` | Opens AccountSheet | Auth UI |
| Planka AuthProvider | `packages/smartgen_planka/lib/providers/auth_provider.dart` | Local-only stub; no server login | Auth UI |

Today there is **no** working sign-in, session, or account id. Plan/Credits rows are display-only.

---

## 2. SharedPreferences (user data)

| Key | File:line | Shape | Feature |
|-----|-----------|-------|---------|
| `collider.wallpaper.themeId` | `lib/main.dart:203,347-365` | `String` theme id | Wallpaper |
| `collider_local_history_v1` | `lib/main.dart:688-702,726-750` | JSON `{global:[session], local:{modelId:[session]}}` | Chat history |
| `collider_active_chat_v1` | `lib/main.dart:689,703-720,754+` | JSON `{prompt, promptTime, items:[{modelId,summary,messages}]}` | Active chat |
| `hist_hidden_v1` | `lib/core/vision/selection.dart:139-151` | `List<String>` session ids | History edits |
| `hist_titles_v1` | `lib/core/vision/selection.dart:141-152` | `List<String>` of `id\\u0001title` | History renames |
| `collider_files_v1` | `lib/core/files/file_store.dart:58,96-125` | JSON `[StoredFile]` metadata | Files |
| `theme_pack_unlocked_ids` | `lib/features/theme/theme_pack_store.dart:32,89-157` | `List<String>` pack ids | Theme Market |
| `theme_store_subscription_active` | `lib/features/theme/theme_pack_store.dart:33,94-151` | `bool` | Theme Market |
| `music_widget_pos_v1` | `lib/features/music/floating_music.dart:34,104-117` | `"dx,dy"` | Music widget |
| `music_widget_on_v1` | `lib/features/music/floating_music.dart:35,43-50` | `bool` | Music widget |
| `theme_list_r2_v2` | `lib/core/media/theme_catalog.dart:87,146-381` | JSON string of remote themes.json | Theme catalog **cache** |

## 3. FileBlobs (IndexedDB web / disk native)

| Blob id / pattern | File:line | Shape | Feature |
|-------------------|-----------|-------|---------|
| `smartgen/planka.json` | `lib/features/smartgen/screens/smartgen_screen.dart:54,69-73` | UTF-8 PlankaStore JSON | Smart Gen (live) |
| `smartgen/boards.json` | `lib/features/smartgen/sg_model.dart:616,669-797` | UTF-8 SgStore JSON | Smart Gen (legacy kinds) |
| `smartgen/kanban.json` | `lib/features/smartgen/kanban_store.dart:55,76-95` | UTF-8 kanban JSON | Smart Gen (legacy) |
| Attachment ids | `smartgen_screen.dart:81-83` via Planka hooks | binary | Smart Gen attachments |
| StoredFile.id | `lib/core/files/file_store.dart:149,174,183,209` | binary file bytes | Files |
| first-frame keys | `lib/core/media/first_frame.dart:26-37` | video poster bytes | Media **cache** |
| Legacy migrate | `lib/features/smartgen/planka_migrate.dart:25-57` | reads boards/kanban → writes planka | One-shot |

Native path: `collider_files/<id>` under app support (`file_blobs_native.dart`).
Web DB: IndexedDB `collider_files` / store `blobs` (`file_blobs_web.dart`).

## 4. Temp (never sync)

| Path | File | Notes |
|------|------|-------|
| `play_*` under temp dir | `audio_source_native.dart`, `video_source_native.dart` | Playback scratch |
| Temp export | `file_blobs_native.dart:72-75` | openExternal helper |

## 5. In-memory that should persist (already covered by prefs/blobs above)

| State | Where | Persistence today |
|-------|-------|-------------------|
| PlankaStore boards/cards/lists/… | `packages/smartgen_planka/lib/local/planka_store.dart` | via `onSave` → FileBlobs `smartgen/planka.json` |
| SgStore boards | `lib/features/smartgen/sg_model.dart` | FileBlobs `smartgen/boards.json` |
| FileStore list | `file_store.dart` | prefs + blobs |
| Ticker / home chat | `main.dart` | `_persistLocalHistory` |
| Theme unlocks | `theme_pack_store.dart` | prefs |
| Music widget | `floating_music.dart` | prefs |

## 6. Not persisted (and not account data)

- Composer draft text (session only)
- Media gen stage thumbnails until "Save to Files" (then Files)
- Market prompt feed (source Supabase feed is dead; D62)
- Provider API keys (Cloudflare Worker secrets only; never in client)

## 7. Existing server

| Service | Role |
|---------|------|
| `https://collider-keys.ebridavid.workers.dev` | Chat proxy; holds provider keys. No user records. |
| Cloudflare R2 (wallpapers / themes) | Public media catalog, not per-account |

**Gap:** no account-scoped records or blobs API. That is what AccountSync + `server/worker` add.
