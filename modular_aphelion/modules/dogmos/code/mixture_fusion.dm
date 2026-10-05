/** Default-off commissioning switch; read only while building the startup registry. */
/datum/config_entry/flag/dogmos_mixture_fusion

/datum/controller/subsystem/dogmos
	/// Startup selection, never a live chemistry toggle.
	var/mixture_fusion_enabled = FALSE

/datum/gas_mixture
	/// HFR-owned internal mixtures cannot run ordinary mixture fusion.
	var/dogmos_fusion_excluded = FALSE
	/// Last admitted opportunity; set only after an eligible owned mixture reaches dispatch.
	var/dogmos_fusion_last_step
	/// Last acknowledged completion, independent of per-call reaction_results clearing.
	var/dogmos_fusion_last_completion
	var/dogmos_fusion_instability

/** Normal Meridian reaction with a selective Aphelion native implementation. */
/datum/gas_reaction/standard/meridian_fusion
	id = "meridian_fusion"
	name = "Fusion"
	priority_group = PRIORITY_PRE_FORMATION

/** Initialize the same generated activation profile used by the native kernel. */
/datum/gas_reaction/standard/meridian_fusion/init_reqs()
	requirements = list(
		/datum/gas/plasma = DOGMOS_FUSION_MIN_MOLES,
		/datum/gas/carbon_dioxide = DOGMOS_FUSION_MIN_MOLES,
		/datum/gas/tritium = DOGMOS_FUSION_FUEL_PER_STEP,
		"MIN_TEMP" = DOGMOS_FUSION_MIN_TEMPERATURE,
		"MAX_TEMP" = DOGMOS_FUSION_MAX_TEMPERATURE,
	)

/** Registration uses the startup choice; a disabled feature has no reaction entry. */
/datum/gas_reaction/standard/meridian_fusion/dogmos_registration_enabled()
	return SSdogmos.mixture_fusion_enabled

/** The DM implementation is a reference for differential fixtures, using the same effect path. */
/datum/gas_reaction/standard/meridian_fusion/react(datum/gas_mixture/air, datum/holder)
	if(!air.dogmos_fusion_admit(holder))
		return NO_REACTION
	var/list/result = air.dogmos_fusion_reference()
	if(!result)
		return NO_REACTION
	var/datum/gas_mixture/proposed = result["mixture"]
	air.copy_from(proposed)
	qdel(proposed)
	air.dogmos_fusion_finish(holder, result["instability"], result["energy_delta"], air.return_temperature())
	return REACTING

/** Resolve an actual supported owner, rather than inferring ownership from composition. */
/datum/gas_mixture/proc/dogmos_fusion_location(datum/holder)
	if(dogmos_fusion_excluded || QDELETED(holder))
		return null
	if(istype(holder, /turf/open))
		var/turf/open/location = holder
		return location.air == src ? location : null
	if(istype(holder, /obj/machinery/portable_atmospherics))
		var/obj/machinery/portable_atmospherics/container = holder
		return !container.suppress_reactions && container.air_contents == src ? get_turf(container) : null
	if(istype(holder, /obj/machinery/atmospherics/components/tank))
		var/obj/machinery/atmospherics/components/tank/tank = holder
		return tank.air_contents == src ? get_turf(tank) : null
	if(istype(holder, /obj/item/tank))
		var/obj/item/tank/tank = holder
		return tank.air_contents == src ? get_turf(tank) : null
	if(istype(holder, /datum/pipeline))
		var/datum/pipeline/network = holder
		if(network.air != src || network.building)
			return null
		for(var/obj/machinery/atmospherics/pipe/member as anything in network.members)
			if(!QDELETED(member) && member.parent == network)
				return get_turf(member)
		for(var/obj/machinery/atmospherics/components/member as anything in network.other_atmos_machines)
			if(!QDELETED(member))
				return get_turf(member)
	return null

/** Pure current-state eligibility; no scheduling claim and no execution preview. */
/datum/gas_mixture/proc/dogmos_fusion_status(datum/holder)
	if(!SSdogmos.mixture_fusion_enabled)
		return "disabled"
	#if !DOGMOS_FUSION_NATIVE_AVAILABLE
	return "unavailable"
	#endif
	if(is_immutable() || !dogmos_fusion_location(holder))
		return "unsupported holder"
	if(get_moles(/datum/gas/hypernoblium) >= REACTION_OPPRESSION_THRESHOLD && return_temperature() > REACTION_OPPRESSION_MIN_TEMP)
		return "suppressed"
	if(return_temperature() < DOGMOS_FUSION_MIN_TEMPERATURE || return_temperature() > DOGMOS_FUSION_MAX_TEMPERATURE || return_volume() <= 0 || return_volume() > DOGMOS_FUSION_MAX_VOLUME)
		return "not eligible"
	if(get_moles(/datum/gas/plasma) < DOGMOS_FUSION_MIN_MOLES || get_moles(/datum/gas/carbon_dioxide) < DOGMOS_FUSION_MIN_MOLES || get_moles(/datum/gas/tritium) < DOGMOS_FUSION_FUEL_PER_STEP)
		return "not eligible"
	if(!isnull(dogmos_fusion_last_completion) && world.time - dogmos_fusion_last_completion < DOGMOS_FUSION_STEP_DECISECONDS)
		return "active"
	return "eligible"

/** Retain an existing processing owner while a due fusion opportunity is deferred. */
/datum/gas_mixture/proc/dogmos_fusion_waiting(datum/holder)
	if(!SSdogmos.mixture_fusion_enabled || isnull(dogmos_fusion_last_step))
		return FALSE
	var/status = dogmos_fusion_status(holder)
	return status == "eligible" || status == "active"

/** One opportunity per reference interval, no catch-up; identity stays with this mixture. */
/datum/gas_mixture/proc/dogmos_fusion_admit(datum/holder)
	if(dogmos_fusion_status(holder) != "eligible")
		return FALSE
	if(!isnull(dogmos_fusion_last_step) && world.time - dogmos_fusion_last_step < DOGMOS_FUSION_STEP_DECISECONDS)
		return FALSE
	dogmos_fusion_last_step = world.time
	return TRUE

/** Publish bounded status and apply effects only after numerical locks are released. */
/datum/gas_mixture/proc/dogmos_fusion_finish(datum/holder, instability, energy_delta, temperature)
	reaction_results[/datum/gas_reaction/standard/meridian_fusion] = instability
	dogmos_fusion_last_completion = world.time
	dogmos_fusion_instability = instability
	var/turf/location = dogmos_fusion_location(holder)
	if(!location)
		return TRUE // Stale owner: numerical step is settled, obsolete effects are discarded.
	if(energy_delta > 0)
		radiation_pulse(location, max_range = min(sqrt(energy_delta / DOGMOS_FUSION_BINDING_ENERGY), GAS_REACTION_MAXIMUM_RADIATION_PULSE_RANGE), threshold = TRITIUM_RADIATION_THRESHOLD)
	if(istype(holder, /turf/open) && temperature > FIRE_MINIMUM_TEMPERATURE_TO_EXIST)
		var/turf/open/open_location = location
		open_location.hotspot_expose(temperature, CELL_VOLUME)
	return TRUE

/** Independent DM arithmetic oracle. Never mutates this mixture or calls reaction effects. */
/datum/gas_mixture/proc/dogmos_fusion_reference()
	var/plasma = get_moles(/datum/gas/plasma)
	var/carbon = get_moles(/datum/gas/carbon_dioxide)
	var/tritium = get_moles(/datum/gas/tritium)
	var/temperature = return_temperature()
	var/volume = return_volume()
	var/capacity = heat_capacity()
	if(!dogmos_fusion_finite(temperature) || !dogmos_fusion_finite(volume) || !dogmos_fusion_finite(capacity) || plasma < DOGMOS_FUSION_MIN_MOLES || carbon < DOGMOS_FUSION_MIN_MOLES || tritium < DOGMOS_FUSION_FUEL_PER_STEP || temperature < DOGMOS_FUSION_MIN_TEMPERATURE || temperature > DOGMOS_FUSION_MAX_TEMPERATURE || volume <= 0 || volume > DOGMOS_FUSION_MAX_VOLUME || capacity <= 0)
		return null
	var/gas_power = 0
	for(var/gas_id in get_gases())
		var/amount = get_moles(gas_id)
		if(!dogmos_fusion_finite(amount) || amount < 0 || amount > DOGMOS_FUSION_MAX_MOLES)
			return null
		gas_power += GLOB.meta_gas_info[META_GAS_FUSION_POWER][gas_id] * amount
	if(!dogmos_fusion_finite(gas_power))
		return null
	var/scale = max(volume / DOGMOS_FUSION_SCALE_DIVISOR, DOGMOS_FUSION_MIN_SCALE)
	var/temperature_scale = log(10, temperature) - DOGMOS_FUSION_BASE_TEMP_SCALE
	var/toroid = DOGMOS_FUSION_TOROID_THRESHOLD + (temperature_scale <= 0 ? temperature_scale : (4 ** temperature_scale) / DOGMOS_FUSION_SLOPE_DIVISOR)
	if(!dogmos_fusion_finite(toroid) || toroid <= 0)
		return null
	var/instability = dogmos_fusion_modulo(gas_power * DOGMOS_FUSION_GAS_POWER_FACTOR, toroid)
	var/new_plasma = dogmos_fusion_modulo((plasma - DOGMOS_FUSION_MIN_MOLES) / scale - instability * sin(TODEGREES((carbon - DOGMOS_FUSION_MIN_MOLES) / scale)), toroid)
	var/new_carbon = dogmos_fusion_modulo((carbon - DOGMOS_FUSION_MIN_MOLES) / scale - new_plasma, toroid) * scale + DOGMOS_FUSION_MIN_MOLES
	new_plasma = new_plasma * scale + DOGMOS_FUSION_MIN_MOLES
	if(!dogmos_fusion_finite(new_plasma) || !dogmos_fusion_finite(new_carbon) || new_plasma < 0 || new_carbon < 0 || new_plasma > DOGMOS_FUSION_MAX_MOLES || new_carbon > DOGMOS_FUSION_MAX_MOLES)
		return null
	var/delta = min(plasma - new_plasma, toroid * scale * 1.5)
	var/raw_energy = (delta > 0 || instability <= DOGMOS_FUSION_ENDOTHERMAL_THRESHOLD) ? max(delta * DOGMOS_FUSION_BINDING_ENERGY, 0) : delta * DOGMOS_FUSION_BINDING_ENERGY * sqrt(instability - DOGMOS_FUSION_ENDOTHERMAL_THRESHOLD)
	var/initial_energy = temperature * capacity
	if(!dogmos_fusion_finite(raw_energy) || !dogmos_fusion_finite(initial_energy))
		return null
	var/energy_delta = clamp(raw_energy, -initial_energy * DOGMOS_FUSION_MAX_ENERGY_FRACTION, initial_energy * DOGMOS_FUSION_MAX_ENERGY_FRACTION)
	var/datum/gas_mixture/proposed = copy()
	proposed.set_moles(/datum/gas/plasma, new_plasma)
	proposed.set_moles(/datum/gas/carbon_dioxide, new_carbon)
	proposed.set_moles(/datum/gas/tritium, tritium - DOGMOS_FUSION_FUEL_PER_STEP)
	var/waste = scale * DOGMOS_FUSION_WASTE_COEFFICIENT * DOGMOS_FUSION_FUEL_PER_STEP
	proposed.adjust_moles(/datum/gas/oxygen, waste)
	proposed.adjust_moles(delta > 0 ? /datum/gas/water_vapor : /datum/gas/bz, waste)
	var/new_temperature = (initial_energy + energy_delta) / proposed.heat_capacity()
	var/valid = dogmos_fusion_finite(new_temperature) && new_temperature >= TCMB && new_temperature <= DOGMOS_FUSION_MAX_TEMPERATURE
	for(var/gas_id in proposed.get_gases())
		var/amount = proposed.get_moles(gas_id)
		valid = valid && dogmos_fusion_finite(amount) && amount >= 0 && amount <= DOGMOS_FUSION_MAX_MOLES
	if(!valid)
		qdel(proposed)
		return null
	proposed.set_temperature(new_temperature)
	return list("mixture" = proposed, "instability" = instability, "energy_delta" = energy_delta)

/** DM's floating remainder is signed; the toroidal map needs Euclidean modulo. */
/proc/dogmos_fusion_modulo(value, modulus)
	var/remainder = value %% modulus
	return remainder < 0 ? remainder + modulus : remainder

/** Numerical input check shared by the DM reference. */
/proc/dogmos_fusion_finite(value)
	return isnum(value) && IS_FINITE__UNSAFE(value)

/client
	/// Bounded on-demand Kennel snapshot; contains no retained mixture or holder references.
	var/list/dogmos_reaction_explanation

/** Resolve pipe scans to their authoritative processing owner without loosening admission. */
/datum/gas_mixture/proc/dogmos_fusion_display_status(atom/target)
	if(istype(target, /obj/machinery/atmospherics/pipe))
		var/obj/machinery/atmospherics/pipe/pipe = target
		if(pipe.parent?.air == src)
			return dogmos_fusion_status(pipe.parent)
	return dogmos_fusion_status(target)
