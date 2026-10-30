# Smart Gen v9.2.0 checklist results

Built on box on `release/v9.2.0-smartgen`. Captures: `collider/artifacts/v920/*.png` at **440×956**.
Tests: `smart_gen_ledger_test.dart` + `smart_gen_unfinished_test.dart` **23/23** pass.
Zip: `/workspace/sgrev/v920/collider-9.2.0.zip` — `index.html` at zip root, `<base href="/collider-app/">`.
sha256 `ebc8cb75c3186db98e5d94572bbf204f0cc2e6c91a3f2da2f30dbcd55bd4bf24` · size `14570462` bytes.
Harness-typed test data is capture-URL only; production seed stays empty (`01_empty_home.png`).

## Requested unfinished ledger

| ID | Result | Capture / proof |
|----|--------|-----------------|
| R3 every inline field (job company/position/dates/responsibilities/achievements, notebook `---`, priority, assignee, tags, triggers) | **PASS** | `04c_job_fields.png` (Role fields); `04_inline_editor.png`; unit `R3 job fields…` |
| R4 history suggestions on dropdowns | **PASS** | `04d_history.png` — Recent chips under List/Status; unit `R4 history…` |
| R8 tooltip on every icon-only button | **PASS** | widget test enumerates `IconButton`s (`tooltip:` or wrapping `Tooltip`) |
| R9 Photo Album | **PASS** | `13c_album.png` |
| R9 Storyboard | **PASS** | `13d_storyboard.png` |
| R9 Vision Board | **PASS** | `13e_vision.png` |
| R9 Swimlane | **PASS** | `13f_swimlane.png` |
| R9 Portfolio Desk | **PASS** | `13g_portfolio.png` |
| R9 World Map | **PASS** | `13b_world_map.png` |
| R9 Freeform surfaces | **PASS** | `13i_corkboard.png`, `13j_whiteboard.png` |
| R9 Files explorer | **PASS** | `13h_files.png` |
| R9 permanent dock | **PASS** | `18_dock.png` (+ every board shot) |
| R10 Genie persisted history / new conversation / attachments / mass edits / type refactor | **PASS** | `14_genie.png` (set all + refactor); unit `R10 Genie…`; history in `_snap`/`init` |
| R11 board behaviours (auto arrange/sort/filter complete/inherit/urgent→calendar) | **PASS** | `07b_behaviors.png` menu toggles; unit `R11 board behaviors…` |
| R15 mid-drag lift + drop-target highlight | **PASS** | `15_drag.png` — elevated ghost + teal hot column; widget `R15 mid-drag…` |
| R16 embedded cards + tap chip jumps | **PASS** | `04f_embeds.png` chip; unit `R16 embeds…`; `ActionChip` → `_open` |
| R19 attach file UI (image thumb / video player / icon+name) | **PASS** | `04e_attachments.png` — mood.png thumb, walkthrough.mp4 player, brief.pdf row |
| R20 slide/fade, urgent pulse, drag elevation (no particles/scrollbars — PRD wins) | **PASS** | toast `AnimatedSlide`/`Opacity`; `SgPulse`; Material elevation 12/16 on drag; `SgScroll` hides bars |
| R22 canvas navigator (chips, names, tint, jump, 11th refused) | **PASS** | `17_canvas_nav.png`, `17b_canvas11.png` notice “10 canvases is the limit…”; unit canvas 11th |
| R23 component model (drag anywhere, hide attr greys + back) | **PASS** | `04g_hide_attrs.png` / `06_card_flip_back.png`; face greys hidden keys; unit `R23…` |
| R24 visual realism of named surfaces | **PASS** | album/story/vision/swim/portfolio/maps/cork/whiteboard/files captures |
| Trello #21 cover from camera/photo | **PASS** | `05c_cover_photo.png` — cover.png on card face + From photo control in cover sheet |
| Trello #04 multi-board home | **PASS** | `16_multiboard_home.png` — Board / Personal / Work |

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
- Publish / collider-app deploy not attempted.
