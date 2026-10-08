/**
 * Bulge families: the set of shapes a garment bulges with. A garment names its family by typepath in its
 * bulge_family var (garment_families.dm).
 *
 * A family is never instantiated. Its data are vars initialised here and read with initial() from the typepath:
 * nothing is allocated or retained, there is no lookup list, and a read costs about what a datum var read does.
 *
 * The shapes are named from these vars: "[shapes]_[half|hard]_[size]_[plain|digi]" up to small_cap, in the template
 * sheets (icons/templates, found by templates.dm), and past it one per penis shape,
 * "[shapes]_[half|hard]_[size]_[plain|digi]_[penis shape]", derived at run time from the penis sprites (top_row, hem,
 * contained, curtain and long say how). Those five vars belong to the shapes stem, as a loincloth's worn_icon,
 * worn_icon_state, first_column, last_column, start_x, start_y and drop belong to its drapes stem: what is derived is
 * kept for the round by its name, so the families that share a stem must agree on them (bulge_derivation checks it).
 * Where a family draws another family's shapes by design, it names that family (half_shapes_of, hard_shapes_of,
 * large_shapes_of) instead of repeating them. A garment whose approved look differs from its family's is given a
 * subtype of the family that says how.
 */
/datum/bulge_family
	/// The finish its adaptive palette is computed with (BULGE_FINISH_*).
	var/finish = BULGE_FINISH_CLOTH
	/// Largest bulge size the family has shapes for when half hard; 0 when it never draws.
	var/half_cap = 4
	/// Largest bulge size the family has shapes for when hard; 0 when it never draws.
	var/hard_cap = 4
	/// Largest size a printed garment of this family has a printed look for. A bigger bulge is drawn from the
	/// family's own shapes up to its caps, and stays at this size where the family has none.
	var/print_cap = 4
	/// Loincloths lift their flap when hard: the penis shows under a drape instead of a hard bulge. Every loincloth
	/// names its drapes, so this is the same as `drapes` being set; it is kept as the plain question.
	var/loincloth = FALSE
	/// Stem of the names of the family's own shapes, and of a skirt's own anatomy clearance and flaps; null when it has
	/// none of its own.
	var/shapes = null
	/// The family whose half-hard shapes (up to small_cap) this family draws, when they are that family's by design.
	var/half_shapes_of = null
	/// The family whose hard shapes (up to small_cap) this family draws by design, with their anatomy clearance and
	/// flaps, except at the sizes it has its own of.
	var/hard_shapes_of = null
	/// Hard sizes (BULGE_SIZE_BIT()) at which a family that draws another family's hard shapes has its own shape.
	var/own_shape_sizes = NONE
	/// Hard sizes at which such a family has its own anatomy clearance.
	var/own_clearance_sizes = NONE
	/// Hard sizes at which such a family has its own flap.
	var/own_flap_sizes = NONE
	/// The family whose shapes past small_cap (one per penis shape) this family draws, by design.
	var/large_shapes_of = null
	/// Largest size drawn from shapes that do not depend on the penis shape; past it, a shape per penis shape.
	var/small_cap = 4
	/// Forms (BULGE_FORM_*) whose shapes past small_cap have digitigrade versions; the others draw the plain ones.
	var/large_digi_forms = NONE
	/// The first row (from the top of the tile) the family's shapes past small_cap cover the penis from (bulge_shape()).
	var/top_row = 20
	/// The last row they cover it to, the garment's hem over the crotch.
	var/hem = 0
	/// Sizes past small_cap (BULGE_SIZE_BIT()) at which the cloth still holds the whole penis below top_row: only its head
	/// shows, below the hem when half hard and at the tip facing east and west when hard.
	var/contained = NONE
	/// Sizes past small_cap at which the hard bulge of the human penis hangs a curtain of cloth from the tip down to the
	/// hem, facing east and west (every other penis shape takes mal's amendments there: bulge_derive_large()).
	var/curtain = NONE
	/// Long legs: past small_cap the cloth holds the whole penis below top_row and never bares the head of a half-hard
	/// one, which it presses flat along the thigh, facing east and west.
	var/long = FALSE
	/// Stem of a printed garment's precoloured patches past small_cap (printed_patches.dmi), drawn instead of a print
	/// derived from its sprite; null when its prints are derived.
	var/printed_patches = null
	/// Stem of a loincloth's drape and cut names (both derived at run time: bulge_drape(), bulge_loincloth_cut()).
	var/drapes = null
	/// The cut a hard loincloth takes when its drape stays above the hem facing south (a tentacle's stub).
	var/lifted_hem = 0
	/// Bulge size from which the loincloth's drape has a flat tip; 0 when it never has.
	var/flat_tip_from = 0
	/// A loincloth's own worn sprite and state: its drape's rows facing south and its cuts are taken from it.
	var/worn_icon = null
	var/worn_icon_state = null
	/// The columns (from the left of the tile) of a loincloth's flap facing south: the rows of its drape there.
	var/first_column = 0
	var/last_column = 0
	/// Where a loincloth's drape starts facing east, the flap's hinge: its column and row. The flap's two columns facing
	/// east end there, and its cut facing east and west takes them from that row down.
	var/start_x = 0
	var/start_y = 0
	/// How far a loincloth's flap drops past its hinge: a penis reaching less far than that has the rest hang below it.
	var/drop = 0
	/// Skirts whose shaft shows through the cloth have anatomy clearance masks (skirt_clearance.dmi).
	var/clearance = FALSE
	/// Skirts that reveal cut a flap off the cover when hard (skirt_flaps.dmi).
	var/flaps = FALSE

/// No bulge: the garment never draws one.
/datum/bulge_family/none
	half_cap = 0
	hard_cap = 0
	print_cap = 0

/datum/bulge_family/boxers
	half_cap = 8
	hard_cap = 8
	shapes = "boxers"
	hem = 24
	contained = BULGE_SIZE_BIT(5)
	curtain = BULGE_SIZE_BIT(5)

/// Loose boxers past size 4 are drawn with the boxers' shapes.
/datum/bulge_family/loose_boxers
	half_cap = 8
	hard_cap = 8
	shapes = "loose_boxers"
	large_shapes_of = /datum/bulge_family/boxers

/// The heart boxers keep their print past size 4, in large hearts made by the print rule and approved by mal.
/datum/bulge_family/loose_boxers/hearts
	print_cap = 8
	printed_patches = "heart_boxers"

/datum/bulge_family/briefs
	half_cap = 8
	hard_cap = 8
	shapes = "briefs"
	hem = 23
	contained = BULGE_SIZE_BIT(5)

/datum/bulge_family/jockstrap
	shapes = "jockstrap"

/// Jeans when hard at size 5 keep one shape for every penis (the approved size 5 trial); past it they follow it.
/datum/bulge_family/jeans
	finish = BULGE_FINISH_DENIM
	hard_cap = 8
	shapes = "jeans"
	small_cap = 5
	hem = 31

/// Long johns draw the jeans' half-hard shapes and the jockstrap's hard ones up to size 4; past it their own, which
/// press onto digitigrade thighs when half hard.
/datum/bulge_family/long_johns
	half_cap = 8
	hard_cap = 8
	shapes = "long_johns"
	half_shapes_of = /datum/bulge_family/jeans
	hard_shapes_of = /datum/bulge_family/jockstrap
	large_digi_forms = BULGE_FORM_HALF
	hem = 24
	long = TRUE

/datum/bulge_family/jumpsuits
	shapes = "jumpsuits"

/datum/bulge_family/khaki_shorts
	shapes = "khaki_shorts"

/datum/bulge_family/athletic_shorts
	half_cap = 8
	hard_cap = 8
	shapes = "athletic_shorts"
	hem = 25
	contained = BULGE_SIZE_BIT(5)

/// Track pants past size 4 are drawn with the long johns' shapes.
/datum/bulge_family/track_pants
	half_cap = 8
	hard_cap = 8
	shapes = "track_pants"
	large_shapes_of = /datum/bulge_family/long_johns

/// The leather flap is stiff: from size 6 its drape has a flat tip.
/datum/bulge_family/leather_loincloth
	finish = BULGE_FINISH_LEATHER
	half_cap = 8
	hard_cap = 8
	loincloth = TRUE
	shapes = "leather_loincloth"
	top_row = 21
	hem = 28
	drapes = "leather_loincloth"
	lifted_hem = 28
	flat_tip_from = 6
	worn_icon = 'icons/mob/clothing/under/costume.dmi'
	worn_icon_state = "loincloth"
	first_column = 12
	last_column = 18
	start_x = 19
	start_y = 21
	drop = 8

/datum/bulge_family/colourable_loincloth
	half_cap = 8
	hard_cap = 8
	loincloth = TRUE
	shapes = "colourable_loincloth"
	top_row = 21
	hem = 27
	drapes = "colourable_loincloth"
	lifted_hem = 27
	worn_icon = 'modular_nova/master_files/icons/mob/clothing/underwear.dmi'
	worn_icon_state = "loincloth"
	first_column = 14
	last_column = 16
	start_x = 18
	start_y = 20
	drop = 7

/// The shorter loincloths: the same shapes half hard, with their own shorter drapes and cuts when hard.
/datum/bulge_family/colourable_loincloth/short
	drapes = "short_loincloth"
	lifted_hem = 25
	worn_icon_state = "loincloth_alt"
	drop = 5

/**
 * Skirts, dresses, robes and kilts: cloth that hangs free over the crotch. The style is mal's pick for each garment
 * from the skirt review: a short or a long hem, and how the cloth meets the bulge. Every reviewed skirt is printed
 * from its own sprite. Skirt shapes never depend on the penis shape.
 */
/datum/bulge_family/skirt
	small_cap = 8

/// Short hem, closed lift: the hem lifts when hard and the dark inside shows under it.
/datum/bulge_family/skirt/short_closed_lift
	shapes = "short_closed_lift"

/**
 * Short hem, reveal: the hem lifts when hard, the lifted flap is cut away and the shaft shows. Hard sizes go to 8.
 * The lifted hem follows each skirt's own hem, so skirts whose hem differs from the common one have a subtype below
 * with their own hard shapes, clearance and flap at the hard sizes where theirs differ. The family names itself as
 * the owner of its half and hard shapes so that those subtypes inherit the common ones everywhere else.
 */
/datum/bulge_family/skirt/short_reveal
	hard_cap = 8
	print_cap = 8
	shapes = "short_reveal"
	half_shapes_of = /datum/bulge_family/skirt/short_reveal
	hard_shapes_of = /datum/bulge_family/skirt/short_reveal
	clearance = TRUE
	flaps = TRUE

/// The lone skirt and the ash walker leg skirt: their own flap at hard size 4.
/datum/bulge_family/skirt/short_reveal/lone_skirt
	shapes = "short_reveal_lone_skirt"
	own_flap_sizes = BULGE_SIZE_BIT(4)

/// The jean skirt: its own flap at hard sizes 1 and 4.
/datum/bulge_family/skirt/short_reveal/jean_skirt
	shapes = "short_reveal_jean_skirt"
	own_flap_sizes = BULGE_SIZE_BIT(1)|BULGE_SIZE_BIT(4)

/// A hem one row higher (row 24): jumpskirts, prisoner skirts, sundresses, kilts and the like. Their own shape,
/// clearance and flap at hard size 1.
/datum/bulge_family/skirt/short_reveal/hem_24
	shapes = "short_reveal_hem_24"
	own_shape_sizes = BULGE_SIZE_BIT(1)
	own_clearance_sizes = BULGE_SIZE_BIT(1)
	own_flap_sizes = BULGE_SIZE_BIT(1)

/// A hem two rows higher (row 23): the imperial skirts, the shorter dress, the virgin killer sweater. Their own
/// shape, clearance and flap at hard size 1.
/datum/bulge_family/skirt/short_reveal/hem_23
	shapes = "short_reveal_hem_23"
	own_shape_sizes = BULGE_SIZE_BIT(1)
	own_clearance_sizes = BULGE_SIZE_BIT(1)
	own_flap_sizes = BULGE_SIZE_BIT(1)

/// The miniskirts, hemmed at row 23: their own shape and clearance at hard size 1 and flap at hard sizes 1 and 4.
/datum/bulge_family/skirt/short_reveal/miniskirt
	shapes = "short_reveal_miniskirt"
	own_shape_sizes = BULGE_SIZE_BIT(1)
	own_clearance_sizes = BULGE_SIZE_BIT(1)
	own_flap_sizes = BULGE_SIZE_BIT(1)|BULGE_SIZE_BIT(4)

/// Its own shape at size 1.
/datum/bulge_family/skirt/short_reveal/formal_pen_skirt
	shapes = "short_reveal_formal_pen_skirt"
	own_shape_sizes = BULGE_SIZE_BIT(1)

/// Its own shape at size 1 and flap at size 4.
/datum/bulge_family/skirt/short_reveal/pen_skirt
	shapes = "short_reveal_pen_skirt"
	own_shape_sizes = BULGE_SIZE_BIT(1)
	own_flap_sizes = BULGE_SIZE_BIT(4)

/// Its own shape at size 1.
/datum/bulge_family/skirt/short_reveal/police_skirt
	shapes = "short_reveal_police_skirt"
	own_shape_sizes = BULGE_SIZE_BIT(1)

/// Its own shape at size 1 and flap at sizes 1 and 4.
/datum/bulge_family/skirt/short_reveal/ash_walker_yellow
	shapes = "short_reveal_ash_walker_yellow"
	own_shape_sizes = BULGE_SIZE_BIT(1)
	own_flap_sizes = BULGE_SIZE_BIT(1)|BULGE_SIZE_BIT(4)

/// Its own shapes at every size, clearance at sizes 1 and 5-8 and flap at sizes 1 and 4.
/datum/bulge_family/skirt/short_reveal/shendyt
	shapes = "short_reveal_shendyt"
	own_shape_sizes = ALL
	own_clearance_sizes = BULGE_SIZE_BIT(1)|BULGE_SIZE_BIT(5)|BULGE_SIZE_BIT(6)|BULGE_SIZE_BIT(7)|BULGE_SIZE_BIT(8)
	own_flap_sizes = BULGE_SIZE_BIT(1)|BULGE_SIZE_BIT(4)

/// Its own shapes at every size, clearance at sizes 5-8 and flap at sizes 1 and 4.
/datum/bulge_family/skirt/short_reveal/blutigen
	shapes = "short_reveal_blutigen"
	own_shape_sizes = ALL
	own_clearance_sizes = BULGE_SIZE_BIT(5)|BULGE_SIZE_BIT(6)|BULGE_SIZE_BIT(7)|BULGE_SIZE_BIT(8)
	own_flap_sizes = BULGE_SIZE_BIT(1)|BULGE_SIZE_BIT(4)

/// Its own shape at size 1.
/datum/bulge_family/skirt/short_reveal/slit_dress
	shapes = "short_reveal_slit_dress"
	own_shape_sizes = BULGE_SIZE_BIT(1)

/// Its own shape at size 1 and flap at sizes 1 and 4.
/datum/bulge_family/skirt/short_reveal/swept_skirt
	shapes = "short_reveal_swept_skirt"
	own_shape_sizes = BULGE_SIZE_BIT(1)
	own_flap_sizes = BULGE_SIZE_BIT(1)|BULGE_SIZE_BIT(4)

/// Its own shapes at every size, clearance at sizes 1 and 5-8 and flap at sizes 1 and 4.
/datum/bulge_family/skirt/short_reveal/body_wraps
	shapes = "short_reveal_body_wraps"
	own_shape_sizes = ALL
	own_clearance_sizes = BULGE_SIZE_BIT(1)|BULGE_SIZE_BIT(5)|BULGE_SIZE_BIT(6)|BULGE_SIZE_BIT(7)|BULGE_SIZE_BIT(8)
	own_flap_sizes = BULGE_SIZE_BIT(1)|BULGE_SIZE_BIT(4)

/// Its own shapes at every size, clearance at sizes 1 and 5-8 and flap at size 1.
/datum/bulge_family/skirt/short_reveal/seriouser
	shapes = "short_reveal_seriouser"
	own_shape_sizes = ALL
	own_clearance_sizes = BULGE_SIZE_BIT(1)|BULGE_SIZE_BIT(5)|BULGE_SIZE_BIT(6)|BULGE_SIZE_BIT(7)|BULGE_SIZE_BIT(8)
	own_flap_sizes = BULGE_SIZE_BIT(1)

/// Short hem, kilt apron: a flat front panel that rises evenly when hard.
/datum/bulge_family/skirt/short_kilt_apron
	shapes = "short_kilt_apron"

/// Long hem, cone: the cloth tents from the tip, with folds fanning down to the hem.
/datum/bulge_family/skirt/long_cone
	shapes = "long_cone"

/// Long hem, curtain: the cloth falls straight down from the tip in pipe folds, and the shaft shows above it.
/datum/bulge_family/skirt/long_curtain
	shapes = "long_curtain"
	clearance = TRUE

/// Long hem, pressed: no tent; the bulge stretches the cloth.
/datum/bulge_family/skirt/long_pressed
	shapes = "long_pressed"
