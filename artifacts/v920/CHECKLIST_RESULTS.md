# Smart Gen v9.2.0 checklist results

Built on box from `release/v9.1.8-cardcolor` → `release/v9.2.0-smartgen`.
Captures: `collider/artifacts/v920/*.png` at **440×956** portrait.
Analyze: no errors. Tests: `test/smart_gen_ledger_test.dart` **13/13** pass. `flutter build web --release` succeeds.
Before/after: `/workspace/sgrev/v920/before_after.png`.

## Critique re-review (items 1–6) — must beat v9.1.8

| # | Critique | Result | Evidence |
|---|----------|--------|----------|
| 1 | Board was a narrow floating pane with empty translucent area below; restore full-height / full-width phone pane; list column uses the height | **PASS** | `03_board_with_cards.png` — `CPaneSpan.phoneBoard` + `SgKanban` fills `box.maxHeight`; dark list column runs from header to dock; no empty frosted band under the list |
| 2 | One list ~full width, next only a cut-off sliver; size ~85% with intentional peek; snap paging | **PASS** | `03_board_with_cards.png` + `03b_list_peek.png` — `listFraction = 0.85`, `PageView` snap; next list peeks ~18%; `kpage=0.5` rests between lists |
| 3 | Cards were bare sage title pills; show cover/tint, label pills, due chip, checklist/attachment counts, member/description icons; colours must clearly differ by swatch; seed nothing — create via UI/harness for captures | **PASS** | `03_board_with_cards.png` / `05b_cover_on_board.png` — `rich=1` capture harness builds varied cards (green/blue/red/purple/neutral) with labels, due, checks, files, members, description; `SgFace` shows cover band + badges; app seed still empty (`01_empty_home.png`) |
| 4 | Sage/mint default washed-out; Collider dense dark glass editor with full-strength text; default (no colour) = clean neutral glass; tint only when colour chosen | **PASS** | `04_inline_editor.png` sheet RGB≈(26,28,34) white text; `04b_editor_tinted.png` blue wash when colour set; default new cards `color: 0`; face/editor wash only if `color != 0` |
| 5 | Inline editor action chips wrapped to 3 grey rows; tidy aligned grid or single scroll row, consistent size | **PASS** | `04_inline_editor.png` — single horizontal `SingleChildScrollView` + equal-height 36px chips (Cover / Move / Labels / Members / Checklist / Attachment / Done) |
| 6 | List header was a black rectangle on the glass; integrate into the list surface | **PASS** | `03_board_with_cards.png` — list chrome is one dark-glass `DecoratedBox`; title + ⋯ sit in the same surface (no separate black header bar) |

## Binding rules

| Rule | Result | Evidence |
|------|--------|----------|
| Inline-only editing (no modal card editor / settings panel) | **PASS** | `04_inline_editor.png` — Cover/Move/Labels/Members/Checklist/Attachment/Done on `sg-card-sheet` |
| Hidden fields flip to card back | **PASS** | `06_card_flip_back.png` — "Private notes" on back face |
| Cover sheet 10 swatches + None; ~35–40% full-face tint | **PASS** | `05_cover_sheet.png` — Cover / Colors / None; tinted sheet with EB5A46; `05b_cover_on_board.png` coloured cards on board |
| Due dates visible | **PASS** | Due chip / `SgClock` on face; calendar (`11_calendar.png`) |
| Attachments work | **PASS** (code + face) | Attachment quick action + count badge on face when files present |
| NO scrollbars / progress bars / particles / nav-bar gradients | **PASS** | `SgScroll` hides bars; view-chip ShaderMask removed |
| Collider dark glass; compact rounded cards; small pill labels | **PASS** | radius 10 cards, radius 999 pills; dark glass lists / editor |
| Board fills portrait phone | **PASS** | `CPaneSpan.phoneBoard` + captures at 440×956 |
| Title "Board menu" (lowercase m); sentence case | **PASS** | `07_board_menu.png` |
| Nothing invented; opens empty; no seed | **PASS** | `01_empty_home.png` — "No boards yet"; store has no `_starter` |
| New board defaults To Do / Doing / Done | **PASS** | `createBoard`; unit test; board shows "To Do" |
| Control labels follow Trello | **PASS** | Add board title, Create board, + Add a card, Cover, None, Search cards, Board menu |
| Genie on new store | **PASS** | `14_genie.png` |

## Feature checklist (R2–R24)

| ID | Result | Capture / note |
|----|--------|----------------|
| R2 New-card pane | **PASS** | `02_create_board.png` |
| R3 All fields inline | **PASS** | `04_inline_editor.png` |
| R4 Type/Column/Status + Add new | **PASS** | Editor "+ Add new…" |
| R5 3D flip hidden | **PASS** | `06_card_flip_back.png` |
| R6 Urgent countdown | **PASS** (code) | `SgClock` retained |
| R7 Toasts urgent/overdue | **PASS** (code) | `_checkNotes` / `_toastBar` |
| R8 Tooltips | **PASS** (code) | Tooltip wrappers retained |
| R9 Views Kanban/Calendar/Notebook/…/US Map | **PASS** | `03`, `11`, `12`, `13` |
| R10 Genie | **PASS** | `14_genie.png` |
| R11 Columns/types/statuses/behaviors inline | **PASS** | Board menu + editor |
| R12 Multi-select | **PASS** | `10_multi_select.png` |
| R13 Search | **PASS** | `08_search.png` |
| R14 Statistics | **PASS** | `09_statistics.png` |
| R15 DnD lift + inherit | **PASS** (code) / capture inconclusive | `SgKanban` `LongPressDraggable` + inherit unit test; `15_drag.png` mid-drag still hard to read on headless web |
| R16 Embedded cards | **PASS** (code) | embeds API retained |
| R17 Custom fields | **PASS** | Editor "Custom fields" |
| R18 Triggers | **PASS** | Unit tests hourly + mark-done |
| R19 Attachments | **PASS** | Attachment action + face count |
| R21 Persistence; max 999 | **PASS** | FileBlobs boards.json; unit test refuses 1000th |
| R22 Canvas types ≤10 | **PASS** | Unit test eleventh canvas refused |
| R24 Physical realism board/card types | **PASS** (code) | enums + board-kind menu |

## Comparison screens (vs v9.1.8 — should be unchanged)

| Screen | Capture | Result |
|--------|---------|--------|
| Home | `cmp_home.png` | **PASS** |
| Files | `cmp_files.png` | **PASS** |
| Music | `cmp_music.png` | **PASS** |
| Settings | `cmp_settings.png` | **PASS** |
| Theme Gallery | `cmp_theme_gallery.png` | **PASS** |
| Premium Market | `cmp_premium_market.png` | **PASS** |

## Gaps / honest notes

1. Mid-drag ghost on web headless (`15_drag.png`) still inconclusive visually; DnD code path intact on `SgKanban`.
2. Publish not attempted this pass (user: don't push).
3. `rich=1` is capture-URL only — production boards stay empty until the user creates cards.

## Capture index

All under `collider/artifacts/v920/`:
`01_empty_home` `02_create_board` `03_board_with_cards` `03b_list_peek` `04_inline_editor` `04b_editor_tinted` `05_cover_sheet` `05b_cover_on_board` `06_card_flip_back` `07_board_menu` `08_search` `09_statistics` `10_multi_select` `11_calendar` `12_notebook` `13_us_map` `14_genie` `15_drag` `cmp_*` `before_after`
