## Dirt overlays

Module ID: DIRT

### Description:

Mess that lands on a person shows on their sprite where it was aimed, until it's washed off. It's the first material of
a dirt overlay system: the generator, the masks, the component and the drawing are general, and only mess uses them so
far.

- **Splats.** `/datum/component/dirtiness` holds a person's or an item's splats (`/datum/dirt_splat`): one of eight
  variants of a zone's mess, at level 1 to 4. Levels 1 to 3 are streaks and separate runs with skin between them;
  level 4 covers the zone in a glaze. A shot adds levels to the zone's newest splat, by its amount
  (`dirt_mess_amount_levels()`: 1, 2, or straight to 4), and what's left past level 4 starts another splat, with a
  variant that zone doesn't have yet. A person carries `DIRT_MESS_MAX_SPLATS` at most, counting their skin,
  underclothes, parts and worn items, and past it the oldest goes first. A part's share of a shot and a taur body's
  pools are splats of their own, so one shot can add several. `dirt_mess_land()` puts a shot on a person.
- **Aiming.** A shot on someone lists a region for each zone that shows on them (`dirt_mess_regions()`) in place of
  "On them", which stays only when none does: a zone needs a drawn limb it lands on, a monkey gets none (a kobold
  does), a taur gets none below the waist, and a portal offers only what it shows: through a wall, the groin and the
  butt. The pick lands with the shot's amount, and drops no floor decal.
- **Masks are made at run time, never shipped.** A surface's splats become one four-direction RGBA icon, registered in
  the resource cache and drawn as it is (`dirt_baked_icon()`): each pixel takes its one tone role's colour (film, body,
  core, fleck or glint) at that role's alpha. Haze, the palest edge, has no role of its own: it's film at half
  coverage, so it takes the film's colour at half alpha. The colours are a parameter (`dirt_mess_role_tints()` for the
  mess), so another material bakes the same way.
- **Where masks come from.** Dirt lies on the body, not on the screen. A body's template maps every pixel near it to a
  limb, an angle round it and a height along it, per direction, built from the limb sprites the body actually draws, so
  other species, digitigrade legs and fitness sizes get their own. Each zone's mess is a few streaks, globs, drips,
  drops and glints placed on that map by a seeded random stream, rasterised to roles, then all the splats on a surface
  merge into one mask, a role to each pixel. Every draw is md5-based and every rounding written out, so the same splats
  on the same sprites give the same pixels on any server.
- **`SSdirt`** builds templates and masks in the background, a piece at a time. It keeps the newest masks (a body keeps
  drawing its own after they're dropped), the templates and sprites read most lately (a waiting job holds its own
  template), the plain human template for the round, and each splat's rasters as one text, its four directions packed
  and joined, so masks made again with one more splat rasterise only that one. A job reads the sprites of its parts or
  taur body one direction a piece first. A body whose new masks aren't made yet draws the ones it had, if any, and is
  drawn again once they are. A job that runtimes or reads a missing sprite is cached as failed, and isn't queued again
  while that's kept. `SSdirt.finish_all()` makes everything queued at once, for tests.
  With `DIRT_MASKS_DEFERRED` commented out there's no queue: masks are made as they're asked for.
- **Where a shot lands** (`dirt_mess_surface()`). On the outermost of the head, mask, suit and uniform whose
  `body_parts_covered` takes in the zone (the face when the mouth is covered), else on the underclothes, else on the
  skin. The underclothes take it when the pieces reaching into the zone cover at least half of it together. Through a
  wall portal only the uniform counts, while no suit hides it: the relay draws no suit. Nor does a skirt or dress the
  relay leaves out (`wall_relay_skips_uniform()`).
  - The piece that shows the most of the zone takes it: its pixels there, less those the pieces above it draw over.
  - Ties go to the kind that belongs there (underwear, then socks, on the groin, butt and thighs; an undershirt or bra
    on the chest; an undershirt on the stomach and back), then to the topmost. So a shirt hem over the waistband leaves
    a groin shot to the underwear, and a corset over it, or a swimsuit over a bra, takes it.
  - Underclothes are judged by their own sprite against the zone's pixels on the plain human template, which `SSdirt`
    builds in the background from init and keeps. So a landing never builds a template, and every body is judged on the
    human shape: on a digitigrade or Muscular body the judgement can be a pixel or two off.
  - Until that template is built, the topmost piece covering the zone by the usual rules takes it: underwear covers the
    groin and butt, an undershirt or bra the chest, and an undershirt the stomach and back too, and a piece covers what
    it hides outright.
- **Skin.** Each limb that carries mess (the head, the chest and the legs) gets a `/datum/bodypart_overlay/dirt_skin`:
  one container image holding the limb's baked image, clipped to the pixels that limb shows. It draws at
  `DIRT_SKIN_LAYER` (22.25): under the underclothes (19.1 and 19.101) and the genitals, over body hair (22.5), markings
  and the limbs. An MD5 of what the limb's baked image draws goes in its render key, so a landing elsewhere on the body
  leaves that limb's images as they were.
- **Dirty limbs' images.** Every key mess adds to a limb's render key (the skin's, the underclothes', a part's share and
  a taur body's pools) starts with `DIRT_PRIVATE_KEY`, and a limb drawn under such a key keeps its images on its own
  mob (`limb_icons_for()`): one entry per zone, dropped when the zone is drawn clean or loses its limb. tg's
  `limb_icon_cache`, shared by every body, serves keys that come back: markings, tails, ears, wings, genitals' states,
  textures, body hair, augment finishes, blood on limbs and heights. A dirty limb's key almost never comes back, so it
  only ever added entries.
- **Fading out under clothes.** Skin mess fades over the last `DIRT_FADE_RINGS` pixels before whatever is worn over it,
  instead of stopping at its edge. The masks are made with the fade, from the sprites drawn in the underclothes and
  garment slots (`dirt_cover_sprites()`), so those sprites are part of the masks' key. A change to those slots has
  `SSdirt` look again once the slots settle, and makes new masks only if what's worn over the skin changed.
- **Clothes.** A worn garment keeps its splats when it comes off. While a person wears it, it draws them through its
  worn wrapper (`COMSIG_ITEM_GET_SEPARATE_WORN_OVERLAYS`): one baked image, `BLEND_INSET_OVERLAY`, so it shows only on
  the garment's own pixels, fitted or not. The masks are the cloth surface of the wearer's body, its rim a role lighter,
  so a garment moved to another body draws from that body's. They float, moved back onto the body's tile by what
  `build_worn_icon()` moves the wrapper by (`dirt_worn_shift()`: its centring on the garment's worn dimensions and its
  worn offsets). Offsets the body puts on the wrapper after that (a species' worn offsets) still move them. On a garment
  drawn on that tile they aren't offset, and the bulge redraws them over its cloth.
- **Underclothes** aren't items. Mess landed on them is held by the person, kept with the piece it's on (its slot and
  accessory), through hiding it and changing to another and back. While that piece is worn and shows, it's drawn over
  it at `DIRT_UNDERCLOTHES_LAYER` through one `/datum/bodypart_overlay/dirt_underclothes` on the chest, kept to the
  pixels it shows. The dresser, the visibility verbs and preferences all redraw the underclothes slot, and the person's
  component then works out again what's drawn. A revealing loincloth the bulge cuts is judged and clipped as it's drawn,
  cut, and where a bulge look's cloth covers a piece, the piece's mess is drawn again over the cloth, kept to it, as the
  look draws a garment's own. Washing the person clears it.
- **Parts.** Breasts and pecs take a share of a chest shot, the penis, testicles and vulva of a groin shot, the butt of
  a butt shot. A part is read as it draws now (`dirt_part_drawn()`), in the layers its kind is drawn from
  (`dirt_part_layers()`: the butt's front and back images, every other part's front image): their colour layers'
  states, and the layer each draws at, custom layering included. A hidden part, one a device or a bulge look draws in
  place of, and one with nothing in those layers (a taur's penis) take nothing. A plain human chest without breasts
  takes the plain pecs' shape as an undrawn guide (`dirt_pecs_guide()`), kept to where the chest shows.
  - In each direction a part draws over or under the surface a shot lands on as its topmost image there does, against
    the garment's layer, `DIRT_UNDERCLOTHES_LAYER` or `DIRT_SKIN_LAYER`. A butt's front image shows only facing north;
    its back image, the other ways, draws under every surface. Which directions each state shows in is read once and
    kept (`dirt_sprite_facings()`), so a draw works out the layers without reading the sprites.
  - A part drawn over that surface in some direction takes its own splat of the same variant, held by the person in
    `part_mess_splats` and drawn with the part (`genital_overlays.dm`): a container just over its front layer, at its
    layer and offsets, holding the share's baked image, kept to the sprite it draws, in the directions it shows over
    what it lies on. A new sprite (an erection, a jiggle, a size) has its masks made again, and the limb's render key
    carries their key, or "pending" while they're made. So the share draws wherever the part does, a portal relay and a
    bulge look included. Every front image draws over the skin, so on bare skin every exposed part takes its own share.
  - Where a part draws under the surface (pecs under a tank top, a genital set to draw below the underwear or a garment,
    a butt in profile, the guide) it shapes that surface's mess instead: its share is drawn in the surface's masks, on
    its own pixels, and the chest's skin mask takes those of its pixels past the body.
  - Either way the surface's mess drops a level in each direction the part shows, two at the genitals, except at the
    top level, which keeps its glaze (`dirt_part_body_level()`), and leaves out the rounded parts' pixels
    (`dirt_merge_with_parts()`). A part's own mess follows its form: lobes on rounded parts (`dirt_lobe_rasterise()`),
    a bead behind the tip of the penis (`dirt_part_rasterise()`), at levels 1 to 3; a top-level splat draws its parts at
    level 3. The vulva, too small for a lobe, also takes the ring of skin round it on bare skin.
  - Through a one-part portal a shot lands on the penis alone, its own entry in the list, offered and landed only while
    it draws its front image. A part removed takes its splats with it, a wash redraws the whole body, and a change to
    what the body draws of its parts makes the masks they shape again.
- **Taurs.** A back shot on a taur lands on the rider's back as on anyone's, the rider drawn on its legless template,
  and puts broken pools with uneven drips along the taur body's back: a splat of the same variant in
  `part_mess_splats` under `ORGAN_SLOT_EXTERNAL_TAUR` (`dirt_taur_takes_pools()`), capped and washed with the rest.
  Big Legs kinds, legs under the rider with no taur back, take none: the shot lands on the rider alone.
  - The taur body is read from its own images (`dirt_read_source()`): each layer's colour layers' states, on the 64x32
    taur canvas. Its pools (`dirt_taur_pools()`) lie on the pixels it shows with the rider drawn between its adjacent
    and front layers (`dirt_taur_owners()`), in a band under the back line the view shows (`dirt_taur_back_region()`:
    none facing south, none at the tail end or beside the rider's waist), and keep clear of the same shot on the
    rider's cloth and skin, so no line runs across both bodies (`dirt_mess_splat_rasterise()`). Level 1 is a drop,
    levels 2 and 3 two pools; a top-level splat draws level 3's pools beside the rider's glaze.
  - Each taur layer draws the pools on the pixels it shows: a container just over its images, at their layer and their
    centred offsets, in that layer's own holder (`taur_overlay.dm`). The masks' key goes in the taur body's render key,
    or "pending" while they're made.
  - A taur suit, a garment drawn over the whole taur canvas (`dirt_taur_fitted()`), takes the shot itself and the taur
    body takes none: the suit's back splats draw the same pools, inset over its own pixels on the canvas round the
    body's tile. Its wrapper is drawn 16 px left by `worn_x_offset`, so the 32x32 mess on it goes 16 px right, onto
    that tile.
  - A taur body removed takes its pools with it. A taur's penis drawn only behind the body takes nothing.
- **The overlay budget.** A mob draws as an error sprite past `MAX_ATOM_OVERLAYS`. Whatever the number of splats or the
  roles they draw, skin mess adds one image per limb that carries it, four at most, each holding one baked image, and
  the underclothes one more. The body's limb images then share one holder per layer (`prepare_bodypart_overlays()`), so
  they take two of the mob's overlays. A part's container joins its front layer's holder, and a taur body's pools each
  layer's. A garment's images go in its worn wrapper and add none.
- **Washing** clears it, through the clean signal, as it clears the floor's decals: showers, washing machines, soap. A
  person's wash reaches the worn items nothing covers.
- **Admin cleanup.** Clear Dirt is available under Debug and in a human's VV action menu. Both require `R_ADMIN`
  and use the same logged admin verb. The Apply Dirt debugging helper is temporarily commented out.

**Pixel parity.** The masks match the reference generator's pixel for pixel. `dirt_mess_corpus.json` lists cases
(random streams, noise, templates, mess on bodies with parts under and over them, on parts, taur bodies under a rider
and the pools on them), and `dirt_mess_manifest.txt` holds the MD5 of each case's text as the reference generator
writes it. The `dirt_mess_manifest` unit test builds the same text in game and fails on any case that differs, writing
every case's text to `data/dirt_mess_masks.txt` to compare. A change that's meant to move pixels is made in the
reference generator first, and the manifest is regenerated from it.

### TG Proc/File Changes:

- `code/modules/mob/living/carbon/carbon_update_icons.dm`: `/mob/living/carbon/proc/update_body_parts()` takes each
  limb's images from `limb_icons_for()`, which serves a key without `DIRT_PRIVATE_KEY` from `limb_icon_cache` as
  before; a body holding no private images reads the cache itself, and skips the call while the cache holds the key.

### Modular Overrides:

- `code/component.dm`: `/datum/component/dirtiness`.
- `code/skin.dm`: `/datum/bodypart_overlay/dirt_skin` and `/datum/bodypart_overlay/dirt_underclothes`.
- `code/worn.dm`: which garment or underclothes a shot lands on, what's worn over the skin, and `/datum/dirt_drawing`.
- `code/landing.dm`: `dirt_mess_land()`, `dirt_mess_place()`, the splat cap, the aim zones and the regions a shot
  offers.
- `code/parts.dm`: `/datum/dirt_part_source`, which parts a body draws and where, the pecs guide, and the parts'
  rasterisers.
- `code/genital_overlays.dm`: on `/datum/bodypart_overlay/mutant/genital`, `get_overlay()` draws a part's share and
  `icon_render_key()` carries its masks' key; on `/obj/item/organ/genital`, `on_mob_insert()` and `on_mob_remove()`.
- `code/taur.dm`: `/datum/dirt_taur_source`, what a taur canvas shows, the pools' rasterisers, and when a back shot
  takes them.
- `code/taur_overlay.dm`: on `/datum/bodypart_overlay/mutant/taur_body`, `get_overlay()` draws the pools,
  `icon_render_key()` carries their masks' key, and `dirt_read_source()` reads the taur body.
- `code/limb_cache.dm`: on `/mob/living/carbon`, `private_limb_icons`, `limb_icons_for()` and `drawn_limb_icons()`;
  on `/obj/item/bodypart`, `on_removal()` drops the limb's private images.
- `code/admin.dm`: the Clear Dirt admin verb and the commented-out Apply Dirt debugging helper.
- `code/subsystem.dm`: `SSdirt`, and `/mob/living/carbon/human/proc/redraw_dirt()`.
- `code/masks.dm`: splats, mask requests and the mask jobs.
- `code/surface.dm`: templates, from the limb sprites a body draws.
- `code/mess.dm`, `code/features.dm`, `code/rasterise.dm` and `code/random.dm`: the generator.

### Defines:

- `code/__DEFINES/~aphelion_defines/dirt.dm`: roles, limbs, zones, thresholds, `DIRT_SKIN_LAYER`,
  `DIRT_UNDERCLOTHES_LAYER`, the underclothes, the fade, the variant, level, amount and splat limits, portal views, part
  kinds, the taur canvas, `DIRT_PRIVATE_KEY`, and the switches and flags `SSdirt` uses.

### Included files that are not contained in this module:

- `modular_aphelion/modules/bulge/`: dirt uses its `bulge_register_icon()`, `bulge_blank_tile()`, `bulge_drawn_root()`,
  `bulge_drawn_leaf()`, `/datum/bulge_bounded_cache`, a penis's `bulge_key`, `bulge_wanted_cut()` and
  `bulge_cut_sprite()`. Its look's anatomy memo (`bulge_anatomy_record()`, `bulge_anatomy_unchanged()`) records the
  testicles' `dirt_share_key()`, so the testicles it draws behind a cover draw their mess as it changes. The look's key
  carries `DIRT_PRIVATE_KEY` when the anatomy it draws carries mess, or the cover's mess goes over its cloth
  (`bulge_over_signature()`), so those chests keep their images on the wearer.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_organs/`: the genitals whose overlays and organs
  `genital_overlays.dm` overrides, and `COMSIG_HUMAN_GENITAL_UPDATED`.
- `modular_nova/modules/customization/modules/surgery/organs/taur_body.dm`: the taur body whose overlay
  `taur_overlay.dm` overrides.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_arousal/climax.dm`: `climax()` offers the regions and lands
  the pick.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_machinery/lewd_portals.dm`: a wall relay draws the chest
  alone, with no legs or shoes, and keeps what it draws over the body (the uniform, the underclothes and the mess
  containers) to the body, through a render target of its own (`body_render_target()`). Images with no sprite of
  their own, the mess containers among them, are always copied (`append_appearance_copies()`) and never taken for
  an organ's (`compare_organ_icon()`). It leaves out a skirt or dress (`wall_relay_skips_uniform()`, by its bulge
  family), so the body shows under it. A wall-stuck body draws no bulge (`portal_hides_bulge()`).
- `code/modules/unit_tests/~nova/dirt_mess_drawing.dm`, `dirt_mess_manifest.dm`, `dirt_mess_corpus.json` and
  `dirt_mess_manifest.txt`: the tests, the parity corpus and its manifest.
- `code/modules/unit_tests/_unit_tests.dm`
- `tgstation.dme`
