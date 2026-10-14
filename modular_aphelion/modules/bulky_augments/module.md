## Recolourable bulky augments

Module ID: BULKY_AUGMENTS

### Description:

Bulky augment finishes for cybernetic arms, with their hands, and legs, drawn on the fitness module's Muscular outline in
colours the player picks for each augment slot in character setup. The finishes whose design has lights glow.

**Finishes.** Each finish is a `/datum/robotic_style/recolorable` subtype (`code/finishes.dm`), so it joins
`GLOB.robotic_styles_list`, the augments' finish picker and every path that takes a robotic style, with no special case
there.

| Finish | Id | Channels the editor shows | Lit zones |
|---|---|---|---|
| Jet Plating | `jet` | Plating (paint), Joints (frame) | none |
| Silverhand | `silverhand` | Chrome, Panel, Frame, Lights | arms |
| Ghostrunner | `ghostrunner` | Plating (frame), Lights | arms, legs |
| Maelstrom Wired | `maelstrom_wired` | Hose, Wrap, Frame, Lights | legs |
| Gorilla Arms | `gorilla` | Plating, Knuckles, Frame | none |
| Maelstrom Brute | `maelstrom_brute` | Iron, Brass, Frame, Lights | arms, legs |
| Synthflesh | `synthflesh` | Chassis, Seams, LED | arms, legs |
| Maine | `maine` | Gauntlets, Knuckles, Seams | none |
| Automail | `automail` | Plates, Brass, Joints | none |
| Jet Boots | `jet_boots` | Plating, Joints | none |
| Synthskin | `synthskin` | Seams (frame); no metal | none |

A finish is data only: its states in the sheets and a subtype. A finish's `name` is its save key, so renaming one drops it
from every save that wears it.

A finish's robotic style vars are fixed by the abstract type: `icon` (the human skin sheet), `supported_slots`
(`ARMS|LEGS`), `has_digi` and `bodyshape_override = BODYSHAPE_HUMANOID`. Each subtype sets `limb_id_override`, its id, the
prefix of its states, so Nova's `set_icon_greyscale()` screams at once over a missing `<id>_<zone>` instead of drawing a
blank limb. Its own data is `channels` (the channels its art uses, each with the label the editor shows), `default_colors`
and `presets` (name to colour string). Only a finish whose design has lights has a `"lights"` channel.

**Colours.** A finish draws from up to four player colours, kept as one colour string: `"#rrggbb"` four times run together,
lowercase, in the order paint, accent, frame, lights (`sanitize_augment_colors()` checks one). A finish without lights keeps
the fourth colour unused.

- Paint is the main plating, accent the trim, frame the joints and inner structure, and lights the strips and clusters.
- Two small untinted shines are fixed: `AUGMENT_SHINE_W` (`#fafbff`) and `AUGMENT_SHINE_X` (`#c4c7d0`).
- The skin, synthflesh and the thigh above a leg's join, is the body's own skin or mutant colour.

Each slot keeps its own colours (`/datum/preferences/var/augment_limb_colors`, slot to colour string), and a slot without
any draws its finish's `default_colors`.

**Sheets.** `python tools/bulky_augments/gen_augment_sheets.py` writes three sheets from each finish's art sources in
`tools/bulky_augments/art/<id>/` (see `tools/bulky_augments/README.md`). Rerun it whenever an art source changes, commit the
sheets with it, and never edit the sheets by hand. Every state is 32x32 in four directions, and `zone` is one of
`BULKY_AUGMENT_ZONES`: `r_arm`, `l_arm`, `r_hand`, `l_hand`, `r_leg` or `l_leg`.

| Sheet | States | What they hold |
|---|---|---|
| `icons/bulky_augments.dmi` | `<id>_<zone>`, `<id>_<zone>_e` | the skin base in the human skin ramp (the Muscular limb's own pixels, with the finish's skin reshades), and the lights mask, only for a zone whose art has lights and, empty where it has none, for the hand of a lit arm |
| `icons/bulky_augments_humanoid.dmi` | the same | the skin base through the humanoid ramp, and the same masks |
| `icons/bulky_augments_paint.dmi` | `<id>_<zone>_paint`, `<id>_<zone>_glow` | the machine pixels packed: in `_paint` red is the paint shade, green accent and blue frame; in `_glow` red is the light shade (a light's core adds a little green, the art's white lift), green the `w` shine and blue the `x` shine. Each is left out where a zone has none of its pixels |

The skin base covers the whole outline, so the limb's own emissive blocker covers the whole limb, and its texture and alpha
behave as an organic limb's.

**Applying a finish.** `apply_style_to_limb()` hands a recolourable finish to its `apply_to()`, whatever augment item it is
on. The limb then:

- carries `/datum/element/augment_paint`, which draws its paint and keys its icons (below);
- draws greyscale, its skin base as its own image;
- takes the slot's colours, or the finish's default;
- glows only when the finish has lights and the limb's own zone has a lights mask, and only while the character's
  `allow_emissives` preference is on, as all player-set glow does (a limb made without preferences, like an admin spawn,
  glows). The zone is checked once, here, never as the limb is drawn;
- is `MUSCLE_SIZE_MUSCULAR`, so clothes and underclothes fit it as a Muscular limb. It's set at runtime, never as a type var,
  since `init_fitness_limb_families()` would take a typed robot limb for a fitness family.

A finish's skin parts take the body's skin tone or mutant colour, which a limb learns only as it is set up for its owner
(`update_limb()`'s `is_creating`). The body's own limbs in the preview have it already. A limb spawned for a finish (the
spawn branch of `/datum/augment_item/limb/apply()`) is set up so once it is on the body, and a protean's regrown limb is too.

`clear_augment_finish()` takes a finish off: the element and the colours go, and the glow and muscle size go back to the
limb type's own. The element goes on only while a limb wears no finish yet, so it is never added twice.

The character setup preview changes the body's own limbs in place, so it also takes a finish off again:

- Where a slot keeps an augment, `apply()` clears the limb first and gives it the muscle size its spawned augment will have,
  the item type's (Normal). A brand finish's preview so fits clothes as the spawned limb will.
- Where a slot has no augment, the reset loop in `limbs_and_markings.dm` clears the limb. The body's shape and garment fit
  are then taken again from its limbs, which the loop changed after they were first taken.

A protean's regrown limb wears the finish its lost limb wore: the protean's limb snapshot keeps the colours, glow and body
shape, and `restore_finish()` hands the regrown limb to the finish's `apply_to()`, then gives it the lost limb's glow back.

**Drawing.** `/datum/element/augment_paint` (`code/limbs.dm`) is on finished limbs only, so every other limb redraws as it
always has. It listens to two signals tg's limb drawing already sends:

- `COMSIG_BODYPART_GET_LIMB_ICON`, at the end of `get_limb_icon()`, after the leg split, height and textures: it adds the
  paint (`draw_augment_paint()`). After the limb's images go a copy of its own image drawing its zone's `_paint` state and
  one drawing its `_glow`, and the same for an arm's hand. Each is coloured by a numeric 4x4 colour matrix
  (`augment_paint_matrix()`), rows paint, accent and frame (or lights and the two shines), then the limb's alpha. The copies
  keep the limb's layer, height, textures and facing. A leg's are split into its two halves through the masked leg cache, as
  `draw_muscle_definition()` splits definition. A zone without a packed state draws no copy for it.
- `COMSIG_BODYPART_GENERATE_ICON_KEY`: it points the limb at the skin sheet in its owner's ramp, the humanoid one under a
  mutant colour (`update_augment_skin_sheet()`), and keys the limb by its colours, its glow, its alpha and that sheet. The
  limb icon cache is shared by every body, so without them one body's arm would be served to another. A body keys a limb
  after `update_limb()` has learnt its owner's `species_color` and before drawing it; a dropped limb keeps the sheet it had
  when it was last keyed or set up.

The lights glow through tg's own limb emissives: a limb that `is_emissive` draws `<state>_e` from its skin sheet before the
leg split, so the mask is split, offset and flagged as the limb is. tg lights an arm's hand along with the arm, so the
generator gives the hand of every lit arm a mask too, empty where the hand has no lights: no finish lights a hand today.

Anything else the limb lights, like a glowing marking, would light the plates over it in the dark. So then each `_paint`
copy also gets an emissive blocker, a copy of the limb's own. A limb with nothing else lit gets none. Only an emissive counts,
told by the constant row of its colour matrix; the emissive blockers that overlays (bodypart overlays, a bulge) bring along
don't. The finish's own lights, the limb's and its hand's masks, are never under a `_paint` pixel, so they stay lit.

The matrices are numeric 16-number lists, never rows of colour strings, which `map_colors_inferred()` would write into the
drawn character preview's iconforge recipe. Each is built once per colours, state and alpha, and kept until 2048 are kept
(`AUGMENT_PAINT_MATRIX_CACHE_SIZE`); then the cache starts over, so applying colours without end can't grow it. No icon is
made for any colour: a zone draws its skin base, at most two copies and its lights mask.

**Preferences.** The colours save as `augment_limb_colors` in the character's save data. On load (`load_augment_colors()`) an
entry is kept only when its slot wears a recolourable finish and its string is valid, then lowercased; anything else is
dropped, never drawn. The preferences import sanitiser keeps their text values.

Changing a slot to another finish, or to none, clears its colours, so a new finish starts at its own default. Changing the
augment item with the finish kept keeps them.

`/datum/preference_middleware/augment_paint` (`code/preferences.dm`, key `augment_paint`) gives character setup:

- constant data, sent once in `preferences.json`: each finish by name, with its `id`, `channels` (`{key, label}`),
  `default`, `presets` (`{name, colors}`) and `zones` (zone to `{paint, glow}`, 0 or 1, read from the paint sheet), the
  editor's `swatches`, `metal` for paint, accent and frame, and `lights`, and `brands`: each brand style by name, with its
  `key` and the `zones` it has sprites for (below);
- window data: `augment_colors` (slot to colour string), `augment_paint_skin` (`{color, humanoid}`: the preview body's
  chest colour, and whether it is a mutant colour) and `augment_paint_emissive` (whether the lights glow);
- the `augment_paint` spritesheet, sent with the window;
- the actions `set_augment_colors {slot, colors}` (a colour string, or null for the finish's default) and
  `copy_augment_colors {slot}` (to every slot wearing a recolourable finish). Each needs a slot wearing a recolourable finish,
  redraws the preview body, and answers with `augment_colors` alone;
- the action `augment_brand_sprites` (no params), which sends the `augment_brands` spritesheet
  (`send_augment_brand_sprites()`, as the species page sends its sheets).

The window's data is sent as each change is made, and may read the preview body before it is rebuilt. So the skin follows
the rebuilt body too: the character preview module's answer, sent right after the rebuild, carries `augment_paint_skin`
whenever it changed since the page last got it (`add_preview_answer()`).

`set_bodypart_aug_style`'s answer carries `augment_colors` too, since a new finish clears a slot's.

**The editor's sprites.** `/datum/asset/spritesheet_batched/augment_paint` (`code/assets.dm`) cuts the sheets into 32x32
views, which the editor recolours on the client:

- `augment_paint32x32 <id>-<zone>-<layer>-<dir>`, `layer` being `skin`, `skinh` (the humanoid ramp), `paint` or `glow`
  (only where the paint sheet holds the state), and `dir` `south`, `north`, `east` or `west`;
- `augment_paint32x32 body-<dir>`, the Muscular body, the preview's silhouette.

`/datum/asset/spritesheet_batched/augment_brands` (`code/assets.dm`) holds the finish picker's try-on sprites,
`augment_brands32x32 brand-<key>-<zone>-<dir>`: each brand style's limbs as the game draws them. They are about 141 KB (680
sprites, against the finishes' 162 KB), and only the finish picker's try-on uses them. So they are not sent with the window,
which would make every preferences open pay for them. The window asks for the sheet once, in the background, as the Augments room is about to be needed
(`augment_brand_sprites`), and nobody who stays away from it loads it.

A brand sprite is the state an augment limb in that style draws (`augment_brand_states()`), resolved as
`apply_style_to_limb()` and `get_limb_icon()` resolve it: `<limb id>_<zone>` in the style's icon, the limb id being the
style's `limb_id_override` or `robotic`, which every styled augment limb has. An arm's hand comes with it. A digitigrade leg
is the zone `r_leg_digi` or `l_leg_digi`, state `<limb id>_<leg>_digi`, only for a style that keeps the digitigrade shape
(`has_digi` and no `bodyshape_override` dropping it): the others draw their plain leg on a digitigrade body. Only zones a
slot can wear the style on, and states with four directions, are in. `key` is the last part of the style's type
(`augment_brand_key()`). A brand sprite is drawn as is; the game tints it with the body's skin when its augment item draws
greyscale, which character setup's augment items carry as `uses_greyscale`.

A styled augment item also carries `default_style` (`build_augment_choices()`), the brand whose sprites are exactly its own
plantigrade look with no style chosen, which the finish picker tries on for "None": apply()'s look, the limb type's icon, or
its greyscale icon, and state in its zone, an arm's hand coming with it. The Cyborg arms and legs take `Cyborg` and the
Prosthetic ones `Surplus`, greyscale variants included. Heads and chests take none, since the brand sprites leave them out,
and for them hovering "None" draws nothing. A leg tries "None" on only on a plantigrade body: on a digitigrade body it
becomes a digitigrade cybernetic leg (`digitigrade_parts.dmi`), which no brand draws, so the room shows no leg there.

Iconforge makes both sheets from the game's icons, in the background at init (`SSasset_loading`), and the batched
spritesheets' smart cache keeps them across rounds, so each is made once per change of its icons.

**The editor.** In the Augments+ room, a part card whose finish is recolourable gets a palette button on its FINISH row, and
the Readout shows that slot's colours as chips. The palette opens a flyout over the card's side of the stage: a scan preview
of the part in four directions over the body's silhouette, recoloured on the GPU (SVG `feColorMatrix`) as colours change, with
a lights-off view; the finish's presets; a row per channel with a picker and quick swatches; and Copy to all parts and Reset
to default. Nothing reaches the server until Apply, a preset, a copy or a reset. With `allow_emissives` off, the lights row
says the lights won't glow until it's on.

In the finish picker, a recolourable finish carries a palette tag, and the finish under the pointer or the keyboard is tried
on the body scan at once, client side, as the markings room tries markings on: its sprites from the `augment_paint` sheet,
or a brand finish's from `augment_brands`, drawn over the scan's facing and lined up with it, with the limb it replaces
masked out of the character through the preview's region map, and a far leg in profile kept behind the near one. The finish
the part wears is not tried on, and "None" shows the augment's own look when its item names a brand style for it
(`default_style`), except on a digitigrade body's leg, where it shows nothing. A finish whose sprites can't be drawn yet, as
a brand finish's before its sheet has come, changes nothing on the body until they can. The window asks for that sheet once
the pointer or the keyboard rests 100 ms on the Augments+ tab or the room's Augments button, or once the stage has shown and
the window is idle, and a window opened again asks again, in case an ask went unanswered. On a digitigrade body every slot
offers only the styles with digitigrade sprites, the ones the server keeps there. Only a pick reaches the server. A press
anywhere outside an open picker or editor closes it, except on the window's drag and resize handles and on the scan's rotate
buttons and lights key, which sit over the stage's scrim so the character can be turned and lit with one open. What is tried
on stays on through the trip to them and while they are used: rows the pointer crosses heading out for them don't take over,
and it comes off once the pointer rests anywhere else. The scan has the other previews' lights key, and each card's trace
lands on its part's pixels in the scan's current facing: a part hidden in that facing lands on its pair, a missing limb
keeps its card's fixed port, and a taur's legs land on its taur body.

**Not done yet:**

- Digitigrade art. Like every brand finish, these draw plantigrade legs on a digitigrade body (`bodyshape_override =
  BODYSHAPE_HUMANOID` with `has_digi`), and the body's clothes follow its legs. Digi art needs `_digi` states, on the
  Muscular digi outline (`mammal_*_leg_digi` in the size sheets), and each finish's `bodyshape_override` dropped.
- Heads and chests.
- Recolouring in the round: colours are set in character setup and travel with the limb.
- The spraycan restyle, which hands `image()` a `/datum/robotic_style` (`crayons.dm`) and so breaks every finish.
- Lit hands. A finish whose art lit a hand but not its arm would not glow there: the glow follows the limb's own zone.

### TG Proc/File Changes:

- None

### Modular Overrides:

- `modular_aphelion/modules/bulky_augments/code/preferences.dm`: `add_preview_answer()` on the middleware, a proc the
  character preview module adds to `/datum/preference_middleware`

### Defines:

- `code/__DEFINES/~aphelion_defines/bulky_augments.dm`: `BULKY_AUGMENTS_SHEET`, `BULKY_AUGMENTS_SHEET_HUMANOID`,
  `BULKY_AUGMENTS_PAINT_SHEET`, `BULKY_AUGMENT_ZONES`, `AUGMENT_SHINE_W` and `AUGMENT_SHINE_X`

### Included files that are not contained in this module:

- `modular_nova/modules/customization/modules/client/augment/limbs.dm`: `/datum/augment_item/limb/apply()` clears the
  preview's limb and keeps a finish's limb greyscale, and sets a spawned finished limb up for its owner, so it takes the
  body's skin; `apply_style_to_limb()` hands a recolourable finish to `apply_to()`
- `modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm`: `apply_to_human()`'s reset
  loop clears a finish, and the body's shape and garment fit are taken again after it; `set_bodypart_aug_style()` clears a
  slot's colours for a new finish, `send_augment_styles()` sends the colours with the finishes, and
  `build_augment_choices()` marks the augment items that take a style and draw greyscale (`uses_greyscale`, only on those)
  and gives a styled item its `default_style` where a brand draws its own plantigrade look
- `modular_nova/master_files/code/modules/client/preferences_savefile.dm`: `load_character_nova()` and
  `save_character_nova()`
- `modular_nova/modules/preferences_import/code/_sanitise.dm`: `prefs_import_pass1()` keeps `augment_limb_colors`
- `modular_nova/modules/protean/code/organs/protean_brain.dm`: `snapshot_limb()` keeps a finish's colours and glow,
  `cached_visual_vars` keeps a limb's body shape, and `restore_finish()` puts the finish back on a regrown limb
  (`replace_limbs()`)
- `modular_aphelion/modules/character_preview/code/drawing.dm`: `/datum/preference_middleware/proc/add_preview_answer()`,
  which `start_answer()` asks every middleware for
- `code/modules/unit_tests/~nova/bulky_augments.dm`: `augment_paint_cache`, `augment_paint_fit`, `augment_paint_save` and
  `augment_paint_sheets`, included from `code/modules/unit_tests/_unit_tests.dm`
- `tools/bulky_augments/`: `gen_augment_sheets.py`, which writes the three sheets, its `README.md`, and the art sources in
  `art/<id>/`
- `tgui/packages/tgui/interfaces/PreferencesMenu/types.ts`
- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/LimbsPage.tsx`
- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/index.tsx`: the Augments+ tab asks for the brand sprites
  on intent
- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/MarkingsRoom/Room.tsx`: the room's Augments button does too
- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/MarkingsRoom/augments/`: `index.tsx`, `parts.ts`,
  `brands.ts`, `paint.tsx`, `tried.ts`, `tryOn.tsx`, `brands.test.tsx`, `paint.test.tsx`, `picker.test.tsx`, `stage.test.tsx` and
  `tryOn.test.tsx`
- `tgui/packages/tgui/styles/meridianos/_augments-paint.scss`, loaded by `tgui/packages/tgui/styles/meridianos/_preferences.scss`,
  and `tgui/packages/tgui/styles/meridianos/_augments-stage.scss`
- `tgstation.dme`

### Credits:

- mal
