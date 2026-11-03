# v8.4 QA round — what was fixed, and the proof

All shots are phone portrait, 430 x 932 logical @3x (iPhone 14/15 Pro Max class).
`v84-01` is the pre-fix build, `v84-02`+ are the fixed build.

| # | Symptom | Root cause | Fix | Proof |
|---|---|---|---|---|
| 1 | Every song row started with an id like `0319bbf2-a06b-4664-b094-0dfcd5ea0b51_1080_hd` and demoted the real name to a small subtitle | The theme ingest writes the **source filename** into `tracks[].title`; the row renders that field first | `MusicPlayer.themeTracks()` promotes the clean theme name whenever the title is filename-shaped (underscore / uuid / media extension), and empties the subtitle when the theme name leads | `v84-01-files-before.png` vs `v84-02-files-after.png` |
| 2 | The segmented pill (`Year / Month / Today / All Files`) painted straight across the last row of files | Figma placed the ornament at y 721, inside the 740-tall panel | Ornament moved to y 758 — it clears the panel by 18 and is centred under the main panel instead of over the seam | `v84-02-files-after.png` |
| 3 | The Files window touched the right edge of the screen and read as a fullscreen app | `cropWidth` equalled the group's own width, so the panel's right edge landed exactly on the screen edge | `cropWidth` widened to 1420 (group shrinks ~6%) and the crop re-centred on the content (x 95.4 .. 1336.4), leaving equal air on both sides; frame height 835.2 -> 872 so the window chrome fits | `v84-01-files-before.png` vs `v84-02-files-after.png` |
| 4 | The Account sheet's own "Plans" heading was cut mid-word at the fold, hiding the last section with no way to scroll to it | The tier catalogue was rendered **twice** — once in the sheet, once in the list that `Plan` / `Manage Subscription` open | The duplicated block removed; `Plan` and `Manage Subscription` remain the single entry point to the tier list | `v84-05-plan-list.png` |
| 5 | Opening the Account sheet from the Apps pane destroyed the Apps pane — closing Account dropped you back to the home surface | The pane stack had one slot, and the Account tab called `onClose()` before pushing | `_drawerStack` / `_pushDrawer` / `_popDrawer` in `main.dart`: a sheet opened from inside another is pushed, the one underneath stays mounted, and closing the top restores it | `v84-04-account-over-apps.png` (Apps rail visible behind the Account sheet) and `v84-06-back-to-apps.png` |

## Checks

- `flutter analyze lib` — 0 errors
- `flutter test` — 62/62 pass
- `flutter build web --base-href "/" --release` — succeeds
