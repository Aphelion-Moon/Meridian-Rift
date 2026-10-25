/datum/reagent
	///Whether it will evaporate if left untouched on a liquids simulated puddle
	var/evaporates = FALSE

	///Fire power per unit, for burning on simulated liquids. The mix's power per unit decides whether it burns and caps how fierce its fire gets.
	var/liquid_fire_power = 0

	///Units of this a burning liquid tile uses up per fire run, if it has fire power. See LIQUID_FIRE_BURNRATE_*.
	var/liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_VOLATILE

	///Whether a fire from this requires oxygen in the atmosphere
	var/fire_needs_oxygen = TRUE

	///How much of the floor a pool of this reagent hides, from 0 (clear) to 1 (opaque). Pools average it by volume.
	var/liquid_opacity = 0

	///The LIQUID_SURFACE_* look a pool takes when this reagent's class holds the most of its volume.
	var/liquid_surface = LIQUID_SURFACE_CLEAR

	///Marks drawn over the pool's surface while this is its class's largest reagent: "grit", "chunks", "bumps" or null.
	var/liquid_surface_detail

/// What liquids read off one reagent type, from get_liquid_reagent_look().
/datum/liquid_reagent_look
	/// The type's liquid_surface.
	var/surface_class
	/// The type's liquid_surface_detail.
	var/surface_detail
	/// The type's liquid_opacity.
	var/opacity
	/// The type's colour as "#rrggbb", with the "#" a few gas reagents leave out.
	var/color
	/// The colour of a pool of only this reagent, from scale_liquid_color(). Null until a lone pool first asks for it.
	var/lone_color

/**
 * Returns what liquids read off a reagent type, worked out once per type.
 *
 * Arguments:
 * - reagent_type: A /datum/reagent type.
 */
/proc/get_liquid_reagent_look(datum/reagent/reagent_type)
	RETURN_TYPE(/datum/liquid_reagent_look)
	var/static/list/looks = list()
	. = looks[reagent_type]
	if(.)
		return
	var/datum/liquid_reagent_look/look = new
	look.surface_class = initial(reagent_type.liquid_surface)
	look.surface_detail = initial(reagent_type.liquid_surface_detail)
	look.opacity = initial(reagent_type.liquid_opacity)
	look.color = initial(reagent_type.color)
	// A few gas reagents leave out the "#", which rgb2num() refuses.
	if(!findtextEx(look.color, "#", 1, 2))
		look.color = "#[look.color]"
	looks[reagent_type] = look
	return look

/**
 * Returns the colour of a pool holding only one reagent type, at any volume above 0, worked out once per type.
 *
 * Any volume mixes to the reagent's own colour, so this is what scale_liquid_color(mix_liquid_color()) gives for it.
 *
 * Arguments:
 * - reagent_type: A /datum/reagent type.
 */
/proc/get_lone_liquid_color(reagent_type)
	var/datum/liquid_reagent_look/look = get_liquid_reagent_look(reagent_type)
	if(isnull(look.lone_color))
		var/list/lone_pool = list()
		lone_pool[reagent_type] = 1
		look.lone_color = scale_liquid_color(mix_liquid_color(lone_pool), look.surface_class)
	return look.lone_color

/**
 * Returns the surface a pool of these reagents draws.
 *
 * The pool takes the LIQUID_SURFACE_* class holding the most volume, ties going to the lower define, and the
 * liquid_surface_detail of that class's largest reagent.
 *
 * Arguments:
 * - reagent_list: Reagent type to volume.
 *
 * Returns:
 * - list(class, detail). A list with no volume gives LIQUID_SURFACE_CLEAR and no detail.
 */
/proc/get_liquid_surface(list/reagent_list)
	var/list/volume_by_class = new /list(LIQUID_SURFACE_COUNT)
	for(var/reagent_type, volume in reagent_list)
		var/datum/reagent/reagent_path = reagent_type
		volume_by_class[initial(reagent_path.liquid_surface)] += volume
	var/surface_class = LIQUID_SURFACE_CLEAR
	for(var/candidate in LIQUID_SURFACE_CLEAR + 1 to LIQUID_SURFACE_COUNT)
		if(volume_by_class[candidate] > volume_by_class[surface_class])
			surface_class = candidate
	var/surface_detail
	var/largest_volume = 0
	for(var/reagent_type, volume in reagent_list)
		var/datum/reagent/reagent_path = reagent_type
		if(volume > largest_volume && initial(reagent_path.liquid_surface) == surface_class)
			largest_volume = volume
			surface_detail = initial(reagent_path.liquid_surface_detail)
	return list(surface_class, surface_detail)

/**
 * Returns a mixed pool colour scaled by its surface class's LIQUID_COLOR_FACTOR_*, as "#rrggbb".
 *
 * Arguments:
 * - mixed_color: The pool's reagent mix, from mix_liquid_color().
 * - surface_class: The pool's LIQUID_SURFACE_* class.
 *
 * Returns:
 * - null: mixed_color is null (a mix with no volume).
 */
/proc/scale_liquid_color(mixed_color, surface_class)
	if(!mixed_color)
		return null
	var/factor = get_liquid_color_factor(surface_class)
	var/list/channels = rgb2num(mixed_color)
	return rgb(round(channels[1] * factor, 1), round(channels[2] * factor, 1), round(channels[3] * factor, 1))

/// Returns the LIQUID_COLOR_FACTOR_* that a pool of this LIQUID_SURFACE_* class scales its mix colour by.
/proc/get_liquid_color_factor(surface_class)
	switch(surface_class)
		if(LIQUID_SURFACE_CLEAR)
			return LIQUID_COLOR_FACTOR_CLEAR
		if(LIQUID_SURFACE_BLOOD)
			return LIQUID_COLOR_FACTOR_BLOOD
	return LIQUID_COLOR_FACTOR_OPAQUE

/// Returns the volume-weighted liquid_opacity of a reagent type to volume list, from 0 (clear) to 1 (opaque).
/proc/mix_opacity_from_reagent_list(list/reagent_list)
	var/total_volume = 0
	var/opaque_volume = 0
	for(var/reagent_type, volume in reagent_list)
		var/datum/reagent/reagent_path = reagent_type
		total_volume += volume
		opaque_volume += initial(reagent_path.liquid_opacity) * volume
	return total_volume > 0 ? opaque_volume / total_volume : 0

/**
 * Returns the volume-weighted RGB mean of a reagent type to volume list, as "#rrggbb".
 *
 * Each reagent counts with its initial(color), alpha ignored: a pool's alpha comes from SSliquids.get_pool_alpha().
 * Liquids hold reagents by type, which can't tell blood types apart, so blood counts with blood_color when it is set.
 *
 * Arguments:
 * - reagent_list: Reagent type to volume.
 * - blood_color: Colour of the blood in the list. Null draws blood in the blood reagent's own colour.
 *
 * Returns:
 * - null: The list holds no volume.
 */
/proc/mix_liquid_color(list/reagent_list, blood_color)
	var/list/volume_by_color = list()
	for(var/reagent_type, volume in reagent_list)
		var/reagent_color = blood_color
		if(!blood_color || reagent_type != /datum/reagent/blood)
			var/datum/liquid_reagent_look/look = get_liquid_reagent_look(reagent_type)
			reagent_color = look.color
		else if(!findtextEx(reagent_color, "#", 1, 2))
			reagent_color = "#[reagent_color]"
		volume_by_color[reagent_color] += volume
	return mix_colors_by_volume(volume_by_color)

/// Returns the volume-weighted RGB mean of a colour to volume list, as "#rrggbb" with alpha ignored, or null when it holds no volume.
/proc/mix_colors_by_volume(list/volume_by_color)
	var/total_volume = 0
	var/red = 0
	var/green = 0
	var/blue = 0
	for(var/mixed_color, volume in volume_by_color)
		var/list/channels = rgb2num(mixed_color)
		red += channels[1] * volume
		green += channels[2] * volume
		blue += channels[3] * volume
		total_volume += volume
	if(total_volume <= 0)
		return null
	// rgb() floors, so round here or remixing one colour drifts it darker.
	return rgb(round(red / total_volume, 1), round(green / total_volume, 1), round(blue / total_volume, 1))

/*
*	ALCOHOL REAGENTS
*/
/datum/reagent/consumable/ethanol
	liquid_fire_power = 10

// 0 fire power
/datum/reagent/consumable/ethanol/beer/light
	liquid_fire_power = 0

/datum/reagent/consumable/ethanol/threemileisland
	liquid_fire_power = 0

/datum/reagent/consumable/ethanol/grog
	liquid_fire_power = 0

/datum/reagent/consumable/ethanol/fetching_fizz
	liquid_fire_power = 0

/datum/reagent/consumable/ethanol/sugar_rush
	liquid_fire_power = 0

/datum/reagent/consumable/ethanol/crevice_spike
	liquid_fire_power = 0

/datum/reagent/consumable/ethanol/fanciulli
	liquid_fire_power = 0

// 2 fire power
/datum/reagent/consumable/ethanol/beer
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/wine
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/lizardwine
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/amaretto
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/goldschlager
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/gintonic
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/iced_beer
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/irishcarbomb
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/hcider
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/narsour
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/peppermint_patty
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/blank_paper
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/applejack
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/jack_rose
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/old_timer
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/duplex
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/painkiller
	liquid_fire_power = 2
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

// 3 fire power
/datum/reagent/consumable/ethanol/longislandicedtea
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/irishcoffee
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/margarita
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/manhattan
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/snowwhite
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/bahama_mama
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/singulo
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/red_mead
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/mead
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/aloe
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/andalusia
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/alliescocktail
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/amasec
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/erikasurprise
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/whiskey_sour
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/triple_sec
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/creme_de_menthe
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/creme_de_cacao
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/creme_de_coconut
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/quadruple_sec
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/grasshopper
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/stinger
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/bastion_bourbon
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/squirt_cider
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/amaretto_alexander
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/sidecar
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/mojito
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/moscow_mule
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/fruit_wine
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/champagne
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/pina_colada
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/ginger_amaretto
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

// 4 fire power
/datum/reagent/consumable/ethanol/rum_coke
	liquid_fire_power = 4
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/booger
	liquid_fire_power = 4
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/datum/reagent/consumable/ethanol/tequila_sunrise
	liquid_fire_power = 4
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_WEAK

/*
*	PYROTECHNIC REAGENTS
*/
/datum/reagent/thermite
	liquid_fire_power = 20

/datum/reagent/phlogiston
	liquid_fire_power = 20

/datum/reagent/clf3
	liquid_fire_power = 30

/datum/reagent/napalm
	liquid_fire_power = 30
	liquid_opacity = 1
	liquid_surface = LIQUID_SURFACE_OIL

/*
*	OTHER
*/

/datum/reagent/fuel
	liquid_fire_power = 10
	liquid_opacity = 1
	liquid_surface = LIQUID_SURFACE_FUEL

/datum/reagent/fuel/oil
	liquid_fire_power = 5
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_HEAVY
	liquid_surface = LIQUID_SURFACE_OIL

// cooking oil: hard to light, steady like motor oil
/datum/reagent/consumable/nutriment/fat/oil
	liquid_fire_power = 4
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_HEAVY

/*
*	OPAQUE REAGENTS
*/
/datum/reagent/blood
	liquid_opacity = 1
	liquid_surface = LIQUID_SURFACE_BLOOD

/datum/reagent/consumable/liquidgibs
	liquid_opacity = 1
	liquid_surface = LIQUID_SURFACE_OPAQUE
	liquid_surface_detail = "chunks"

/datum/reagent/consumable/milk
	liquid_opacity = 1
	liquid_surface = LIQUID_SURFACE_OPAQUE

/datum/reagent/consumable/soymilk
	liquid_opacity = 1
	liquid_surface = LIQUID_SURFACE_OPAQUE

/datum/reagent/consumable/cream
	liquid_opacity = 1
	liquid_surface = LIQUID_SURFACE_OPAQUE

/datum/reagent/consumable/cum
	liquid_opacity = 1
	liquid_surface = LIQUID_SURFACE_OPAQUE

/datum/reagent/drug/maint/tar
	liquid_fire_power = 3
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_TAR
	liquid_opacity = 1
	liquid_surface = LIQUID_SURFACE_TAR
	liquid_surface_detail = "bumps"

/datum/reagent/mercury
	liquid_opacity = 1
	liquid_surface = LIQUID_SURFACE_MIRROR

/datum/reagent/cement
	liquid_opacity = 1
	liquid_surface = LIQUID_SURFACE_OPAQUE
	liquid_surface_detail = "grit"

/datum/reagent/concrete
	liquid_opacity = 1
	liquid_surface = LIQUID_SURFACE_OPAQUE
	liquid_surface_detail = "grit"

/datum/reagent/concrete_mix
	liquid_opacity = 1
	liquid_surface = LIQUID_SURFACE_OPAQUE
	liquid_surface_detail = "grit"
