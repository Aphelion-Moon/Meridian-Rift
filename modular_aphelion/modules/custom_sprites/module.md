## Custom hair and markings

Module ID: CUSTOM_SPRITES

### Description:

Adds pixel editors for custom hair and markings in character preferences. You can
add to an existing haircut, draw a whole-body marking, or give individual body
zones their own drawings. Everything uses the existing SpriteEditor.

#### Opening the editors

Custom hair drawing is in the hairstyle picker on the main character page.
Custom marking drawing is on the body customization page's Markings tab.
Each marking section there also has a Custom button:
Head, Torso, Left arm, Right arm, Left leg and Right leg. These pass `body_zone`
to the same editor. The whole-body drawing stays separate and can be used
alongside all six zone drawings.

Each drawing has a 32 by 32 canvas with Front, Back, Right and Left views. A dot
beside a view means it contains paint. Hair bounds follow the hairstyle, with
room to add to it. Whole-body markings use the body's bounds; zone editors also
use the selected limb's actual silhouette in each direction. Missing limbs,
stumps and unsupported taur parts have no editable zone pixels.

`ALLOW_CUSTOM_SPRITE_EDITING` defaults to enabled. Set it to `0` in
`config/nova/config_nova.txt` to hide the buttons and reject editing actions.
Saved drawings still render. Editors check the owning client, character slot,
target and optional body zone on the server, including after color-picker dialogs.

#### Tools and controls

- Select comes first in the toolbar. Drag a box, then drag inside it to move the
  selected paint. The box can start in a shaded area, and you can grab it there
  too. Only allowed painted pixels move; their destination must stay inside the
  drawing bounds and limb mask. The box stays inside the canvas.
- Pencil, eraser, eyedropper and fill use the same canvas. Pencil and eraser
  include the release position and send one transaction per stroke. Fill stops
  at holes in a zone's silhouette.
- The eyedropper takes painted color first. If there is no paint at that pixel,
  it samples the visible guide. Sampling a color does not use a Custom slot.
- Undo and redo each step through one action. A selection move is one action,
  including overlapping moves and pixels it replaces. Custom drawing history
  keeps up to 100 actions and lasts only for that editor session.
- Clear layer sits beside undo/redo and clears the current direction. It can
  also remove old paint outside bounds that changed with the character's body
  or hairstyle. It is undoable. Clearing an empty view leaves redo alone.
- Guide and Grid can be toggled. The guide is naked and excludes the drawing
  being edited. Guide and paint share the same canvas and pixel grid. Preview
  comes last in the sidebar and keeps the character's normal underwear visibility.
- The window opens at 900 by 780. Closing and reopening resets the tool to Pencil.
  Changing direction or using history cancels the current selection/drag.

| Shortcut | Action |
| --- | --- |
| Ctrl+S | Save without closing. Saved flashes after the server confirms success. |
| Ctrl+Z | Undo. |
| Ctrl+Y or Ctrl+Shift+Z | Redo. |
| Escape | Deselect, or dismiss an open swatch menu. |
| Delete while hovering a Custom swatch | Remove that saved color. |

The keyboard handlers leave text inputs alone. Canvas gestures claim their own
mouse events so drawing does not turn into dragging the window. The shared
window handler uses the mouse event's current Alt state, so a missed key release
cannot leave window dragging stuck on.

Select is also available in ordinary painting canvases and NanoPaint. Their
existing restrictions on tools, layers, colors and undo still apply.

#### Palette and color blending

Palette contains sampled colors. Hair uses the selected hairstyle's shades with
the character's effective hair color, plus its active gradient color. Markings
use all three mutant colors and sampled marking shades. Eyedropper picks are
also available here.

Custom holds up to 16 colors for the account, shared across character slots and
all custom editors. The + opens a color picker and disappears when full.
Right-click a Palette color, then click Save to keep it. Right-click a Custom
color, then click Remove to delete it. Delete while hovering does the same thing.
The menus stay open while moving to the action; clicking outside or pressing
Escape dismisses them.

Custom colors save immediately through the normal account preference writer.
Discarding a drawing does not discard palette changes. Removing a swatch does
not remove painted pixels or colors still needed by undo/redo. If a drawing has
no room for another color, unavailable Custom swatches stay visible but disabled.
Themes cannot paint over the swatches; selection uses a border.

Color blending starts with both options off:

- Blend with hair color multiplies Custom colors by the effective hair color.
  This option is only shown in the hair editor.
- Blend with color multiplies them by a chosen color. Its picker starts at white.

The options are mutually exclusive. They use Multiply blending on Custom colors
for new strokes. Palette colors, guide samples and existing paint keep their
RGB. A gradient color saved into Custom follows the same blending rules as any
other Custom color. The selected brush updates after server acknowledgement.

#### Emissive drawings

Every drawing saves its own Emissive setting for each of the four views. The
checkbox edits the current view and defaults off. It is independent of the
normal hair emissive preference. The master emissive appearance preference can
suppress glow without changing these saved choices.

Emissive views get glow masks; non-emissive views get blockers. Both use the
paint's masking, clipping, opacity and placement. Unused directions have explicit
blank frames, so a South-only drawing cannot show its mask in every direction.
Attached masks inherit the character's facing and pose through the existing
worn-emissive grouping. Dropped hair uses the dropped head's South-facing path.

#### Saving and loading

Drawings live in `custom_sprites.json` beside the account's `preferences.json`.
The file is loaded lazily and held by the preferences datum. Switching slots
validates and selects that slot's drawings from the loaded data.

| Stored value | Scope and contents |
| --- | --- |
| `characterN.hair` | One custom hair drawing for that character slot. |
| `characterN.markings` | One whole-body custom marking for that slot. |
| `characterN.limb_markings` | Drawings keyed by `head`, `chest`, `l_arm`, `r_arm`, `l_leg` and `r_leg`. Unknown zones are discarded. |
| `custom_sprite_palette` in `preferences.json` | The account's Custom swatches, separate from drawing data. |

A drawing stores `version`, `palette`, `dirs`, `tint` and optional `emissive`
metadata. Direction keys are BYOND's `"2"` (Front/South), `"1"` (Back/North),
`"4"` (Right/East) and `"8"` (Left/West). Missing directions are empty canvases.

Each direction stores 1,024 palette indexes, row by row from the top left.
Index `0` is transparent. An `r` prefix uses run-length encoding: a hexadecimal
run length from 1 to 15 followed by an index character. An `f` prefix stores the
flat grid when compression would be larger. Version 1 allows 15 opaque colors;
version 2 allows 63. Both cap the encoded direction at 1,025 characters. Only
used colors are saved. The decoder checks lengths, indexes and expanded size
before accepting data.

Save and close, the window's close action, and normal preference/slot changes
save the current drawing. Ctrl+S saves and keeps editing. Discard drops changes
since the last successful save. Deleting a character slot discards its editor
and removes its drawings. Character exports exclude the drawing file;
successful preference imports remove old drawings and their recovery files.

The sidecar writer uses rust-g and caps the file at 8 MiB. A clean, unchanged
save does no disk write. For a changed file it:

1. Writes the new JSON to `.new` and reads it back to verify the full contents.
2. Makes sure `.bak` contains the last verified revision.
3. Writes and verifies the main JSON file.
4. Removes deleted slot entries from the backup before reporting success, then
   clears the dirty state and removes the staging file.

Loading a missing or unreadable main file falls back to `.bak`. If neither copy
is readable, saving is refused so the existing files are left intact. Failed
saves keep the draft in memory and show an error instead of Saved. The save/close
action stays retryable. This state belongs to the whole sidecar, so saving a
different drawing can also flush a pending change.

Replacement is not atomic. A crash during a write can recover the previous
revision, so the last attempted edit is not guaranteed to survive. These checks
apply to the drawing sidecar; Custom swatches use the existing preference writer.

#### Rendering and caching

Preferences copy drawings onto DNA. Hair gets its own head snapshot; markings
get separate whole-body and zone overlays on each limb. DNA copies use independent
lists. Limb update signals handle regenerated or replaced parts, while detached
parts retain their appearance. Markings clip to limb geometry and split across
the normal leg layers. They do not draw on husks or taur bodyparts.

On the first render of a drawing, its pixel data is decoded into a workspace and
exported through rust-g to a BYOND icon with all four views. Temporary export
files are removed after use, including failed exports. Later renders reuse the
icon by its content hash. Turning uses the icon's existing direction frames.

| Cache | Key |
| --- | --- |
| Raw paint icons | Palette and encoded direction data. |
| Clipped limb and split-leg icons | Paint content, limb geometry and relevant leg layer. |
| Directional glow/blocker icons | Paint/mask geometry and the enabled directions. |
| Sampled palettes | Source icon file and state. |
| Hair bounds | Hairstyle icon file and state. |
| Limb editing masks | Limb icon, state and auxiliary zone. |

Each of these caches is shared server-wide and capped at 256 entries, with the
oldest inserted entry evicted first. Cached icons and lists are treated as
immutable. They are runtime caches; the JSON is what persists across restarts.
Tint, opacity and emissive choices do not rebuild raw paint or clipped pixels,
but final appearance keys include the settings that affect the result. Hair
still takes a private copy for its masks and final overlay assembly.

The editor renders strokes locally. Server previews wait for a 0.6-second pause
and skip unchanged drawings. Encoded pixels are cached until paint changes;
metadata changes reuse them. Guide and preview PNGs are editor-owned data URLs,
with no global asset/CDN registration. The browser reuses decoded guides, cached
shading geometry and unchanged drag previews. Only the opened drawing is sent
to its editor.

#### Older saves and limits

Version 1 drawings still load. A legacy single emissive boolean applies to all
four views; missing emission settings default off. Explicit saved whole-drawing
tints are baked into the editor's literal colors on opening, preserving their
rendered result. They are written back only through the usual save path.

Legacy hair with no explicit `tint` still goes through the old hair color and
gradient rendering path. It has not been automatically converted: gradients can
produce more colors than the 63-color format allows. New paint in one of those
old drawings can still inherit that filter. New drawings use literal colors.

| Limit | Value |
| --- | --- |
| Drawing size | 32 by 32, four directions. |
| Drawings per character | Hair, whole-body markings, and six body-zone drawings. |
| Saved Custom swatches | 16 per account. |
| Colors in one drawing | 63 opaque colors, plus transparency. Undoable colors also reserve room. |
| Undo history | 100 actions per open custom editor. |
| Drawing sidecar | 8 MiB per account, using the existing character-slot limit. |
| Animation and extra canvas layers | Not supported by the custom editors. |

#### Tests and maintenance

The native tests in `tests/` cover codec validation, input/history validation,
selection overlap and shaded starts, limb masks, palette limits, drawing
ownership, directional glow/blockers, persistence failures and recovery, slot
changes, imports, save/reopen/erase, and preview caching. Keep the shared painting
and NanoPaint paths working when changing SpriteEditor.

`tests/screenshot_hair.dm` loads `tests/fixtures/leia_buns.json` through the real
sidecar reader. It adds brown side buns to Short Hair (`#583820`), checks
save/reopen and cached rendering, and verifies that removal reveals the original
hair. The screenshot shows Front, Back, Right and Left. Its reference is
`code/modules/unit_tests/screenshots/custom_sprite_saved_hair_screenshot_leia_buns.png`.
Review the native output before replacing that baseline. The
[fixture notes](tests/fixtures/README.md) describe the sample artwork.

Use the repository's [native unit-test instructions](../../../code/modules/unit_tests/README.md)
and [screenshot test instructions](../../../code/modules/unit_tests/screenshots/README.md).
The module tests are included by `tgstation.dme`. Temporary `TEST_FOCUS` entries
must stay out of committed source. `BUILD.cmd` is the normal Windows build entry
point; there is no separate build command for this module.

From `tgui/`, the focused UI checks are:

```powershell
bun test packages/tgui/interfaces/common/CustomSpriteEditor packages/tgui/interfaces/common/SpriteEditor packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/LimbsPage.test.tsx packages/tgui/layouts/Window.test.tsx
bun run tgui:tsc
bun run tgui:build
```

The UI tests cover tool gestures, guide alignment, selection acknowledgement,
save feedback, color blending, swatch menus, theme styling and the zone buttons.
Native icon tests and browser fixtures do not cover every live-client case.
Check real drawing/dragging, hats, turning/resting, limb changes, save/relog and
slot/import behavior in DreamSeeker when changing those paths.

### TG Proc/File Changes:

These are the core hooks this module needs. Existing-file edits use
`APHELION EDIT` markers with their original code retained. New UI files start with
`// THIS IS AN APHELION UI FILE`.

| File | Procs or declarations changed |
| --- | --- |
| `code/__DEFINES/sprite_editor.dm` | Adds `SPRITE_EDITOR_TOOL_SELECT`. |
| `code/datums/dna/dna.dm` | `/datum/dna/copy_dna()` copies all three drawing fields and synchronizes the recipient. |
| `code/modules/client/preferences.dm` | `/datum/preferences/Destroy()` closes editors and deletes the sidecar datum; `ui_close()` saves editors before removing the preview. |
| `code/modules/client/preferences_savefile.dm` | `/datum/preferences/switch_to_slot()` finishes the old slot's editors; `remove_current_slot()` discards editors and removes that slot's drawings. |
| `code/modules/mob/living/carbon/carbon_update_icons.dm` | `/mob/living/carbon/update_body_parts()` still reaches forced hair/eye refreshes when the limb icons themselves are unchanged. |
| `code/modules/surgery/bodyparts/head_hair_and_lips.dm` | `/obj/item/bodypart/head/copy_appearance_from()` snapshots hair paint; `get_base_hair_overlays()` applies it without modifying the shared hairstyle icon and adds its separate masks. |
| `code/modules/sprite_editing/workspace.dm` | `/datum/sprite_editor_workspace/copy()`, `new_transaction()`, `undo()`, `redo()`, `can_transact()`, `preprocess_new_transaction()`, `transact()`, `reverse_transact()` and `to_icon()`: preserve workspace configuration, validate/sanitize commands, support selection patches, repair layer/history handling and safely export runtime icons. |
| `code/modules/art/paintings.dm` | `/obj/item/canvas/Initialize()` enables Select alongside its existing tools. |
| `code/modules/modular_computers/file_system/programs/nanopaint.dm` | `/datum/computer_file/program/nanopaint/ui_act()` forwards history counts; `write_to_file()` and `save_file()` preserve the old image or remove a newly created empty file when export fails. |

The shared workspace's bounds, selection-patch and sanitization helpers live in
this module. Keeping the core calls in place preserves validation and history
ordering for every SpriteEditor user.

### Modular Overrides:

All paths here are relative to this module unless stated otherwise.

| File | Types, overrides and owned behavior |
| --- | --- |
| `code/editor.dm` | `/datum/config_entry/flag/allow_custom_sprite_editing`; `/datum/preference_middleware/custom_sprites` implements `get_ui_data()`, `apply_to_human()`, `pre_set_preference()` and `on_new_character()`. `/datum/custom_sprite_editor` owns the window, draft, palette actions, guides, preview timer and save/close lifecycle. |
| `code/persistence.dm` | `/datum/json_savefile/custom_sprites` overrides `New()`, `load()`, `save()`, `set_entry()`, `remove_entry()` and `wipe()` for verified sidecar writes and recovery. Adds the preferences-owned drawing fields and load/save/close/delete helpers, plus `custom_sprites_after_import()`. |
| `code/palette.dm` | `/datum/preference/custom_sprite_palette` implements account storage, default/deserialize/serialize/validation and `is_accessible()`. Its UI is owned by the editor. |
| `code/workspace.dm` | `/datum/sprite_editor_workspace/custom_sprite` overrides `New()`, `is_point_allowed()`, `new_transaction()`, `preprocess_new_transaction()`, `transact()` and `reverse_transact()`. Owns palette validation, mask-aware fill, history limits, serialization and Clear. Adds shared `valid_point_pair()`, `is_point_allowed()`, `prepare_selection_move()` and `sanitize_transaction()` helpers. |
| `code/appearance.dm` | Adds DNA/head drawing fields, human synchronization and `/datum/component/custom_sprite_appearance` limb-signal registration. `/datum/bodypart_overlay/custom_marking` implements `can_draw_on_bodypart()`, `icon_render_key()`, `get_image()`, `color_image()` and `get_all_overlays()`; its `/zone` subtype keeps zone ownership separate. Also owns hair and directional emission/blocker helpers. |
| `code/images.dm` | Palette sampling, bounded runtime caches, drawing hydration/icon generation, hair bounds, limb silhouettes and directional editing masks. |
| `code/codec.dm` | Drawing and zone-map validation, palette-index encoding/decoding, legacy emission normalization and content hashes. |

### Defines:

| File | Define | Purpose |
| --- | --- | --- |
| `code/codec.dm` | `CUSTOM_SPRITE_MAX_CUSTOM_COLORS` | 16 account swatches. |
| `code/codec.dm` | `CUSTOM_SPRITE_MAX_COLORS` | 63 opaque drawing colors. |
| `code/codec.dm` | `CUSTOM_SPRITE_INDEX_ALPHABET` | `0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_`; index 0 is transparent. |
| `code/persistence.dm` | `CUSTOM_SPRITE_MAX_SIDECAR_BYTES` | 8 MiB drawing-file limit. |
| `code/__DEFINES/sprite_editor.dm` at repository root | `SPRITE_EDITOR_TOOL_SELECT` | Shared Select tool bit, `1<<4`. |

### Included files that are not contained in this module:

Paths in this section are relative to the repository root. The core files above
are also required.

| File or directory | Use |
| --- | --- |
| `tgstation.dme` | Includes this module's code and native tests. |
| `config/nova/config_nova.txt` | Documents the editing switch. |
| `modular_nova/modules/preferences_import/code/import_verb.dm` | `prefs_import_invalidate_cache()` calls the drawing cleanup after a successful import. |
| `modular_aphelion/modules/worn_emissives/code/worn_emissives.dm` | Existing final appearance grouping keeps paint masks aligned with the character's pose. |
| `tgui/packages/tgui/interfaces/CustomHairEditor.tsx`, `CustomMarkingsEditor.tsx` | The two interface entry points. |
| `tgui/packages/tgui/interfaces/common/CustomSpriteEditor/` | Shared custom window, palette/context menus, backend types and their tests. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/MainPage.tsx` | Hair editor button. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/LimbsPage.tsx`, `LimbsPage.test.tsx` | Whole-body and zone marking buttons, and their tests. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/types.ts` | Editing-availability flag. |
| `tgui/packages/tgui/interfaces/common/SpriteEditor/index.tsx`, `atoms.ts`, `helpers.ts`, `Types/types.ts`, `Types/Tool.ts` | Shared editor state, rendering/context hooks, gesture cancellation and selection types. |
| `tgui/packages/tgui/interfaces/common/SpriteEditor/Components/AdvancedCanvas.tsx`, `Palette.tsx` | Canvas input/rendering and shared palette behavior. |
| `tgui/packages/tgui/interfaces/common/SpriteEditor/Types/Tools/` | Pencil, Eraser, Eyedropper and Bucket updates; the Select tool and focused tool tests. |
| `tgui/packages/tgui/interfaces/common/SpriteEditor/drawBounds.ts`, `useSpriteEditorHotkeys.ts`, `SpriteEditor.test.tsx` | Cached shading geometry, shared shortcuts/history cancellation and editor interaction tests. |
| `tgui/packages/tgui/interfaces/NtosNanopaint/NanopaintMenuBar.tsx` | Uses the same history cancellation as toolbar and keyboard actions. |
| `tgui/packages/tgui/layouts/Window.tsx`, `Window.test.tsx` | Current-event Alt handling and respecting gestures already claimed by a control. |
| `tgui/packages/tgui/styles/interfaces/CustomSpriteEditor.scss`, `tgui/packages/tgui/styles/main.scss` | Custom editor styling and its stylesheet registration. |
| `code/modules/unit_tests/screenshots/custom_sprite_saved_hair_screenshot_leia_buns.png` | Saved-hair screenshot reference. |
| `icons/blanks/32x32.dmi`, `icons/mob/leg_masks.dmi` | Existing blank frames and leg-layer masks. Hair/body/marking assets are resolved from the character's existing accessories and bodyparts. |

### Credits:

- ImogenOC.
- Built on the existing /tg/station SpriteEditor, painting canvas, NanoPaint and
  unit-test/screenshot infrastructure, plus Nova's character customization.
