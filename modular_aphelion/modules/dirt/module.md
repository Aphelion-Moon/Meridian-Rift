## Dirt overlays

Module ID: DIRT

### Description:

Semen that lands on a person shows on their sprite where it was aimed, until it's washed off. It's the first material of
a dirt overlay system: the generator, the masks, the component and the drawing are general, and only semen uses them so
far.

- **Splats.** `/datum/component/dirtiness` holds a person's or an item's splats (`/datum/dirt_splat`): one of eight
  variants of a zone's semen, at level 1 to 4. Levels 1 to 3 are streaks and separate runs with skin between them;
  level 4 covers the zone in a glaze. A shot adds levels to the zone's newest splat, by its load
  (`dirt_semen_load_levels()`: 1, 2, or straight to 4), and what's left past level 4 starts another splat, with a
  variant that zone doesn't have yet. A person carries `DIRT_SEMEN_MAX_SPLATS` at most, counting their skin, their parts
  and their worn items, and past it the oldest goes first. `dirt_semen_land()` puts a shot on a person.
- **Masks are made at run time, never shipped.** A surface's splats become one greyscale mask per tone role (haze,
  film, body, core, glint), each a four-direction icon registered in the resource cache. They're drawn as overlays
  tinted with the role's colour and alpha. Haze is the film's colour at half alpha, drawn as half coverage in the film
  mask.
- **Where masks come from.** Dirt lies on the body, not on the screen. A body's template maps every pixel near it to a
  limb, an angle round it and a height along it, per direction, built from the limb sprites the body actually draws, so
  other species, digitigrade legs and fitness sizes get their own. Each zone's semen is a few streaks, globs, drips,
  drops and glints placed on that map by a seeded random stream, rasterised to roles, then all the splats on a surface
  merge into one mask per role. Every draw is md5-based and every rounding written out, so the same splats on the same
  sprites give the same pixels on any server.
- **`SSdirt`** builds templates and masks in the background, a piece at a time, and keeps them for the round. A body
  whose masks aren't made yet draws without them and is drawn again once they are. A job that runtimes or reads a
  missing sprite is cached as failed and never queued again. `SSdirt.finish_all()` makes everything queued at once, for
  tests. `DIRT_MASKS_DEFERRED` turns the queue off, making masks as they're asked for.
- **Skin.** Each limb that carries semen (the head, the chest and the legs) gets a `/datum/bodypart_overlay/dirt_skin`:
  one container image holding the role images, clipped to the pixels that limb shows. It draws at `DIRT_SKIN_LAYER`,
  above the underclothes and below the uniform, so underwear takes it as skin. The masks' key goes in the limb's icon
  cache key, so bodies drawn alike share their images.
- **The overlay budget.** A mob draws as an error sprite past `MAX_ATOM_OVERLAYS`. Whatever the number of splats, skin
  semen adds one image per limb that carries it, four at most. The body's limb images then share one holder per layer
  (`prepare_bodypart_overlays()`), so the four take one of the mob's overlays.
- **Washing** clears it, through the clean signal, as it clears the floor's decals: showers, washing machines, soap.
- **Examine.** A person's examine names the regions with semen on them, to an examiner when both have the ERP
  preference on.
- **Admin verbs**, under Debug: Apply Dirt (a human in view, then semen on a zone, at a level and variant or at random as
  a climax lands it) and Clear Dirt.

**Pixel parity.** The masks match the reference generator's pixel for pixel. `dirt_semen_corpus.json` lists cases
(random streams, noise, templates and semen on bodies), and `dirt_semen_manifest.txt` holds the MD5 of each case's text
as the reference generator writes it. The `dirt_semen_manifest` unit test builds the same text in game and fails on any
case that differs, writing every case's text to `data/dirt_semen_masks.txt` to compare. A change that's meant to move
pixels is made in the reference generator first, and the manifest is regenerated from it.

### TG Proc/File Changes:

None.

### Modular Overrides:

- `code/component.dm`: `/datum/component/dirtiness`.
- `code/skin.dm`: `/datum/bodypart_overlay/dirt_skin`.
- `code/landing.dm`: `dirt_semen_land()`, `dirt_semen_place()`, the splat cap and the aim zones.
- `code/admin.dm`: the Apply Dirt and Clear Dirt admin verbs.
- `code/subsystem.dm`: `SSdirt`, and `/mob/living/carbon/human/proc/redraw_dirt()`.
- `code/masks.dm`: splats, mask requests and the mask jobs.
- `code/surface.dm`: templates, from the limb sprites a body draws.
- `code/semen.dm`, `code/features.dm`, `code/rasterise.dm` and `code/random.dm`: the generator.

### Defines:

- `code/__DEFINES/~aphelion_defines/dirt.dm`: roles, limbs, zones, thresholds, `DIRT_SKIN_LAYER`, the variant, level,
  load and splat limits, portal views, and the switches and flags `SSdirt` uses.

### Included files that are not contained in this module:

- `modular_aphelion/modules/bulge/`: dirt uses its `bulge_register_icon()`, `bulge_blank_tile()` and
  `/datum/bulge_bounded_cache`.
- `code/modules/unit_tests/~nova/dirt_semen_drawing.dm`, `dirt_semen_manifest.dm`, `dirt_semen_corpus.json` and
  `dirt_semen_manifest.txt`: the tests, the parity corpus and its manifest.
- `code/modules/unit_tests/_unit_tests.dm`
- `tgstation.dme`
