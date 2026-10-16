/**
 * Fixtures the body marking tests share: the markings a test body wears and their colours, the standard and merge
 * fills, a rendered icon's pixel signature and the emissive glow check. Their names come from the before/after
 * baselines the markings datumisation was measured with.
 */

/// The markings the fixture wears. Each one claims all eight marking zones and ships art for every one
/// of them plus both leg shapes, so no case falls back to a sheet's default frame and hides a difference.
/// Named explicitly rather than read out of GLOB.body_markings_per_limb, whose order can change.
/proc/markings_baseline_marking_names()
	return list("Bovine", "Dalmatian", "Guilmon Mark")

/// One fixed colour per fixture marking, so no signature ever depends on a mutant colour roll.
/proc/markings_baseline_marking_colors()
	return list("#4488cc", "#cc4422", "#33aa55")

/**
 * Builds the fixture's marking map in the nested shape a savefile holds: zone -> (marking name -> list(color, emissive)).
 *
 * Every zone in GLOB.marking_zones receives all three fixture markings. Only the second one emits, so a
 * test covers both the plain and the emissive branch of append_base_marking_overlays(). Callers load it
 * through body_marking_collection_from_list(), the way a saved character's markings arrive, and replace the
 * whole collection with it, so a species randomiser that already seeded a zone cannot leave a stray entry behind.
 *
 * Returns a new list.
 */
/proc/markings_baseline_fill()
	var/list/names = markings_baseline_marking_names()
	var/list/colors = markings_baseline_marking_colors()
	. = list()
	for(var/zone in GLOB.marking_zones)
		var/list/worn = list()
		for(var/index in 1 to length(names))
			// An integer 0/1, which is what a savefile holds for the emissive flag.
			worn[names[index]] = list(colors[index], index == 2 ? 1 : 0)
		.[zone] = worn

/// The one colour every marking of the merge fixture wears.
/proc/markings_merge_fixture_color()
	return "#4488cc"

/**
 * Builds the merge fixture's marking map, in the same nested shape as markings_baseline_fill(): the same three markings
 * on every zone, all in one colour and all glowing. Each zone's markings then run together in colour and in glow, which
 * the standard fixture, three colours with one glow per zone, never does. Its tests draw a zone's same-coloured
 * markings, and its glows, as one.
 *
 * Returns a new list.
 */
/proc/markings_merge_fixture_fill()
	var/merge_color = markings_merge_fixture_color()
	. = list()
	for(var/zone in GLOB.marking_zones)
		var/list/worn = list()
		for(var/name in markings_baseline_marking_names())
			worn[name] = list(merge_color, 1)
		.[zone] = worn

/**
 * Reduces a rendered icon to one comparison key.
 *
 * Every pixel of every cardinal folds into a single md5, so a colour-only change is caught where
 * difference().getbbox() would miss it. The canvas size travels with the hash so a later run can never
 * silently compare a differently sized render.
 *
 * Arguments:
 * - canvas: the icon to reduce, normally from get_flat_icon_for_all_directions().
 *
 * Returns a list holding the hash and the canvas shape.
 */
/proc/markings_baseline_signature(icon/canvas)
	var/width = canvas.Width()
	var/height = canvas.Height()
	var/list/pixels = list()
	for(var/direction in GLOB.cardinals)
		for(var/y in 1 to height)
			for(var/x in 1 to width)
				var/pixel = canvas.GetPixel(x, y, "", direction)
				// A fully transparent pixel has no colour; a placeholder keeps the stream aligned.
				pixels += isnull(pixel) ? "." : pixel
	return list(
		"pixels_md5" = md5(jointext(pixels, "")),
		"width" = width,
		"height" = height,
		"samples" = length(pixels),
	)

/**
 * Tells a glowing emissive appearance from an emissive blocker, which shares its plane.
 *
 * Every emissive colour matrix writes its glow into the constant row, and a blocker leaves that row at
 * zero (see _EMISSIVE_COLOR() and _EM_BLOCK_COLOR()).
 *
 * Arguments:
 * - overlay: an appearance already known to sit on the emissive plane.
 *
 * Returns TRUE when the appearance glows.
 */
/proc/markings_baseline_is_glowing(image/overlay)
	var/list/color_matrix = overlay.color
	if(!islist(color_matrix) || length(color_matrix) < 20)
		return FALSE
	return !!(color_matrix[17] || color_matrix[18] || color_matrix[19])
