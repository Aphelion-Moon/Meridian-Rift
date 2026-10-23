// Dirt overlays: masks generated at runtime and drawn over skin, clothes and parts. See modular_aphelion/modules/dirt.

// A mask pixel's tone role. Each role is one greyscale mask, tinted with its material's colour and alpha.
#define DIRT_ROLE_NONE 0
/// The palest edge, drawn as half coverage in the film mask.
#define DIRT_ROLE_HAZE 1
#define DIRT_ROLE_FILM 2
#define DIRT_ROLE_BODY 3
/// The thickest part: the contact point, or a wet coat's underside.
#define DIRT_ROLE_CORE 4
#define DIRT_ROLE_FLECK 5
/// A wet coat's highlight.
#define DIRT_ROLE_GLINT 6

// The limbs a body's surface maps each pixel to. An arm runs on into its hand.
#define DIRT_LIMB_HEAD 1
#define DIRT_LIMB_TORSO 2
#define DIRT_LIMB_R_ARM 3
#define DIRT_LIMB_L_ARM 4
#define DIRT_LIMB_R_LEG 5
#define DIRT_LIMB_L_LEG 6

/// The first row, counted down from the top, whose torso pixels count as the legs'. Dirt climbs the legs to the hips.
#define DIRT_BELT 21
/// How many pixels round a body its surface reaches, so dirt may run past the silhouette onto clothing.
#define DIRT_SURFACE_MARGIN 3

// Why nothing may be drawn on a face's pixel.
#define DIRT_GUARD_EYE 1
#define DIRT_GUARD_MOUTH 2

// Thicknesses run from 0 to 1, and only a feature's contact zone may pass DIRT_CONTACT.
#define DIRT_CONTACT 0.86
#define DIRT_BODY_T (DIRT_CONTACT - 0.06)
#define DIRT_FILM_T 0.36
/// A marker, not a thickness: exactly this value draws as haze.
#define DIRT_HAZE_T 0.3
// The least thickness that draws each role.
#define DIRT_THRESHOLD_CORE (DIRT_CONTACT + 0.04)
#define DIRT_THRESHOLD_BODY 0.5
#define DIRT_THRESHOLD_FILM 0.22

// Where a shot can be aimed.
#define DIRT_ZONE_FACE "face"
#define DIRT_ZONE_CHEST "chest"
#define DIRT_ZONE_STOMACH "stomach"
#define DIRT_ZONE_BACK "back"
#define DIRT_ZONE_GROIN "groin"
#define DIRT_ZONE_THIGHS "thighs"
#define DIRT_ZONE_BUTT "butt"
/// The penis, through a glory hole.
#define DIRT_ZONE_COCK "cock"

// What a mask lies on. Cloth draws its outline a role lighter.
#define DIRT_SURFACE_SKIN "skin"
#define DIRT_SURFACE_CLOTH "cloth"

/// The layer skin's semen draws at: above the underclothes, below the uniform and genitals drawn above underwear.
#define DIRT_SKIN_LAYER (UNDER_UNIFORM_LAYER - 0.02)

/// Variants of each zone's semen.
#define DIRT_SEMEN_VARIANTS 8
/// The level a splat stops growing at, the one that covers its zone; what a climax adds past it starts another splat.
#define DIRT_SEMEN_MAX_LEVEL 4
/// The least load, in units of fluid, that adds two levels rather than one.
#define DIRT_SEMEN_LOAD_HEAVY 20
/// The least load that goes straight to DIRT_SEMEN_MAX_LEVEL.
#define DIRT_SEMEN_LOAD_HUGE 45
/// The most splats a person carries across their skin, parts and worn items. The oldest goes first.
#define DIRT_SEMEN_MAX_SPLATS 50

// What a portal shows of the person on its far side.
#define DIRT_PORTAL_NONE 0
#define DIRT_PORTAL_LOWER_BODY 1
#define DIRT_PORTAL_PENIS 2

/// Whether a mask that isn't made yet waits for SSdirt, drawn without it until it's done, rather than being made as it's
/// drawn. Comment it out to make every mask as it's drawn.
#define DIRT_MASKS_DEFERRED

// What a mask request is drawn on.
#define DIRT_MASKS_BODY "body"
#define DIRT_MASKS_PART "part"
#define DIRT_MASKS_TAUR "taur"

// What a finished mask job draws again on each body that drew without it while it waited.
#define DIRT_REDRAW_BODY (1<<0)
#define DIRT_REDRAW_UNIFORM (1<<1)
#define DIRT_REDRAW_SUIT (1<<2)
#define DIRT_REDRAW_HEAD (1<<3)
#define DIRT_REDRAW_MASK (1<<4)

/// Pixels of skin a view keeps between two runs or drops, and between splats: side by side they filled into a sheet.
#define DIRT_RUN_GAP 1
/// The run group of level 2's carry-on from a deposit's first drop.
#define DIRT_RUN_GROUP_EARLY "early"

// Where an exposed part draws against the surface over it.
#define DIRT_PART_HIDDEN 0
#define DIRT_PART_UNDER 1
#define DIRT_PART_OVER 2

/// `value` modulo `divisor` with the divisor's sign, as the reference generator takes it, where BYOND's % and %% keep the
/// value's. Exact for whole numbers from -(2^24 - divisor) up to 2^24. It reads `value` twice, so pass it a variable,
/// never a call such as draw().
#define DIRT_MODULO(value, divisor) ((value) - (divisor) * floor((value) / (divisor)))

/// An angle in `degrees` turned into the range -180 up to 180, never 180, as the reference generator wraps one. Exact from
/// -540 up to 540, which a difference of two thetas never leaves. It reads `degrees` up to five times, so pass it a
/// variable.
#define DIRT_WRAP_DEGREES(degrees) ((degrees) >= 180 ? (degrees) - 360 : ((degrees) < -180 ? (degrees) + 360 : (degrees)))
