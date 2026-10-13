## Fitness levels

Module ID: FITNESS

### Description:

Bigger, more defined arms, legs and torsos for bodies drawn from the human and humanoid sheets, in five levels past
today's sprites:

| Level | Name | Look |
|---|---|---|
| 0 | Baseline | today's sprites |
| 1 | Tuned | a bit bigger, soft |
| 2 | Wired | as big as 1, defined |
| 3 | Hardened | muscular |
| 4 | Overclocked | muscular and defined |
| 5 | Redline | deepest definition |

**Character setup.** Body type has a "Physique (Advanced)" button for species whose own limbs come in fitness levels. Its
menu has "Match strength stat", on by default. There is no strength stat yet, so while it is on the limbs stay at the
baseline. Unticked, it shows a level each for the arms, legs and torso, which mix freely.

**Limbs.** Each level of each limb is a subtype of the plain limb, `<limb>/fitness/level_<N>`, which differs only in the art
it draws: the chest, both arms (their hands too, which draw from the arm's sheet) and both legs, of the human and humanoid
sheets. A leg's level carries over to the digitigrade leg it turns into. The art is one sheet per level, `icons/human_parts_fitness_<N>.dmi`
and `icons/humanoid_parts_fitness_<N>.dmi`, under the plain sheets' state names. The humanoid sheets are the human ones
through the humanoid palette, except the hands, which are the humanoid sheet's own.

A fitness limb draws its level's sheet wherever that sheet holds its state, and its own sheet otherwise (`fitness_sheet()`).
Skin tones off move a human's limbs to the humanoid fitness sheets. Digitigrade legs keep their plain sheet and draw their
level's state from the fitness sheets:

- A human's digitigrade legs are the mammal ones: `mammal_r_leg_digi` and `mammal_l_leg_digi`, in the human fitness sheets.
- A humanoid's are `humanoid_r_leg_digi` and `humanoid_l_leg_digi`, in the humanoid fitness sheets.

**Where the levels live.** The preferences write them to `dna.features` (`FEATURE_FITNESS_ARMS`, `_LEGS` and `_TORSO`) and
swap the limbs. A body's species points its own limb types at the levels when it is gained, so regrown limbs, and the limbs
a change to another species builds, come out at the levels in the DNA. A change that keeps the species, such as a changeling
taking another human's form, leaves the limbs the body has until they regrow. A limb keeps its level when it is cut off and
put back on, or put on someone else.

**Clothing.** Read a limb's level from `fitness_level` on `/obj/item/bodypart`, 0 for the baseline, per limb:
`body.get_bodypart(BODY_ZONE_L_LEG)?.fitness_level`. One leg can be a cybernetic one at 0 while the other is at 3.

**Underclothes.** Underwear, bras, undershirts and socks are redrawn over the limbs they cover, at runtime, each limb at its
own level (`code/garment_fitting.dm`). `make_appearance()` draws a garment's fitted sprite (`fitted_sprite()`): its state
fitted, then cut for a female body, so a body at the baseline with no pecs under it gets today's sprites untouched. A body's
redraw (`update_body()`) refits its underclothes, and a limb changing, regrowing or being swapped for an augment redraws it.
A taur body's legs aren't fitted, but its arms are.

A digitigrade body's legs are fitted through their own templates only where the legs drawn are digitigrade art: a `_d`
state (a style with `has_custom_digi_sprite`), or the legs the GAGS digitigrade mask draws (`digi_icon_state`), which are
cut and masked first and then fitted. A plantigrade state on a digitigrade body, like the babydoll or a one-piece swimsuit,
is fitted as the human legs it draws, as worn clothing is.

Each style has a `fit_mode` (`code/garment_fit_styles.dm`):

| Mode | Styles | What it does |
|---|---|---|
| `GARMENT_FIT_SOLID` | every style by default | Moves the garment's edge out to the limb's new edge and fills the gap with the pixel inside it. Rows above an arm's old top are fitted only for a sleeve, so straps stay put. |
| `GARMENT_FIT_PATTERN` | fishnets | Draws only the new pixels, each copied from 2 pixels further in, so the mesh keeps its rhythm. |
| `GARMENT_FIT_SHADED_SLEEVES` | plain long sleeves | Solid, then the arms' muscle shading in the garment's own colours, and the moved edge a shade darker. |
| `GARMENT_FIT_KNIT` | the ribbed turtleneck and turtleneck leotard | Solid, then the ribs laid again along each sleeve, its inner shadow thinned and its cuff ribbed. |

The fitting is a port of the fitting spec's reference fitters (`fitref.py` and `pecref.py`) and must stay pixel for pixel
equal to them.

**What fitting costs.** A body keeps its fit (`garment_fit` on `/mob/living/carbon/human`: each fitness arm's and leg's
level), worked out again only when its limbs or body shape change (`synchronize_bodyshapes()`), and null at the baseline.
A draw reads it, so a garment on a body at the baseline costs what it did before fitting existed, give or take one look.
Fits are shared datums (`get_garment_fit()`), each with its digitigrade twin and its twins over each pec shape, and a fitted
sprite is cached once a round by its fit and what draws it, in nested lists rather than by a text key, and handed to the
appearance as the cached resource. A fitted garment drawn again costs about what its baseline twin does: measured in a
debug build, within 2 µs of it per draw, and 7 µs more for a top over pecs, which reads the pecs first.

A garment's first fit to a new fit is made by `SSgarment_fitting` (`code/garment_fit_queue.dm`): the garment is drawn as it
is, the fit queued, and the slot drawn again once it's made, a view of one direction's frame at a time in the tick time
other subsystems leave over, so no draw makes one. A fit asked for again while it waits only notes another body to draw
again. A dummy, which is drawn for snapshots such as record photos and character previews, has its fits made as it's drawn,
and so fills the cache for the bodies drawn after it. `GARMENT_FITS_DEFERRED` turns the queue off. `finish_all()` makes
every queued fit at once, for tests and anything else that must see a body fitted now.

`fitting/garment_metadata.json` holds, for the static worn and underclothes sheets, which states pick shaded sleeves and each
fitted state's views' colours, so a fit of one of their states reads only the pixels it moves; a generated icon, a female
cut or a body shape mask is read from its pixels. Each sheet is checked against its hash the first time it's used each
round, and one changed since the file was written is read from its pixels too. Run
`python tools/fitness/gen_garment_metadata.py` whenever one of those sheets changes, and commit the JSON it writes.

**Worn clothing.** A uniform, suit, shoes and gloves worn by a human are fitted the same way, as they're drawn
(`code/worn_fitting.dm`). `build_worn_icon()` fits the icon it has built, after the female cut and every body shape mask
that redraws the legs, and before the item's worn overlays, so its emissive blocker is drawn from the fitted sprite. Each
direction and animation frame is fitted, and an animated state keeps its frame delays, read from its sheet; one whose sheet
can't be read, like a generated one, isn't fitted. Glows the item draws from separate `-emissive` states of its own sheet
get the same fit (`fit_worn_glows()`). Blood, dirt and damage overlays, and uniform accessories, aren't fitted.

- Only an item in one of those four slots is fitted, and only a 32x32 state with four directions: never one held, on a
  mannequin or inside another item, nor a taur's 64x32 sheets. A taur body's arms are fitted, its legs aren't.
- A digitigrade body's legs are fitted through their digitigrade templates only where the legs drawn are digitigrade art:
  a `*_digi` sheet, or the digitigrade legs the GAGS mask draws over a plantigrade sprite (`CLOTHING_DIGITIGRADE_MASK`). A
  plantigrade sprite on a digitigrade body is fitted as the human legs it draws.
- An item's mode is its own `fit_mode` if it sets one (on `/obj/item/clothing`). Otherwise shoes and gloves are fitted
  solid, and uniforms and suits by their sleeves in the front view of the icon drawn, GAGS colours included
  (`garment_sleeve_mode()`, a port of the spec's `sleeve_mode.py`): shaded sleeves where they're one plain colour, solid where
  they're busy, dark or missing. A glow only shows its shape, so it's fitted solid, or as a pattern for a pattern garment.
- Each fit is cached once a round by the fit and the sheet, state, item type, female cut, body shape and colours, never by
  wearer, and made as "What fitting costs" says. An animated state is fitted frame by frame.
- A fitness arm or leg put on or taken off redraws all four slots (`refit_worn_clothing()`): otherwise a leg redraws only the
  uniform and suit, and an arm only the gloves. A level from the preferences redraws them when its swap ends its render batch.

**Pecs under underclothes.** Pecs are part of the body's shape (`shapes_body()` on `/obj/item/organ/genital`): underclothes
covering them draw over them, where any other genital is hidden. Pecs drawn so use their nippleless twin. A uniform or suit
still hides them, and examine and interactions still read them as covered. A butt is hidden by underclothes, as before.

A top worn over the chest (an undershirt, a bra, or underwear that hides breasts) is fitted to pecs drawn under it, after its
limbs, by the pecs' shape and whether they have nipples (`pecs_under_underclothes()`, `garment_fit_shape` on the pec shapes):

- Front and back views: where a pec reaches past the chest's own side, the top's chest panel moves out over it, at most 2
  pixels, its edge's own detail and all. Mesh copies its pattern, and a knit its ribs.
- Side views: the pec's bulge past the body's front is fitted as a limb is.
- Front view: the pecs' lower curve is shaded one step down, a "smile", on solid and shaded-sleeve tops. Knit and mesh tops
  aren't shaded; the `GARMENT_FIT_PEC_SMILE_*` defines pick the modes.

Fitting a top to pecs needs its front and back views' colours: from the sheet metadata for a static sheet's state, so it
costs little more than the limbs' fit, and otherwise read from its pixels, about 2.3 ms more for a solid or mesh top.

**Tops cut for breasts.** Some tops have a version for a chest without breasts, which they draw on any chest without them,
pecs or none, except a female body's without pecs; over breasts they're drawn as they are (`chest_cut_state()`):

- The fishnet tops in both slots ("Fishnet - Sleeved", "Fishnet - Sleeveless" and their greyscale twins) have a bra drawn
  into them. Their `_flat` states are pure mesh with the same scoop neck. "Fishnet - Crew Sleeved" and "Fishnet - Crew
  Sleeveless", and their greyscale twins, are crew-neck mesh tees in the undershirt slot.
- Pasties sit lower on a chest without breasts, over its nipples: `_m` on a bare chest, and `_m1`, `_m2` and `_m3` over pecs,
  bigger pecs and the biggest pecs, by their `garment_fit_shape`, with nipples or without.

**Fitting templates.** `fitting/fit_templates.json` holds, for each limb, level and view, the rows its outline grew in,
its baseline pixels and its fitted pixels' skin tones; the limbs are the arms, the legs, and the digitigrade legs, measured
from the mammal sheet's. A leg in a side view grows toward both its front and its back, and its rows never take the sleeve
test, which only keeps straps on an arm's shoulder. `fitting/pec_templates.json` holds each pec shape's outline, pixels,
side bulge and smile, and the chest's own outline. `tools/fitness/gen_fit_templates.py` and `gen_pec_templates.py` make
them from the sprites: run `python tools/fitness/gen_fit_templates.py` (and `gen_pec_templates.py`) whenever the limb or
pec art changes, and commit the JSON they write. The files are compiled into the resource file and read as the server
starts, with the sheet metadata (`SSgarment_fitting`).

### TG Proc/File Changes:

- `code/datums/sprite_accessories/clothing.dm`: `/datum/sprite_accessory/clothing/proc/make_appearance()` asks
  `get_icon_state()` with the wearer, keys its cache by the sheet too, and draws the fitted sprite (`fitted_sprite()`)
- `code/modules/mob/living/carbon/human/human_update_icons.dm`: `/obj/item/proc/build_worn_icon()` calls
  `fit_worn_icon()` and `fit_worn_glows()`
- `tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/character_preferences/body_type.tsx`: the body
  type input carries the Physique (Advanced) button (`withPhysiqueAdvanced()`)

### Modular Overrides:

- `modular_aphelion/modules/fitness/code/fitness_body.dm`: `/datum/species/on_species_gain()`,
  `/mob/living/carbon/human/synchronize_bodyshapes()`
- `modular_aphelion/modules/fitness/code/fitness_limbs.dm`: `/obj/item/bodypart/update_limb()`,
  `/obj/item/bodypart/generate_icon_key()`, `/obj/item/bodypart/generate_husk_key()`
- `modular_aphelion/modules/fitness/code/worn_fitting.dm`: `/obj/item/bodypart/try_attach_limb()`,
  `/obj/item/bodypart/drop_limb()`
- `modular_aphelion/modules/fitness/code/garment_fit_styles.dm`: `fit_mode` on underclothes styles, and
  `garment_fit_shape` on the pec shapes

### Defines:

- `code/__DEFINES/~aphelion_defines/fitness.dm`: `FITNESS_LEVEL_BASELINE`, `FITNESS_LEVEL_MAX`, `FEATURE_FITNESS_ARMS`,
  `FEATURE_FITNESS_LEGS`, `FEATURE_FITNESS_TORSO`, `FITNESS_LIMB_TYPE`, `GARMENT_FIT_SOLID`, `GARMENT_FIT_PATTERN`,
  `GARMENT_FIT_SHADED_SLEEVES`, `GARMENT_FIT_KNIT`, the `GARMENT_FIT_PEC_SMILE_*` modes, `GARMENT_FIT_MAX_FRAMES`,
  `GARMENT_FITS_DEFERRED` and the `GARMENT_FIT_REDRAW_*` flags
- `modular_aphelion/modules/fitness/code/fitness_limbs.dm`: `FITNESS_SHEET_HUMAN_1` to `_5` and
  `FITNESS_SHEET_HUMANOID_1` to `_5`. File-local.
- `modular_aphelion/modules/fitness/code/garment_fitting.dm`: `FIT_INDEX`, `PEC_PANEL_MAX_MOVE` and the `SLEEVE_*`
  thresholds. File-local.
- `modular_aphelion/modules/fitness/code/worn_fitting.dm`: `WORN_FIT_BODYSHAPES` and `WORN_FIT_REDRAW`. File-local.
- `modular_aphelion/modules/fitness/code/garment_fit_queue.dm`: `GARMENT_FIT_MAX_PIECES` and
  `GARMENT_FIT_MAX_FINISH_ROUNDS`. File-local.

### Included files that are not contained in this module:

- `modular_nova/modules/customization/modules/mob/dead/new_player/sprite_accessories/underwear/bras.dm`:
  `chest_cut_state()`, and the fishnet and pasties `get_icon_state()` overrides
- `modular_nova/modules/customization/modules/mob/dead/new_player/sprite_accessories/underwear/undershirts.dm`: the
  fishnet `get_icon_state()` overrides
- `modular_nova/master_files/icons/mob/clothing/underwear.dmi`: the mesh tops' `_flat` states and the pasties'
  `_m`, `_m1`, `_m2` and `_m3` states
- `modular_nova/modules/customization/modules/mob/dead/new_player/sprite_accessories/genitals.dm`:
  `/datum/sprite_accessory/genital/is_hidden()` asks `hidden_by_clothing()`, and the biggest pec shapes
- `modular_nova/modules/modular_items/lewd_items/code/lewd_organs/_genital.dm`: `covered_by_outer_clothing()`,
  `covered_by_underclothes()`, `shapes_body()` and `hidden_by_clothing()`
- `modular_nova/modules/modular_items/lewd_items/code/lewd_organs/breasts.dm`: pecs shape the body, draw their
  nippleless twin under underclothes, and bigger pecs draw their back
- `modular_nova/master_files/icons/mob/sprite_accessory/genitals/breasts_onmob.dmi`: the bigger pecs' back and the
  biggest pecs; `fitting/pec_templates.json` is made from this sheet
- `modular_nova/master_files/icons/mob/sprite_accessory/genitals/breasts_onmob_jiggle.dmi` and the four
  `breasts_onmob_pecbounce*.dmi` sheets: the same states
- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/PhysiqueAdvanced.tsx` (the Physique (Advanced)
  menu)
- `tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/character_preferences/aphelion/fitness.tsx`
- `tgui/packages/tgui/styles/interfaces/PhysiqueAdvanced.scss`, loaded by
  `tgui/packages/tgui/styles/meridianos/_index.scss`
- `code/modules/unit_tests/~nova/fitness.dm`, included from `code/modules/unit_tests/_unit_tests.dm`
- `code/modules/unit_tests/~nova/pecs.dm`: the `flat_mesh` and `under_underclothes` tests
- `tools/fitness/`: `gen_fit_templates.py`, `gen_pec_templates.py` and `gen_garment_metadata.py`, which write the
  `fitting/` JSON files
- `tgstation.dme`

### Credits:

- mal
