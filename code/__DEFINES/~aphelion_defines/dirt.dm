// Dirt overlays: masks generated at runtime and drawn over skin, clothes and parts. See modular_aphelion/modules/dirt.

// A mask pixel's tone role. Each role draws in its material's tint for that role (dirt_baked_frames()).
/// No role: a bare pixel.
#define DIRT_ROLE_NONE 0
/// The palest edge, drawn as film at half coverage.
#define DIRT_ROLE_HAZE 1
/// A thin coat, from DIRT_THRESHOLD_FILM up: a mark's fringe and edges.
#define DIRT_ROLE_FILM 2
/// A solid coat, from DIRT_THRESHOLD_BODY up: most of a mark.
#define DIRT_ROLE_BODY 3
/// The thickest part: the contact point, or a wet coat's underside.
#define DIRT_ROLE_CORE 4
/// A fleck: dirt_cleanup() and dirt_despeckle() leave it as it is.
#define DIRT_ROLE_FLECK 5
/// A glint: a bead's, a pool's or a wet coat's.
#define DIRT_ROLE_GLINT 6

// The limbs a body's surface maps each pixel to. An arm runs on into its hand.
/// The head, the only limb the face's guards apply on.
#define DIRT_LIMB_HEAD 1
/// The torso, down to DIRT_BELT: its rows from there down count as the legs'.
#define DIRT_LIMB_TORSO 2
/// The right arm.
#define DIRT_LIMB_R_ARM 3
/// The left arm.
#define DIRT_LIMB_L_ARM 4
/// The right leg, and its side of the torso from DIRT_BELT down.
#define DIRT_LIMB_R_LEG 5
/// The left leg, and its side of the torso from DIRT_BELT down.
#define DIRT_LIMB_L_LEG 6

/// A limb's bit in a field of limbs, such as the limbs a general deposit covers (/datum/dirt_splat/var/limbs).
#define DIRT_LIMB_BIT(limb) (1 << ((limb) - 1))
/// Every limb's bit, DIRT_LIMB_HEAD to DIRT_LIMB_L_LEG.
#define DIRT_LIMBS_ALL 63
/// The limbs skin mess draws on: the head, the torso and the legs, where aimed mess lands.
#define DIRT_MESS_SKIN_LIMBS (DIRT_LIMB_BIT(DIRT_LIMB_HEAD) | DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG))

// A template pixel's limb has 4 bits of its flags (DIRT_PIXEL_LIMB()). DIRT_LIMB_L_LEG is the last limb.
#if DIRT_LIMB_L_LEG > 15
#error The last DIRT_LIMB_* define is over 15: a template pixel holds its limb in 4 bits of its flags.
#endif

// A template pixel's flags (/datum/dirt_surface/var/flags_of): its limb, its zone and three flags, in one number.
/// A pixel's limb, a DIRT_LIMB_* define, or 0 off the surface: bits 0 to 3.
#define DIRT_PIXEL_LIMB(flags) ((flags) & 15)
/// A pixel's zone, its place in dirt_pixel_zones(), or 0 off the body (the margin, and off the surface): bits 4 to 7.
#define DIRT_PIXEL_ZONE(flags) (((flags) >> 4) & 15)
/// The rim, bit 8: the silhouette's edge and the margin's first ring, where clothing draws its outline. Each leg's sole
/// stays off it: it's in contact with the floor.
#define DIRT_PIXEL_RIM (1<<8)
/// The outline, bit 9, once /datum/dirt_surface/proc/outline() has marked it: the body pixels a covering coat fades at.
#define DIRT_PIXEL_OUTLINE (1<<9)
/// The outline and the pixels beside it, bit 10, once /datum/dirt_surface/proc/outline_band() has marked them: where a
/// covering coat breaks in profile.
#define DIRT_PIXEL_BAND (1<<10)

// A raster packed as text (/datum/dirt_pixels/proc/drawn()): "1" if it covers, else "0", then its drawn pixels one run
// at a time in row-major order. Each run is four base-64 digits ("0" to "o") holding 24 bits.
/// How many characters a packed run takes.
#define DIRT_PACKED_CHARS 4
/// How many runs a packed raster holds.
#define DIRT_PACKED_COUNT(drawn) ((length(drawn) - 1) / DIRT_PACKED_CHARS)
/// The 24 bits of a packed raster's run, counted from 1, which the fields below read.
#define DIRT_PACKED_BITS(drawn, run) ((text2ascii(drawn, (run) * DIRT_PACKED_CHARS - 2) - 48) * 262144 + (text2ascii(drawn, (run) * DIRT_PACKED_CHARS - 1) - 48) * 4096 + (text2ascii(drawn, (run) * DIRT_PACKED_CHARS) - 48) * 64 + text2ascii(drawn, (run) * DIRT_PACKED_CHARS + 1) - 48)
/// A run's bits: its first pixel's index - 1 (11 bits), its length - 1 (6), its DIRT_ROLE_* define (3) and its
/// thickness's code (4, dirt_thickness_code()).
#define DIRT_PACKED_RUN(first, run_length, role, code) (((first) - 1) * 8192 + ((run_length) - 1) * 128 + (role) * 16 + (code))
/// A run's first pixel, from its bits.
#define DIRT_PACKED_FIRST(bits) (floor((bits) / 8192) + 1)
/// A run's last pixel.
#define DIRT_PACKED_LAST(bits) (floor((bits) / 8192) + floor((bits) / 128) % 64 + 1)
/// A run's DIRT_ROLE_* define.
#define DIRT_PACKED_ROLE(bits) (floor((bits) / 16) % 8)
/// A run's thickness code: its thickness is dirt_packed_thicknesses()[code + 1].
#define DIRT_PACKED_CODE(bits) ((bits) % 16)

/// The first row, counted down from the top, whose torso pixels count as the legs'. Dirt climbs the legs to the hips.
#define DIRT_BELT 21
/// How many pixels round a body its surface reaches, so dirt may run past the silhouette onto clothing.
#define DIRT_SURFACE_MARGIN 3

// Why nothing may be drawn on a face's pixel.
/// An eye or a pixel beside it. The eye's diagonals take film at most instead (eye_soft).
#define DIRT_GUARD_EYE 1
/// A human head's mouth, whose pixels are the head sprite's.
#define DIRT_GUARD_MOUTH 2

// Thicknesses run from 0 to 1, and only a feature's contact zone may pass DIRT_CONTACT.
/// The most any mark lies but a contact point or a wet coat's underside, which lie just past it to draw core.
#define DIRT_CONTACT 0.86
/// A solid coat's thickness, drawn as body.
#define DIRT_BODY_T (DIRT_CONTACT - 0.06)
/// A fringe's or thin edge's thickness, drawn as film. It's also the most a covering mark lies on the outline.
#define DIRT_FILM_T 0.36
/// A marker, not a thickness: exactly this value draws as haze.
#define DIRT_HAZE_T 0.3
// The least thickness that draws each role.
/// Core: only a contact point or a wet coat's underside reaches it.
#define DIRT_THRESHOLD_CORE (DIRT_CONTACT + 0.04)
/// Body: a solid coat (DIRT_BODY_T) passes it.
#define DIRT_THRESHOLD_BODY 0.5
/// Film, and the least that draws at all: anything thinner is dropped.
#define DIRT_THRESHOLD_FILM 0.22
/// A thickness's role: haze for exactly DIRT_HAZE_T, else core or body past their thresholds, and film below.
/// It reads the thickness three times, so pass it a var.
#define DIRT_THICKNESS_ROLE(thickness) ((thickness) == DIRT_HAZE_T ? DIRT_ROLE_HAZE : ((thickness) >= DIRT_THRESHOLD_CORE ? DIRT_ROLE_CORE : ((thickness) >= DIRT_THRESHOLD_BODY ? DIRT_ROLE_BODY : DIRT_ROLE_FILM)))

// Where a shot can be aimed.
/// The lower face, under the eyes. Whatever covers the mouth takes the shot.
#define DIRT_ZONE_FACE "face"
/// The torso's upper front.
#define DIRT_ZONE_CHEST "chest"
/// The belly: the torso's front between the groin and the chest.
#define DIRT_ZONE_STOMACH "stomach"
/// The back, under the shoulder blades. On a taur, the taur body's back takes a share too.
#define DIRT_ZONE_BACK "back"
/// The front at the waistband: the torso's lowest part and the tops of the legs.
#define DIRT_ZONE_GROIN "groin"
/// The front of the thighs, from the knee up.
#define DIRT_ZONE_THIGHS "thighs"
/// The cheeks either side of the cleft, and the backs of the upper legs.
#define DIRT_ZONE_BUTT "butt"
/// The penis, through a one-part portal.
#define DIRT_ZONE_COCK "cock"

// What a mask lies on. Cloth draws its outline a role lighter.
/// Bare skin: bare legs streak, lone pixels go, and each limb's mask is clipped to that limb's pixels.
#define DIRT_SURFACE_SKIN "skin"
/// A worn item or underclothes: one mask over the whole canvas, clipped to what the garment shows.
#define DIRT_SURFACE_CLOTH "cloth"
/// A drawn part's own coat or feathers on a canvas (dirt_canvas_rasterise()): a taur body, a tail, wings, ears, horns.
#define DIRT_SURFACE_FUR "fur"
/// Hair on a canvas: film unless a whole-body coat covers it, never core, its crown first.
#define DIRT_SURFACE_HAIR "hair"

// The canvases dirt is drawn on beside the body's (dirt_canvases()), by size: how each sits over the mob's tile.
/// A tile-sized sprite: tails, ears, horns, hair.
#define DIRT_CANVAS_TILE "32x32"
/// A sprite reaching up past the tile.
#define DIRT_CANVAS_TALL "32x48"
/// The wings' sheet, centred on the tile.
#define DIRT_CANVAS_WINGS "45x34"
/// A taur body's, centred on the tile (DIRT_TAUR_WIDTH).
#define DIRT_CANVAS_TAUR "64x32"

// The kinds of drawn shape dirt lands on by their own rules (dirt_shape_deposit()). Slime lies in their own pixels.
/// A taur body.
#define DIRT_SHAPE_TAUR "taur"
/// Wings.
#define DIRT_SHAPE_WINGS "wings"
/// A tail.
#define DIRT_SHAPE_TAIL "tail"
/// Any other drawn part (ears, horns, a snout...), which takes only the field causes (dirt_shape_rasterise()).
#define DIRT_SHAPE_PART "part"
/// The hairstyle, which takes the causes that reach the hair (dirt_hair_levels()) as hair (dirt_shape_rasterise()).
#define DIRT_SHAPE_HAIR "hair"

/// The layer skin's dirt draws at: under the underclothes (UNDER_UNIFORM_LAYER and UNDER_UNIFORM_SOCKS_LAYER) and the
/// genitals, over body hair (BODY_HAIR_LAYER), markings and the limbs.
#define DIRT_SKIN_LAYER (BODY_LAYER + 0.25)
/// The layer dirt on the underclothes draws at: over them, under the uniform and genitals drawn above underwear.
#define DIRT_UNDERCLOTHES_LAYER (UNDER_UNIFORM_LAYER - 0.02)
/// The layer skin dirt on a hand draws at: over the hand (BODYPARTS_HIGH_LAYER), which draws over the uniform, and
/// under gloves.
#define DIRT_HAND_SKIN_LAYER (BODYPARTS_HIGH_LAYER - 0.05)
/// The postfix of the second layer of an arm's skin dirt overlay. That layer draws the hand's dirt (skin.dm). The
/// setup_lists() override adds it to SSaccessories.all_layer_postfixes, which holds every bodypart_overlay layer
/// postfix. No accessory icon has a state ending in it, so it adds no matrixed colour channel.
#define DIRT_HAND_LAYER_POSTFIX "hand"
/// Starts each key dirt adds to a limb's render key: a limb drawn under a key carrying it keeps its images on its own
/// mob (/mob/living/carbon/proc/limb_icons_for()), not in tg's shared limb icon cache.
#define DIRT_PRIVATE_KEY "dirt-private|"
/// The entry a taur body adds to its render key while the blood below its waist draws over the taur body's own dirt
/// (/datum/component/dirtiness/proc/waist_blood_over()). The chest's last render key holds it while that side is drawn.
#define DIRT_TAUR_BLOOD_OVER_KEY (DIRT_PRIVATE_KEY + "blood-over")
/// The images update_body_parts() draws a limb with under the key it was last drawn with. A body holding no private
/// images reads tg's limb_icon_cache as tg does, and calls limb_icons_for() only for a key the cache lacks: a private
/// one whose entry left with a swapped limb. It reads `key` more than once, so pass it a variable. For a
/// /mob/living/carbon proc only.
#define DIRT_LIMB_ICONS_STEADY(limb, key) (private_limb_icons ? limb_icons_for(limb, key, FALSE) \
	: (limb_icon_cache[key] || limb_icons_for(limb, key, FALSE)))
/// The images update_body_parts() draws a limb with under a new key. A body holding no private images, drawn under a
/// key without DIRT_PRIVATE_KEY, fills tg's limb_icon_cache as tg does. It reads `key` more than once, so pass it a
/// variable. For a /mob/living/carbon proc only.
#define DIRT_LIMB_ICONS_CHANGED(limb, key) ((private_limb_icons || findtextEx(key, DIRT_PRIVATE_KEY)) \
	? limb_icons_for(limb, key, TRUE) : (limb_icon_cache[key] ||= limb.get_limb_icon(FALSE)))

// The underclothes a body can wear, each its own surface for dirt.
/// The underwear slot: the groin, butt and the thighs it reaches, and the chest too for a one-piece swimsuit.
#define DIRT_UNDERCLOTHES_UNDERWEAR "underwear"
/// The bra slot: the chest.
#define DIRT_UNDERCLOTHES_BRA "bra"
/// The undershirt slot: the chest, stomach and back, and the groin and butt too for a corset or leotard.
#define DIRT_UNDERCLOTHES_UNDERSHIRT "undershirt"
/// The socks slot: the thighs, groin and butt where they reach (stockings, tights). Taurs and bodies with fewer than
/// two legs wear none.
#define DIRT_UNDERCLOTHES_SOCKS "socks"

/// How many variants each deposit has: a zone's mess or a cause's dirt.
#define DIRT_VARIANTS 8
/// The level a splat stops growing at, the one that covers its zone. What a shot adds past it starts another splat.
#define DIRT_MESS_MAX_LEVEL 4
/// The least amount, in units of fluid, that adds two levels rather than one.
#define DIRT_MESS_AMOUNT_HEAVY 20
/// The least amount that goes straight to DIRT_MESS_MAX_LEVEL.
#define DIRT_MESS_AMOUNT_HUGE 45
/// The most splats a person carries across their skin, underclothes, parts, drawn parts, hair and worn items. Mess and
/// other dirt count together. Past it, the splat that landed or was raised longest ago goes first.
#define DIRT_MAX_SPLATS 32
/// The most general deposits one carrier holds. Past it, the one that landed or was raised longest ago goes.
#define DIRT_CARRIER_DEPOSITS 3
/// The skin as a carrier of general dirt (dirt_shown_carriers()), beside worn items and underclothes keys.
#define DIRT_CARRIER_SKIN "skin"
/// The hairstyle as a carrier of general dirt, held with the person's drawn parts
/// (/datum/component/dirtiness/var/part_splats). No organ slot has this name.
#define DIRT_CARRIER_HAIR "hair"
/// The layer of the hair's pieces drawn over hats (hair_appendages_outer), beside DIRT_CARRIER_HAIR's, as dirt reads it.
#define DIRT_HAIR_OUTER "hair_outer"
/// A body is bare, and its skin takes the painted designs, when more than this share of its chest shows skin
/// (dirt_bare_bodied()).
#define DIRT_BARE_SHARE 0.6

// What dirt is made of (/datum/dirt_material), by the reference generator's ids.
#define DIRT_MATERIAL_MUD "mud"
#define DIRT_MATERIAL_DRIED_MUD "dried_mud"
#define DIRT_MATERIAL_RED_CLAY "red_clay"
#define DIRT_MATERIAL_DUST "dust"
#define DIRT_MATERIAL_PLASTER "plaster"
#define DIRT_MATERIAL_ASH "ash"
#define DIRT_MATERIAL_GRIME "grime"
#define DIRT_MATERIAL_OIL "oil"
#define DIRT_MATERIAL_GREASE "grease"
#define DIRT_MATERIAL_SOOT "soot"
/// Wet cloth, darkened in its own colour. It lands on cloth only.
#define DIRT_MATERIAL_SWEAT "sweat"
/// Slime in any colour: a splat stores it as "slime#RRGGBB" (dirt_material()).
#define DIRT_MATERIAL_SLIME "slime"
/// What a shot leaves, aimed at a zone (dirt_mess_land()).
#define DIRT_MATERIAL_MESS "mess"
/// How many slime colours' materials SSdirt keeps, the newest made.
#define DIRT_SLIME_COLOURS 64
/// Blood in any colour, run down a taur's body from its garment's stain: "blood#RRGGBB" (dirt_material()). Never a
/// splat's: it's drawn from the garment's own blood (dirt_taur_blood_inputs()).
#define DIRT_MATERIAL_BLOOD "blood"
/// How many blood colours' materials SSdirt keeps, the newest made, as slime's (DIRT_SLIME_COLOURS).
#define DIRT_BLOOD_COLOURS 32

// What a material draws along a coat's edge (/datum/dirt_material/var/edge).
/// Nothing.
#define DIRT_EDGE_NONE 0
/// A ring of film round thick patches: oil's wicked halo, wet mud's damp edge.
#define DIRT_EDGE_HALO 1
/// A darker tide along the top edge, broken.
#define DIRT_EDGE_TIDE 2

// How a material draws (/datum/dirt_material/var/flags). Every flag changes pixels.
/// One wet fleck per view on a leg (dirt_sheen()), and one glint on the hair (dirt_hair_dirt()).
#define DIRT_MATERIAL_SHEEN (1<<0)
/// Light flecks scattered in the coat.
#define DIRT_MATERIAL_SPECKS (1<<1)
/// A pale material that lifts dark cloth. Its coats thin out up the legs, so they don't read as other trousers.
#define DIRT_MATERIAL_LIGHT (1<<2)
/// A glossy material (oil, grease, slime). A covering coat keeps few windows and catches the light in more places.
#define DIRT_MATERIAL_GLOSSY (1<<3)
/// Goo, which keeps its core on skin, where anything else softens to body.
#define DIRT_MATERIAL_GOO (1<<4)
/// Not a colour, but the cloth darkened under it.
#define DIRT_MATERIAL_WET (1<<5)

// What puts dirt where it lies, by the reference generator's ids. Each draws its own features (dirt_cause_features()).
#define DIRT_CAUSE_WALK "walk"
#define DIRT_CAUSE_KNEEL "kneel"
#define DIRT_CAUSE_CRAWL "crawl"
#define DIRT_CAUSE_FALL "fall"
#define DIRT_CAUSE_SPLASH "splash"
#define DIRT_CAUSE_MACHINE "machine"
#define DIRT_CAUSE_SMOKE "smoke"
#define DIRT_CAUSE_DUST "dust"
#define DIRT_CAUSE_WEAR "wear"
#define DIRT_CAUSE_SWEAT "sweat"
/// Slime from above.
#define DIRT_CAUSE_SLIMED "slimed"
#define DIRT_CAUSE_PLUNGE "plunge"
#define DIRT_CAUSE_BLAST "blast"
#define DIRT_CAUSE_DOUSE "douse"
// Slime where it touched.
#define DIRT_CAUSE_SLIMED_HEAD "slimed_head"
#define DIRT_CAUSE_SLIMED_CHEST "slimed_chest"
#define DIRT_CAUSE_SLIMED_BACK "slimed_back"
#define DIRT_CAUSE_SLIMED_R_ARM "slimed_r_arm"
#define DIRT_CAUSE_SLIMED_L_ARM "slimed_l_arm"
#define DIRT_CAUSE_SLIMED_R_LEG "slimed_r_leg"
#define DIRT_CAUSE_SLIMED_L_LEG "slimed_l_leg"
/// The start of mess's causes, "aimed_<zone>". A mess splat's cause is implied by its zone (dirt_rasterise_aimed()).
#define DIRT_CAUSE_AIMED_PREFIX "aimed_"
/// The level a general deposit's cause stops at, unless dirt_cause_max_level() gives it a harder fourth (machine work,
/// smoke).
#define DIRT_DEPOSIT_MAX_LEVEL 3

// Thetas, the angles round a limb (/datum/dirt_surface/var/theta_of), that a cause aims at.
/// The body's front.
#define DIRT_THETA_FRONT 0
/// The body's back.
#define DIRT_THETA_BACK 180

// What a stamp (/datum/dirt_feature/stamps) does to a pixel besides drawing a role on it.
/// Wipes it clean, for a dark hand's highlight.
#define DIRT_STAMP_CLEAN "clean"
/// Draws film on it over whatever is there, for a solid hand's highlight.
#define DIRT_STAMP_LIT "lit"

// What a portal shows of the person on its far side.
/// No portal: the whole person.
#define DIRT_PORTAL_NONE 0
/// A wall portal: the groin and the butt (dirt_portal_shows()), and only on what its relay draws.
#define DIRT_PORTAL_LOWER_BODY 1
/// A portal relaying one part alone: only that part's zone is offered, while the part draws its front image.
#define DIRT_PORTAL_PENIS 2

// What a mask request is drawn on.
/// A body, from its limbs' template: its skin, its underclothes or a worn item.
#define DIRT_MASKS_BODY "body"
/// A part's own share (DIRT_PART_*), read from the part's sprites.
#define DIRT_MASKS_PART "part"
/// A taur body's back, or a taur suit's over it, on the DIRT_TAUR_WIDTH canvas.
#define DIRT_MASKS_TAUR "taur"
/// A drawn part's own dirt (a tail, wings, ears, horns...), on its sprite's canvas (/datum/dirt_shape_source).
#define DIRT_MASKS_SHAPE "shape"
/// The hairstyle's dirt, on its sprite's canvas less its darkest strands (dirt_hair_dirt()).
#define DIRT_MASKS_HAIR "hair"
/// Sweat's multiplier on a garment, from its masks' wet pixels and its own worn sprite (/datum/dirt_mask_request/wet).
#define DIRT_MASKS_WET "wet"

// What a finished mask job draws again on each body that drew without it while it waited.
/// The body's own overlays: its skin, underclothes and taur body (update_body_parts()).
#define DIRT_REDRAW_BODY (1<<0)
/// The uniform slot's item (update_worn_undersuit()).
#define DIRT_REDRAW_UNIFORM (1<<1)
/// The suit slot's item (update_worn_oversuit()).
#define DIRT_REDRAW_SUIT (1<<2)
/// The head slot's item (update_worn_head()).
#define DIRT_REDRAW_HEAD (1<<3)
/// The mask slot's item (update_worn_mask()).
#define DIRT_REDRAW_MASK (1<<4)
/// Not masks: what the body wears changed, so its skin's dirt may fade at other edges.
#define DIRT_REDRAW_COVER (1<<5)
/// Not masks: what draws the body's parts may have changed, so the masks they shape may be made again.
#define DIRT_REDRAW_PARTS (1<<6)
/// A part's own share: the whole body, whose redraw a portal relay showing the part follows.
#define DIRT_REDRAW_SHARE (1<<7)
/// The shoes slot's item (update_worn_shoes()).
#define DIRT_REDRAW_SHOES (1<<8)
/// The gloves slot's item (update_worn_gloves()).
#define DIRT_REDRAW_GLOVES (1<<9)
/// The neck slot's item (update_worn_neck()).
#define DIRT_REDRAW_NECK (1<<10)
/// The belt slot's item (update_worn_belt()).
#define DIRT_REDRAW_BELT (1<<11)
/// The back slot's item (update_worn_back()).
#define DIRT_REDRAW_BACK (1<<12)
/// The glasses slot's item (update_worn_glasses()).
#define DIRT_REDRAW_GLASSES (1<<13)
/// The ears slot's item (update_worn_ears()).
#define DIRT_REDRAW_EARS (1<<14)
/// The suit storage slot's item (update_suit_storage()).
#define DIRT_REDRAW_SUIT_STORE (1<<15)

/// How many pixels skin dirt fades out over before what's worn over it, rather than cut off at its edge.
#define DIRT_FADE_RINGS 2

/// Pixels of skin a view keeps between two runs or drops, and between splats: side by side they filled into a sheet.
#define DIRT_RUN_GAP 1
/// The run group of level 2's carry-on from a deposit's first drop.
#define DIRT_RUN_GROUP_EARLY "early"
/// The run group of level 1's shot. The shots after it take the groups after it, in draw order.
#define DIRT_RUN_GROUP_SHOT 0
/// The run group of level 1's drop. The drops after it take the groups after it.
#define DIRT_RUN_GROUP_DROP 10
/// The run group of the top level's first run. Its others take the groups after it.
#define DIRT_RUN_GROUP_COVER 20

// The parts that take a share of the mess aimed at them, by what they're drawn as.
/// The breasts organ drawn as breasts, sharing the chest's mess.
#define DIRT_PART_BREASTS "breasts"
/// The breasts organ drawn as pecs, or the plain pecs' shape a human chest without breasts takes mess in.
#define DIRT_PART_PECS "pecs"
/// The penis, sharing the groin's mess as a bead behind its tip rather than in lobes.
#define DIRT_PART_PENIS "penis"
/// The testicles, sharing the groin's mess.
#define DIRT_PART_TESTICLES "testicles"
/// The vulva, sharing the groin's mess. On skin it also takes the ring of visible pixels round it.
#define DIRT_PART_VAGINA "vagina"
/// The butt, sharing the butt's mess, read from its front and back images.
#define DIRT_PART_BUTT "butt"
/// The column a pair of parts (breasts, pecs, a butt, testicles) parts along, front and back.
#define DIRT_PART_MIDLINE 15
/// The last level a part's own mess has: a splat at the top level draws its parts at this one.
#define DIRT_PART_MAX_LEVEL 3

/// Pixels across the canvas a taur body is drawn on, centred on its tile.
#define DIRT_TAUR_WIDTH 64
/// How far into the taur canvas the body's own tile starts.
#define DIRT_TAUR_INSET 16
/// The last level a taur body's pools have: a splat at the top level draws them at this one.
#define DIRT_TAUR_MAX_LEVEL 3
/// What a taur canvas pixel shows where the rider is drawn over the taur body.
#define DIRT_TAUR_RIDER "rider"
/// What a taur canvas pixel shows where a taur-fitted garment's cloth is drawn (dirt_taur_drawn_stack()).
#define DIRT_TAUR_CLOTH "cloth"

/// `value` modulo `divisor` with the divisor's sign, as the reference generator takes it. BYOND's % and %% keep the
/// value's, and tg's WRAP() adds a clamp and a test it doesn't need. Exact for whole numbers from -(2^24 - divisor)
/// up to 2^24. It reads `value` twice, so pass it a variable, never a call such as draw().
#define DIRT_MODULO(value, divisor) ((value) - (divisor) * floor((value) / (divisor)))

/// An angle in `degrees` turned into the range -180 up to 180, never 180, as the reference generator wraps one. Exact
/// from -540 up to 540. A difference of two thetas stays in that range, except against a painted design's point
/// copied round the body (dirt_painted_around()), which can reach about -546. That one still wraps past any reach it's
/// compared with, so it changes no pixel. It reads `degrees` up to three times, so pass it a variable.
#define DIRT_WRAP_DEGREES(degrees) ((degrees) >= 180 ? (degrees) - 360 : ((degrees) < -180 ? (degrees) + 360 : (degrees)))

/// The row, from 0 at the top, of a pixel index (from 1, row by row) on a view `width` pixels wide.
#define DIRT_INDEX_ROW(index, width) floor(((index) - 1) / (width))
/// The column, from 0 at the left, of a pixel index (from 1, row by row) on a view `width` pixels wide, from its row.
#define DIRT_INDEX_COLUMN(index, row, width) ((index) - 1 - (row) * (width))
/// Whether a text starts with a prefix. It reads the prefix twice, so pass it a define or a var.
#define DIRT_HAS_PREFIX(checked, prefix) (copytext(checked, 1, length(prefix) + 1) == (prefix))

// What a taur's blood below the waist is read from (dirt_taur_blood_inputs()), by index. The list stays a list.
/// Its stains, each a list indexed by DIRT_STAIN_*, the suit's first.
#define DIRT_BLOOD_INPUT_STAINS 1
/// The taur-fitted garment's sprite, list(icon, icon state), or null.
#define DIRT_BLOOD_INPUT_CLOTH 2
/// Whether the taur body draws.
#define DIRT_BLOOD_INPUT_BODY_DRAWS 3
/// The taur-fitted garment's slot, or null.
#define DIRT_BLOOD_INPUT_CLOTH_SLOT 4
/// The slot of the outermost bloodied garment.
#define DIRT_BLOOD_INPUT_OUTER_SLOT 5
// One stain of that blood, by index.
/// Its blood overlay's icon state.
#define DIRT_STAIN_STATE 1
/// Its material's key (dirt_blood_material_key()).
#define DIRT_STAIN_MATERIAL 2
/// Its variant (dirt_blood_variant()).
#define DIRT_STAIN_VARIANT 3
/// The icon of the suit drawn over a uniform's stain, or null.
#define DIRT_STAIN_COVER_ICON 4
/// That suit's icon state, or null.
#define DIRT_STAIN_COVER_STATE 5
/// That suit's shift off the tile (dirt_worn_shift()), or null where it has none.
#define DIRT_STAIN_COVER_SHIFT 6
// What a request's blood masks are made from (dirt_taur_blood_data(), /datum/dirt_mask_request/var/blood), by index.
/// The stains, as DIRT_BLOOD_INPUT_STAINS.
#define DIRT_BLOOD_DATA_STAINS 1
/// The taur-fitted garment's sprite, as DIRT_BLOOD_INPUT_CLOTH.
#define DIRT_BLOOD_DATA_CLOTH 2
/// Whether the taur body draws.
#define DIRT_BLOOD_DATA_BODY_DRAWS 3
/// The seam row (dirt_blood_seam_row()).
#define DIRT_BLOOD_DATA_SEAM_ROW 4
/// The rows the rider and the garment show at the rider's height (dirt_height_rows()), or null.
#define DIRT_BLOOD_DATA_ROWS 5
// What the taur canvas holds for blood in one direction (dirt_blood_carriers()), by index.
/// What each pixel shows (dirt_taur_owners()).
#define DIRT_BLOOD_CANVAS_OWNERS 1
/// The carriers' pixels: the taur body's while it draws, and the taur-fitted garment's.
#define DIRT_BLOOD_CANVAS_CARRIERS 2
/// Those of them that show.
#define DIRT_BLOOD_CANVAS_SHOWN 3
/// The rider's pixels that show off them.
#define DIRT_BLOOD_CANVAS_RIDER 4
/// The rider's hands, drawn over a uniform, in the rider's own rows.
#define DIRT_BLOOD_CANVAS_HANDS 5
// A garment as sweat's multiplier reads it (dirt_wet_look()), by index.
/// Its icon.
#define DIRT_WET_GARMENT_SHEET 1
/// Its icon state.
#define DIRT_WET_GARMENT_STATE 2
/// Its colour, "#RRGGBB", or anything else for none.
#define DIRT_WET_GARMENT_COLOUR 3
/// Its greyscale colours.
#define DIRT_WET_GARMENT_GREYSCALE 4
/// How far its sprite lies right of the body's canvas.
#define DIRT_WET_GARMENT_SHIFT_X 5
/// How far its sprite lies up from the body's canvas.
#define DIRT_WET_GARMENT_SHIFT_Y 6
/// The sprites drawn over it that stay dry (dirt_accessory_sprites()), where there are any.
#define DIRT_WET_GARMENT_KEPT_DRY 7

/// Whether game events land general dirt (sources.dm). Comment it out to turn every source off.
#define DIRT_SOURCES
/// The most landings that wait for SSdirt at once (/datum/dirt_job/landing).
#define DIRT_LANDINGS_WAITING 256

/// Admin-only VV action using the Clear Dirt admin verb.
#define VV_HK_DIRT_CLEAR "dirtclear"
