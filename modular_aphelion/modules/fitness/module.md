## Muscle size and definition

Module ID: FITNESS

### Description:

Bodies drawn from the human and humanoid sheets come in three muscle sizes, each with four steps of muscle definition. A
body has one size and one definition, for its chest, arms and legs alike.

| Size | Look |
|---|---|
| Normal | today's sprites |
| Athletic | a bit bigger |
| Muscular | muscular, with a rounder side-view biceps and, on a male chest, a glute bump in the side views |

| Definition | Look |
|---|---|
| None | the size's own sprites |
| Toned | light definition |
| Defined | clear definition |
| Shredded | the deepest definition |

**Character setup.** For a species whose own limbs come in muscle sizes, Body type has three inputs under it: a "Muscles -
automatic" box, ticked by default, and a slider each for "Muscle definition" and "Muscle size", locked while the box is
ticked. Automatic muscles will follow the character's stats, dexterity their definition and strength their size. Neither
stat exists yet, so automatic means Normal with no definition. The sliders keep their steps while the box is ticked.

**Limbs.** Each limb drawn from the human or humanoid sheet, and each digitigrade leg they turn into, has a family of
subtypes (`<limb>/fitness`, `<limb>/fitness/athletic` and `<limb>/fitness/muscular`) that differ only in the art they draw:

- The plain limb is Normal with no definition.
- `<limb>/fitness` is Normal with a definition.
- `athletic` and `muscular` draw their size's sheet, at any definition.

A digitigrade leg draws no definition, so its family has the sizes only. A leg's size carries over to the digitigrade leg it
turns into. The plain limb takes no definition: drawing one needs the fitness subtypes' overrides, and keeping them off the
plain limb keeps its redraw as it was.

**Sizes.** The size sheets are `icons/human_parts_athletic.dmi`, `human_parts_muscular.dmi` and their humanoid twins, under
the plain sheets' state names; Normal is today's sheets, untouched. The humanoid sheets are the human ones through the
humanoid palette, except a few humanoid edge pixels and the hands, which are the humanoid sheet's own. A size limb draws its
size's sheet wherever that sheet holds its state, and its own sheet otherwise (`fitness_sheet()`). Skin tones off move a
human's limbs to the humanoid size sheets. Digitigrade legs keep their plain sheet and draw their size's state from the size
sheets:

- A human's digitigrade legs are the mammal ones: `mammal_r_leg_digi` and `mammal_l_leg_digi`, in the human size sheets.
- A humanoid's are `humanoid_r_leg_digi` and `humanoid_l_leg_digi`, in the humanoid size sheets.

The Muscular sheets carry a rounder side-view biceps (one more pixel on the arm's front edge, `r_arm` E and `l_arm` W) and
the male chest's glute bump (3 pixels behind the hand, `chest_m` E and W). In both size sheets, the west view's near leg
mirrors the east view's.

**Definition.** The overlays are `icons/human_definition.dmi` and `icons/humanoid_definition.dmi`, one state for each state a
limb draws, size and step: `<drawn state>_<size>_<step>`, like `human_chest_f_muscular_2` or `humanoid_r_leg_normal_1`. An
overlay holds only the pixels its step changes on its size's sprite, in the sheet's own greyscale, all inside the limb's
outline: definition never changes an outline. The chest's overlays carry its abs, back and glutes.

A fitness limb with a definition draws its overlay (`draw_muscle_definition()`) as a copy of its own image, so it is
coloured, offset for height and textured as the limb is. The overlay sits right above the limb, both halves of a leg, and so
under its markings, custom markings, tattoos and everything else drawn on it. On a husk it's toned as the limb is
(`husk_toned_sheet()`). No icon is made for it: the leg halves come from the masked leg cache, and a husk's tone is made
once per sheet. Nothing is drawn where the overlay sheet has no state for what the limb draws: on hands, digitigrade legs,
and a limb drawn from another sheet, like another species' look. Nor is anything drawn on a limb that draws nothing itself,
like a taur's hidden legs.

**Where size and definition live.** The preferences write them to `dna.features` (`FEATURE_MUSCLE_SIZE` and
`FEATURE_MUSCLE_DEFINITION`), before species, and swap the limbs (`update_fitness_limbs()`). A body's species points its own
limb types at its size and definition when it is gained, so regrown limbs, and the limbs a change to another species builds,
come out at the size and definition in the DNA. A change that keeps the species, such as a changeling taking another human's
form, leaves the limbs the body has until they regrow.

A limb's size is its type, and its definition its own (`muscle_definition`): a new fitness limb takes the definition in its
first owner's DNA. A limb keeps both when it is cut off and put back on, or put on someone else.

**Clothing.** Read a limb's size from `muscle_size` on `/obj/item/bodypart`, a `MUSCLE_SIZE_*` define, per limb:
`body.get_bodypart(BODY_ZONE_L_LEG)?.muscle_size`. One leg can be a cybernetic one at Normal while the other is Muscular.
Definition changes no outline, so it never changes a fit.

**Underclothes.** Underwear, bras, undershirts and socks are redrawn over the limbs they cover, at runtime, each limb at its
own size (`code/garment_fitting.dm`). `make_appearance()` draws a garment's fitted sprite (`fitted_sprite()`): its state
fitted, then cut for a female body, so a Normal body with no pecs under it gets today's sprites untouched. A body's redraw
(`update_body()`) refits its underclothes, and a limb changing, regrowing or being swapped for an augment redraws it. A taur
body's legs and chest aren't fitted, but its arms are.

A digitigrade body's legs are fitted through their own templates only where the legs drawn are digitigrade art: a `_d` state
(a style with `has_custom_digi_sprite`), or the legs the GAGS digitigrade mask draws (`digi_icon_state`), which are cut and
masked first and then fitted. A plantigrade state on a digitigrade body, like the babydoll or a one-piece swimsuit, is fitted
as the human legs it draws, as worn clothing is.

Each style has a `fit_mode` (`code/garment_fit_styles.dm`):

| Mode | Styles | What it does |
|---|---|---|
| `GARMENT_FIT_SOLID` | every style by default | Moves the garment's edge out to the limb's new edge and fills the gap with the pixel inside it. Rows above an arm's old top are fitted only for a sleeve, so straps stay put. |
| `GARMENT_FIT_PATTERN` | fishnets and the shibari sleeves | Draws only the new pixels, each copied from 2 pixels further in, so the mesh keeps its rhythm and rope its gaps. |
| `GARMENT_FIT_SHADED_SLEEVES` | plain long sleeves | Solid, then the arms' muscle shading in each sleeve's own colours, and the moved edge a shade darker. |
| `GARMENT_FIT_KNIT` | the ribbed turtleneck and turtleneck leotard | Solid, then the ribs laid again along each sleeve, its inner shadow thinned and its cuff ribbed. |

Shaded sleeves take the size's own arm shading, at no definition, whatever the arm's definition.

Shaded sleeves step down the garment's colours, brightest to darkest, through each sleeve's own colours alone
(`sleeve_colours()`): those the garment has over that arm, and its other colours of the same family. A lit colour is of the
family when it's a grey and the sleeve has a lit grey, or when its hue is within 20 degrees of every lit hue the sleeve has,
which keeps the sleeve one hue as `garment_sleeve_mode()` judges it. A dark one, an outline's or a shadow's, is of the family
when it's a grey and the sleeve has a grey, or its hue is within 20 degrees of any the sleeve has. A garment of one material
shades as it did with its whole ramp. A uniform's sleeve no longer takes its skirt's, belt's or boots' colour, which the whole
ramp gave the sailor dress's and the cowboy uniform's moved edges (Pol, 2026-10-14).

Each step also keeps the stepped pixel's own family (`garment_colours_kin()`), so a sleeve of a hue and a grey doesn't step
one into the other: DutchUniform's grey edge took its red, and janimaid's grey frill its navy. A step may go:

- into a charcoal or a black, a dark near-grey, which shades and outlines every colour;
- from a dark colour, an outline's or a shadow's, to another;
- from a near-grey to another, a near-grey's channels spreading under 24% of its brightest, so a greyscale garment's own
  faintly blue shading stays one ramp;
- or into a hue within 20 degrees of the pixel's hue, or of a charcoal's cast, its hue however slight: a grey never steps
  into a hue, while a blue-cast charcoal may step into navy, as the security uniforms' edges do.

A step that doesn't fit takes the next darker one that does, and a pixel with none is left as it is.

**Sleeves.** Whether a garment has a sleeve over an arm is judged once, from its front view, where the arms show whole: it does
when it covers at least half of the upper third of the arm's baseline pixels there. A short sleeve covers the upper arm and
counts; a strap covers a pixel or two of it and doesn't. Every view's fit uses that answer (`garment_front_sleeves()`), so a
fit does the front views last, while they're still the garment's own (`GARMENT_FIT_PIECE_VIEW()`). A leg is judged the same
way in each view, from the upper third of its own baseline pixels there. Under a sleeve:

- The rows an arm grew into above its old top are fitted.
- A solid row is also fitted where the garment covers its old edge alone, a hem a pixel thick against the arm's edge. The
  gap takes the edge pixel when the pixel inside it is bare, so the fit never opens a hole.
- Side views, unless the garment is a pattern: the bigger arm's pixels the sleeve leaves bare, down to where today's arm
  begins, take the nearest sleeve colour in their row (`close_hem()`), so a short sleeve's edge doesn't stop partway across
  a bigger arm.

**Polos.** A polo's side views leave the near forearm bare below the short sleeve, edged at the back by a 1 pixel strip. The
hem rule above takes that strip for a sleeve's one-pixel hem and moves it out across a bigger forearm, which then looked thin
(Pol, 2026-10-14). The polos opt in to one more rule after it (`bares_near_forearm()`, on the four tg polos and Nova's): in
each side-view row where the polo as drawn leaves some of today's near arm bare, the fitted polo is cleared over the whole
near arm of its size (`bare_near_forearm()`), so the forearm shows at its own width. Rows its sleeve covers are fitted as
before. Other shirts, and the polo-styled CentCom intern jumpsuit, keep their fit: the jumpsuit leaves the forearm bare
with no strip, and its one pixel over a Muscular forearm is its own torso, as on the plain shirts.

**Glutes.** The Muscular male chest's glute bump, 3 pixels behind the hand in the side views, is covered by garments that
reach the hips' back edge there: its bands (`"chest_m"` in the templates) are fitted after the legs, as a pec's side bulge
is, so a garment covering the old edge and the pixel inside it moves out over the bump. Most bottoms, uniforms and suits are
already drawn wide enough at the hips and stay as they are; what changes is the garments that stop at today's outline there,
like the turtlenecks, the leotard and the mesh. The female chest and the Athletic one have no bump. A body's fit has the chest
only while its chest is a fitness chest drawn male (`limb_gender`), so a fitness chest refits its body's garments each time
it's set up for the body, which sets its male or female art.

The fitting is a port of the fitting spec's reference fitters (`fitref.py` with `fitref_v6.py`'s rules,
`fitref_v10.py`'s polo forearm, `fitref_v11.py`'s sleeve colours and `fitref_v12.py`'s own-family steps, `pecref.py` and
`sleeve_mode.py`) and must stay pixel for pixel equal to them.

**What fitting costs.** A body keeps its fit (`garment_fit` on `/mob/living/carbon/human`: each fitness arm's and leg's size,
and its chest's where it has glutes to fit), worked out again only when its limbs or body shape change
(`synchronize_bodyshapes()`), and null on a Normal body. A draw reads it, so a garment on a Normal body costs what it did
before fitting existed, give or take one look. Fits are shared datums (`get_garment_fit()`), each with its digitigrade twin,
its twins over each pec shape and, over pecs, its twins flexing from each flex sheet (`flexing()`), and a fitted sprite is cached once a round by its fit and what draws it, in nested lists
rather than by a text key, and handed to the appearance as the cached resource. A fitted garment drawn again costs about what
its Normal twin does: measured in a debug build, within 2 µs of it per draw, and 7 µs more for a top over pecs, which reads
the pecs first.

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
`python lab/fitness/gen_garment_metadata.py` whenever one of those sheets changes, and commit the JSON it writes. `lab/` is
a git-ignored folder kept out of commits, so a checkout without it has only the JSON.

**Worn clothing.** A uniform, suit, shoes and gloves worn by a human are fitted the same way, as they're drawn
(`code/worn_fitting.dm`). `build_worn_icon()` fits the icon it has built, after the female cut and every body shape mask
that redraws the legs, and before the item's worn overlays, so its emissive blocker is drawn from the fitted sprite. Each
direction and animation frame is fitted, and an animated state keeps its frame delays, read from its sheet; one whose sheet
can't be read, like a generated one, isn't fitted. Glows the item draws from separate `-emissive` states of its own sheet
get the same fit (`fit_worn_glows()`). Blood, dirt and damage overlays, and uniform accessories, aren't fitted.

- Only an item in one of those four slots is fitted, and only a 32x32 state with four directions: never one held, on a
  mannequin or inside another item, nor a taur's 64x32 sheets. A taur body's arms are fitted, its legs and chest aren't.
- A digitigrade body's legs are fitted through their digitigrade templates only where the legs drawn are digitigrade art:
  a `*_digi` sheet, or the digitigrade legs the GAGS mask draws over a plantigrade sprite (`CLOTHING_DIGITIGRADE_MASK`). A
  plantigrade sprite on a digitigrade body is fitted as the human legs it draws.
- An item's mode is its own `fit_mode` if it sets one (on `/obj/item/clothing`). Otherwise shoes and gloves are fitted
  solid, and uniforms and suits by their sleeves in the front view of the icon drawn, GAGS colours included
  (`garment_sleeve_mode()`, a port of the spec's `sleeve_mode.py`): shaded sleeves where they're one plain colour, solid where
  they're busy, dark or missing. A glow only shows its shape, so it's fitted solid, or as a pattern for a pattern garment.
- Each fit is cached once a round by the fit and the sheet, state, item type, female cut, body shape and colours, never by
  wearer, and made as "What fitting costs" says. An animated state is fitted frame by frame.
- A fitness arm, leg or chest above the Normal size put on or taken off redraws all four slots (`refit_worn_clothing()`):
  otherwise a leg redraws only the uniform and suit, and an arm only the gloves. A size from the preferences redraws them
  when its swap ends its render batch.

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

Tank tops hang straight over the pecs instead (`hangs_straight_over_pecs()`, which the styles drawing the `tank_*` states
override): their front and back panels stay as drawn, and the pecs peek out past them at the armholes. The front view still
shades the smile, and the side views still fit the bulge.

Fitting a top to pecs needs its front and back views' colours: from the sheet metadata for a static sheet's state, so it
costs little more than the limbs' fit, and otherwise read from its pixels, about 2.3 ms more for a solid or mesh top.

**Flexing pecs.** While pecs flex (`start_flex()`, the `*pbounce` emotes), a top fitted to them moves with them
(`/datum/garment_fit_job/underclothes/flex`): its limbs are fitted once a view, and the pecs on each frame of the flex from
that frame's pec template (`fitting/pec_flex_templates.json`), tanks hanging straight as they do still. The frames are drawn
over a state of the flex's own sheet, so the top keeps the pecs' delays and loops. A flex starting or stopping redraws the
underclothes with the chest (`set_animation_icon()`), so the top starts in step with the pecs and stops with them, back to
its still fit. A jiggle isn't fitted, and a top whose state is animated itself keeps its still fit.

Each flex's fit is made once a round by `SSgarment_fitting`, ahead of any flex: the first time a top is drawn over pecs,
its fits over those pecs flexing from each of the four flex sheets are queued behind its still fit (`fitted_sprite()`), so
the top moves from the pecs' first flex on. Nobody waits for them and nobody is drawn again for them. A flex that comes
before its fit is made draws the top still all through, since a top that started moving partway would move out of step
with the pecs, and asks for the fit itself, as it did before the warm-up. A dummy queues none, and has each made as the
flex that needs it is drawn; so does every body with `GARMENT_FITS_DEFERRED` off. Measured in a debug build, a flex's fit
takes 5-20 ms to make, a view of a frame at a time; a top drawn while flexing costs about 4 µs more than drawn still, and a
still top over pecs about 0.2 µs more than before tops followed the flex, before the warm-up added its four cache lookups to
each draw of a top over pecs.

**The female cut over pecs.** A female body with pecs, of any shape and whether they show or not, isn't shaped at the chest
(`female_cut_over_pecs()`, `code/female_cut.dm`): a full cut on its uniform or underclothes keeps only its crotch
(`FEMALE_UNIFORM_LOWER_ONLY`, through `masking_helpers.dmi`'s full cut less the pixels of its top-only one,
`female_lower_cut_mask()`), and a top-only cut, the one digitigrade legs, taurs and Ceruleans also get, isn't made at all. A
male body and a body without pecs are cut as before. Pecs put in or taken out redraw a female body's uniform and
underclothes.

**Tops cut for breasts.** Some tops have a version for a chest without breasts, which they draw on any chest without them,
pecs or none, except a female body's without pecs; over breasts they're drawn as they are (`chest_cut_state()`):

- The fishnet tops in both slots ("Fishnet - Sleeved", "Fishnet - Sleeveless" and their greyscale twins) have a bra drawn
  into them. Their `_flat` states are pure mesh with the same scoop neck. "Fishnet - Crew Sleeved" and "Fishnet - Crew
  Sleeveless", and their greyscale twins, are crew-neck mesh tees in the undershirt slot.
- Pasties sit lower on a chest without breasts, over its nipples: `_m` on a bare chest, and `_m1`, `_m2` and `_m3` over pecs,
  bigger pecs and the biggest pecs, by their `garment_fit_shape`, with nipples or without.

**Fitting templates.** `fitting/fit_templates.json` holds, for each limb, muscle size and view, the rows its outline grew in,
its baseline pixels and its fitted pixels' skin tones; the limbs are the arms, the legs, and the digitigrade legs, measured
from the mammal sheet's, plus `chest_m`, the male chest's glute bands at the sizes that have them. A leg in a side view grows
toward both its front and its back, and its rows never take the cap rule, which keeps straps on an arm's shoulder.
`fitting/pec_templates.json` holds each pec shape's outline, pixels, side bulge and smile, and the chest's own outline, and
`fitting/pec_flex_templates.json` the same for each frame of each pec flex sheet, with the sheet's frame delays; a frame's
smile is the still smile, lifted in each column as far as the pec's crease lifts on that frame.
`lab/fitness/gen_fit_templates.py` and `gen_pec_templates.py` make them from the sprites: run
`python lab/fitness/gen_fit_templates.py` (and `gen_pec_templates.py`, which writes both pec files) whenever the size or pec
art changes, and commit the JSON they write. Definition needs no templates. The files are compiled into the resource file and read as the server starts,
with the sheet metadata (`SSgarment_fitting`).

**Making the art.** The six sheets were generated from the approved mockups by a scratch script outside the repository,
`gen_physique_sheets.py` (session 597eba23's `scratchpad/defwb/`), which needs the mockup tools beside it and reads the old
fitness level sheets (`git show 4e379c2bd185:modular_aphelion/modules/fitness/icons/human_parts_fitness_<N>.dmi`). Edit the
sheets themselves from now on, keeping the overlays inside their size's outline, and regenerate the templates after any
outline change.

**Height.** tg makes a human taller or shorter with displacement maps that draw one torso row twice, or drop one or two.
tg's maps do that at row 16 from the top, which is a pec's crease. A flex then drew its crease two pixels thick and jumping
on a Taller or Tallest body, and squashed the pecs on a Shortest or dwarf one. Every human torso uses `icons/height_cuts.dmi`
instead:

- Taller and Tallest draw row 18 twice.
- Shortest drops row 18.
- A dwarf drops rows 18 and 19.

These rows are below every pec shape (rows 9 to 17, in every frame of every flex). The legs and arms keep tg's maps, and
monkeys keep tg's torso maps. Medium, Short and Tall bodies don't move a torso row, and draw as before.

### TG Proc/File Changes:

- `code/datums/sprite_accessories/clothing.dm`: `/datum/sprite_accessory/clothing/proc/make_appearance()` asks
  `get_icon_state()` with the wearer, keys its cache by the sheet too, cuts over pecs as `female_cut_over_pecs()` says, and
  draws the fitted sprite (`fitted_sprite()`)
- `code/modules/mob/living/carbon/human/human_update_icons.dm`: `/obj/item/proc/build_worn_icon()` calls
  `fit_worn_icon()` and `fit_worn_glows()`; `/mob/living/carbon/human/update_worn_undersuit()` cuts over pecs as
  `female_cut_over_pecs()` says; `wear_female_version()` cuts `FEMALE_UNIFORM_LOWER_ONLY` through `female_lower_cut_mask()`;
  `/mob/living/carbon/human/proc/apply_height_filter()` stretches and shrinks a human torso with `icons/height_cuts.dmi`
- `tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/character_preferences/body_type.tsx`: the body
  type input carries the muscle inputs under it (`withMuscles()`)

### Modular Overrides:

- `modular_aphelion/modules/fitness/code/fitness_body.dm`: `/datum/species/on_species_gain()`,
  `/mob/living/carbon/human/synchronize_bodyshapes()`
- `modular_aphelion/modules/fitness/code/fitness_limbs.dm`: `update_limb()`, `generate_icon_key()`, `generate_husk_key()`
  and `get_limb_icon()` on each limb family's fitness subtypes (`FITNESS_LIMB_DRAWING()`), never on `/obj/item/bodypart`,
  so a plain limb's redraw costs what it did before fitness
- `modular_aphelion/modules/fitness/code/worn_fitting.dm`: `/obj/item/bodypart/try_attach_limb()`,
  `/obj/item/bodypart/drop_limb()`
- `modular_aphelion/modules/fitness/code/garment_fit_styles.dm`: `fit_mode` on underclothes styles,
  `hangs_straight_over_pecs()` on the tank tops, `bares_near_forearm()` on the polos, `garment_fit_shape` on the pec
  shapes, and `/obj/item/organ/genital/breasts/set_animation_icon()`
- `modular_aphelion/modules/fitness/code/female_cut.dm`: `/obj/item/organ/genital/breasts/on_mob_insert()` and
  `on_mob_remove()`

### Defines:

- `code/__DEFINES/~aphelion_defines/fitness.dm`: `MUSCLE_SIZE_NORMAL`, `MUSCLE_SIZE_ATHLETIC`, `MUSCLE_SIZE_MUSCULAR`,
  `MUSCLE_DEFINITION_MAX`, `FEATURE_MUSCLE_SIZE`, `FEATURE_MUSCLE_DEFINITION`, `FITNESS_LIMB_TYPE`, `GARMENT_FIT_SOLID`,
  `GARMENT_FIT_PATTERN`, `GARMENT_FIT_SHADED_SLEEVES`, `GARMENT_FIT_KNIT`, the `GARMENT_FIT_PEC_SMILE_*` modes,
  `GARMENT_FIT_MAX_FRAMES`, `GARMENT_FIT_PIECE_VIEW`, `GARMENT_FITS_DEFERRED`, the `GARMENT_FIT_REDRAW_*` flags and
  `FEMALE_UNIFORM_LOWER_ONLY`
- `modular_aphelion/modules/fitness/code/fitness_limbs.dm`: `FITNESS_SHEET_HUMAN_ATHLETIC`, `FITNESS_SHEET_HUMAN_MUSCULAR`,
  their `HUMANOID` twins, `FITNESS_DEFINITION_HUMAN`, `FITNESS_DEFINITION_HUMANOID`, `MUSCLE_SIZE_NAME`, `FITNESS_ICON_KEY`
  and `FITNESS_LIMB_DRAWING`. File-local.
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
  `breasts_onmob_pecbounce*.dmi` sheets: the same states; `fitting/pec_flex_templates.json` is made from the pec bounce
  sheets
- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/Muscles.tsx` (the muscle inputs under the body type)
- `tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/character_preferences/aphelion/fitness.tsx`
- `tgui/packages/tgui/styles/interfaces/Muscles.scss`, loaded by `tgui/packages/tgui/styles/meridianos/_index.scss`
- `code/modules/unit_tests/~nova/fitness.dm`, included from `code/modules/unit_tests/_unit_tests.dm`
- `code/modules/unit_tests/~nova/pecs.dm`: the `flat_mesh`, `under_underclothes`, `flexing_top` and `female_cut` tests
- `tgstation.dme`

### Credits:

- mal
