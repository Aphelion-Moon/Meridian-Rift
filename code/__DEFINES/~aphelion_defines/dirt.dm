// Dirt overlays: masks generated at runtime and drawn over skin, clothes and parts. See modular_aphelion/modules/dirt.

// A mask pixel's tone role. Each role is one greyscale mask, tinted with its material's colour and alpha.
/// No role: a bare pixel.
#define DIRT_ROLE_NONE 0
/// The palest edge, drawn as half coverage in the film mask.
#define DIRT_ROLE_HAZE 1
/// A thin coat, from DIRT_THRESHOLD_FILM up: a mark's fringe and edges.
#define DIRT_ROLE_FILM 2
/// A solid coat, from DIRT_THRESHOLD_BODY up: most of a mark.
#define DIRT_ROLE_BODY 3
/// The thickest part: the contact point, or a wet coat's underside.
#define DIRT_ROLE_CORE 4
/// A speck highlight: dirt_cleanup() and dirt_despeckle() leave it as it is.
#define DIRT_ROLE_FLECK 5
/// A wet coat's highlight.
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

// A template pixel's limb has 4 bits of its flags (DIRT_PIXEL_LIMB()). DIRT_LIMB_L_LEG is the last limb.
#if DIRT_LIMB_L_LEG > 15
#error The last DIRT_LIMB_* define is over 15: a template pixel holds its limb in 4 bits of its flags.
#endif

// A template pixel's flags (/datum/dirt_surface/var/flags_of): its limb, its zone and three marks, in one number.
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
/// A fringe's or thin edge's thickness, drawn as film; also the most a covering mark lies on the outline.
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

/// The layer skin's mess draws at: under the underclothes (UNDER_UNIFORM_LAYER and UNDER_UNIFORM_SOCKS_LAYER) and the
/// genitals, over body hair (BODY_HAIR_LAYER), markings and the limbs.
#define DIRT_SKIN_LAYER (BODY_LAYER + 0.25)
/// The layer mess on the underclothes draws at: over them, under the uniform and genitals drawn above underwear.
#define DIRT_UNDERCLOTHES_LAYER (UNDER_UNIFORM_LAYER - 0.02)
/// Starts each key mess adds to a limb's render key: a limb drawn under a key carrying it keeps its images on its own
/// mob (/mob/living/carbon/proc/limb_icons_for()), not in tg's shared limb icon cache.
#define DIRT_PRIVATE_KEY "dirt-private|"
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

// The underclothes a body can wear, each its own surface for mess.
/// The underwear slot: the groin, butt and the thighs it reaches; a one-piece swimsuit the chest too.
#define DIRT_UNDERCLOTHES_UNDERWEAR "underwear"
/// The bra slot: the chest.
#define DIRT_UNDERCLOTHES_BRA "bra"
/// The undershirt slot: the chest, stomach and back; a corset or leotard the groin and butt too.
#define DIRT_UNDERCLOTHES_UNDERSHIRT "undershirt"
/// The socks slot: the thighs, groin and butt where they reach (stockings, tights). Taurs and bodies with fewer than
/// two legs wear none.
#define DIRT_UNDERCLOTHES_SOCKS "socks"

/// Variants of each zone's mess.
#define DIRT_MESS_VARIANTS 8
/// The level a splat stops growing at, the one that covers its zone; what a shot adds past it starts another splat.
#define DIRT_MESS_MAX_LEVEL 4
/// The least amount, in units of fluid, that adds two levels rather than one.
#define DIRT_MESS_AMOUNT_HEAVY 20
/// The least amount that goes straight to DIRT_MESS_MAX_LEVEL.
#define DIRT_MESS_AMOUNT_HUGE 45
/// The most splats a person carries across their skin, parts and worn items. The oldest goes first.
#define DIRT_MESS_MAX_SPLATS 32

// What a portal shows of the person on its far side.
/// No portal: the whole person.
#define DIRT_PORTAL_NONE 0
/// A wall portal: the groin and the butt (dirt_portal_shows()), and only on what its relay draws.
#define DIRT_PORTAL_LOWER_BODY 1
/// A portal relaying one part alone: only that part's zone is offered, while the part draws its front image.
#define DIRT_PORTAL_PENIS 2

/// Whether a mask that isn't made yet waits for SSdirt, drawn without it until it's done, rather than being made as
/// it's drawn. Comment it out to make every mask as it's drawn.
#define DIRT_MASKS_DEFERRED

// What a mask request is drawn on.
/// A body, from its limbs' template: its skin, its underclothes or a worn item.
#define DIRT_MASKS_BODY "body"
/// A part's own share (DIRT_PART_*), read from the part's sprites.
#define DIRT_MASKS_PART "part"
/// A taur body's back, or a taur suit's over it, on the DIRT_TAUR_WIDTH canvas.
#define DIRT_MASKS_TAUR "taur"

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
/// Not masks: what the body wears changed, so its skin's mess may fade at other edges.
#define DIRT_REDRAW_COVER (1<<5)
/// Not masks: what draws the body's parts may have changed, so the masks they shape may be made again.
#define DIRT_REDRAW_PARTS (1<<6)
/// A part's own share: the whole body, whose redraw a portal relay showing the part follows.
#define DIRT_REDRAW_SHARE (1<<7)

/// How many pixels skin mess fades out over before what's worn over it, rather than cut off at its edge.
#define DIRT_FADE_RINGS 2

/// Pixels of skin a view keeps between two runs or drops, and between splats: side by side they filled into a sheet.
#define DIRT_RUN_GAP 1
/// The run group of level 2's carry-on from a deposit's first drop.
#define DIRT_RUN_GROUP_EARLY "early"

// The parts that take a share of the mess aimed at them, by what they're drawn as.
/// The breasts organ drawn as breasts, sharing the chest's mess.
#define DIRT_PART_BREASTS "breasts"
/// The breasts organ drawn as pecs, or the plain pecs' shape a human chest without breasts takes mess in.
#define DIRT_PART_PECS "pecs"
/// The penis, sharing the groin's mess as a bead behind its tip rather than in lobes.
#define DIRT_PART_PENIS "penis"
/// The testicles, sharing the groin's mess.
#define DIRT_PART_TESTICLES "testicles"
/// The vulva, sharing the groin's mess; on skin it also takes the ring of visible pixels round it.
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

/// `value` modulo `divisor` with the divisor's sign, as the reference generator takes it, where BYOND's % and %% keep
/// the value's. Exact for whole numbers from -(2^24 - divisor) up to 2^24. It reads `value` twice, so pass it a
/// variable, never a call such as draw().
#define DIRT_MODULO(value, divisor) ((value) - (divisor) * floor((value) / (divisor)))

/// An angle in `degrees` turned into the range -180 up to 180, never 180, as the reference generator wraps one. Exact
/// from -540 up to 540, which a difference of two thetas never leaves. It reads `degrees` up to five times, so pass it
/// a variable.
#define DIRT_WRAP_DEGREES(degrees) ((degrees) >= 180 ? (degrees) - 360 : ((degrees) < -180 ? (degrees) + 360 : (degrees)))
