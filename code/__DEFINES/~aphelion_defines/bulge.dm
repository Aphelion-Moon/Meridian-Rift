// Kinds of pushed-out cloth in a bulge shape template: which shade a pixel takes. See print_derivation.dm.
/// The cloth itself.
#define BULGE_KIND_CLOTH 1
/// Light: the cloth under white at 70/255.
#define BULGE_KIND_LIGHT 2
/// Highlight: the cloth under white at 110/255.
#define BULGE_KIND_HIGHLIGHT 3
/// Shade: the cloth under black at 55/255.
#define BULGE_KIND_SHADE 4
/// Deep shade: the cloth under black at 105/255.
#define BULGE_KIND_DEEP_SHADE 5

// Suit rules (/obj/item/clothing/var/bulge_suit_rule): the cells in which a garment worn in the suit slot was
// reviewed and does not hide the bulge. A cell is the garment's own default appearance in one worn state on one kind
// of legs; the toggled state is its "_t" state (buttons open, unzipped, hood up). Every other cell hides the bulge.
/// Default worn state, plain legs.
#define BULGE_SUIT_DEFAULT_PLAIN (1<<0)
/// Default worn state, digitigrade legs.
#define BULGE_SUIT_DEFAULT_DIGI (1<<1)
/// Toggled worn state, plain legs.
#define BULGE_SUIT_TOGGLED_PLAIN (1<<2)
/// Toggled worn state, digitigrade legs.
#define BULGE_SUIT_TOGGLED_DIGI (1<<3)
/// Default worn state, either legs.
#define BULGE_SUIT_DEFAULT_STATE (BULGE_SUIT_DEFAULT_PLAIN|BULGE_SUIT_DEFAULT_DIGI)
/// Toggled worn state, either legs.
#define BULGE_SUIT_TOGGLED_STATE (BULGE_SUIT_TOGGLED_PLAIN|BULGE_SUIT_TOGGLED_DIGI)
/// Both worn states, either legs.
#define BULGE_SUIT_EITHER_STATE (BULGE_SUIT_DEFAULT_STATE|BULGE_SUIT_TOGGLED_STATE)

// Finishes of the adaptive palette (/datum/bulge_family/var/finish), as the palette code keys them.
#define BULGE_FINISH_CLOTH "cloth"
#define BULGE_FINISH_DENIM "denim"
#define BULGE_FINISH_LEATHER "leather"

// Forms of a bulge as bits (/datum/bulge_family/var/large_digi_forms).
/// Half hard.
#define BULGE_FORM_HALF (1<<0)
/// Fully hard.
#define BULGE_FORM_HARD (1<<1)

/// The bit for bulge size `size` (1-8) in a set of sizes (/datum/bulge_family/var/own_shape_sizes and the like).
#define BULGE_SIZE_BIT(size) (1 << ((size) - 1))

// Where a bulge draws (bulge.dm), relative to the layer of the garment it draws over.
/// How far above its cover's layer a bulge's cloth, and the anatomy shown over it, draw.
#define BULGE_ABOVE_COVER 0.05
/// How far below its cover's layer the anatomy a cover shows draws: under the cover, over whatever is under it.
#define BULGE_BEHIND_COVER 0.0005
/// The name the cloth a bulge draws carries: it is clothing, so the textures a limb draws its skin with skip it
/// (/obj/item/bodypart/proc/get_limb_icon()).
#define BULGE_CLOTH_NAME "bulge cloth"

// What of a penis drawn as a bulge still shows, as bits (/mob/living/carbon/human/proc/bulge_pokes_out()).
/// Some of it is drawn over the cloth: the tip or head past the garment, what a printed patch leaves bare, the shaft
/// over a revealing skirt.
#define BULGE_POKES_PAST_CLOTH (1<<0)
/// It is drawn behind a cover cut or lifted for it: a revealing skirt or a loincloth, hard.
#define BULGE_POKES_UNDER_COVER (1<<1)
