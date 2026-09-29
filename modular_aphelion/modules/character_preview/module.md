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
- **Memory stays bounded.** A drawing is named by the md5 of its recipes, so characters that look alike
  share one, and it is kept only while an open window shows it: at most one per character with setup open.
  Closing the window lets its drawing go, and a window asks for the drawing when it opens, saying which one
  it holds, so it is sent one only if that is another.

Measured live in the lab client, over 29 changes: the preview mob's rebuild, unchanged, takes about 13 ms;
the drawing adds about 3 ms of main-thread time, most of it the walk, and iconforge about 35 ms on its own
thread. A change reaches the screen in 48 ms (median of 8), where the map took 123 to 251 ms.

### TG Proc/File Changes:

Existing-file edits use `APHELION EDIT` markers with their original code retained; the Nova file is edited
directly. New UI files start with `// THIS IS AN APHELION UI FILE`.

| File | Procs or declarations changed |
| --- | --- |
| `code/modules/client/preferences.dm` | `/datum/preferences/ui_interact()` no longer shows the preview map, `ui_static_data()` no longer sends `character_preview_view`, and `ui_close()` lets the drawing go. `/atom/movable/screen/map_view/char_preview`: Nova's canvas vars and its blocks in `Destroy()` and `update_body()` are commented out, with Aphelion's `preview_bounds` and `display_to_client()` that went with them; adds `var/image/silicon_preview`, where `update_body()` keeps a silicon job's image before it calls `character_preview_changed()`. |
| `code/modules/asset_cache/spritesheet/batched/universal_icon.dm` | `/proc/get_flat_uni_icon()` passes over an appearance without an icon, and names a runtime icon's file by the md5 of its content, writing it once. Adds `/proc/uni_icon_facings_json()`. |
| `modular_nova/modules/character_preview_background/code/character_preview_background.dm` | `/datum/preference/choiced/background_state` no longer rebuilds the preview mob (`should_update_preview = FALSE`), and the map's `/atom/movable/screen/map_view/char_preview/setDir()` override is removed. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/index.tsx` | `PreferencesMenu` turns the character back to face south as the window opens. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/index.tsx` | `CharacterPreferenceWindow` asks for the drawing when it mounts. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/MainPage.tsx` | `MainPage` shows the drawn preview, and `handleRotate` turns it. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/loadout/index.tsx` | `LoadoutPreviewSection` shows the drawn preview, framed as a mirror, and its arrows turn it. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/LimbsPage.tsx` | `RotateCharacterButtons` turn the drawn preview, and `PreviewSection` shows it, framed as a scanner. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/QuirksPage.tsx` | `QuirkPage` no longer keeps a hidden map preview alive for appearance quirks. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/types.ts` | Adds `CharacterPreviewDrawing`, `PreferencesMenuData`'s `character_preview` and `character_preview_pending`, and `ServerData`'s `background_state.tiles`; `character_preview_view` is commented out. |

### Modular Overrides:

- `code/drawing.dm`: adds `/datum/preferences/var/preview_drawing` and `/datum/preferences/proc/character_preview_changed()`.
- `code/backgrounds.dm`: `/datum/preference/choiced/background_state/compile_constant_data()` also sends each background's tile.

### Defines:

- `code/drawing.dm`: `CHARACTER_PREVIEW_DIR`, `CHARACTER_PREVIEW_SETTLE` and `CHARACTER_PREVIEW_MAX_WAIT`. File-local.

### Included files that are not contained in this module:

- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/CharacterPreview/`: the preview, its drawing and fit (`drawing.tsx`), the turn every tab shares (`turn.ts`), and their tests.
- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/SpeciesRegistry/`: the species chamber shows the same drawing (`SpeciesSprite.tsx`, `SpecimenViewer.tsx`, `index.tsx`, `model.ts`).
- `tgui/packages/tgui/styles/meridianos/_character_preview.scss`, loaded by `_preferences.scss`: the preview and
  its frame in every theme, with `tests/character-preview-frame.test.tsx`.
- `code/modules/unit_tests/~nova/custom_sprites/tall_hair.dm`: checks the drawing's height for tall hair.
- `tgstation.dme`

### Credits:

- mal
