/**
 * A finish drawn on the Muscular outline in up to four player colours (paint, accent, frame, lights).
 *
 * Its limbs draw three sheets: their own greyscale image, the skin base, from BULKY_AUGMENTS_SHEET (or its humanoid twin under
 * a mutant colour), and over it copies of that image drawing the finish's packed _paint and _glow states through colour
 * matrices (draw_augment_paint()), so no icon is ever made for a colour. limb_id_override is the finish's id: the prefix of
 * its states in all three sheets.
 *
 * Only a finish whose design has lights has a "lights" channel, and only the zones its art lights have a lights mask
 * (<id>_<zone>_e); a limb glows only there (apply_to()). The colour string keeps its lights colour either way.
 *
 * A finish's name is its save key: renaming one drops it from every save that wears it.
 */
/datum/robotic_style/recolorable
	abstract_type = /datum/robotic_style/recolorable
	icon = BULKY_AUGMENTS_SHEET
	supported_slots = ARMS|LEGS
	has_digi = TRUE
	bodyshape_override = BODYSHAPE_HUMANOID
	/// The channels its art uses, in channel order, "paint", "accent", "frame" or "lights" -> the label the editor shows.
	var/list/channels
	/// Its colours before a player picks any, "#rrggbb" four times: paint, accent, frame, lights.
	var/default_colors
	/// Colour sets offered in the editor, name -> a colour string as default_colors.
	var/list/presets

/// How many matrices augment_paint_matrix() keeps before it starts over.
#define AUGMENT_PAINT_MATRIX_CACHE_SIZE 2048

/**
 * Returns a recolourable finish's colour matrix for one of its packed states: numeric and 4x4, rows red, green, blue, alpha,
 * as Nova's naga tail builds its (constrict.dm). Never rows of colour strings, which map_colors_inferred() can't flatten for
 * the drawn character preview. Each is built once and kept, by colours, state and alpha, until AUGMENT_PAINT_MATRIX_CACHE_SIZE
 * are kept; then the cache is emptied before the next is added, since a player can apply colours without end. A matrix is
 * cheap to build again, and a limb keeps the one it was given.
 *
 * The red, green and blue rows are the colours each packed channel draws in: paint, accent and frame for the _paint state,
 * lights and the two untinted shines for the _glow state. A channel's shade scales its colour, so a pixel packed at half red
 * draws half the paint colour.
 *
 * Arguments:
 * - colors: The colour string, paint, accent, frame, lights.
 * - glow: FALSE for the _paint state (paint, accent, frame), TRUE for the _glow state (lights and the two shines).
 * - alpha: The limb's alpha, which the matrix carries.
 *
 * Returns:
 * - list: 16 numbers. It's shared: read it or hand it to a color var, never edit it.
 */
/proc/augment_paint_matrix(colors, glow, alpha = 255)
	var/static/list/matrices = list()
	var/key = "[colors][glow ? "g" : "p"][alpha]"
	. = matrices[key]
	if(.)
		return
	var/list/rows
	if(glow)
		rows = list(copytext(colors, 22, 29), AUGMENT_SHINE_W, AUGMENT_SHINE_X)
	else
		rows = list(copytext(colors, 1, 8), copytext(colors, 8, 15), copytext(colors, 15, 22))
	var/list/matrix = list()
	for(var/row in rows)
		matrix += rgb2num("[row]00")
	matrix += list(0, 0, 0, alpha)
	for(var/i in 1 to length(matrix))
		matrix[i] /= 255
	if(length(matrices) >= AUGMENT_PAINT_MATRIX_CACHE_SIZE)
		matrices.Cut()
	matrices[key] = matrix
	return matrix

/**
 * Returns `colors` lowercased when it is four "#rrggbb" colours run together, else null. It runs only as a save loads and on
 * the editor's actions, so its regex is made each time rather than kept.
 *
 * Arguments:
 * - colors: Anything: a save's entry, an action's parameter.
 */
/proc/sanitize_augment_colors(colors)
	if(!istext(colors))
		return null
	var/regex/valid = regex(@"^(#[0-9a-fA-F]{6}){4}$")
	if(!valid.Find(colors))
		return null
	return LOWER_TEXT(colors)

/datum/robotic_style/recolorable/jet
	name = "Jet Plating"
	limb_id_override = "jet"
	channels = list("paint" = "Plating", "frame" = "Joints")
	default_colors = "#c4c8d0#c4c8d0#787c88#5fd4ff"
	presets = list(
		"Anime grey" = "#c4c8d0#c4c8d0#787c88#5fd4ff",
		"Gunmetal" = "#a89e94#a89e94#605854#ffb347",
		"Champagne" = "#dcc496#dcc496#463828#ffb347",
		"Blue steel" = "#96a2be#96a2be#2c303e#5fd4ff",
		"Black chrome" = "#60646e#60646e#18181c#ff3b3b",
		"White" = "#f0eee8#f0eee8#6e7482#5fd4ff",
	)

/datum/robotic_style/recolorable/silverhand
	name = "Silverhand"
	limb_id_override = "silverhand"
	channels = list("paint" = "Chrome", "accent" = "Panel", "frame" = "Frame", "lights" = "Lights")
	default_colors = "#969ba8#be3723#30323a#96e8ff"
	presets = list(
		"Silverhand" = "#969ba8#be3723#30323a#96e8ff",
		"Gold" = "#c9a54a#2b2b30#6a5430#ffcc66",
		"Black steel" = "#5a5f6b#be3723#121317#ff4040",
		"Arctic" = "#d8dde6#3d7bff#5a6070#9fe8ff",
		"Toxic" = "#8a9a7a#b4ff3d#263020#b4ff3d",
	)

/datum/robotic_style/recolorable/ghostrunner
	name = "Ghostrunner"
	limb_id_override = "ghostrunner"
	channels = list("frame" = "Plating", "lights" = "Lights")
	default_colors = "#464a52#28c8e6#808ca5#46ebff"
	presets = list(
		"Ghostrunner" = "#464a52#28c8e6#808ca5#46ebff",
		"Crimson" = "#464a52#28c8e6#c46a76#ff3b5c",
		"Shadow" = "#464a52#28c8e6#4a4e5a#b06bff",
		"Bone" = "#464a52#28c8e6#d8d2c2#ffb347",
		"Jade" = "#464a52#28c8e6#6f9a8a#3dffb0",
	)

/datum/robotic_style/recolorable/maelstrom_wired
	name = "Maelstrom Wired"
	limb_id_override = "maelstrom_wired"
	channels = list("paint" = "Hose", "accent" = "Wrap", "frame" = "Frame", "lights" = "Lights")
	default_colors = "#e8e6e2#cd2828#707482#ff2d28"
	presets = list(
		"Maelstrom" = "#e8e6e2#cd2828#707482#ff2d28",
		"Ice" = "#e8e6e2#3d7bff#3a3e4a#3dc8ff",
		"Gold" = "#d8c49a#2a2a2a#5a4a30#ffcc33",
		"Moss" = "#c8d0b8#6aa84f#4a5040#b4ff3d",
		"Scrap" = "#a89a88#8a3a2a#4a403a#ff8a3d",
	)

/datum/robotic_style/recolorable/gorilla
	name = "Gorilla Arms"
	limb_id_override = "gorilla"
	channels = list("paint" = "Plating", "accent" = "Knuckles", "frame" = "Frame")
	default_colors = "#b2202a#cdd2dc#2a282e#8ce8ff"
	presets = list(
		"Crimson" = "#b2202a#cdd2dc#2a282e#8ce8ff",
		"Olive drab" = "#6e7a58#c8c2b0#24261e#ffb347",
		"Gold" = "#c9a54a#2b2b30#1e1a14#ffcc66",
		"Night" = "#2e3340#9aa4b8#14161c#3dc8ff",
		"Bone" = "#e6e0d0#b8b2a2#3a3630#ff3b3b",
	)

/datum/robotic_style/recolorable/maelstrom_brute
	name = "Maelstrom Brute"
	limb_id_override = "maelstrom_brute"
	channels = list("paint" = "Iron", "accent" = "Brass", "frame" = "Frame", "lights" = "Lights")
	default_colors = "#847e84#d7a046#28252a#ff2d28"
	presets = list(
		"Maelstrom" = "#847e84#d7a046#28252a#ff2d28",
		"Rust" = "#8a5a3a#c88a3a#2a1e18#3de0c8",
		"Chrome" = "#c4c8d0#d7a046#2a2c32#ff3b3b",
		"Gunmetal" = "#4a4e56#d7a046#16171b#3dc8ff",
		"Moss" = "#6a7060#a8b060#20231c#b4ff3d",
	)

/datum/robotic_style/recolorable/synthflesh
	name = "Synthflesh"
	limb_id_override = "synthflesh"
	channels = list("paint" = "Chassis", "frame" = "Seams", "lights" = "LED")
	default_colors = "#e6e8ec#e6e8ec#3c4250#46b4ff"
	presets = list(
		"Detroit" = "#e6e8ec#e6e8ec#3c4250#46b4ff",
		"Amber LED" = "#e6e8ec#e6e8ec#3c4250#ffb030",
		"Red LED" = "#e6e8ec#e6e8ec#3c4250#ff3b3b",
		"Graphite" = "#6a707c#6a707c#1e2128#46ebff",
		"Gold" = "#d8c08a#d8c08a#4a3a24#ffd060",
	)

/datum/robotic_style/recolorable/maine
	name = "Maine"
	limb_id_override = "maine"
	channels = list("paint" = "Gauntlets", "accent" = "Knuckles", "frame" = "Seams")
	default_colors = "#8a8f99#c8ccd4#2c2a30#3dff7a"
	presets = list(
		"Edgerunner" = "#8a8f99#c8ccd4#2c2a30#3dff7a",
		"Militech" = "#6e7a58#c8c2b0#24261e#3dff7a",
		"Chrome" = "#c4c8d0#ffffff#2a2c32#3dff7a",
		"Black" = "#3a3d44#9aa4b8#121316#3dff7a",
		"Gold" = "#c9a54a#e8d8a0#2a2414#3dff7a",
	)

/datum/robotic_style/recolorable/automail
	name = "Automail"
	limb_id_override = "automail"
	channels = list("paint" = "Plates", "accent" = "Brass", "frame" = "Joints")
	default_colors = "#d8d4c8#c8a050#3c3a30#ff8c1a"
	presets = list(
		"Rockbell" = "#d8d4c8#c8a050#3c3a30#ff8c1a",
		"Steel" = "#b4b8c0#8a6a3a#2a2c30#ff8c1a",
		"Copper" = "#c88a5a#e0b070#3a2618#ff8c1a",
		"Gunmetal" = "#5a5e66#c8a050#1e1f22#ff8c1a",
		"Ivory" = "#efe8d8#a88a4a#5a5040#ff8c1a",
	)

/datum/robotic_style/recolorable/jet_boots
	name = "Jet Boots"
	limb_id_override = "jet_boots"
	channels = list("paint" = "Plating", "frame" = "Joints")
	default_colors = "#c4c8d0#c4c8d0#787c88#5fd4ff"
	presets = list(
		"Anime grey" = "#c4c8d0#c4c8d0#787c88#5fd4ff",
		"Gunmetal" = "#a89e94#a89e94#605854#5fd4ff",
		"Champagne" = "#dcc496#dcc496#463828#5fd4ff",
		"Blue steel" = "#96a2be#96a2be#2c303e#5fd4ff",
		"Black chrome" = "#60646e#60646e#18181c#5fd4ff",
		"White" = "#f0eee8#f0eee8#6e7482#5fd4ff",
	)

/datum/robotic_style/recolorable/synthskin
	name = "Synthskin"
	limb_id_override = "synthskin"
	channels = list("frame" = "Seams")
	default_colors = "#808080#808080#6a707c#808080"
	presets = list(
		"Synthskin" = "#808080#808080#6a707c#808080",
		"Silver" = "#808080#808080#b4bac6#808080",
		"Umber" = "#808080#808080#3a2a2a#808080",
		"Black" = "#808080#808080#141418#808080",
		"Neon blue" = "#808080#808080#2e7cff#808080",
		"Kiwi pink" = "#808080#808080#ff3d9a#808080",
		"Arasaka red" = "#808080#808080#c81e2a#808080",
	)

#undef AUGMENT_PAINT_MATRIX_CACHE_SIZE
