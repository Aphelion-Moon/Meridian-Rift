// Muscle size and definition: how built a body is drawn. See modular_aphelion/modules/fitness.
/// Whether character setup offers muscle size and definition. While it doesn't, every character is drawn Normal with no
/// definition.
#define MUSCLE_OPTIONS_OFFERED FALSE
/// Today's limbs.
#define MUSCLE_SIZE_NORMAL 0
#define MUSCLE_SIZE_ATHLETIC 1
#define MUSCLE_SIZE_MUSCULAR 2
/// The most defined step, Shredded. 0 is no definition, 1 Toned and 2 Defined.
#define MUSCLE_DEFINITION_MAX 3

/// dna.features entries holding a body's muscle size and definition.
#define FEATURE_MUSCLE_SIZE "muscle_size"
#define FEATURE_MUSCLE_DEFINITION "muscle_definition"

/// The type in `limb_type`'s fitness family drawn at a muscle `size` and `definition`, or null when `limb_type` has no fitness
/// subtypes. See GLOB.fitness_limb_families.
#define FITNESS_LIMB_TYPE(limb_type, size, definition) (GLOB.fitness_limb_families[limb_type]?[(size) ? (size) + 2 : 1 + !!(definition)])

// How an underclothes style is redrawn over fitness limbs (/datum/sprite_accessory/clothing/var/fit_mode). The values are the
// mode names of the fitting spec, which the cache keys carry.
/// Each fitted row moves the garment's edge out to the limb's new edge and fills the gap with the pixel inside it.
#define GARMENT_FIT_SOLID "solid"
/// Mesh: only the new pixels are drawn, each copied from 2 pixels further in, so the mesh keeps its rhythm.
#define GARMENT_FIT_PATTERN "pattern"
/// Plain long sleeves: solid, then the arms' muscle shading in the garment's own colours, and the moved edge a shade darker.
#define GARMENT_FIT_SHADED_SLEEVES "sleeve_c"
/// Ribbed knit sleeves: solid, then the ribs laid again along each sleeve, its inner shadow thinned and its cuff ribbed.
#define GARMENT_FIT_KNIT "knit"

// Whether a top fitted in each mode shades the lower curve of pecs drawn under it, a "smile" one shade down, in the front
// view. Every mode fits the top's outline to the pecs either way.
#define GARMENT_FIT_PEC_SMILE_SOLID TRUE
#define GARMENT_FIT_PEC_SMILE_SHADED_SLEEVES TRUE
#define GARMENT_FIT_PEC_SMILE_KNIT FALSE
#define GARMENT_FIT_PEC_SMILE_PATTERN FALSE

/// A female cut (female_sprite_flags, as wear_female_version() takes them) of the lower body alone: what a full cut leaves on a
/// female body with pecs, whose torso it doesn't shape. See female_cut_over_pecs().
#define FEMALE_UNIFORM_LOWER_ONLY (1<<4)

/// The most animation frames a garment's state may have to be fitted; one with more is drawn as it is.
#define GARMENT_FIT_MAX_FRAMES 64

/// The view a garment's fit fits as its `piece`th, of 4 per animation frame: views are numbered direction by direction (S, N,
/// E, W) and frame by frame within each, and the front views go last, so each view's sleeve test reads its frame's front view
/// as the garment draws it (garment_front_sleeves()).
#define GARMENT_FIT_PIECE_VIEW(piece, frames) ((piece) > 3 * (frames) ? (piece) - 3 * (frames) : (piece) + (frames))

/// Whether a garment's first fit to a new fit waits for SSgarment_fitting, the garment drawn as it is until it's done, rather
/// than being made as it's drawn. A dummy, drawn for snapshots such as record photos and character previews, is fitted as
/// it's drawn either way. Comment it out to make every fit as it's drawn.
#define GARMENT_FITS_DEFERRED

// What a finished garment fit draws again on each body that drew the garment as it is while it waited.
#define GARMENT_FIT_REDRAW_UNDERCLOTHES (1<<0)
#define GARMENT_FIT_REDRAW_UNIFORM (1<<1)
#define GARMENT_FIT_REDRAW_SUIT (1<<2)
#define GARMENT_FIT_REDRAW_SHOES (1<<3)
#define GARMENT_FIT_REDRAW_GLOVES (1<<4)
