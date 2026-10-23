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

/// Returns the volume-weighted liquid_opacity of a reagent type to volume list, from 0 (clear) to 1 (opaque).
/proc/mix_opacity_from_reagent_list(list/reagent_list)
	var/total_volume = 0
	var/opaque_volume = 0
	for(var/reagent_type, volume in reagent_list)
		var/datum/reagent/reagent_path = reagent_type
		total_volume += volume
		opaque_volume += initial(reagent_path.liquid_opacity) * volume
	return total_volume > 0 ? opaque_volume / total_volume : 0

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

/*
*	OTHER
*/

/datum/reagent/fuel
	liquid_fire_power = 10
	liquid_opacity = 1

/datum/reagent/fuel/oil
	liquid_fire_power = 5
	liquid_fire_burnrate = LIQUID_FIRE_BURNRATE_HEAVY

/*
*	OPAQUE REAGENTS
*/
/datum/reagent/blood
	liquid_opacity = 1

/datum/reagent/consumable/liquidgibs
	liquid_opacity = 1

/datum/reagent/consumable/milk
	liquid_opacity = 1

/datum/reagent/consumable/soymilk
	liquid_opacity = 1

/datum/reagent/consumable/cream
	liquid_opacity = 1

/datum/reagent/drug/maint/tar
	liquid_opacity = 1

/datum/reagent/mercury
	liquid_opacity = 1

/datum/reagent/cement
	liquid_opacity = 1

/datum/reagent/concrete
	liquid_opacity = 1

/datum/reagent/concrete_mix
	liquid_opacity = 1
