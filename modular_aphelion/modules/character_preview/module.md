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
  instead, every way until the pointer lets go, and so does one held still for 0.3 s first, whichever way it
  then sets off. A pan goes as far as brings any part of what the character draws to the box's middle, so it
  never leaves the box; the pan is kept in the drawing's pixels, so a zoom keeps what is at the middle there. A
  double-click fits it again, unpanned. A turn renders once per quarter and a zoom once per
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
- **A room of its own.** The club themes' Augments+ Markings frames the preview itself, as a club's mirror (see the
  markings_room module): its `club` motif draws no floor and no frame, `maxScale` lets the fit pass a tile filling
  the box, `overlay` draws layers lined up with the character in its arrival (each marked `data-preview-pan` pans
  with it, beside its canvas so a layer can blend with it), and `onTap` reports a press let go before it dragged.
- **Lights off, to see what glows.** A lightbulb beside each tab's turn buttons turns the preview's lights off, on
  every tab at once, as a turn holds. The page then lights the character as the game's lighting plate does in an
  unlit room: every pixel, the floor's included, is multiplied by its light, which is the 10% the game's dark leaves
  plus the bloom's light falling on it, the colours of what blooms grown and blurred as the game's bloom filter
  spreads them at the player's own bloom setting; and a pixel that glows keeps its own colour, through anything worn
  over it that blocks the glow, as the game's emissive plane has it. The frame stays lit. The page works from each facing's glow, drawn beside
  it in the same strip: the look's emissive overlays alone, flattened as the emissive plane holds them, red where
  something glows and blooms, green where it glows without, black where a blocker hides it (`glow.dm`). The server
  draws it only while a window has its lights off, and only for a look with something that glows; a lights-on window,
  or a look with nothing glowing, draws exactly what it drew before. Turning them off draws the look once more with
  its glow, unless the drawing already has it; turning them on again draws nothing. A window opens with its lights
  on. The custom hair and markings editors' previews have the same switch; see that module.
- **What animates, animates.** A look with something animated, like a halo's bob, an IPC screen's blink, fairy wings'
  flutter or a galaxy suit's twinkle, plays it in the preview, as the game does. iconforge draws a look's first frame
  only, so the drawing carries, beside its facings, patches: the look at each later step of its animation, cropped to
  the box of pixels that changes, side by side in one more image. The page lays each over the facing in turn, on its
  1x canvas before height's rows move, a step at a time, while the window is shown and the lights are on; with them
  off, the preview holds still. It plays whatever the player's system says of motion, as the game's own client does:
  the game's client reports reduced motion for a window's first moments anyway. Which pixels an animated icon state
  changes, and between which of its frames, is read once a round, in `SScharacter_preview`'s spare time, a frame at a
  time (`animation.dm`); a look shown before then is drawn still, and drawn again once it has been. What moves apart
  keeps its own time, a quick flutter and a slow flick each theirs, and what overlaps moves on one timeline. A drawing
  carries at most 32 patches and 16384 of their pixels, shared out cheapest first: an animation with more steps than
  fit keeps fewer, evenly, each shown for the time of those dropped after it, so it still runs its whole length.
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
  drawing rebuilds it first, once for everything the action changed: once the tick's other work has run, a lone
  change's answer and a burst's alike, then and there if nothing waits ahead of it and the rebuild fits in what is
  left of the tick, as it nearly always does, or, when it doesn't fit, while such rebuilds have taken less than a
  tenth of the last second. Otherwise the mob waits its turn (`SScharacter_preview`), rebuilt in the tick time other
  subsystems leave over, in order; changes that come while it waits go into the one rebuild, and the page shows the
  same loader, once the wait is long enough to see. The queue never goes half a second without a rebuild, so a busy
  server still rebuilds previews, a little late, and runs a tick over for one at most twice a second. Without a
  window, the mob is rebuilt at once, as tg does.
- **Memory stays bounded.** A drawing is named by the md5 of its recipes, so characters that look alike
  share one, and it is kept only while an open window shows it: at most one per character with setup open.
  Closing the window lets its drawing go, and a window asks for the drawing when it opens, saying which one
  it holds, so it is sent one only if that is another. iconforge keeps every image it makes until it is told
  to let them go, 80 to 330 KB a look, and a look is hardly ever drawn twice, so every 100 drawings it is told
  to, once none is under way (one under way would come out empty) and no spritesheet is being made. New
  drawings wait for that, a tick or two. The custom sprite editors' pictures, which iconforge keeps too, about
  28 KB each, count toward it a tenth each. tg's asset loader tells iconforge to let go too, on every fire once
  its queue has first emptied, every two seconds; it skips that while a preview is being drawn.

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
A burst's answer, like a slider dragged a change a tick for ten ticks, reaches the page about 0.3 s after its last
change, as it did when every change rebuilt the mob; queued for its turn instead, it took a tick longer.

The pan, profiled in Chromium 141 (software-rendered) over 240 moves, one a frame: no frame dropped, at full
speed or with the CPU slowed four times; a move restyles what it moves in about 0.16 ms (0.65 ms slowed), and
lays out, paints, rasters and renders nothing. Taking the layers and letting them go costs about 8 ms of
raster, once a pan.

The lights off, measured in DreamDaemon 516.1687 on three characters over two runs: a plain human, a lizard with
three glowing markings and glowing eyes, and that lizard in a jumpsuit. A drawing with the lights on costs nothing
more. With them off, finding whether anything glows takes 5 to 47 µs; for a look that glows, its glow adds a second
walk of about 1.2 ms (the look's own walk took 0.9 to 1.2 ms), about 0.3 ms of iconforge's own thread with its caches
warm (3 to 4.5 ms cold), and 0.55 to 0.75 KB to the 4.5 to 5.5 KB data URL. The page lights a facing on its 1x canvas
when it turns, a drawing comes or the switch flips, and draws nothing in between.

The lights-off look was matched to the game's own render: a lab client standing a glowing lizard in a sealed, unlit
room and in one lit at 18%, captured at 4x and lined up with its preview drawing, for two characters at the default
bloom and one at bloom 5. The game shows a glowing pixel in exactly its own colour, leaves 10% of the light elsewhere,
and lights what lies round a blooming pixel with its colour, grown by the bloom filter's offset and blurred 1.2 times
its size across, at 0.95 of its strength: fitted to the first capture within 1.5 of 255 levels (12.3 without the
bloom). The page's own drawing, run in Chromium on the same drawings and floors, came out within 0.0 to 0.07 RMS on
glowing pixels, 1.4 to 3.2 on the rest of the character and 0.8 to 1.6 on the floor of the dark captures, and within
2.3 to 5.3 and 2.8 to 3.3 of the dim ones.

The animation, measured in DreamDaemon 516.1687 on six looks: a halo, fairy wings, an IPC's pink screen, a galaxy
suit, a lizard's slow tongue flick and an ethereal. Reading a state, once a round: 1.3 ms for a halo, 2.1 to 2.5 for
an ethereal's head or an IPC screen, 5 to 6.5 for wings or a lit cigarette, 29 for the galaxy suit's 32 frames and 110
to 120 for the flick's 80, in calls of at most 1.7 ms. A walk of a look with nothing animated takes about 30 µs more,
to find that out; one of a look that animates, 0.4 to 1.1 ms more, to work out its steps and write its patches'
recipes; and iconforge's own thread 0.1 to 1.2 ms more. The patches add 0.3 to 0.8 KB to the data for the halo, the
screen and the flick, and 13 to 23 KB for the wings, the galaxy suit and the ethereal, whose patches are capped. The
page's own laying of the patches, run in Chromium on those drawings and on a lizard with both wings and a flick, gave
exactly iconforge's whole drawing of each facing at each step's start, every pixel: 136 checks. In the game's own
client, character setup opened on that lizard, untouched, played from its first moments, each step at its time to
within 10 ms.

### TG Proc/File Changes:

Edits to tg files are marked `APHELION EDIT`, with their original code retained, except inside Nova's existing edit
blocks, which aren't tagged again; Nova's modular files are edited directly.

| File | Procs or declarations changed |
| --- | --- |
| `code/modules/client/preferences.dm` | `/datum/preferences/ui_interact()` no longer shows the preview map, `ui_static_data()` no longer sends `character_preview_view`, and `ui_close()` lets the drawing go. `/atom/movable/screen/map_view/char_preview`: Nova's canvas vars and their code in `Destroy()` and `update_body()` are commented out, and Aphelion's earlier `preview_bounds` and `display_to_client()`, which went with them, are gone; `var/image/silicon_preview` stays, where `update_body()` keeps a silicon job's image. `update_body()` takes `catching_up`: with setup open, a change leaves the body stale and asks for a drawing (`defer_rebuild()`), whose rebuild is the one catching up; `Destroy()` takes the view out of the rebuild queue. |
| `code/controllers/subsystem/asset_loading.dm` | `/datum/controller/subsystem/asset_loading/fire()` doesn't tell iconforge to let go while a character preview is being drawn (`character_preview_drawing_under_way()`). |
| `code/modules/asset_cache/spritesheet/batched/universal_icon.dm` | `/proc/get_flat_uni_icon()` passes over an appearance without an icon, names a runtime icon's file by the md5 of its content, writing it once, and takes `grow`: the canvas then fits every overlay, and the new `flat_x1`, `flat_y1`, `flat_width` and `flat_height` vars say where the look sits in it. Adds `/proc/uni_icon_facings_json()`. |
| `code/__HELPERS/icons.dm` | `getFlatIcon()` takes the same `grow`, with `grown_origin` to say where the grown canvas starts, and `get_flat_human_icon()` passes `grow` on. |
| `code/modules/admin/outfit_editor.dm`, `code/modules/admin/verbs/selectequipment.dm` | Their outfit previews pass `grow = TRUE`, so wings, tails and big hats show whole. |
| `code/modules/client/preferences/age.dm`, `names.dm`, `paraplegic.dm`, `playtime_reward_cloak.dm`, `random.dm`, `trans_prosthetic.dm` | Preferences the preview doesn't show set `should_update_preview = FALSE` (three in `random.dm`), so changing them doesn't rebuild the preview mob. |
| `modular_nova/modules/character_preview_background/code/character_preview_background.dm` | `/datum/preference/choiced/background_state` no longer rebuilds the preview mob (`should_update_preview = FALSE`), and the map's `/atom/movable/screen/map_view/char_preview/setDir()` override is removed. |
| Nova preference and quirk files under `modular_nova/` | Set `should_update_preview = FALSE` on the preferences the preview doesn't show: text, sounds, opt-ins, quirk options and the like. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/index.tsx` | `PreferencesMenu` turns the character back to face south, with its lights on, as the window opens. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/index.tsx` | `CharacterPreferenceWindow` asks for the drawing when it mounts. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/MainPage.tsx` | `MainPage` shows the drawn preview, `handleRotate` turns it, and `CharacterControls` has its lights switch. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/loadout/index.tsx` | `LoadoutPreviewSection` shows the drawn preview, framed as a mirror, its arrows turn it, and its lights switch sits beside them. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/LimbsPage.tsx` | `RotateCharacterButtons` turn the drawn preview and switch its lights, and `PreviewSection` shows it, framed as a scanner. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/QuirksPage.tsx` | `QuirkPage` no longer keeps a hidden map preview alive for appearance quirks. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/types.ts` | Adds `CharacterPreviewDrawing` (with each facing's `glow_frames`, and its `CharacterPreviewAnimation`), `PreferencesMenuData`'s `character_preview` and `character_preview_pending`, and `ServerData`'s `background_state.tiles`; `character_preview_view` is commented out. |

### Modular Overrides:

- `code/drawing.dm`: `/datum/preference_middleware/character_preview`, which answers the window and draws the
  preview, with its glow while the window's lights are off (`set_lights()`, the `character_preview_lights` action);
  `/datum/preferences/var/preview_drawing` with `character_preview_changed()` and `character_preview_open()`;
  `character_preview_walk()`, `character_preview_flat_box()` and `character_preview_turns_itself()`, which make the
  recipes; and `/proc/iconforge_drawn()` with the globals it keeps: the drawings under way and how many looks' worth
  iconforge has drawn since it last let go of what it keeps, the custom sprite editors' pictures counting a tenth
  each; `/proc/character_preview_drawing_under_way()`.
- `code/animation.dm`: what animates. `SScharacter_preview`'s `animation_of()` gives what animating an icon state
  takes, once `read_animations()` has read it, a frame at a time in the subsystem's spare time (`readings`), and tells
  the drawings that waited for it (`reading_waiters`); `/datum/preview_animation_reading` reads one, with
  `preview_animation_split()` and `preview_animation_difference()`; `character_preview_animation()` makes a walk's
  patches, from `preview_animated_leaves()`, `preview_animation_track()`, `preview_animation_steps()`,
  `preview_animation_frames_at()`, `preview_animation_fewer_steps()` and `preview_animation_tokens()`; and
  `GLOB.character_preview_animations` keeps what has been read this round.
- `code/glow.dm`: what of a look glows. `emissive_branches()` takes a look's own emissive overlays, the glowing and
  the blocking, within a span of layers; `emissive_branches_lit()` and `emissive_branch_lit()` say whether any of them
  glows; `emissive_holder()` holds them for a flatten to draw as the emissive plane does; `character_preview_glow()`
  flattens a look's glow onto its drawing's canvas. The custom sprite editors use them for their previews' glows.
- `code/effects.dm`: `character_preview_effects()`, what the page draws over the drawing: the body's transform, and
  the rows tg's height filters move, which `character_preview_rows()` reads from their displacement maps
  (`character_preview_map_rows()`). The species page moves its renders' rows with it too.
- `code/backgrounds.dm`: `/datum/preference/choiced/background_state/compile_constant_data()` also sends each
  background's tile, taken from the custom sprite editors' `custom_sprite_background_tiles()`.
- `code/rebuilds.dm`: `SScharacter_preview`, the queue of preview mobs waiting to be rebuilt, which reads animated
  icon states in its spare time, and
  `/atom/movable/screen/map_view/char_preview`'s `body_stale`, `turns` and `defer_rebuild()`.

### Defines:

- `code/drawing.dm`: `CHARACTER_PREVIEW_DIR`, `CHARACTER_PREVIEW_SETTLE`, `CHARACTER_PREVIEW_MAX_WAIT`,
  `CHARACTER_PREVIEW_CLEANUP_EVERY` and `CHARACTER_PREVIEW_JOB_TIMEOUT`. File-local.
- `code/rebuilds.dm`: `CHARACTER_PREVIEW_OVERRUN_BUDGET`, `CHARACTER_PREVIEW_OVERRUN_BURST` and
  `CHARACTER_PREVIEW_REBUILD_OVERDUE`. File-local.
- `code/animation.dm`: `CHARACTER_PREVIEW_ANIMATION_MAX_PATCHES`, `CHARACTER_PREVIEW_ANIMATION_MAX_PIXELS`,
  `CHARACTER_PREVIEW_ANIMATION_MAX_PERIOD`, `CHARACTER_PREVIEW_ANIMATION_MAX_FRAMES`,
  `CHARACTER_PREVIEW_ANIMATION_MAX_AREA` and `CHARACTER_PREVIEW_ANIMATION_MIN_DELAY`. File-local.

### Included files that are not contained in this module:

- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/CharacterPreview/`: the preview, its drawing and
  fit and its animation (`drawing.tsx`), the turn every tab shares (`turn.ts`), the lights switch every tab shares
  (`lights.tsx`), its drag and wheel gestures (`gestures.ts`) and pan (`pan.ts`), and tests for the fit and the
  animation's steps.
- `tgui/packages/tgui/interfaces/common/LightsOff.tsx`, `LightsOff.test.ts`: a picture lit with its lights off from its
  glow, the light it keeps and its bloom, and the lights switch, shared with the custom sprite editors; and their tests.
- `code/modules/unit_tests/~nova/character_preview_animation.dm`, included from
  `code/modules/unit_tests/_unit_tests.dm`: a DM unit test that a state's moving box and frames are read as they are,
  that a look whose states wait to be read is drawn still and drawn again once they have been, that a halo moves in
  one patch a facing, and how steps come round together, skip frames that look alike and are kept fewer.
- `code/modules/unit_tests/~nova/character_preview_glow.dm`, included from `code/modules/unit_tests/_unit_tests.dm`: a
  DM unit test that glow is drawn only with the lights off and only for a look that glows, on the drawing's canvas,
  and that a jumpsuit over a glowing marking hides its glow.
- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/SpeciesRegistry/`: the species chamber shows the same drawing (`SpeciesSprite.tsx`, `SpecimenViewer.tsx`, `index.tsx`, `model.ts`).
- `tgui/packages/tgui/styles/meridianos/_character_preview.scss`, loaded by `_preferences.scss`: the preview and
  its frame in every theme.
- `modular_aphelion/modules/custom_sprites/code/images.dm`: `custom_sprite_background_tiles()`, the background tiles;
  its pictures count toward `iconforge_drawn()`.
- `code/modules/unit_tests/~nova/character_preview_rebuilds.dm`, included from `code/modules/unit_tests/_unit_tests.dm`:
  a DM unit test that, with setup open, changes wait for their turn and one rebuild takes them all in.
- `tgstation.dme`

### Credits:

- mal
