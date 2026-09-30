## Drawn character preview

Module ID: CHARACTER_PREVIEW

### Description:

Character setup's preview is a drawing the server makes of the preferences preview mob and sends in the
window's data, in place of a BYOND map control. Every tab that shows the character (Character, Loadout,
Augments+ and the species page's chamber) shows that one drawing.

- **One drawing, every tab.** `/datum/preference_middleware/character_preview` draws the preview mob facing
  each way, into one PNG strip, whenever it changes while a window is open, and sends it as
  `character_preview`. The tabs turn it themselves: all four facings are in the strip, so a turn costs
  nothing, and one turn holds from tab to tab. A window opens with the character facing south.
- **Drawn as the game draws it.** One `get_flat_uni_icon()` walk, its canvas grown to fit parts that reach
  past the mob's tile (big ears, wings, taur bodies), serves all four facings (`uni_icon_facings_json()`),
  and iconforge draws the strip off the main thread. A body that something redraws when it turns, like a
  golem's or a Teshari's head moving glasses and hats without sprites of their own to the side it faces, is
  turned and walked once per facing instead, each walk cropped to the canvas that fits all four, as the map
  turned the mob itself when it turned. Height and body size, which a flatten leaves out, go with the
  drawing: `character_preview_effects()` reads which rows tg's height filters move from their displacement
  maps, and the mob's transform. The page moves those rows on a canvas at 1x and applies the transform in
  CSS, which samples at screen resolution as the map does. A silicon job's preview draws its image.
- **Fitted by the page.** Each tab shows the character at the largest whole-number scale at which everything
  it draws, in any facing, fits the box, up to a tile filling the box's shorter side, so its pixels stay
  square. The chosen background's tile repeats under it at the same scale, one tile under the character's
  own. The background is the page's, so choosing another redraws nothing.
- **Turned, zoomed and panned by hand.** Dragging across the preview turns the character a quarter per 40px,
  and the wheel zooms it in whole steps, from 1x to twice the fit. A drag that sets off up or down pans it
  instead, every way until the pointer lets go, as far as brings any part of what the character draws to the
  box's middle, so it never leaves the box; the pan is kept in the drawing's pixels, so a zoom keeps what is at
  the middle there. A double-click fits it again, unpanned. A turn renders once per quarter and a zoom once per
  step; a pan renders nothing, moving the character and its floor by their own inline `translate`, the floor by
  the pan less whole tiles. The frame, the scanner's rule included, stays put through all of it. The species
  page's chamber has its own turntable and neither zooms nor pans.
- **Framed by the theme.** Each theme cases the preview on the box's edge in materials it already ships, as
  the species chamber's casing is built: Aphelion's bezel and calibration rule, the forge themes' own window
  frames, Scavenger's riveted rust plate, Wastelander's tube, and so on; Classic and Highline keep a plain
  edge. Each tab adds one motif: a portrait's corners (Character), a fitting mirror's glass and clips
  (Loadout), or a scanner's rule along the character's tile, ticked in the drawing's pixels (Augments+).
  The floor is never painted over: what the frame draws on it is small and keylined, so it reads on every
  background. The frame never draws again once shown, nothing in it moves, and it takes no pointer.
- **Nothing lands on the player's disk.** The strip travels inside the data as a PNG data URL, in a small
  update of its own that leaves the rest of the preferences data alone. BYOND keeps every file a client is
  sent in its cache for good, and a map kept every look the preview mob had; the player's cache doesn't
  grow however often the character changes. iconforge's file is deleted as soon as it has been read.
- **Changes can't pile up.** A lone change is drawn as soon as the action that made it has finished, in the same
  tick, so an action that changes the look twice, like swapping one loadout hat for another, draws only the look it
  ends with. Changes that come while a drawing is under way, or within a quarter second of the last answer, wait in
  one slot, each newer one taking the place of the last, until they stop for a quarter second or a second has
  passed; then the latest look is drawn once. The page shows the theme's loader over the drawing it has while a
  newer one waits.
- **Rebuilt once an action, in turn when many change at once.** Rebuilding the preview mob applies every
  preference to it: 10 to 40 ms that can't be split. tg rebuilds it inside every action that changes it, twice
  for a loadout item that takes another's place, and many players changing their characters at once ran every
  tick over, which every player on the server felt. With setup open, a change only marks the mob stale, and the
  drawing rebuilds it first, once for everything the action changed: as a lone change's action ends, then and
  there if nothing waits ahead of it and the rebuild fits in what is left of the tick, as it nearly always does,
  or, when it doesn't fit, while such rebuilds have taken less than a tenth of the last second. Otherwise, and for
  a burst of changes, the mob waits its turn (`SScharacter_preview`), rebuilt in the tick time other subsystems
  leave over, in order; changes that come while it waits go into the one rebuild, and the page shows the same
  loader, once the wait is long enough to see. The queue never goes half a second without a rebuild, so a busy
  server still rebuilds previews, a little late, and runs a tick over for one at most twice a second. Code that
  reads the mob, like a new marking's default colours, has it rebuilt first (`current_body()`). Without a window,
  the mob is rebuilt at once, as tg does.
- **Memory stays bounded.** A drawing is named by the md5 of its recipes, so characters that look alike
  share one, and it is kept only while an open window shows it: at most one per character with setup open.
  Closing the window lets its drawing go, and a window asks for the drawing when it opens, saying which one
  it holds, so it is sent one only if that is another. iconforge keeps every image it makes until it is told
  to let them go, 80 to 330 KB a look, and a look is hardly ever drawn twice, so every 100 drawings it is told
  to, once none is under way (one under way would come out empty) and no spritesheet is being made. New
  drawings wait for that, a tick or two. The custom sprite editors' pictures, which iconforge keeps too, about
  28 KB each, count toward it a tenth each.

Measured live in the lab client, over 29 changes: the preview mob's rebuild, unchanged, takes about 13 ms;
the drawing adds about 3 ms of main-thread time, most of it the walk, and iconforge about 35 ms on its own
thread. A change reaches the screen in 48 ms (median of 8), where the map took 123 to 251 ms.

Under load, measured with rust-g 7.0.0's iconforge built from its tag for x86_64 on 4 cores: a drawing takes
3.5 ms of a thread for a plain human and 11.7 ms for a Nova character with markings and three-coloured parts on
a 64x64 canvas; 64 kept under way at once drew 300 a second without slowing a main loop in the same process;
and one goes to the page as a 2 to 2.3 KB data URL. Without letting go, 6000 such drawings kept 1.9 GB; letting
go every 100, emulated tick by tick with 16 under way at once, kept at most 156 MB, and none came out empty.
The page spends 2.5 ms on a drawing (11 ms with the CPU slowed four times) and shows it on the next frame; a
burst's answer, which shows the loader first, 10 to 19 ms.

The rebuilds, measured in DreamDaemon 516.1687 in the lobby, each player clicking a loadout item every 3 seconds, or
every second, for 20 seconds, their actions coming at the end of a tick as verbs do, against rebuilding inside the
action as before: with 1 to 20 players clicking every 3 seconds, a click's drawing reaches the page in a median of 52
to 88 ms (before, 51 to 101 ms), and the server keeps time (1.00 to 1.05x). With 50 players every 3 seconds it takes
0.9 s, at 1.03x; before, 0.14 s, but the server ran at 1.31x, slowing everyone. With 100 players every second, 3.4 s
at 1.02x (before, 2.5 s at 4.6x); with 200, 8.7 s at 1.08x (before, 58 s at 8.5x). A rebuild took about 30 ms.

The pan, profiled in Chromium 141 (software-rendered) over 240 moves, one a frame: no frame dropped, at full
speed or with the CPU slowed four times; a move restyles three elements in about 0.16 ms (0.65 ms slowed), and
lays out, paints, rasters and renders nothing. Taking the layers and letting them go costs about 8 ms of
raster, once a pan.

### TG Proc/File Changes:

Existing-file edits use `APHELION EDIT` markers with their original code retained; the Nova file is edited
directly. New UI files start with `// THIS IS AN APHELION UI FILE`.

| File | Procs or declarations changed |
| --- | --- |
| `code/modules/client/preferences.dm` | `/datum/preferences/ui_interact()` no longer shows the preview map, `ui_static_data()` no longer sends `character_preview_view`, and `ui_close()` lets the drawing go. `/atom/movable/screen/map_view/char_preview`: Nova's canvas vars and its blocks in `Destroy()` and `update_body()` are commented out, with Aphelion's `preview_bounds` and `display_to_client()` that went with them; adds `var/image/silicon_preview`, where `update_body()` keeps a silicon job's image before it calls `character_preview_changed()`. `update_body()` takes `catching_up`: with setup open, a change leaves the body stale for the drawing to rebuild (`defer_rebuild()`), and that rebuild doesn't announce the change again; `Destroy()` takes the view out of the rebuild queue. |
| `code/modules/asset_cache/spritesheet/batched/universal_icon.dm` | `/proc/get_flat_uni_icon()` passes over an appearance without an icon, and names a runtime icon's file by the md5 of its content, writing it once. Adds `/proc/uni_icon_facings_json()`. |
| `modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm` | `add_marking()` and `set_preset()` read the preview mob through `current_body()`, so a change still waiting to be rebuilt into it counts. |
| `modular_nova/modules/character_preview_background/code/character_preview_background.dm` | `/datum/preference/choiced/background_state` no longer rebuilds the preview mob (`should_update_preview = FALSE`), and the map's `/atom/movable/screen/map_view/char_preview/setDir()` override is removed. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/index.tsx` | `PreferencesMenu` turns the character back to face south as the window opens. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/index.tsx` | `CharacterPreferenceWindow` asks for the drawing when it mounts. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/MainPage.tsx` | `MainPage` shows the drawn preview, and `handleRotate` turns it. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/loadout/index.tsx` | `LoadoutPreviewSection` shows the drawn preview, framed as a mirror, and its arrows turn it. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/LimbsPage.tsx` | `RotateCharacterButtons` turn the drawn preview, and `PreviewSection` shows it, framed as a scanner. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/QuirksPage.tsx` | `QuirkPage` no longer keeps a hidden map preview alive for appearance quirks. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/types.ts` | Adds `CharacterPreviewDrawing`, `PreferencesMenuData`'s `character_preview` and `character_preview_pending`, and `ServerData`'s `background_state.tiles`; `character_preview_view` is commented out. |

### Modular Overrides:

- `code/drawing.dm`: adds `/datum/preferences/var/preview_drawing`, `/datum/preferences/proc/character_preview_changed()` and `character_preview_open()`,
  and `/proc/iconforge_drawn()` with the globals it keeps: the drawings under way and how many looks' worth
  iconforge has drawn since it last let go of what it keeps, the custom sprite editors' pictures counting a tenth
  each.
- `code/backgrounds.dm`: `/datum/preference/choiced/background_state/compile_constant_data()` also sends each background's tile.
- `code/rebuilds.dm`: `SScharacter_preview`, the queue of preview mobs waiting to be rebuilt, and
  `/atom/movable/screen/map_view/char_preview`'s `body_stale` and `turns`, `defer_rebuild()` and `current_body()`.

### Defines:

- `code/drawing.dm`: `CHARACTER_PREVIEW_DIR`, `CHARACTER_PREVIEW_SETTLE`, `CHARACTER_PREVIEW_MAX_WAIT`,
  `CHARACTER_PREVIEW_CLEANUP_EVERY` and `CHARACTER_PREVIEW_JOB_TIMEOUT`. File-local.
- `code/rebuilds.dm`: `CHARACTER_PREVIEW_OVERRUN_BUDGET`, `CHARACTER_PREVIEW_OVERRUN_BURST` and
  `CHARACTER_PREVIEW_REBUILD_OVERDUE`. File-local.

### Included files that are not contained in this module:

- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/CharacterPreview/`: the preview, its drawing and fit (`drawing.tsx`), the turn every tab shares (`turn.ts`), its drag, hold and wheel gestures (`gestures.ts`) and pan (`pan.ts`), and their tests.
- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/SpeciesRegistry/`: the species chamber shows the same drawing (`SpeciesSprite.tsx`, `SpecimenViewer.tsx`, `index.tsx`, `model.ts`).
- `tgui/packages/tgui/styles/meridianos/_character_preview.scss`, loaded by `_preferences.scss`: the preview and
  its frame in every theme, with `tests/character-preview-frame.test.tsx`.
- `code/modules/unit_tests/~nova/custom_sprites/tall_hair.dm`: checks the drawing's height for tall hair.
- `code/modules/unit_tests/~nova/character_preview_rebuilds.dm`: checks that a change with setup open leaves the mob for
  the drawing to rebuild, that rebuilds take their turns in order, and that code reading the mob gets it rebuilt first.
- `tgstation.dme`

### Credits:

- mal
