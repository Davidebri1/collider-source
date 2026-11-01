# Canvas gaps captures — word audit (440×956)

Reach: Apps → Smart Gen → Canvas (surface chip). Genie via board menu / genie=1.

| Shot | Key words / notes |
|---|---|
| 01_board_tiles | Sprint centred (Settings Align header); single VFadeScroll chip row (Ledger…Canvas selected into view); chip "1"; Desk; Shot list / Lookbook / Mood tiles in free slots; dark navy grid to pane floor (no grey band) |
| 02_background_picker | Background centred; scenes-first ThemeCatalog thumbs (neon/alley — no White Network / Abstract Background speck); tints after; Canvas selected |
| 03_throw_* | Thrown / Beta / Gamma; real Playwright mouse flick; start→settle ~324px; release→settle ~48px |
| 04_genie_open | Genie only in body below number chips; New conversation / Minimize / Close; Message Genie; opaque panel |
| 05_genie_minimised | Genie FAB in canvas area; board tiles visible; navy grid full height |

## Against David's 6

1. Single horizontal surface-chip row + VFadeScroll fade + selected into view — yes
2. Settings `_paneHeader`-style header (title centre, leading left, trailing right) — yes
3. Dark navy grid default (not `#2F6FED`) — yes (`SgCanvas.color` `0xFF1A2838`, wash α≈0.28)
4. Grey band y≈770–845 eliminated — yes. Root cause: `main.dart` nested `CPane` phoneBoard (`bottomInset: 78`) inside `SettingsGlassPane` + `paneH.clamp(..., 740)` so the inset showed Settings frost; phone now mounts `SmartGenScreen` alone so CPane owns glass/height. Widget/line: `lib/main.dart` smartgen `Positioned.fill` host (~2560); CPane finite height `lib/core/vision/cpane.dart` phoneWork `LayoutBuilder`/`phoneH`.
5. Bg picker: working scene thumbs first, tints after, centred "Background" — yes
6. Genie only inside canvas area below number chips — yes (`Expanded` Stack in `sg_pane.dart` build)

## Tests
`flutter test test/smart_gen_canvas_gaps_test.dart` — All tests passed (5).
