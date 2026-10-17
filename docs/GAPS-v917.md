# v9.1.7 WIP: gaps by screen (QA build build-qa3, phone 390x844 @3x)

Nothing here is live. Live is still v9.1.6h (main.dart.js a4171fc0…). Production build of this code: build-prod2, main.dart.js 685fb52a3cacd41cdcd08b04cb14846bc8b8866cba5a08adc9dc23a0182050b8. QA strings appear 0 times in it.

| Screen | Changed | Side-by-side / evidence | Remaining gap |
|---|---|---|---|
| Home / ticker | About 4 compact rows that scroll; tap opens the conversation with an inline composer; long-press menu; grey-slab switches removed | shots/ticker3.png, shots/slab2.png, ref: release/ref9-home.png | Long summaries end in an ellipsis. Not checked on a physical phone |
| Home / composer | Chip row removed; + opens the full menu; ticker gets the shared blur (3) while the composer is summoned | shots/composer_before_after.png (left before, right after), shots/c_plusmenu_b_crop.png | Inactive menu rows are 60 % white per Figma 1:3, so they read faint |
| Nav bar | Settings · Home · Apps restored (v9 icon) | shots/hist_kbd.png | — |
| History | Centred, no longer top-shifted | shots/hist_kbd.png (left), before: shots/p_history_s.png | No empty state (not on the list) |
| Files | Player opens and plays, controls below the video; empty state; denser glass | shots/f_player8_s.png, shots/empty2.png | #86/#87/#90/#91 not started |
| Smart Gen | One empty state, one add button | shots/empty2.png | #92/#94/#96 not started |
| Premium | Set as wallpaper path works with the QA unlock; owned pill seen | shots/ui_set2.png, shots/under4.png | Ticker hidden under the black stage (#6/#7); cover overlaps the name after a swipe (seen, not on the list) |
| Gallery / Music | Theme list without 66 broken items | shots/under4.png, setwall/report.json | Ticker hidden under the hero card and the music list (#6/#7) |
| Catalog | 65 broken or streaked videos plus 7.webp hidden (tool/qa/blocked-themes.json) | setwall/report.json, shots/ok_sheet_*.png, shots/removed_7webp.png | Default stays Reflection Lake 1280x720 because the 4K copy is broken (#79) |

## Batch 3 (Oct 15, 5:40 AM): build vs before (build-qa3), 390x844
Side-by-sides are in release/v91/v917/cpane/: sbs_market, sbs_smartgen, sbs_music, sbs_files3, sbs_consensus2, sbs_browser, sbs_history, sbs_settings, sbs_apps, sbs_themes, sbs_premium, sbs_row, sbs_composer_send2 and sbs_discfull.
- Centred, same width, nothing cut off, not worse than before: Discover, Smart Gen (it was off-centre before), Files (it was full width before), Music, Browser, Roundup (it was a full-screen black page), and the opened conversation (#122).
- Unchanged: Gallery, Premium, Settings, History (Global) and Apps. The ticker now docks under Apps.
- Open: the Browser page shows a white strip at its right edge, as it did before (the site's own page). Settings is still ~80 % wide and waits for #97.
- Motion (#36): see motion/run.log. On the box's software renderer, Premium cold open, Discover open, Files open and row open still show one-step stalls.
