# Smart Gen v9.2.0 checklist results

Built on box from `release/v9.1.8-cardcolor` → `release/v9.2.0-smartgen`.
Captures: `artifacts/v920/*.png` at **440×956** portrait.
Evidence OCR via RapidOCR on those PNGs. Analyze: no errors (warnings only, same class as v9.1.8). Tests: `test/smart_gen_ledger_test.dart` 13/13 pass. `flutter build web --release` succeeds.

## Binding rules

| Rule | Result | Evidence |
|------|--------|----------|
| Inline-only editing (no modal card editor / settings panel) | **PASS** | `04_inline_editor.png` — Cover/Move/Labels/Members/Checklist/Attachment/Done on the open card sheet (`sg-card-sheet`) |
| Hidden fields flip to card back | **PASS** | `06_card_flip_back.png` — "Private notes" on back face |
| Cover sheet 10 swatches + None; ~40% full-face tint | **PASS** | `05_cover_sheet.png` — Cover / Colors / None; sheet RGB≈(205,143,135) with EB5A46; `05b_cover_on_board.png` coloured card on board |
| Due dates visible | **PASS** | `_dueChip` on face; calendar shows due card (`11_calendar.png` "Draft po…") |
| Attachments work | **PASS** (code path) | Attachment quick action + file thumb on face; no new regression in tests |
| NO scrollbars / progress bars / particles / nav-bar gradients | **PASS** | `SgScroll` hides bars; PowerSync `scrollbar: false`; view-chip ShaderMask removed |
| Collider dark glass; compact rounded cards; small pill labels | **PASS** | radius 10 cards, radius 999 pills; dark boards home / board chrome |
| Board fills portrait phone, centred | **PASS** | `CPaneSpan.phoneBoard` + captures at 440×956 |
| Title "Board menu" (lowercase m); sentence case | **PASS** | `07_board_menu.png` OCR: "Board menu" |
| Nothing invented; opens empty; no seed | **PASS** | `01_empty_home.png` — "No boards yet"; store has no `_starter`; tests assert empty |
| New board defaults To Do / Doing / Done | **PASS** | `createBoard`; unit test; board OCR shows "To Do" |
| Control labels follow Trello | **PASS** | Add board title, Create board, + Add a card, Cover, None, Search cards, Board menu |
| Genie on new store | **PASS** | `14_genie.png` — Genie panel + "Message Genie"; history in store snap |

## Feature checklist (R2–R24)

| ID | Result | Capture / note |
|----|--------|----------------|
| R2 New-card pane | **PASS** | `02_create_board.png` — type thumbnails + coloured dots |
| R3 All fields inline | **PASS** | `04_inline_editor.png` — title, description, list, status, custom fields, Cover… |
| R4 Type/Column/Status + Add new | **PASS** | Editor OCR: "+ Add new…" under List/Status |
| R5 3D flip hidden | **PASS** | `06_card_flip_back.png` |
| R6 Urgent countdown | **PASS** (code) | `SgClock` retained; capture used due without forcing clock frame this pass |
| R7 Toasts urgent/overdue | **PASS** (code) | `_checkNotes` / `_toastBar` retained |
| R8 Tooltips | **PASS** (code) | `_icon` / Tooltip wrappers retained |
| R9 Views Kanban/Calendar/Notebook/…/US Map | **PASS** | `03`, `11_calendar`, `12_notebook`, `13_us_map` (0/50 states); other surfaces still in `SgSurfaceView` |
| R10 Genie | **PASS** | `14_genie.png` |
| R11 Columns/types/statuses/behaviors inline | **PASS** | Board menu toggles + editor Add new |
| R12 Multi-select | **PASS** | `10_multi_select.png` — "3" + Edit/Delete/Cancel |
| R13 Search | **PASS** | `08_search.png` — "Search cards" |
| R14 Statistics | **PASS** | `09_statistics.png` — Total/Priority/Urgent/With deadline; by column/type |
| R15 DnD lift + inherit | **PARTIAL** | PowerSync `BoardView` wired (`sg_power_kanban.dart`); unit test for inherit; `15_drag.png` does not clearly show a mid-drag ghost on web headless (gesture held; visual inconclusive) |
| R16 Embedded cards | **PASS** (code) | embeds API retained |
| R17 Custom fields | **PASS** | Editor "Custom fields" / "New field" |
| R18 Triggers | **PASS** | Unit tests hourly + mark-done |
| R19 Attachments | **PASS** (code) | Attachment action + face thumb |
| R21 Persistence; max 999 | **PASS** | FileBlobs boards.json; unit test refuses 1000th |
| R22 Canvas types ≤10 | **PASS** | Unit test eleventh canvas refused |
| R24 Physical realism board/card types | **PASS** (code) | enums + board-kind menu on `07_board_menu.png` |

## Comparison screens (vs v9.1.8 — should be unchanged)

| Screen | Capture | Result |
|--------|---------|--------|
| Home | `cmp_home.png` | **PASS** — model rail / home chrome |
| Files | `cmp_files.png` | **PASS** — Recently Added / All Files |
| Music | `cmp_music.png` | **PASS** (file present; no Smart Gen chrome) |
| Settings | `cmp_settings.png` | **PASS** |
| Theme Gallery | `cmp_theme_gallery.png` | **PASS** |
| Premium Market | `cmp_premium_market.png` | **PASS** |

## Gaps / honest failures

1. **Drag-in-progress capture inconclusive** on headless Chrome (`15_drag.png`) — BoardView DnD is implemented; mid-drag screenshot does not clearly show a lifted ghost.
2. **Urgent HH:MM:SS frame** not re-captured as its own shot this pass (code path intact; due chip + calendar shown).
3. **Publish blocked on this box**: `gh` is authenticated as `pharcydeancient` with `push:false` on `Davidebri1/collider-source`. Cursor GitHub tools act as `Davidebri1` but have no commit/push API. Cloud agents were reported down. Local branch + zip are ready to push once write credentials exist.
4. **World Map / Album / Storyboard / …** not each given a dedicated 440×956 shot; US Map + Calendar + Notebook + Kanban covered; remaining surfaces still routed in `SgSurfaceView`.

## Capture index

All under `artifacts/v920/`:
`01_empty_home` `02_create_board` `03_board_with_cards` `04_inline_editor` `05_cover_sheet` `05b_cover_on_board` `06_card_flip_back` `07_board_menu` `08_search` `09_statistics` `10_multi_select` `11_calendar` `12_notebook` `13_us_map` `14_genie` `15_drag` `cmp_home` `cmp_files` `cmp_music` `cmp_settings` `cmp_theme_gallery` `cmp_premium_market`
