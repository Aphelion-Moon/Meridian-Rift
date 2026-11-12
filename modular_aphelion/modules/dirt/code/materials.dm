/**
 * What dirt is made of: its tone roles' colours and the flags that change how it's drawn, as the reference generator's
 * materials. One of each is made and shared (dirt_material()). Slime's and blood's are made per colour.
 */
/datum/dirt_material
	/// A DIRT_MATERIAL_* define.
	var/id
	/// What a splat stores it as (/datum/dirt_splat/var/material), and what a merged pixel and a baked run name it by:
	/// the id, or "slime#RRGGBB" for slime and "blood#RRGGBB" for blood.
	var/key
	/// What examine calls it.
	var/name
	/// Each role's list(colour, alpha from 0 to 1), indexed by DIRT_ROLE_* define, haze included: the film's colour at
	/// half its alpha. A material without a glint of its own glints in its fleck's tint. You should NEVER modify it.
	var/list/tints
	/// A DIRT_EDGE_* define.
	var/edge = DIRT_EDGE_NONE
	/// DIRT_MATERIAL_* flags.
	var/flags = NONE
	/// The DIRT_CAUSE_* defines it's drawn a step darker by, or null.
	var/list/darker_causes
	/// For slime and blood, the colour it's made from: "#RRGGBB".
	var/base_colour

/// Keys it by its id, as a splat stores every material but slime and blood.
/datum/dirt_material/New()
	. = ..()
	key = id

/**
 * Returns, as text, the parts of the material that change a raster's pixels under a cause: its edge, its flags, and
 * "d" where the cause draws it a step darker. Materials alike in these share rasters, which take colours only in the
 * bake. Every slime colour shares one, and oil shares grease's except where it's splashed.
 *
 * Arguments:
 * - cause: The DIRT_CAUSE_* define it's drawn by.
 */
/datum/dirt_material/proc/shape_class(cause)
	return "e[edge]f[flags][(length(darker_causes) && (cause in darker_causes)) ? "d" : ""]"

/datum/dirt_material/mud
	id = DIRT_MATERIAL_MUD
	name = "mud"
	tints = list(
		list("#5C4631", 0.25),
		list("#5C4631", 0.5),
		list("#36291B", 0.72),
		list("#261C12", 0.9),
		list("#8A7253", 0.85),
		list("#CFC6B6", 0.4),
	)
	edge = DIRT_EDGE_HALO
	flags = DIRT_MATERIAL_SHEEN

/datum/dirt_material/dried_mud
	id = DIRT_MATERIAL_DRIED_MUD
	name = "dried mud"
	tints = list(
		list("#ADA592", 0.21),
		list("#ADA592", 0.42),
		list("#9A907C", 0.65),
		list("#7F735E", 0.82),
		list("#C2BAA6", 0.85),
		list("#C2BAA6", 0.85),
	)
	edge = DIRT_EDGE_TIDE
	flags = DIRT_MATERIAL_LIGHT

/datum/dirt_material/red_clay
	id = DIRT_MATERIAL_RED_CLAY
	name = "red clay"
	tints = list(
		list("#A86C4A", 0.21),
		list("#A86C4A", 0.42),
		list("#8B4A2E", 0.68),
		list("#5E3220", 0.85),
		list("#B97A55", 0.85),
		list("#B97A55", 0.85),
	)
	edge = DIRT_EDGE_TIDE

/datum/dirt_material/dust
	id = DIRT_MATERIAL_DUST
	name = "dust"
	tints = list(
		list("#B7A887", 0.12),
		list("#B7A887", 0.24),
		list("#C2B596", 0.4),
		list("#CFC3A6", 0.5),
		list("#DDD2B8", 0.6),
		list("#DDD2B8", 0.6),
	)
	flags = DIRT_MATERIAL_LIGHT

/datum/dirt_material/plaster
	id = DIRT_MATERIAL_PLASTER
	name = "plaster"
	tints = list(
		list("#D6D4CE", 0.16),
		list("#D6D4CE", 0.32),
		list("#E4E2DC", 0.55),
		list("#EEECE8", 0.62),
		list("#F6F5F2", 0.75),
		list("#F6F5F2", 0.75),
	)
	flags = DIRT_MATERIAL_LIGHT

/datum/dirt_material/ash
	id = DIRT_MATERIAL_ASH
	name = "ash"
	tints = list(
		list("#8C8682", 0.16),
		list("#8C8682", 0.32),
		list("#6E6864", 0.5),
		list("#55504D", 0.62),
		list("#C4BCB0", 0.45),
		list("#C4BCB0", 0.45),
	)
	flags = DIRT_MATERIAL_SPECKS | DIRT_MATERIAL_LIGHT

/datum/dirt_material/grime
	id = DIRT_MATERIAL_GRIME
	name = "grime"
	tints = list(
		list("#4E4E54", 0.225),
		list("#4E4E54", 0.45),
		list("#3B3B42", 0.64),
		list("#2C2C32", 0.74),
		list("#F2F2F2", 0.22),
		list("#F2F2F2", 0.22),
	)

/datum/dirt_material/oil
	id = DIRT_MATERIAL_OIL
	name = "oil"
	tints = list(
		list("#5C4326", 0.19),
		list("#5C4326", 0.38),
		list("#241C14", 0.72),
		list("#130F0A", 0.86),
		list("#6E6A64", 0.7),
		list("#B9B6AF", 0.4),
	)
	edge = DIRT_EDGE_HALO
	flags = DIRT_MATERIAL_SHEEN | DIRT_MATERIAL_GLOSSY
	// splashed, its brown film vanishes on dark cloth
	darker_causes = list(DIRT_CAUSE_SPLASH)

/datum/dirt_material/grease
	id = DIRT_MATERIAL_GREASE
	name = "grease"
	tints = list(
		list("#8A7444", 0.175),
		list("#8A7444", 0.35),
		list("#5A4626", 0.6),
		list("#3A2C16", 0.75),
		list("#A89A7C", 0.7),
		list("#D6CBA6", 0.4),
	)
	edge = DIRT_EDGE_HALO
	flags = DIRT_MATERIAL_SHEEN | DIRT_MATERIAL_GLOSSY

/datum/dirt_material/soot
	id = DIRT_MATERIAL_SOOT
	name = "soot"
	tints = list(
		list("#45454C", 0.18),
		list("#45454C", 0.36),
		list("#1C1C20", 0.74),
		list("#121216", 0.82),
		list("#8A8A90", 0.45),
		list("#8A8A90", 0.45),
	)

/// Its tints say how wet the cloth is. They're white, because the cloth's own colour darkens under it.
/datum/dirt_material/sweat
	id = DIRT_MATERIAL_SWEAT
	name = "sweat"
	tints = list(
		list("#FFFFFF", 0.25),
		list("#FFFFFF", 0.5),
		list("#FFFFFF", 0.85),
		list("#FFFFFF", 1),
		list("#FFFFFF", 0.8),
		list("#FFFFFF", 0.8),
	)
	flags = DIRT_MATERIAL_WET

/datum/dirt_material/mess
	id = DIRT_MATERIAL_MESS
	name = "mess"
	flags = DIRT_MATERIAL_GLOSSY | DIRT_MATERIAL_GOO

/// Takes mess's tints (dirt_mess_role_tints()).
/datum/dirt_material/mess/New()
	. = ..()
	tints = dirt_mess_role_tints()

/datum/dirt_material/slime
	id = DIRT_MATERIAL_SLIME
	name = "slime"
	flags = DIRT_MATERIAL_GLOSSY | DIRT_MATERIAL_GOO

/**
 * Arguments:
 * - colour: "#RRGGBB", upper case.
 */
/datum/dirt_material/slime/New(colour)
	. = ..()
	base_colour = colour
	key = "[id][colour]"
	tints = dirt_slime_tints(colour)

/// Blood run down a taur's body from its garment's stain (dirt_taur_blood_inputs()), in the stain's own colour.
/datum/dirt_material/blood
	id = DIRT_MATERIAL_BLOOD
	name = "blood"

/**
 * Arguments:
 * - colour: "#RRGGBB", upper case.
 */
/datum/dirt_material/blood/New(colour)
	. = ..()
	base_colour = colour
	key = "[id][colour]"
	tints = dirt_blood_tints(colour)

/**
 * Returns a shared material. One is made once a round for each id, and slime and blood get one for each colour.
 * SSdirt.slime_materials keeps the newest DIRT_SLIME_COLOURS, and SSdirt.blood_materials the newest DIRT_BLOOD_COLOURS.
 *
 * Arguments:
 * - id: A DIRT_MATERIAL_* define, or a splat's material, "slime#RRGGBB" for slime, "blood#RRGGBB" for blood.
 * - colour: Slime's or blood's colour, "#RRGGBB" in upper or lower case, with DIRT_MATERIAL_SLIME or
 *   DIRT_MATERIAL_BLOOD as the id.
 *
 * Returns null for an id that isn't a material's, slime or blood without a colour, or a colour that isn't "#RRGGBB".
 */
/proc/dirt_material(id, colour = null)
	RETURN_TYPE(/datum/dirt_material)
	var/static/regex/hex_colour = regex(@"^#[0-9A-Fa-f]{6}$")
	if(!istext(id))
		return null
	SSdirt.materials ||= dirt_made_materials()
	var/datum/dirt_material/material = SSdirt.materials[id]
	if(material)
		return material
	var/coloured_id = copytext(id, 1, length(DIRT_MATERIAL_BLOOD) + 1) == DIRT_MATERIAL_BLOOD ? DIRT_MATERIAL_BLOOD : DIRT_MATERIAL_SLIME
	if(isnull(colour))
		if(copytext(id, 1, length(coloured_id) + 1) != coloured_id)
			return null
		colour = copytext(id, length(coloured_id) + 1)
	else if(id != coloured_id)
		return null
	if(!istext(colour) || !hex_colour.Find(colour))
		return null
	colour = uppertext(colour)
	var/key = "[coloured_id][colour]"
	var/datum/bulge_bounded_cache/kept = coloured_id == DIRT_MATERIAL_BLOOD ? SSdirt.blood_materials : SSdirt.slime_materials
	material = kept.fetch(key)
	if(material)
		return material
	return kept.store_value(key, coloured_id == DIRT_MATERIAL_BLOOD ? new /datum/dirt_material/blood(colour) : new /datum/dirt_material/slime(colour))

/**
 * Makes every material but slime and blood, and returns them as alist(DIRT_MATERIAL_* define = /datum/dirt_material).
 */
/proc/dirt_made_materials()
	RETURN_TYPE(/alist)
	var/alist/materials = alist()
	for(var/material_type in subtypesof(/datum/dirt_material) - /datum/dirt_material/slime - /datum/dirt_material/blood)
		var/datum/dirt_material/material = new material_type
		materials[material.id] = material
	return materials

/**
 * Returns slime's tints from its colour, indexed by DIRT_ROLE_* define, as the reference generator's ramp makes them
 * from tg's own slimes. Shadows turn toward blue or magenta, and a warm colour turns less, because its underside reads
 * as dried blood if it turns far. Highlights turn toward yellow. Saturation is full at the base and gone only in the
 * highlight. Value runs from about a quarter to nine tenths, never black or white.
 *
 * Arguments:
 * - colour: "#RRGGBB".
 */
/proc/dirt_slime_tints(colour)
	RETURN_TYPE(/list)
	var/list/channels = rgb2num(colour)
	var/list/hsv = dirt_rgb_to_hsv(channels[1] / 255, channels[2] / 255, channels[3] / 255)
	var/hue = hsv[1]
	var/saturation = hsv[2]
	var/value = hsv[3]
	var/warm = hue < 0.2 || hue > 0.92
	var/shade = warm ? 0.72 : 0.62
	var/turn = warm ? 8 : 25
	var/film = dirt_slime_tone(hue, value + (1 - value) * 0.15, saturation * 0.8, 60, 8)
	return list(
		list(film, 0.225),
		list(film, 0.45),
		list(dirt_slime_tone(hue, value, saturation, 0, 0), 0.72),
		list(dirt_slime_tone(hue, value * shade, saturation * 0.95, 240, turn), 0.85),
		list(dirt_slime_tone(hue, value * (shade - 0.2), saturation * 0.85, 240, turn * 1.6), 0.85),
		list(dirt_slime_tone(hue, 0.92, saturation * 0.18, 60, 25), 0.9),
	)

/**
 * Returns one tone of slime's ramp as "#RRGGBB", upper case: the colour's hue turned toward another, at a value and
 * saturation each kept from 0 to 1. Each channel rounds halves up.
 *
 * Arguments:
 * - hue: The slime's hue, from 0 up to 1.
 * - value: The tone's value.
 * - saturation: The tone's saturation.
 * - toward: The hue it turns toward, in degrees.
 * - degrees: How far it turns at most, in degrees.
 */
/proc/dirt_slime_tone(hue, value, saturation, toward, degrees)
	var/list/channels = dirt_hsv_to_rgb(dirt_hue_toward(hue, toward / 360, degrees / 360), clamp(saturation, 0, 1), clamp(value, 0, 1))
	return uppertext(rgb(floor(channels[1] * 255 + 0.5), floor(channels[2] * 255 + 0.5), floor(channels[3] * 255 + 0.5)))

/**
 * Returns blood's tints from its colour, indexed by DIRT_ROLE_* define, in only the tones tg's own stain shows. The
 * stain's sheets are grey and drawn in the blood's colour, so each role is the colour times a grey, at an alpha. Both
 * are taken from the stain's pixels beside the taur waist crop (rows 15-20 of tg's four worn blood sheets, every
 * facing). Sorted by alpha they fall in four bands. Film, body and core take the middle grey and alpha of the upper
 * three. Haze takes film's at half its alpha, fleck the darkest grey the dense ones show at core's alpha, and glint
 * body's. Each channel rounds halves up, and each alpha rounds to three decimals.
 *
 * Arguments:
 * - colour: "#RRGGBB".
 */
/proc/dirt_blood_tints(colour)
	RETURN_TYPE(/list)
	// each role's list(grey, alpha), out of 255
	var/static/list/ramp = list(list(205, 39), list(205, 79), list(237, 135), list(237, 205), list(177, 205), list(237, 135))
	var/list/channels = rgb2num(colour)
	. = list()
	for(var/list/tone as anything in ramp)
		var/grey = tone[1]
		var/tinted = uppertext(rgb(floor(channels[1] * grey / 255 + 0.5), floor(channels[2] * grey / 255 + 0.5), floor(channels[3] * grey / 255 + 0.5)))
		. += list(list(tinted, floor(tone[2] * 1000 / 255 + 0.5) / 1000))

/**
 * Returns a hue moved toward another the short way round, by `amount` at most, from 0 up to 1. Hues are in turns,
 * where 1 is the whole colour wheel.
 *
 * Arguments:
 * - hue: The hue.
 * - target: The hue it moves toward.
 * - amount: The most it moves.
 */
/proc/dirt_hue_toward(hue, target, amount)
	var/difference = target - hue + 0.5
	difference = difference - floor(difference) - 0.5
	var/turned = hue + clamp(difference, -amount, amount)
	return turned - floor(turned)

/**
 * Returns list(hue, saturation, value) of a colour, each from 0 to 1, the hue from 0 up to 1, as Python's colorsys.
 *
 * Arguments:
 * - red, green, blue: The colour's channels, from 0 to 1.
 */
/proc/dirt_rgb_to_hsv(red, green, blue)
	RETURN_TYPE(/list)
	var/brightest = max(red, green, blue)
	var/darkest = min(red, green, blue)
	if(brightest == darkest)
		return list(0, 0, brightest)
	var/spread = brightest - darkest
	var/red_share = (brightest - red) / spread
	var/green_share = (brightest - green) / spread
	var/blue_share = (brightest - blue) / spread
	var/hue
	if(red == brightest)
		hue = blue_share - green_share
	else if(green == brightest)
		hue = 2 + red_share - blue_share
	else
		hue = 4 + green_share - red_share
	hue = hue / 6
	return list(hue - floor(hue), spread / brightest, brightest)

/**
 * Returns list(red, green, blue) of a colour, each from 0 to 1, as Python's colorsys.
 *
 * Arguments:
 * - hue: From 0 up to 1.
 * - saturation, value: From 0 to 1.
 */
/proc/dirt_hsv_to_rgb(hue, saturation, value)
	RETURN_TYPE(/list)
	if(!saturation)
		return list(value, value, value)
	var/sector = floor(hue * 6)
	var/fraction = hue * 6 - sector
	var/low = value * (1 - saturation)
	var/falling = value * (1 - saturation * fraction)
	var/rising = value * (1 - saturation * (1 - fraction))
	switch(sector % 6)
		if(0)
			return list(value, rising, low)
		if(1)
			return list(falling, value, low)
		if(2)
			return list(low, value, rising)
		if(3)
			return list(low, falling, value)
		if(4)
			return list(rising, low, value)
	return list(value, low, falling)
