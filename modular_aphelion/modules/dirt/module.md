## Dirt overlays

Module ID: DIRT

### Description:

Dirt that lands on a person shows on their sprite until it's washed off: mess where a shot was aimed, and general dirt,
a cause's dirt in a material (mud from walking, soot from smoke), on everything that shows where its cause reaches.
Slime, tool work on machines, dirt underfoot, blasts, fire and smoke, mining, falls, lying down and rolling on dirt,
reagents and sweat land general dirt in a round (`sources.dm`).

- **Splats.** `/datum/component/dirtiness` holds a person's or an item's splats (`/datum/dirt_splat`): one of eight
  variants of a zone's mess, at level 1 to 4. Levels 1 to 3 are streaks and separate runs with skin between them.
  Level 4 covers the zone in a glaze. A shot adds levels to the zone's newest splat, by its amount
  (`dirt_mess_amount_levels()`: 1, 2, or straight to 4), and what's left past level 4 starts another splat, with a
  variant that zone doesn't have yet. A splat notes when it first landed (`/datum/dirt_splat/var/serial`), the order
  splats merge in, and when it last landed or was raised (`last_serial`). A person carries `DIRT_MAX_SPLATS` at most,
  counting their skin, underclothes, parts, drawn parts, hair and worn items (`dirt_carriers()`, suit storage
  included), and past it the splat that landed or was raised longest ago goes first. A part's share of a shot and a
  taur body's pools are splats of their own, so one shot can add several. `dirt_mess_land()` puts a shot on a person.
- **Aiming.** A shot on someone lists a region for each zone that shows on them (`dirt_mess_regions()`) in place of
  "On them", which stays only when none does: a zone needs a drawn limb it lands on, a monkey gets none (a kobold
  does), a taur gets none below the waist, and a portal offers only what it shows: through a wall, the groin and the
  butt. The pick lands with the shot's amount, and drops no floor decal.
- **Masks are made at run time, never shipped.** A surface's splats become one four-direction RGBA icon, registered in
  the resource cache and drawn as it is (`dirt_baked_icon()`): each pixel takes its one tone role's colour (film, body,
  core, fleck or glint) at that role's alpha. Haze, the palest edge, has no role of its own: it's film at half
  coverage, so it takes the film's colour at half alpha. The colours are the pixel's material's.
- **Materials** (`materials.dm`, `/datum/dirt_material`): mud, dried mud, red clay, dust, plaster, ash, grime, oil,
  grease, soot, sweat, slime, mess and blood. Each has its role colours and alphas, haze included, an edge (a halo, a
  tide or none) and flags (sheen, specks, light, glossy, goo, wet). `dirt_material()` returns the shared one for an id.
  Slime and blood are made from any colour, slime by tg's slime ramp (`dirt_slime_tints()`) and blood in the tones of
  tg's stain sheets (`dirt_blood_tints()`). `SSdirt` keeps the newest `DIRT_SLIME_COLOURS` and `DIRT_BLOOD_COLOURS`,
  and one dropped is made again from its key. A splat stores its material as text (`slime#RRGGBB` for slime), and a
  general deposit also its cause and the limbs it covers. Blood is never a splat's: `dirt_land()` refuses it as it
  refuses mess, and the blood below a taur's waist is drawn from the garments' own blood. Splats merge to one material
  and one role per pixel (`dirt_merge()`): the higher role wins, then the thicker, and the earlier splat keeps a full
  tie. Only mess keeps its splats apart. Runs are keyed by material, so each run takes its material's colour in the
  bake. Masks of mess alone name no material, which the bake reads as mess.
- **Causes.** `dirt_rasterise()` is the one entry point: mess's go to `dirt_rasterise_aimed()`, the 21 general causes to
  their procs (`dirt_cause_procs()`, `causes_ground.dm`, `causes_upper.dm`): walking, kneeling, crawling, a fall, a
  splash, machine work, smoke, settling dust, wear, sweat, slime from above, a plunge, a blast, a douse, and slime
  where it touched each of seven zones. Levels run 1 to 3. Machine work and smoke have a harder fourth
  (`dirt_cause_max_level()`), and splashed oil draws a step darker.
  - The marks are coats, patches, mantles from above and damp shapes (`features_coat.dm`). A plunge, a blast and a douse
    are one field in mob space (`coverage.dm`), so their lines meet across every shape that samples it.
  - The face and hands are too small to wrap dirt round, so they take stamps (`stamps.dm`). On a human head only, the
    dirtier cheek takes a smudge, and some causes smudge the other cheek a level lighter. At level 4 both cheeks draw
    level 3, the smudges' top level. The fingertips take dirt too, the dominant hand a level ahead unless both reach
    the same level, as in a level 3 fall or machine work from level 3. From level 3 smoke's soot veils the face, film
    at most and never on an eye.
- **Where masks come from.** Dirt lies on the body, not on the screen. A body's template maps every pixel near it to a
  limb, an angle round it and a height along it, per direction, built from the limb sprites the body actually draws, so
  other species, digitigrade legs and fitness sizes get their own. Each zone's mess is a few streaks, globs, drips,
  drops and glints placed on that map by a seeded random stream, rasterised to roles, then all the splats on a surface
  merge into one mask, a role to each pixel. Mess's draws are md5-based. Under `DIRT_DRAFT_EXACT` every other deposit
  draws as the original draft drew it: an MT19937 stream seeded from the seed text (`/datum/dirt_random/draft`), and
  the draft's 32-bit noise hash (`dirt_draft_noise()`), its products read from tables and its lattice points read in
  place: the same numbers, worked out once. Every rounding is written out, so the same splats on the same sprites give
  the same pixels on any server.
- **`SSdirt`** builds templates and masks in the background, a piece at a time. It keeps the newest masks (a body keeps
  drawing its own after they're dropped), the templates and sprites read most lately (a waiting job holds its own
  template), the plain human template for the round, and each splat's rasters as one text, its four directions joined,
  each packed four characters a run of pixels in one role and thickness (`drawn()`), so masks made again with one more
  splat rasterise only that one. A merge reads the texts run by run. The blood below a taur's waist keeps its rasters
  there too, one per stain and without the blood's colour, so the taur body and a taur-fitted garment share them. A job
  reads the sprites of its parts or shape one direction a piece first, and draws a field a band a piece. A job keeps
  the noise lattice a deposit samples across its bands and directions until it's made. A shape's deposit drawn whole
  starts each direction afresh. A body whose new masks aren't made yet draws the ones it had, if any, and is drawn
  again once they are. A job whose request a newer one replaced is dropped when its drawing next asks for masks under
  another key. Where no ask follows, the drawing drops it at once: an emptied surface, hidden skin, an absent or
  emptied piece of underclothes, a part that leaves, a taur suit whose splats no longer reach the taur canvas, and a
  taur suit's upper part with nothing to draw (`/datum/dirt_drawing/proc/drop_jobs()`). A job another body still
  waits for is kept. A job that runtimes or reads a missing sprite is cached as failed, and isn't queued again while
  that's kept. A deleted carrier drops its queued jobs, and so does a part leaving the body. An item's carrier deleted
  while nobody wears it keeps them, as whoever wore it may still wait for them. `SSdirt.finish_all()` makes everything
  queued at once, for whatever has to see dirt drawn at once. With `DIRT_MASKS_DEFERRED` commented out there's no
  queue: masks are made as they're asked for.
  - Every cache is bounded: masks 256 (0.1-0.5 MB, icons aside), rasters 2048 (0.85-1.4 KB a splat, about 2.9 MB at
    most), templates 16 (about 220 KB each, 3.5 MB), sprite reads 256 (about 1.1 KB each, 0.3 MB), sprite facings 2048
    (about 180 B each, 0.4 MB), whether sprites have one direction 2048 (the same size each), coverage reads 512
    (about 1.86 KB each, 0.9 MB), part fields 256 (about 300 B each, 75 KB), seed texts' draft words 256
    (0.2-0.77 MB), slime colours 64 (an estimated 600 B each, 40 KB), blood colours 32 (the same size each), sweat's
    multipliers 128 (about 90 KB at most), wags' sprites 16 (2.7-14 KB a tile tail's, 34-91 KB a taur tail's: about
    1.5 MB at most) and the noise lattice's points 8192 (about 335 KB, from 2048 points' 78-87 KB measured). There's
    one lattice, passed from a job to SSdirt to a field and back as a deposit is drawn, and a second only while a
    deposit is drawn outside a job. The draft hash's tables hold 6,144 numbers (48 KB). The hair's sources are kept a
    hairstyle and hair-mask icon each, and the pieces it shows over hats, as tg keeps those icons
    (`blended_hair_icons_cache`). A field's samples are transient: 5 values a pixel of its canvas at most, so 10,240 for
    a taur's coat, about 0.7-1.0 MB at an estimated 70-100 B an alist entry. A job's deposit keeps one table
    across its directions, held while its fields draw their bands and dropped once it's drawn in every direction. So
    are the painted designs' shown points (`dirt_painted_near()`): one deposit's, an estimated 50 KB at most, dropped
    for the next deposit's. A job keeps the deposit's features by level the same way, made by its first direction and
    unbound before each later one binds them (`dirt_level_features()`): an estimated 30-250 KB while it's drawn. The
    noise those features sample goes in one table beside them, each value under its exact arguments (`noise()`): an
    estimated 20-120 KB while it's drawn. A skin's job holds the masks its drawing draws until the job's own are made,
    so a limb whose runs are unchanged keeps its icon. If the drawing drops those masks meanwhile, the job keeps them
    until it ends.
- **Where general dirt lands** (`dirt_land()`). A cause reaches a fixed set of limbs (`dirt_cause_reach()`, written from
  the reference generator and pinned by the corpus), and every carrier that shows on one of them takes the
  deposit for those limbs (`dirt_shown_carriers()`): each worn item drawn on the body, each piece of underclothes, and
  the skin. They're judged as underclothes are for mess, on the plain human template facing south and north, every one
  that shows rather than the one that shows most: worn items by the layers they're drawn at, the hands over the uniform
  as skin, the underclothes under every worn item and the skin under everything. A taur suit shows over the rider's
  tile as any garment, and takes its hem band besides. The skin takes only the limbs the person draws. A wet material
  and the sweat cause never land on bare skin, nor on underwear, which draws general dirt as skin does.
  One landing shares one variant, and every deposit draws on the person's dirtier side (the component's `side`, picked
  once), so its lines meet across the carriers. A carrier keeps a deposit only on the limbs it showed on (its raster
  read on those alone, `dirt_merge()`): shorts taken off keep walking mud on the legs alone. The same cause and
  material raise a deposit's level, up to the cause's top, and it keeps its variant and its place in the merge, and
  counts as landed when it's raised (`last_serial`). A carrier holds `DIRT_CARRIER_DEPOSITS` general deposits, and
  past that the one that landed or was raised longest ago goes.
  - A deposit's raster is made whole, on every limb, under its cause, its material's shape class
    (`/datum/dirt_material/proc/shape_class()`), level, variant and side, so every carrier holding it shares it, and
    keeps to its own limbs as the masks merge. One with a painted design on a bare body's skin (`dirt_painted_design()`)
    is kept under its material and as painted instead, as the designs differ by material. Any other draws there as on
    a dressed body and shares its rasters.
  - Bare bodies (`dirt_bare_bodied()`: more than `DIRT_BARE_SHARE` of the chest showing skin, facing south, past the
    garments, undershirt, bra and socks) take the painted designs on their skin and underwear. It's judged when the
    masks are asked for, from what's worn then, so dressing has them made again (`check_cover()`).
  - The painted designs (`painted.dm`) are the reference generator's hand-painted cells: machine work in oil or grease
    (grease wearing oil's points, in its own colour) and smoke in soot worked in from the hands, a blast of soot, a
    plunge into mud, and walking and kneeling in any material. They draw below the head, which keeps the deposit's own
    marks, mirrored on a body dirtier on the other side. Walking and kneeling never mark the head, so under their
    designs their own marks aren't drawn. Which of a design's points a level shows is the same in every direction, so
    the last deposit's are kept and its four directions build them once.
  - Underwear takes the skin's dirt, painted on a bare body. Undershirts, bras and socks take cloth's.
  - A body hidden under a worn sprite bigger than its tile (`dirt_body_hidden()`: a sleeping bag) draws no skin dirt
    and keeps it, and isn't bare.
  - Examining a person or an item names the heaviest general material on it (`dirt_examine_line()`). Mess has no line.
- **What lands general dirt** (`sources.dm`). Every source lands through `dirt_source_land()`, never `dirt_land()`
  itself. Each source is a `/datum/dirt_source` subtype that's never made: the gate reads its cause, material, level,
  chance, cooldown and whether it waits off the type, and the call passes what the event works out itself, such as a
  slime's colour, the zone's slime cause, a decal's material or a blast's severity. The gate refuses anything but a
  human, a body being deleted, the plain monkey species (as mess does) and a human without a
  `/datum/component/dirt_sources`, the listener every human but a preview dummy gets as it's made. It keeps their
  cooldowns, by the source's type, split for a slime person's touch by the slime cause and for reagents by the
  material. Then it rolls the source's chance, and the roll starts the cooldown, landed or not, so a cooldown caps how
  often a source rolls. `DIRT_SOURCES` turns every source off. A source that can reach a crowd in one tick (blasts,
  fire, smoke, falls and reagents) is `deferred`: its landings wait for a later fire of `SSdirt`
  (`/datum/dirt_job/landing`), so they land a few at a time as the tick has room. A person deleted meanwhile takes none,
  and while `DIRT_LANDINGS_WAITING` wait, more are refused.
  - A latched slime letting go, if it slimes its victim (`/datum/status_effect/slimed`), lands slime from above in its
    colour, a rainbow slime's in a random slime type's. The status and the deposit each come off their own way.
  - A slime's hit that does something lands slime where it hit, folded onto the base zone, and a chest hit from behind
    on the back.
  - A slime person (`isjellyperson()`) leaves slime in their mutant colour with a hug on the chest (a level more for a
    bear hug), a head pat on the head and a grab where it was aimed, and the other person's slime goes on their chest
    or the arm they used. Each kind of touch keeps its own cooldown, so a grab doesn't hold off the bear hug after it.
  - A wrench, screwdriver, crowbar, welder or wirecutter job that succeeds on a machine greases the worker by chance,
    one roll in its cooldown at most, and on a vehicle, a mech or a cyborg oils them (`/datum/dirt_source/tool_work`).
    A scan or a multitool link leaves nothing. Engineers roll a lower chance (`engineer_chance`).
  - Walking or crawling over dirt, ash, flour, concrete dust, garbage or rubble lands its material by a low chance, the
    floor looked at once in `floor_check_interval` (`/datum/dirt_source/floor_decal`, `dirt_decal_materials()`).
    Stepping into a wet oil pool lands oil.
  - An explosion lands a blast of soot at its severity, after it acts, so a body it gibs takes none.
  - Catching fire lands smoke's soot, and going out after `burn_time` alight adds a level
    (`/datum/dirt_source/soot/fire`). Standing in smoke lands it once in its cooldown.
  - Breaking rock from beside it lands settling dust by a low chance. Rock broken from range lands none.
  - A fall from standing lands what's underfoot (`dirt_fall_material()`): a dirty decal's, a wet oil pool's, or the
    ground's own (`dirt_ground_materials()`): dust from dirt and sand, ash from ash. Grass, snow, basalt and a clean
    floor land nothing.
  - Lying down by choice on such a spot lands its crawling marks, once in its cooldown (`/datum/dirt_source/resting`).
    Rolling on one to put out a fire (`/datum/status_effect/stop_drop_roll`) lands a fall's marks at level 1 each roll
    turn, once in its own cooldown (`/datum/dirt_source/rolling`). The drop into the roll is a fall of its own.
  - Reagents touching someone as a liquid or a vapour land their material (`dirt_reagent_materials()`): oil and tar oil,
    cooking oil and lube grease, carbon soot, ash ash, cement, concrete and flour plaster, slime jelly slime in its own
    colour. A splash lands by its volume. A pool ankle deep or more touching someone standing in it, its reagents in a
    holder with no atom of their own, is wading: a walk at the ankles, deeper a plunge by depth. Splashes and wading
    (`/datum/dirt_source/reagents/splash` and `wading`) each roll once for a material in their cooldowns, apart, so
    foam, showers and standing liquid, which touch every tick, don't stack it at once.
  - Sweat lands on cloth: a climax and collapsing from exhaustion at level 2, and working out
    (`/datum/status_effect/exercised`) and a core overheating as the game reckons it at level 1, once in one cooldown
    between those two (`/datum/dirt_source/sweat/worked_up`). Only a climax lands in water: the rest never do
    (`TRAIT_IMMERSED`). A person reads as sweaty to interaction text while anything they wear holds sweat
    (`dirt_wears_sweat()`).
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
- **Skin.** Each limb the skin's splats lie on gets a `/datum/bodypart_overlay/dirt_skin`: one container image holding
  the limb's baked image, clipped to the pixels that limb shows. Mess lies on the head, the chest and the legs, and
  general dirt on any limb, the arms too. It draws at `DIRT_SKIN_LAYER` (22.25): under the underclothes (19.1 and
  19.101) and the genitals, over body hair (22.5), markings and the limbs. An arm's also draws its hand's at
  `DIRT_HAND_SKIN_LAYER`, over the hand, which draws over the uniform, and under gloves. An MD5 of what the limb's baked
  image draws goes in its render key, so a landing elsewhere on the body leaves that limb's images as they were.
- **Dirty limbs' images.** Every key mess adds to a limb's render key (the skin's, the underclothes', a part's share and
  a taur body's pools) starts with `DIRT_PRIVATE_KEY`, and a limb drawn under such a key keeps its images on its own
  mob (`limb_icons_for()`): one entry per zone, dropped when the zone is drawn clean or loses its limb. tg's
  `limb_icon_cache`, shared by every body, serves keys that come back: markings, tails, ears, wings, genitals' states,
  textures, body hair, augment finishes, blood on limbs and heights. A dirty limb's key almost never comes back, so in
  that cache it would only add entries.
- **Fading out under clothes.** Skin mess fades over the last `DIRT_FADE_RINGS` pixels before whatever is worn over it,
  instead of stopping at its edge. The masks are made with the fade, from the sprites drawn in the underclothes and
  garment slots (`dirt_cover_sprites()`), so those sprites are part of the masks' key. A worn sprite its wrapper moves,
  or one that isn't 32x32, such as a taur suit, a 64x64 hat or a hat drawn higher, covers where it lies over the body
  (`dirt_worn_read_shift()`), by the same rule that reads where general dirt lands. A change to those slots has
  `SSdirt` look again once the slots settle, and makes new masks only if what's worn over the skin changed. `SSdirt`'s
  own redraw of a body changes nothing worn, so it has no look taken (`SSdirt.redrawing`, let go of even when the
  redraw runtimes).
- **Clothes.** A worn garment keeps its splats when it comes off. While a person wears it, it draws them through its
  worn wrapper (`COMSIG_ITEM_GET_SEPARATE_WORN_OVERLAYS`): one baked image, `BLEND_INSET_OVERLAY`, so it shows only
  where the wrapper has drawn before it: on the garment's own pixels, fitted or not, and on any image added before it,
  such as a blood stain it draws over. The masks are the cloth surface of the wearer's body, its rim a role lighter,
  so a garment moved to another body draws from that body's. They float, moved back onto the body's tile by what
  `build_worn_icon()` moves the wrapper by (`dirt_worn_shift()`: its centring on the garment's worn dimensions and its
  worn offsets). Offsets the body puts on the wrapper after that (a species' worn offsets) still move them. On a garment
  drawn on that tile they aren't offset, and the bulge redraws them over its cloth. A steady draw matches the wearer's
  sprites through notes on the wearer's carrier (`worn_sources`, `worn_reads`), by a few vars. A limb or the eyes
  leaving drops the notes, and a full match that passes notes them again. An item in suit storage keeps and
  draws the dirt it holds, is drawn again when its masks are made, and counts among the person's carriers
  (`dirt_carriers()`), so the cap, examine and Clear Dirt reach it. No dirt lands on it there.
- **Dirt and tg's blood stain.** On a garment, whichever of blood and dirt landed last draws on top, for the whole
  garment. tg adds the stain after dirt's images, so it draws over them while the garment's newest blood landed after
  its newest dirt (`stain_over()`). Otherwise, while the garment holds blood that shows, `on_worn_overlays()` notes
  where its first dirt image and its sweat's multiplier are (`/obj/item/var/dirt_stain_slot`), and `build_worn_icon()`
  has `dirt_order_worn()` move the stain to that first place, with the multiplier just under it, only for an item
  whose place is set. The stain is the last image after that place whose state names blood, as every
  `get_blood_overlay()` names it, digitigrade shoes' included. An item that draws none, such as a belt, a backpack or a
  mask that doesn't cover the head, keeps its order, its sweat over its dirt. Images that aren't dirt's added after
  dirt's, such as a MOD module fitted after the carrier was made, then draw over the stain too. Only the images' order
  changes, never a mask: the stain moves, and the sweat's multiplier with it. The dirt module's own
  `/obj/item/add_blood_DNA()` has an item's carrier note when blood that shows on items landed (`blood_landed`),
  before the merge, and never for blood the item refuses. Mess or a deposit landed or raised on the garment notes when
  it landed (`dirt_landed`), but sweat, a wet material, doesn't, as it never draws over the stain. The same blood
  landing again counts as new blood. Sweat's multiplier always draws under the stain. A taur suit's hem band is the
  suit's dirt, so it draws on the side of the stain the rest of that dirt does.
- **Sweat** (`sweat.dm`) darkens the cloth it lands on in the cloth's own colour: a garment holding it draws a
  `BLEND_MULTIPLY` multiplier made from its sprite near the wet pixels, in its worn wrapper, and a piece of underclothes
  its own beside the underclothes' container. Multipliers are kept in `SSdirt.wet_icons`, the ones asked for most
  lately, and a garment holds its own while a new one is made. A multiplier's job makes the garment's sprite once and
  reads every direction from it. A garment keeps the key it asked for with the masks' key and the look it read, so a
  steady draw builds no key. Accessories pinned on a uniform stay dry (`dirt_accessory_sprites()`). The multiplier
  always draws under a blood stain on the garment.
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
  - A part drawn over the skin takes the skin's general deposits on its own pixels, in the directions it draws over it
    (`dirt_parts_over()`), drawn under its own share in its container. It takes no share of them, and the skin's mess
    stays off it.
  - Through a one-part portal a shot lands on the penis alone, its own entry in the list, offered and landed only while
    it draws its front image. A gloryhole's occupant draws their penis only through its relay, so it takes no share of
    a shot on the body and shapes none of the body's mess (`dirt_body_parts()`, which asks `portal_relays_penis()`). A
    part removed takes its splats with
    it, a wash redraws the whole body, and a change to what the body draws of its parts makes the masks they shape
    again.
- **Taurs.** A back shot on a taur lands on the rider's back as on anyone's, the rider drawn on its legless template,
  and puts broken pools with uneven drips along the taur body's back: a splat of the same variant in
  `part_mess_splats` under `ORGAN_SLOT_EXTERNAL_TAUR` (`dirt_taur_takes_pools()`), capped and washed with the rest.
  Big Legs kinds, legs under the rider with no taur back, take none: the shot lands on the rider alone, and no general
  dirt lands on their legs.
  - The taur body is read from its own images (`dirt_read_source()`): each layer's colour layers' states, on the 64x32
    taur canvas. Its pools (`dirt_taur_pools()`) lie on the pixels it shows with the rider drawn between its adjacent
    and front layers (`dirt_taur_owners()`), in a band under the back line the view shows (`dirt_taur_back_region()`:
    none facing south, none at the tail end or beside the rider's waist), and keep clear of the same shot on the
    rider's cloth and skin, so no line runs across both bodies (`dirt_mess_splat_rasterise()`). Level 1 is a drop,
    and levels 2 and 3 are two pools. A top-level splat draws level 3's pools beside the rider's glaze.
  - The taur body takes general dirt that reaches the legs it stands in place of, and slime on its back, front or legs
    (`dirt_taur_takes()`). Walking, crawling and dust coat it from wherever its kind touches the floor (`taur_coat.dm`),
    slime lies in its own pixels (`dirt_splat_region()`), a douse runs along its own top edges, and the rest comes from
    the canvas field (`dirt_shape_deposit()`). A coat is a field of its own in each direction
    (`/datum/dirt_canvas_field/taur_coat`): its view a piece, then each level's coat a band of the body's pixels a piece
    and its finish another, and drawn whole as its bands back to back.
  - The rider stretches with height (`dirt_height_rows()`), and the taur body doesn't. The taur body's own dirt is
    made as an Average rider shows the canvas: its pools are placed and kept clear of the rider's mess there, its slime
    and a douse lie on the pixels it shows then, and its canvas field and coat read no rider. Every height shares their
    rasters and merges them alike. Height enters only the masks' key (`/datum/dirt_mask_request/var/rows`), never a
    raster's. The rider's height then decides only what each layer shows. Nothing is drawn where the stretched rider
    covers the taur body. A pixel a taller rider uncovers keeps the merged dirt it holds, as a canvas field or a coat
    draws under the rider too. Else it takes the merged dirt of the pixel just below its run of uncovered pixels, where
    the taur body shows that pixel at Average height, and a glint there goes on as body (`dirt_taur_height_fill()`). So
    no clean band shows under the rider's waist.
  - Each taur layer draws its dirt on the pixels it shows: a container just over its images, at their layer and their
    centred offsets, in that layer's own holder (`taur_overlay.dm`). The masks' key goes in the taur body's render key,
    or "pending" while they're made.
    A steady redraw of the pools reads the rider's sprites again only once a var its limbs or eyes are drawn from
    changes (`rider_unchanged()`). The blood below the waist matches them in full on every key build.
  - A taur suit, a garment drawn over the whole taur canvas (`dirt_taur_fitted()`), takes the shot itself and the taur
    body takes none: the suit's back splats draw the same pools, inset over its own pixels on the canvas round the
    body's tile. Its wrapper is drawn 16 px left by `worn_x_offset`, so the 32x32 mess on it goes 16 px right, onto
    that tile.
  - A taur suit also takes what the taur body would of general dirt, as its hem band: cloth over the whole canvas, inset
    over its own pixels. Its deposits keep the cause's reach as their limbs, so worn by a biped it draws them there.
    Walking, crawling and dust on it are the hidden taur body's contact coat, and slime and a douse lie on that body's
    pixels, as its pools do. Its upper part, over the rider on the body's tile, draws its general dirt as clothing too,
    as the suit on a biped would, over the hem band. It leaves out the legs' share of walking, crawling and dust, which
    the coat draws (`ready_cloth_masks()`). It also takes what reaches the rider alone on the limbs it shows on, which
    the hem band doesn't draw. What it's drawn over takes none.
    A suit holding mess alone draws it under its pools; one holding general dirt too draws its tile's mess over them,
    the hem band and pools first, though little overlaps, as the pools keep clear of the rider's mess.
  - A taur body removed takes its pools with it. A taur's penis drawn only behind the body takes nothing.
  - **Blood below the waist** (`blood.dm`). A taur's uniform or suit stain and rips are cut at the waist where its
    sprite is cropped there or taur-fitted (`cuts_effects_at_taur_waist()`). A skirt or robe that isn't cropped, a
    `LARGE_WORN_ICON` garment and a Big Legs taur's clothes keep their whole stain, and nothing runs from them. Below
    the cut, dirt draws the blood running on down the body, in the stain's own colour (`/datum/dirt_material/blood`),
    from the columns where the stain's dense mass reaches the cut (`dirt_blood_mass()`): a faint fringe starts
    nothing. It starts one row under the stain's last drawn row, which the rider's height moves while the taur body
    stays put (`dirt_blood_seam_row()`). It's never stored: it follows the garments' blood, the variant comes from
    the blood's DNA, and it goes when they're washed or taken off. A cover check (`check_taur_blood()`) then deletes any
    carrier on the person, their uniform or their suit that holds nothing (`holds_nothing()`: no splats, no drawing,
    nothing drawn on a limb and no dirtier side), whatever made it, taur or not. While blood runs below the waist, it
    keeps the person's carrier and the taur-fitted garment's. It's worked out as the game draws it at the rider's
    height, the rider and a taur-fitted garment stretched by the height filters, the taur body where it is
    (`dirt_height_rows()`). The taur body draws its share with its own images, its adjacent layer over the rider as
    the game draws them. A taur-fitted garment draws its share inset on its own cloth, back in its wrapper's rows, so
    a run crossing an apron's hem meets itself at every height. A uniform's runs keep off those of the suit over it.
    Facing east or west, a run reaching the ground where the body turns into a coil rounds the bend. Facing north none
    is drawn, and rips never run. A taur that gets a stain without a carrier of dirt has one made at SSdirt's next
    fire, outside the render.
    - On the taur body the blood draws over the body's own dirt (its pools and deposits) while it landed after that
      dirt, else under it (`waist_blood_over()`). The garments' own dirt plays no part. Blood counts as landing when the
      person's carrier first sees a uniform or suit that shows a stain hold a blood DNA list it didn't hold before, or
      sees another garment in that slot (`note_waist_blood()`). The carrier looks as blood lands, from the dirt
      module's `/obj/item/add_blood_DNA()`, and again as the slot draws. A merge makes a new list. It counts by the DNA
      it adds (`dirt_waist_blood_landed()`): a merge adding none, the same blood landing again, counts whatever that
      blood is, and so does one adding DNA of blood that shows a stain. One adding only DNA of blood that shows none
      counts nothing, even with blood that shows one landing again beside it. A garment's first blood is the
      list it was given, which another garment can hold too, so each slot notes its garment beside its list
      (`suit_blood_garment`, `uniform_blood_garment`). Taking a garment off and on again counts nothing. A carrier made
      while blood is worn, on a uniform the suit hides too, notes that blood as landed before it. The chest's render key
      carries the side (`DIRT_TAUR_BLOOD_OVER_KEY`), and a cover check draws the body again on a side it doesn't take.
    - On a taur-fitted garment's cloth the run draws over the cloth's own dirt while its blood landed after that dirt
      (`dirt_cloth_run_over()`). When the cloth is the outermost bloodied garment, that's its own stain's side, so a
      run crossing the hem keeps it there. Blood run onto it from another garment landed when the person's carrier last
      saw blood land at the waist (`waist_blood_landed`). The taur body decides its own side apart, so at the waist a
      stain, the run on the cloth and the run on the body can draw on different sides of their dirt.
- **Drawn parts** (`appendages.dm`): tails, wings, ears, horns and the other mutant parts each carry their own general
  dirt under their organ slot (`part_splats`), taken with the organ. Each draws it in a container over each of its
  layers' images, in that layer's own holder. Every mutant part's `get_overlay()` and `icon_render_key()` call
  `dirt_shape_overlay()` and `dirt_shape_render_key()`, which leave at a typecache check for a part that takes none,
  and after one component lookup on a person whose parts hold none.
  A still part is read again only once its own render key, its accessory or its limb's gender changes.
  - A tail takes ground dirt along its own underside, smoke, wear, machine work and kneeling as a sparse film, a douse
    along its top edges, and a fall, a splash, a plunge and a blast from the canvas field facing north, as it hangs off
    the back. Wings take the same, but the ground and kneeling give them only two drips at level 3, and slime from
    above or lain in on the back. Every other part takes a fall, a splash, a plunge, a blast and a douse alone.
  - A part sits on the canvas its sheet and offsets match (`dirt_canvases()`): the tile, a 32x48 tile, the 45x34 wings
    canvas or the 64x32 taur canvas. One on no canvas takes nothing (32x48 big ears drawn 8 px down). Moth wings on the
    tile, and a taur's 64x32 tail, take dirt as any other part. Tail spines, held by the tail rather than by an organ of
    their own, stay clean.
- **The canvas generator** (`canvas.dm`) draws dirt for what isn't the template body. Its fields lie in mob space,
  pixels across from the tile's middle and up from its floor, so every canvas samples one field through its own offset
  and a tail's mud line meets the legs'. The game clips each canvas to the real sprite. A mask job draws a field
  `DIRT_FIELD_BAND_PIXELS` a piece, once for every direction it serves; a douse the same. Bands on the body too: a
  plunge, a blast or a douse on a body's template is a field of its own in each direction
  (`/datum/dirt_canvas_field/body`), its coat bound a band of rows a piece, and drawn whole as its bands back to back.
  A field's levels share the noise that doesn't take the level: the first level that asks samples it, by pixel or by
  the one column or row it takes, and the later ones read it back (`samples`).
- **Wagging tails.** A wagging tail draws its dirt baked on every frame of its wag, one animated icon a layer, made at
  its first wag after its dirt changes and kept until it changes again. Nothing shows while it's made, but a one-frame
  wag shows its still dirt, and keeps it where its frame shows the still sprite. Each frame takes the still tail's dirt
  pixel by pixel, from the same point along the tail from the hips and across it (`/datum/dirt_tail_carry`), so the
  dirt swings with the tail and looks the same still and wagging. The job merges the still's rasters once and
  rasterises nothing per frame. `SSdirt.wag_sprites` keeps what the wags baked most lately show and where each pixel
  takes the still's dirt from, so a wag baked again, for other dirt or on another body with the same tail, reads no
  sprite. An animated wag's job queues behind the other jobs waiting, and a wag's job is dropped if its dirt changes
  first while no other body waits for it.
- **Hair** (`hair.dm`) carries its own general dirt under `DIRT_CARRIER_HAIR`, while it shows: a plunge, a blast and
  slime from above from level 2, a douse and slime on the head from level 1, smoke and slime lain in with the back from
  level 3 (`dirt_hair_levels()`). It's read from the icon the head draws the hairstyle from (`dirt_hair_source()`), its
  darkest quarter of strands kept clean, then despeckled and given a glint where a material with a sheen lies, and
  drawn in one container over the hair. A hairstyle's pieces drawn over hats (braids and the like,
  `hair_appendages_outer`) take it with the hair, worked out over both together, and draw their share in one more
  container over them, at their layer. A hat that hides the hair takes the deposit as a worn item, and the hair under it
  none. A head that leaves the body takes the hair's dirt with it, unless it's swapped without the usual effects, as a
  species change swaps it.
- **Emissive blockers.** Each baked image of dirt draws an emissive blocker in its shape and at its alpha
  (`dirt_emissive_blocker()`), so in the dark a thin film dims a glow under it and a thick coat cuts it. The blocker
  comes just after its image, at its layer and offsets. On a limb and in the hair it's one of their images, beside the
  container, never in it. On a garment it's inset and moved as the dirt is, in the worn wrapper, and the worn emissive
  pass lifts it into the wrapper's mirror on the emissive plane. The inset keeps it to the garment, because the cloth
  masks cover the whole body. Sweat's multiplier draws none, and neither does blood below a taur's waist, on the taur
  body or on a taur-fitted garment's cloth. The bulge's copies of a garment's dirt over its cloth (`bulge_over_cloth()`)
  draw none either: the cloth's own blocker covers what glows under them. The underclothes' dirt drawn again over a
  look's cloth does draw one. A blocker keeps its image's place against a garment's glowing stain. Dirt that landed
  after the blood dims the stain's glow, and blood that landed after the dirt still glows over it.
- **The overlay budget.** A mob draws as an error sprite past `MAX_ATOM_OVERLAYS`. Whatever the number of splats or the
  roles they draw, skin dirt adds one image per limb that carries it, six at most, and one per dirty hand, each holding
  one baked image, and the underclothes one more, with one multiplier per sweaty piece beside it. Each baked image has
  its blocker beside the image holding it, and a multiplier has none. The body's limb images then share one holder per
  layer, and their blockers one group per layer (`prepare_bodypart_overlays()`), so they take four of the mob's
  overlays, six with a dirty hand, and each multiplier one more, as it multiplies and joins no holder. A part's
  container joins its front layer's holder, a taur body's and a drawn part's each layer's, and each blocker joins the
  group of the part's own blockers or glows at that layer, or adds one where the part draws none there. The hair's
  containers, two with pieces over hats, go in with the hair's images, the hair's blocker in with the hair's own, and
  the pieces' blocker adds one group unless a piece glows. A garment's images go in its worn wrapper, and their
  blockers in its mirror, which adds one group to the slot only for a garment that draws no glow or blocker of its own.
  A body dirty everywhere takes about four more overlays for its blockers.
- **Washing** clears it, through the clean signal, as it clears the floor's decals: showers, washing machines, soap. A
  person's wash reaches the worn items nothing covers. A wash drops the mask jobs it leaves nothing to draw, unless
  another body waits for them, and a garment's only while it's worn. An item's carrier is deleted once a wash, Clear
  Dirt or the cap leaves it no splats and no blood below a taur's waist (`clear_mess()`, `mess_changed()`). One left
  drawing that blood lets go of its cloth's masks, and is deleted once the blood goes. A person's carrier stays through
  a wash and Clear Dirt, and keeps its dirtier side, since what they wear may still draw on it. Once their skin has
  drawn dirt, it also keeps the skin's drawing until it's destroyed, so it never holds nothing (`holds_nothing()`) and
  no cover check deletes it.
- **Admin cleanup.** Clear Dirt is available under Debug and in every mob's VV action menu, where it acts only on a
  human. Both require `R_ADMIN`, and the VV action runs the verb, so both are logged alike. The Apply Dirt debugging
  helper (mess at a zone, or a cause's dirt in a material, slime in a colour, at a level and variant, or at random) is
  temporarily commented out.
- **Known limits.**
  - The hair's dirt follows the stock hairstyle, not hair paint, and its field doesn't shift with the hair's offsets,
    though its container does.
  - Per-facing accessory offsets (Teshari's) aren't followed by a drawn part's dirt or its wag.
  - A wag's carry measures a tail from its pixel nearest the hips, a taur's rump: facing south a kitsune taur's tail
    roots at a small bit between its fans, and a tail curled over its own back at its tip.
  - Big Legs taurs, parts on no canvas and tail spines take no general dirt.
  - Hair seen through a partly see-through piece drawn over hats shows clean there: each layer bakes its own pixels.
  - Dirt drawn over a blood stain also shows on the stain's pixels that lie off the garment, such as a pair of shorts'
    stain on the bare chest, because the cloth masks cover the whole body and the stain widens what the inset keeps to.
  - The order against a stain is the whole garment's: once dirt lands after the blood, all of its dirt draws over the
    stain, the older too.
  - The taur body's blood takes a new side at the next cover check after blood lands, so for one fire it can show the
    old one.
  - On a garment that shows a stain, blood it already holds that shows none, landing on it again, still counts as
    blood landing below a taur's waist. Blood it holds that shows one, landing again with new blood that shows none,
    doesn't.
  - An item's first blood, landed by the item's own call, shows its stain and its run below a taur's waist only when
    something next draws the slot or the body.
  - A person with no splats of their own (skin, underclothes and parts), whose garments hold some, isn't checked again
    when a genital changes. The garments follow the change when they're next drawn.
  - On bare skin tg's blood draws over skin dirt whatever landed last: damage blood at `DAMAGE_LAYER` and bloody hands
    at `GLOVES_LAYER` both draw over it.
  - A blocker dims only what glows under its layer, as its dirt covers only what's drawn under it: skin dirt leaves the
    eyes, the genitals and the parts drawn in front glowing.
  - A glow a part's subtype adds after the part's dirt stays bright under it: the cybernetic cat ears' inner glow and
    the abyss fish tail's skeleton.
  - On a garment that draws no blocker of its own, its dirt dims only that garment's glows and stain. With no glow and
    no glowing stain under the dirt, its blocker is inset on nothing, so it draws no pixel. What glows under the
    garment shows through its dirt at full.
  - Blood below a taur's waist neither glows nor blocks. Where it's drawn over the taur body's dirt, that dirt's blocker
    still dims a glow of the taur body under them in the dark.
  - Dirt in see-through hair blocks at the square of the hair's alpha ratio, as the hair's own blocker does:
    `emissive_blocker()` takes that alpha both as the blocker's alpha and in its colour matrix.

**Pixel parity.** The masks match the reference generator's pixel for pixel. `dirt_corpus.json` lists cases: random and
draft-stream draws, both noise hashes, templates, mess on bodies with parts under and over them and on parts, taur
bodies under a rider and the pools on them, materials, general deposits (painted designs among them, a taur's rider
too), merges, each cause's reach, sweat's multiplier, canvases, tails, wings, shapes, slime on shapes, taur coats and
hair. `dirt_manifest.txt` holds the MD5 of each case's text as the reference generator writes it. The `dirt_manifest`
unit test builds the same text in game and fails on any case that differs, then writes every case's text to
`data/dirt_masks.txt` to compare. A change that's meant to move pixels is made in the reference generator first, and the
manifest is regenerated from it.

### TG Proc/File Changes:

- `code/modules/mob/living/carbon/carbon_update_icons.dm`: `/mob/living/carbon/proc/update_body_parts()` takes each
  limb's images from `limb_icons_for()`, which serves a key without `DIRT_PRIVATE_KEY` from `limb_icon_cache` as tg
  does. A body holding no private images reads the cache itself, and skips the call while the cache holds the key
  (`DIRT_LIMB_ICONS_STEADY()`, `DIRT_LIMB_ICONS_CHANGED()`).
- `code/modules/mob/living/carbon/human/human_update_icons.dm`: `/obj/item/proc/build_worn_icon()` calls
  `dirt_order_worn()` on the separate worn overlays while the item's `dirt_stain_slot` is set, which moves the blood
  stain under dirt that landed after it.
- `code/modules/clothing/under/_under.dm`: `/obj/item/clothing/under/worn_overlays()` keeps the accessories' overlays on
  a taur's rider (`fit_rider_overlays()`).
- `code/modules/mob/living/carbon/human/human.dm`: `/mob/living/carbon/human/Initialize()` gives every human but a
  preview dummy its `/datum/component/dirt_sources`, while `DIRT_SOURCES` is on.

### Modular Overrides:

- `code/component.dm`: `/datum/component/dirtiness`, the order of its images against a garment's blood stain
  (`on_blood_added()`, `stain_over()`), and the examine line. `/obj/item/add_blood_DNA()` notes blood for dirt as it
  lands on an item, then calls the base proc.
- `code/skin.dm`: `/datum/bodypart_overlay/dirt_skin` (mess and general dirt, the hands' too),
  `/datum/bodypart_overlay/dirt_underclothes` (each piece's dirt and its sweat's multiplier) and
  `dirt_emissive_blocker()`, every baked image's blocker.
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
  skin's general dirt on it, and `icon_render_key()` carries their keys; on `/obj/item/organ/genital`,
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
  `dirt_shape_render_key()`, the reads), and on `/datum/bodypart_overlay/mutant/tail` its wag; the wag's frames and
  carry.
- `code/hair.dm`: on `/obj/item/bodypart/head`, `generate_icon_key()` carries the hair's masks' key and
  `get_hair_overlays()` draws the hair's dirt and its outer pieces'; the hair's merge.
- `code/sweat.dm`: sweat's multiplier and the accessories kept dry.
- `code/limb_cache.dm`: on `/mob/living/carbon`, `private_limb_icons`, `limb_icons_for()` and `drawn_limb_icons()`;
  on `/obj/item/bodypart`, `on_removal()` drops the limb's private images.
- `code/admin.dm`: the Clear Dirt admin verb and the commented-out Apply Dirt debugging helper.
- `code/subsystem.dm`: `SSdirt`, and `/mob/living/carbon/human/proc/redraw_dirt()`.
- `code/masks.dm`: splats, mask requests and the mask jobs.
- `code/materials.dm`: materials, `dirt_material()` and slime's and blood's colours.
- `code/surface.dm`: templates, from the limb sprites a body draws.
- `code/mess.dm`, `code/features.dm`, `code/features_coat.dm`, `code/causes_ground.dm`, `code/causes_upper.dm`,
  `code/coverage.dm`, `code/stamps.dm`, `code/painted.dm`, `code/rasterise.dm` and `code/random.dm`: the generator.
- `code/canvas.dm`: the canvas generator, for taur bodies, drawn parts and hair.

### Defines:

- `code/__DEFINES/~aphelion_defines/dirt.dm`: roles, limbs, zones, thresholds, `DIRT_SKIN_LAYER`,
  `DIRT_UNDERCLOTHES_LAYER`, the underclothes, the fade, the variant, level, amount and splat limits, materials, their
  edges and flags, causes, carriers, limb bits, portal views, part kinds, canvases and shapes, the taur canvas,
  `DIRT_PRIVATE_KEY`, `DIRT_TAUR_BLOOD_OVER_KEY`, the switches and flags `SSdirt` uses, and `DIRT_SOURCES` with
  `DIRT_LANDINGS_WAITING`. Each source's chance, cooldown, level and volumes are on its `/datum/dirt_source` subtype
  (`code/sources.dm`).

### Included files that are not contained in this module:

- `modular_aphelion/modules/bulge/`: dirt uses its `bulge_register_icon()`, `bulge_blank_tile()`, `bulge_drawn_root()`,
  `bulge_drawn_leaf()`, `bulge_is_accessory()`, `/datum/bulge_bounded_cache`, a penis's
  `bulge_key`, `bulge_wanted_cut()` and `bulge_cut_sprite()`. Its look's anatomy memo (`bulge_anatomy_record()`,
  `bulge_anatomy_unchanged()`) records the testicles' `dirt_share_key()`, so the testicles it draws behind a cover draw
  their mess as it changes. The look's key carries `DIRT_PRIVATE_KEY` when the anatomy it draws carries mess, or the
  cover's mess goes over its cloth (`bulge_over_signature()`), so those chests keep their images on the wearer. Its
  `bulge_over_cloth()` redraws a cover's dirt over the look's cloth, kept to it, a sweat multiplier still multiplying.
  Its `is_visibly_sweaty()` asks `dirt_wears_sweat()`.
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
  alone, with no legs or shoes, and keeps what it draws over the body (the uniform, the underclothes, the mess
  containers and the chest's glows and blockers) to the body, through a render target of its own
  (`body_render_target()`). The clip is an alpha mask, so what it keeps takes the body's alpha: on a translucent body
  the chest's glows come out dimmer through a wall relay than on the person, and its blockers block less. Images with
  no sprite of their own, the mess containers among them, are always copied (`append_appearance_copies()`) and never
  taken for an organ's (`compare_organ_icon()`). It leaves out a skirt or dress (`wall_relay_skips_uniform()`, by its
  bulge family), so the body shows under it. A wall-stuck body draws no bulge (`portal_hides_bulge()`). A gloryhole's
  occupant draws their penis only through its relay (`portal_relays_penis()`), which `dirt_body_parts()` asks.
- `code/modules/unit_tests/~nova/dirt_mess_drawing.dm`, `dirt_drawing.dm`, `dirt_taur_blood.dm`, `dirt_sources.dm`,
  `dirt_manifest.dm`, `dirt_corpus.json` and `dirt_manifest.txt`: the tests, the parity corpus and its manifest.
- `code/modules/unit_tests/_unit_tests.dm`
- `tgstation.dme`
