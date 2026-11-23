## Dirt overlays

Module ID: DIRT

### Description:

Dirt that lands on a person shows on their sprite until it's washed off. Mess lands where a shot was aimed. General
dirt, a cause's dirt in a material (mud from walking, soot from smoke), lands on everything that shows where its cause
reaches.

- **Splats.** `/datum/component/dirtiness` holds a person's or an item's splats (`/datum/dirt_splat`): a zone's mess at
  level 1 to 4 in one of `DIRT_VARIANTS` variants, or a general deposit. A person carries `DIRT_MAX_SPLATS` at most,
  across their skin, underclothes, parts, hair and what they wear, and the one landed longest ago goes first.
- **Aiming.** A shot offers a region for each zone that shows on its target (`dirt_mess_regions()`), and
  `dirt_mess_land()` puts it on them. A shot's amount adds levels to the zone's newest splat, and what's left past the
  top starts another.
- **Masks.** A surface's splats merge into one mask a direction, a tone role to each pixel (`dirt_merge()`). The masks
  are baked at run time into four-direction icons (`dirt_baked_icon()`), one for each limb, layer, garment or part
  they draw on. Each pixel takes its role's colour and alpha for its material.
- **Materials** (`materials.dm`): mud, soot, oil, slime, sweat and the rest, each with its role colours, an edge and its
  flags. `dirt_material()` returns the shared one for an id, and slime and blood are made from any colour.
- **The generator.** `dirt_rasterise()` draws a splat on a body's template: mess as streaks, globs and drips, and each
  general cause as its features (`features.dm`, `coverage.dm`, `causes_ground.dm`, `causes_upper.dm`). The face and
  hands are too small to wrap dirt round, so they take stamps (`stamps.dm`).
- **Templates** (`surface.dm`). Dirt lies on limbs, not on the screen. A body's template maps each pixel to a limb, an
  angle round it and a height along it, built from the limb sprites the body draws, so every species gets its own.
- **`SSdirt`** makes templates and masks in the background, a piece at a time, and every cache it keeps is bounded. A
  body draws its old masks until its new ones are made, and is drawn again once they are. `SSdirt.finish_all()` makes
  everything queued at once.
- **Where general dirt lands** (`dirt_land()`). A cause reaches a fixed set of limbs (`dirt_cause_reach()`), and every
  carrier that shows on one of them takes the deposit there (`dirt_shown_carriers()`). The same cause and material
  raise a deposit rather than add one, and a bare body takes the painted designs (`painted.dm`).
- **What lands it** (`sources.dm`). Slime, tool work on machines, dirt underfoot, blasts, fire, smoke and mining land
  general dirt in a round. So do falls, lying down and rolling on dirt, reagents and sweat, each through
  `dirt_source_land()`. Undefining `DIRT_SOURCES` turns them all off.
- **Where a shot lands** (`dirt_mess_surface()`): the outermost garment over the zone, else the piece of underclothes
  that shows the most of it, else the skin.
- **Skin** (`skin.dm`, `limb_cache.dm`). Each limb the skin's dirt lies on draws it in one container image, and an arm
  draws one more for its hand. A dirty limb's render key carries `DIRT_PRIVATE_KEY`, so its images stay on its own mob,
  out of tg's shared limb cache. Skin dirt fades out over `DIRT_FADE_RINGS` pixels before what's worn over it.
- **Clothes** (`worn.dm`). A garment keeps its dirt when it comes off, and draws it inset in its worn wrapper while
  it's worn. On a garment, whichever of blood and dirt landed last draws on top (`stain_over()`).
- **Sweat** (`sweat.dm`) darkens the cloth it lands on through a multiplier, and never lands on bare skin.
- **Underclothes** aren't items, so the person holds their dirt, kept with the piece it's on.
- **Parts** (`parts.dm`, `genital_overlays.dm`). Breasts, pecs, the penis, the testicles, the vulva and the butt take a
  share of a shot at their zone, and draw it with their own images.
- **Taurs** (`taur.dm`, `taur_coat.dm`, `taur_overlay.dm`). A back shot lands on the rider and as pools along the taur
  body, which takes general dirt of its own. A taur suit takes the pools itself and draws its hem band.
- **Blood below a taur's waist** (`blood.dm`). A uniform's or suit's stain, cut at the waist, runs down onto the taur
  body or a taur-fitted garment's cloth, drawn from the garments' own blood at the rider's height.
- **Drawn parts** (`appendages.dm`, `canvas.dm`). Tails, wings, ears, horns and the other mutant parts carry their own
  general dirt, drawn by the canvas generator. A typecache of the parts that take dirt (`dirt_shape_kinds()`) lets
  every other part leave at the first check. A wagging tail draws its dirt on every frame of its wag.
- **Hair** (`hair.dm`) carries its own general dirt under `DIRT_CARRIER_HAIR` while it shows, its pieces drawn over hats
  too.
- **Emissive blockers.** Each baked image but sweat's multiplier draws a blocker in its shape and alpha
  (`dirt_emissive_blocker()`), so in the dark dirt dims a glow under it. A garment's dirt draws them only while blood
  or a glow of the garment's own lies under them (`dirt_glow_under()`).
- **The overlay budget.** However many splats a body holds, its skin and underclothes dirt takes four of its overlays,
  six with a dirty hand, and each sweat multiplier one more. Their images share one holder a layer, and their blockers
  one group (`prepare_bodypart_overlays()`, in worn_emissives).
- **Washing** clears it through the clean signal: showers, washing machines, soap. Clear Dirt (Debug, and every mob's VV
  menu, `R_ADMIN`) takes it all off a human.
- **Pixel parity.** The masks match the reference generator's pixel for pixel, case by case of `dirt_corpus.json`
  against `dirt_manifest.txt`, so a change meant to move pixels starts in the reference generator.

Known limits:
- The hair's dirt follows the stock hairstyle, not hair paint, and a drawn part's dirt ignores per-facing offsets.
- Big Legs taurs, parts on no canvas and tail spines take no general dirt.
- On bare skin tg's blood draws over skin dirt, whatever landed last.
- A blocker dims only what glows under its layer, so skin dirt leaves the eyes, the genitals and the parts drawn in
  front glowing.
- Blood below a taur's waist neither glows nor blocks.

### TG Proc/File Changes:

- `code/modules/mob/living/carbon/carbon_update_icons.dm`: `/mob/living/carbon/proc/update_body_parts()` takes each
  limb's images from `limb_icons_for()`, which serves a key without `DIRT_PRIVATE_KEY` from `limb_icon_cache` as tg
  does. A body holding no private images reads the cache itself, and skips the call while the cache holds the key
  (`DIRT_LIMB_ICONS_STEADY()`, `DIRT_LIMB_ICONS_CHANGED()`).
- `code/modules/mob/living/carbon/human/human_update_icons.dm`: `/obj/item/proc/build_worn_icon()` calls
  `dirt_order_worn()` on the separate worn overlays while the item's `dirt_stain_slot` is set, which moves the blood
  stain under dirt that landed after it.
- `code/modules/clothing/under/_under.dm` and `code/modules/clothing/suits/_suits.dm`: the accessories' overlays stay
  on a taur's rider (`fit_rider_overlays()`, `fit_rider_overlay()`).
- `code/modules/clothing/clothing.dm` and the gloves', head's, masks', suits' and uniforms' base files: blood and rip
  overlays go through `fit_worn_effect()`, which cuts a taur's at the waist.
- `code/modules/mob/living/carbon/human/human.dm`: `/mob/living/carbon/human/Initialize()` gives every human but a
  preview dummy its `/datum/component/dirt_sources`, while `DIRT_SOURCES` is defined.

### Modular Overrides:

- `code/component.dm`: `/datum/component/dirtiness`, the order of its images against a garment's blood stain
  (`on_blood_added()`, `stain_over()`), and the examine line. `/obj/item/add_blood_DNA()` notes blood for dirt as it
  lands on an item, then calls the base proc.
- `code/skin.dm`: `/datum/bodypart_overlay/dirt_skin` (mess and general dirt, the hands' too),
  `/datum/bodypart_overlay/dirt_underclothes` (each piece's dirt and its sweat's multiplier) and
  `dirt_emissive_blocker()`, every baked image's blocker. On `/datum/controller/subsystem/accessories`, `setup_lists()`
  adds `DIRT_HAND_LAYER_POSTFIX` to `all_layer_postfixes`.
- `code/worn.dm`: which garment or underclothes a shot lands on, what shows on each limb for general dirt, whether a
  body is bare or hidden, what's worn over the skin, `/datum/dirt_drawing`, `/obj/item/var/dirt_stain_slot` and
  `/obj/item/proc/dirt_order_worn()`.
- `code/landing.dm`: `dirt_mess_land()`, `dirt_mess_place()`, `dirt_land()`, each cause's reach, the splat cap, the
  aim zones and the regions a shot offers.
- `code/sources.dm`: the sources (`/datum/dirt_source`), `dirt_source_land()`, `/datum/component/dirt_sources`,
  `/datum/dirt_job/landing` and what lands general dirt. On `/datum/status_effect/slimed`, `on_apply()`. On
  `/mob/living/basic/slime`, `melee_attack()`. `tool_act()` on `/obj/machinery`, `/obj/vehicle` and
  `/mob/living/silicon/robot`. On `/datum/status_effect/exercised`, `on_apply()` and `refresh()`. On
  `/datum/status_effect/stop_drop_roll` and its `hallucinating` subtype, `reduce_firestacks()`.
- `code/parts.dm`: `/datum/dirt_part_source`, which parts a body draws and where, the pecs guide, and the parts'
  rasterisers.
- `code/genital_overlays.dm`: on `/datum/bodypart_overlay/mutant/genital`, `get_overlay()` draws a part's share and the
  skin's general dirt on it, and `icon_render_key()` carries their keys. On `/obj/item/organ/genital`,
  `on_mob_insert()` and `on_mob_remove()`.
- `code/taur.dm`: `/datum/dirt_taur_source`, what a taur canvas shows, the pools' rasterisers, when a back shot takes
  them, the dirt a taller rider uncovers, what general dirt the taur body takes, and the taur suit over it.
- `code/taur_overlay.dm`: on `/datum/bodypart_overlay/mutant/taur_body`, `get_overlay()` draws its pools, general dirt
  and the blood below the waist, `icon_render_key()` carries their masks' keys and the blood's side, and
  `dirt_read_source()` reads the taur body.
- `code/taur_coat.dm`: the taur body's contact coats.
- `code/blood.dm`: blood below a taur's waist: where the stain meets the crop, the start row by height, what it's drawn
  from and on, its shape, which side of the dirt it draws on, and the cover check that keeps it current.
- `code/appendages.dm`: on `/datum/bodypart_overlay/mutant`, the drawn parts as carriers (`dirt_shape_overlay()`,
  `dirt_shape_render_key()`, the reads), and on `/datum/bodypart_overlay/mutant/tail` its wag. The wag's frames and
  carry.
- `code/hair.dm`: on `/obj/item/bodypart/head`, `generate_icon_key()` carries the hair's masks' key and
  `get_hair_overlays()` draws the hair's dirt and its outer pieces'. The hair's merge.
- `code/sweat.dm`: sweat's multiplier and the accessories kept dry.
- `code/limb_cache.dm`: on `/mob/living/carbon`, `private_limb_icons` and `limb_icons_for()`.
  On `/obj/item/bodypart`, `on_removal()` drops the limb's private images.
- `code/admin.dm`: the Clear Dirt admin verb.
- `code/subsystem.dm`: `SSdirt`, and `/mob/living/carbon/human/proc/redraw_dirt()`.
- `code/masks.dm`: splats, mask requests and the mask jobs.
- `code/materials.dm`: materials, `dirt_material()` and slime's and blood's colours.
- `code/surface.dm`: templates, from the limb sprites a body draws.
- `code/mess.dm`, `code/features.dm`, `code/features_coat.dm`, `code/causes_ground.dm`, `code/causes_upper.dm`,
  `code/coverage.dm`, `code/stamps.dm`, `code/painted.dm`, `code/rasterise.dm` and `code/random.dm`: the generator.
- `code/canvas.dm`: the canvas generator, for taur bodies, drawn parts and hair.

### Defines:

- `code/__DEFINES/~aphelion_defines/dirt.dm`: roles, limbs and limb bits, a template's pixel flags, belt and margin, the
  packed raster, the face's guards, thicknesses and thresholds, zones, surface kinds, canvases and shapes, the dirt
  layers and the hand's postfix, `DIRT_PRIVATE_KEY`, `DIRT_TAUR_BLOOD_OVER_KEY` and the limb icon macros, the
  underclothes, the variant, level, amount and splat limits, carriers, the bare share, materials with their edges,
  flags and cache sizes, causes, thetas, what a stamp does to a pixel, portal views, mask kinds, the redraw flags, the
  fade, run spacing and groups, part kinds, the taur canvas, the maths, index and prefix macros, the indexes of the
  blood and sweat lists, and the `DIRT_SOURCES` switch with `DIRT_LANDINGS_WAITING` and `VV_HK_DIRT_CLEAR`. Each
  source's chance, cooldown, level and volumes are on its `/datum/dirt_source` subtype (`code/sources.dm`).

### Included files that are not contained in this module:

- `modular_aphelion/modules/bulge/`: dirt uses its `bulge_register_icon()`, `bulge_blank_tile()`, `bulge_drawn_root()`,
  `bulge_drawn_leaf()`, `bulge_is_accessory()`, `bulge_clipped_icon()`, `/datum/bulge_bounded_cache`, a penis's
  `bulge_key`, `bulge_template`, `bulge_layer` and `bulge_cover_type`, `BULGE_ABOVE_COVER`, `bulge_wanted_cut()` and
  `bulge_cut_sprite()`. Its look records the testicles' `dirt_share_key()` (`bulge_anatomy_record()`,
  `bulge_anatomy_unchanged()`), and its key carries `DIRT_PRIVATE_KEY` when its anatomy or its cover's cloth carries
  mess (`bulge_over_signature()`). `bulge_over_cloth()` redraws a cover's dirt over the look's cloth, and
  `is_visibly_sweaty()` asks `dirt_wears_sweat()`.
- `modular_aphelion/modules/custom_sprites/code/images.dm`: `custom_sprite_taur_key()` leaves the taur body's dirt
  entries (`DIRT_PRIVATE_KEY`) out of its render key, as paint is clipped to the body's own images.
- `modular_nova/master_files/code/datums/bodypart_overlays/mutant_bodypart_overlay.dm`: every mutant part's
  `get_overlay()` and `icon_render_key()` call `dirt_shape_overlay()` and `dirt_shape_render_key()`.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_organs/`: the genitals whose overlays and organs
  `genital_overlays.dm` overrides, and `COMSIG_HUMAN_GENITAL_UPDATED`.
- `modular_nova/modules/customization/modules/surgery/organs/taur_body.dm`: the taur body whose overlay
  `taur_overlay.dm` overrides. It doesn't stretch with height, but a Big Legs kind does (`height_location()`, set as
  it draws).
- `modular_nova/master_files/code/modules/clothing/clothing.dm`: `fit_worn_effect()` cuts a taur's stain at the waist
  and notes it (`dirt_note_taur_stain()`). `cuts_effects_at_taur_waist()` says which garments' stains are cut there, and
  `dirt_taur_blood_inputs()` and `dirt_waist_blood()` follow it. The cut is `taur_waist_crop()`, the mask
  `generate_taur_clothing()` crops a taur's clothes with, which dirt reads the stain's last kept rows from.
  `fit_rider_overlays()` keeps a uniform's accessories on the rider, and `fit_rider_overlay()` those the suit draws
  above itself.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_arousal/climax.dm`: `climax_into_partner()` offers the
  regions and lands the pick, and `climax_through_portal_device()` lands a shot through a one-part portal on the
  penis.
- `modular_nova/modules/extra_vv/code/extra_vv.dm`: the VV action runs the Clear Dirt verb, which clears every carrier
  (`dirt_carriers()`).
- `modular_nova/modules/modular_items/lewd_items/code/lewd_machinery/lewd_portals.dm`: a wall relay draws the chest
  alone, and keeps what it draws over the body, the dirt containers among them, to the body through a render target
  of its own (`body_render_target()`). It always copies images with no sprite of their own
  (`append_appearance_copies()`), never takes them for an organ's (`compare_organ_icon()`), and leaves out a skirt or
  dress (`wall_relay_skips_uniform()`). A wall-stuck body draws no bulge (`portal_hides_bulge()`), and a gloryhole's
  occupant draws their penis only through its relay (`portal_relays_penis()`, asked by `dirt_body_parts()`).
- `code/modules/unit_tests/~nova/dirt_test_helpers.dm`, `dirt_mess_drawing.dm`, `dirt_drawing.dm`,
  `dirt_taur_blood.dm`, `dirt_sources.dm`, `dirt_manifest.dm`, `dirt_corpus.json` and `dirt_manifest.txt`: the tests,
  their shared helpers, the parity corpus and its manifest.
- `code/modules/unit_tests/_unit_tests.dm`
- `tgstation.dme`
