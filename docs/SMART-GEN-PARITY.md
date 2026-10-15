# Smart Gen parity

The pane is the shared centred glass window from `collider-latest-wip` at `435e06f` (`lib/core/vision/cpane.dart`). It is not full width. The side rail is hidden while Smart Gen is open, because on a phone that rail covers the left edge of the centred pane. Cards, canvases, boards and Genie sit inside the pane. Scrollbars are hidden. Card fronts rest with no flip transform (`before-mirror.png` is the rejected mirrored board; `r01-kanban.png` is the upright board). One list fills the pane and the next list is a horizontal scroll away (`r01-doing.png`). The overdue notice floats and dismisses; it is not in the resting shots. Notebook pages turn with a binding and page dots. A calendar day shows the card title. Field types, board kinds, hold kinds, and hooks are the ones in David's clone.

The attached `smart-gen-trello-clone.tar.gz` was not on disk. The public `Davidebri1/trello-clone` tree is the unmodified 0l1v3rr schema (boards, lists, cards, labels, a description string, an empty Activity stub, guests, stars, a color or image background). The Smart Gen behaviour past that schema is taken from the three binding specs: `spec-unformatted.txt` section 9, `summary.txt`, and `SMART_GEN_REQUIREMENTS.md` R1–R25. `smart-gen-ui.md` was not used.

Photos are 390×844 phone captures under `docs/branch-review/smartgen/`. A starter board named Launch is created when nothing is saved, so the surfaces are reviewable. `callAiApi` is a real function and does not call a provider.

## Trello clone

| Clone feature | Flutter | Evidence |
| --- | --- | --- |
| Boards, lists, cards | Pass. Launch has To Do, Doing, Done and the starter cards. | `r01-kanban.png` |
| Drag a card between lists | Pass. Long-press drag, drop highlight, and the list name is inherited when that behavior is on. Covered by `test/smart_gen_ledger_test.dart`. | `r01-kanban.png` |
| Labels | Pass. Colored chips on the card and in the editor. | `r01-kanban.png`, `r03-editor.png` |
| Tiptap description | Partial. The description is an inline multiline field. It is not a Tiptap document. | `r03-editor.png` |
| Activity | Pass, beyond the clone. The clone's Activity widget is an empty heading. This pane records moves, edits and comments on the card. | `r03-editor.png` |
| Guests | Pass. Sam Rivera is on the board menu. | `r11-menu.png` |
| Stars | Pass. The header star toggles the board. | `r01-kanban.png` |
| Board backgrounds | Partial. Four color washes. The clone's image background is not a separate picker. | `r11-menu.png` |
| Card types and typed fields | Pass. Artifact through Memory, plus string, number, boolean, date, time, datetime fields. | `r02-create.png`, `r03-editor.png` |
| Board kinds | Pass as surfaces: corkboard, clipboard, ledger, desk, binder, slate, plus the section 9 views. | `r24-*.png` |
| Canvases and free drag | Pass. Numbered chips, swipe, drag on the canvas, eleventh refused. | `r22-canvas.png` |
| Craft paper | Partial. Notebook, clipboard and desk use paper colors. There is no port of `globals.css`. | `r09-notebook.png`, `r24-desk.png` |

## Ledger R1–R25

| ID | Result | What the photo shows |
| --- | --- | --- |
| R1 | Pass | Full-surface color wash on the cards, not a left stripe. `r01-kanban.png` |
| R2 | Pass | New opens type thumbnails with a colored dot. A tap creates the card. `r02-create.png` |
| R3 | Pass | Title, description, type, column, status, assignee, due, urgent, tags, hidden notes, notebook, triggers, job fields, checklist, members, files, custom fields and embeds are inline on the card. `r03-editor.png` |
| R4 | Partial | Column and status offer `+ Add new…` and the new value becomes a list. Previously used values are not suggested as history chips. `r03-editor.png` |
| R5 | Pass | The memory card's back shows the private note. `r05-flip.png` |
| R6 | Pass | Urgent cards with a due time show a ticking `HH:MM:SS` clock; past due reads OVERDUE. `r01-kanban.png`, `r24-desk.png` |
| R7 | Pass | Opening the board toasts the overdue urgent card. A card due inside an hour toasts once. `r24-desk.png` |
| R8 | Pass | Search, statistics, select, new, Genie, board menu, flip, calendar arrows and close use `Tooltip` (hover, and long-press on a phone). `r01-kanban.png` |
| R9a | Pass | Kanban columns and a highlighted drop target. `r01-kanban.png` |
| R9b | Pass | October 2026 month grid. A due card is a title chip on its day. `r09-calendar.png` |
| R9c | Pass | Trip notes is a bound page you swipe, split on `---`, with a page dot for the open page. `r09-notebook.png` |
| R9d | Pass | Covers in a grid with the title on the tile. `r09-album.png` |
| R9e | Pass | Numbered horizontal scenes with a color bar. `r09-storyboard.png` |
| R9f | Pass | Alternating tall and short cards. `r09-vision.png` |
| R9g | Pass | Rows by card type, columns across. `r09-swimlane.png` |
| R9h | Pass | Papers on a wood desk. The job card shows Collider · Design lead. `r09-portfolio.png` |
| R9i | Pass | 50 states and capitals. California is mapped: `1 / 50 states mapped`. `r09-us.png` |
| R9j | Pass | 20 countries, Japan mapped. `r09-world.png` |
| R9k | Pass | Whiteboard, desk, and the other object surfaces. `r24-whiteboard.png`, `r24-desk.png` |
| R9l | Partial | Files lists each attachment and the source card. It does not yet sort, zoom, run a slideshow, or use the floating file ribbon from the 24 September note. `r09-files.png` |
| R10 | Partial | Genie is an in-pane thread with history, a new-conversation control, and local commands (`set all priority to high`, `refactor task as note`). Pro is stated on the panel. `callAiApi` does not hit a network. There is no file-attachment button on the composer. `r10-genie.png` |
| R11 | Pass | Columns, statuses, custom fields and the board behaviors are edited on the surface. No settings route. `r11-menu.png` |
| R12 | Pass | Select mode outlines cards. The bar shows the count and Edit / Delete / Cancel. Delete arms, then confirms, and removes only the selected cards. Edit applies status, assignee, and priority to that selection in place. `r12-multi.png` |
| R13 | Pass | Search covers title, description, tags, assignee and company. A result opens that card in place. `r13-search.png` |
| R14 | Pass | Floating counts for total, priority, urgent, deadline, each list and each type. `r14-stats.png` |
| R15 | Pass | Drag between lists. With inherit on, the card's status becomes the list name. Tested in `smart_gen_ledger_test.dart`. `r01-kanban.png` |
| R16 | Pass | A card can embed another card. The chip opens that card. `r03-editor.png` |
| R17 | Pass | Custom fields are named on the card and stored on the card. `r03-editor.png` |
| R18 | Pass | `done-final` and `hourly` are stored on the card. The hourly tick and mark-done are covered by the test. `r03-editor.png` |
| R19 | Partial | Image attachments show as covers. Other files show a name. There is no video player. `r09-album.png`, `r09-files.png` |
| R20 | Partial | Flip, chips and the drop highlight animate. Urgent cards pulse. Particles and custom scrollbars are not in the pane; scrollbars are hidden on purpose. `r01-kanban.png` |
| R21 | Pass | The board and the Genie thread persist through file storage. The 1000th card is refused. Tested. `r01-kanban.png` |
| R22 | Pass | Canvas chips, swipe, and free drag. The 11th canvas is refused with a notice. Tested. `r22-canvas.png` |
| R23 | Partial | A card's type can be changed in place, and a canvas kind is part of the canvas. Component kind is not drawn as its own mandatory control. `r03-editor.png` |
| R24 | Pass | Notebook, portfolio desk, corkboard, clipboard, ledger, binder and slate each use their own surface. `r09-notebook.png`, `r24-desk.png`, `r24-cork.png`, `r24-clipboard.png`, `r24-ledger.png`, `r24-binder.png`, `r24-slate.png` |
| R25 | Pass | No dialog and no settings route in this Smart Gen. Options sit on the control they change. `r03-editor.png`, `r11-menu.png` |
