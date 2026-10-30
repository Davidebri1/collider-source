# Smart Gen v9.2.0 checklist results

Built on box on `release/v9.2.0-smartgen`. Captures: `collider/artifacts/v920/*.png` at **440×956**.
Tests: `smart_gen_ledger_test.dart` + `smart_gen_unfinished_test.dart` + `premium_live_apply_test.dart` — **38/38** pass.
Zip: `/workspace/publish920/collider-9.2.0-complete.zip` — `index.html` at zip root, `<base href="/collider-app/">`.
Harness-typed test data is capture-URL only; production seed stays empty (`01_empty_home.png`).

## Steering (2026-10-30) — tilt + live Premium Set

| Ask | Result | Proof |
|-----|--------|-------|
| Remove all Smart Gen card rotation/tilt (Desk, Cork, Vision, any) | **PASS** | `Transform.rotate` gone from `lib/features/smartgen/`; Desk/Cork upright in `21_desk_upright.png`, `21b_cork_upright.png`, `21c_vision_upright.png` |
| Test fails if any Smart Gen card has non-zero rotation | **PASS** | `Smart Gen cards never use non-zero Transform.rotate` in `smart_gen_unfinished_test.dart` |
| Live premium themes can be Set/Applied as running wallpaper | **PASS** | `themeIsSettable` / `_owned` includes `!purchasesAvailable` on web preview; Premium market shows **Set as wallpaper** for live Alley Wet (`20c_premium_set_live.png`); Home plays R2 mp4 (`20_home_live_theme.png`, `20d_home_live_alley.png` — video element playing `0_Alley_Wet_1280x720.mp4`) |
| R2 / DATA-SOURCES assets reachable outside the app | **PASS** | Worker list + ranged GET of live mp4 in `premium_live_apply_test.dart` |

### 5-whys — live wallpapers could not be set as theme

1. **Symptom:** Tapping the Premium Market capsule on a live (video) theme never made it the running Home wallpaper.
2. **Why?** The capsule showed **Buy** (price), not **Set as wallpaper**, so `onApplyTheme` never ran for those themes.
3. **Why Buy?** `_owned(t)` was false for nearly every premium live loop (`!isPremium || isUnlocked || …` failed).
4. **Why not owned?** Themes were premium (`isPremium: true` from R2 video objects in `ThemeCatalog._r2Theme`) and not in `_unlocked`, and the web preview never unlocks them.
5. **Root cause:** `ThemePackStore.purchasesAvailable = bool.fromEnvironment('COLLIDER_STORE')` is **false** on the web preview build, so Buy always fails under D66 (no fake unlock). Combined with ownership gating Set behind purchase, **Set was unreachable for every unpaid live loop** even though R2 mp4 URLs are valid (CORS + ranged GET OK) and `ThemeLivingBackdrop` can play them. DATA-SOURCES / Worker list was not the failure — the apply path never fired.

**Fix:** `themeIsSettable(t)` treats catalog themes as settable when the store is unavailable (`!purchasesAvailable`), so web preview shows **Set as wallpaper** and `onApplyTheme` runs. Real store builds (`COLLIDER_STORE=true`) still require unlock.

## Requested unfinished ledger

| ID | Result | Capture / proof |
|----|--------|-----------------|
| R3 every inline field (job company/position/dates/responsibilities/achievements, notebook `---`, priority, assignee, tags, triggers) | **PASS** | `04c_job_fields.png`; unit `R3 job fields…` |
| R4 history suggestions on dropdowns | **PASS** | `04d_history.png`; unit `R4 history…` + `R4 + Add new status…` |
| R8 tooltip on every icon-only button | **PASS** | widget test enumerates `IconButton`s |
| R9 Photo Album | **PASS** | `13c_album.png` |
| R9 Storyboard | **PASS** | `13d_storyboard.png` |
| R9 Vision Board | **PASS** | `13e_vision.png` / `21c_vision_upright.png` (no tilt) |
| R9 Swimlane | **PASS** | `13f_swimlane.png` (SgFace glass cards) |
| R9 Portfolio Desk | **PASS** | `13g_portfolio.png` / `21_desk_upright.png` (no tilt) |
| R9 World Map | **PASS** | `13b_world_map.png` |
| R9 Freeform surfaces | **PASS** | `13i_corkboard.png` / `21b_cork_upright.png`, `13j_whiteboard.png` |
| R9 Files explorer | **PASS** | `13h_files.png` (sidebar + preview + sort) |
| R9 permanent dock | **PASS** | `18_dock.png` |
| R10 Genie persisted history / new conversation / attachments / mass edits / type refactor | **PASS** | `14_genie.png`; unit `R10…` |
| R11 board behaviours | **PASS** | `07b_behaviors.png`; unit `R11…` |
| R15 mid-drag lift + drop-target highlight | **PASS** | `15_drag.png` |
| R16 embedded cards + tap chip jumps | **PASS** | `04f_embeds.png` |
| R19 attach file UI | **PASS** | `04e_attachments.png` |
| R20 slide/fade, urgent pulse, drag elevation | **PASS** | unit `R20 urgent pulse…`; `SgPulse` |
| R22 canvas navigator | **PASS** | `17_canvas_nav.png`, `17b_canvas11.png` |
| R23 free-drag + snap/align + hide attrs | **PASS** | `19_vision_free.png`, `19b_vision_snap.png`; unit `R23…` |
| R24 visual realism of named surfaces | **PASS** | album/story/vision/swim/portfolio/maps/cork/whiteboard/files |
| Trello #21 cover from camera/photo | **PASS** | `05c_cover_photo.png`; `applyCoverPhoto` |
| Trello #04 multi-board home | **PASS** | `16_multiboard_home.png` |

## Critique 1–6 (retained)

| # | Result | Capture |
|---|--------|---------|
| 1 full phone pane | **PASS** | `03_board_with_cards.png` |
| 2 ~85% + peek | **PASS** | `03b_list_peek.png` |
| 3 rich faces via harness | **PASS** | `03_board_with_cards.png` |
| 4 dark glass / tint only when coloured | **PASS** | `04_inline_editor.png`, `04b_editor_tinted.png` |
| 5 single chip row | **PASS** | `04_inline_editor.png` |
| 6 integrated list header | **PASS** | `03_board_with_cards.png` |

## Notes
- No “Launch” invented content in empty home or harness titles.
- Review sheet: `review7_live_notilt.png`.
- Shortfalls (unchanged): real AI provider key not wired; Elite / paid store gate only when `COLLIDER_STORE` is set.
- Publish / collider-app deploy not attempted from this agent; deploy request JSON is prepared for the parent.
