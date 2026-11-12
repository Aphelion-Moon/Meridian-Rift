/**
 * A game event that lands general dirt through the gate, dirt_source_land(). It's never made. The gate reads its cause,
 * material, level, chance, cooldown and deferred off the type, and keys its cooldown by the type. The event's own procs
 * read the extra vars on subtypes, and pass the gate what the event works out, such as a slime's colour.
 */
/datum/dirt_source
	/// A DIRT_CAUSE_* define, or null where the call passes it.
	var/cause
	/// A DIRT_MATERIAL_* define, or null where the call passes it.
	var/material
	/// The deposit's level where the call passes none. dirt_land() keeps it from 1 up to the cause's top.
	var/level = 1
	/// The chance that it lands, in percent, where the call passes none.
	var/chance = 100
	/// How long, in deciseconds, one roll of the chance holds off the next on a person, landed or not, or 0 for none.
	var/cooldown = 0
	/// Whether its landings wait for a later fire of SSdirt (/datum/dirt_job/landing), for a source that can reach a
	/// crowd in one tick.
	var/deferred = FALSE

/// Slime, in the colour that the call passes.
/datum/dirt_source/slime
	material = DIRT_MATERIAL_SLIME

/datum/dirt_source/slime/slimed_status
	cause = DIRT_CAUSE_SLIMED
	level = 2

/// A slime's hit. It lands where it hit, and every zone shares the one cooldown.
/datum/dirt_source/slime/hit
	cooldown = 5 SECONDS

/// A slime person's touch. Each kind of touch keeps a cooldown for each place on the body it lands, by slime cause.
/datum/dirt_source/slime/touch
	cooldown = 10 SECONDS

/datum/dirt_source/slime/touch/hug
	/// The level of a bear hug, which is a hug while the hugger holds an aggressive grab or stronger.
	var/bear_hug_level = 2

/datum/dirt_source/slime/touch/head_pat

/datum/dirt_source/slime/touch/grab

/// Tool work on a machine, a vehicle, a mech or a cyborg.
/datum/dirt_source/tool_work
	cause = DIRT_CAUSE_MACHINE
	chance = 15
	cooldown = 30 SECONDS
	/// The chance, in percent, that it lands on an engineer, in place of chance.
	var/engineer_chance = 5

/// Walking or crawling over a dirty decal. It has no cooldown, but floor_check_interval limits how often it looks.
/datum/dirt_source/floor_decal
	chance = 3
	/// The chance, in percent, that it lands on someone lying down, in place of chance.
	var/crawl_chance = 15
	/// The least time, in deciseconds, between two looks at the floor under one person.
	var/floor_check_interval = 2 SECONDS

/datum/dirt_source/oil_pool
	cooldown = 20 SECONDS

/datum/dirt_source/soot
	material = DIRT_MATERIAL_SOOT
	deferred = TRUE

/// An explosion, which lands at a level equal to its severity.
/datum/dirt_source/soot/blast
	cause = DIRT_CAUSE_BLAST

/// Catching fire, and the fire going out.
/datum/dirt_source/soot/fire
	cause = DIRT_CAUSE_SMOKE
	/// The least time, in deciseconds, that someone burns before their fire going out lands soot again.
	var/burn_time = 5 SECONDS

/datum/dirt_source/soot/smoke
	cause = DIRT_CAUSE_SMOKE
	cooldown = 15 SECONDS

/datum/dirt_source/mining
	cause = DIRT_CAUSE_DUST
	material = DIRT_MATERIAL_DUST
	chance = 10
	cooldown = 20 SECONDS

/// A fall from standing, which lands what's underfoot.
/datum/dirt_source/fall
	cause = DIRT_CAUSE_FALL
	deferred = TRUE

/// Lying down by choice on a dirty spot.
/datum/dirt_source/resting
	cause = DIRT_CAUSE_CRAWL
	cooldown = 30 SECONDS

/// Each turn of rolling on a dirty spot, as stop, drop and roll puts out a fire.
/datum/dirt_source/rolling
	cause = DIRT_CAUSE_FALL
	cooldown = 10 SECONDS

/// Reagents touching someone. A splash and wading each keep a cooldown for each material.
/datum/dirt_source/reagents
	deferred = TRUE
	/// The least volume of a material that lands, in reagent units. Any less lands nothing and starts no cooldown.
	var/least_volume = 1

/datum/dirt_source/reagents/splash
	cause = DIRT_CAUSE_SPLASH
	cooldown = 5 SECONDS
	/// The volume of a material, in reagent units, from which a splash lands at level 2.
	var/level_2_volume = 10
	/// The volume of a material, in reagent units, from which a splash lands at level 3.
	var/level_3_volume = 30

/// Standing in liquid. It lands as walking at the ankles, and deeper as a plunge, one level for each depth past them.
/datum/dirt_source/reagents/wading
	cooldown = 5 SECONDS

/// Sweat, which lands on cloth only.
/datum/dirt_source/sweat
	cause = DIRT_CAUSE_SWEAT
	material = DIRT_MATERIAL_SWEAT

/// Working out, or an overheating core.
/datum/dirt_source/sweat/worked_up
	cooldown = 1 MINUTES
	/// The degrees a core can go over its normal temperature before it's overheating, as
	/// /datum/species/proc/body_temperature_skin() reckons it.
	var/overheating_margin = 10

/datum/dirt_source/sweat/climax
	level = 2

/datum/dirt_source/sweat/exhaustion
	level = 2

/**
 * The listener for the events on a person that land general dirt in a round. Every human but a preview dummy gets one
 * as it's made, and keeps it. It stores the cooldowns that the gate (dirt_source_land()) holds those events to.
 */
/datum/component/dirt_sources
	/// The world.time when each source with a cooldown can next roll its chance on this person, by its key
	/// (cooldown_key()). It's null until the first cooldown starts.
	var/alist/cooldown_ends
	/// The world.time when check_floor() next looks at the floor under this person. Every step reads it, so it's a
	/// var of its own, not a key in cooldown_ends.
	var/next_floor_check = 0
	/// The world.time when this person last caught fire, or null while they aren't burning.
	var/burning_since

/datum/component/dirt_sources/Initialize()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/dirt_sources/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(parent, COMSIG_STEP_ON_BLOOD, PROC_REF(on_stepped_in_pool))
	RegisterSignal(parent, COMSIG_CARBON_HELP_ACT, PROC_REF(on_helped))
	RegisterSignal(parent, COMSIG_LIVING_START_PULL, PROC_REF(on_started_pulling))
	RegisterSignal(parent, COMSIG_ATOM_EX_ACT, PROC_REF(on_blasted))
	RegisterSignal(parent, COMSIG_LIVING_IGNITED, PROC_REF(on_ignited))
	RegisterSignal(parent, COMSIG_LIVING_EXTINGUISHED, PROC_REF(on_extinguished))
	RegisterSignal(parent, COMSIG_CARBON_EXPOSED_TO_SMOKE, PROC_REF(on_smoked))
	RegisterSignal(parent, COMSIG_MOB_MINED, PROC_REF(on_mined))
	RegisterSignal(parent, COMSIG_LIVING_THUD, PROC_REF(on_fell))
	RegisterSignal(parent, COMSIG_LIVING_RESTING, PROC_REF(on_resting_changed))
	RegisterSignal(parent, COMSIG_ATOM_EXPOSE_REAGENTS, PROC_REF(on_exposed_to_reagents))
	RegisterSignal(parent, COMSIG_MOB_CLIMAXED, PROC_REF(on_climaxed))
	RegisterSignal(parent, COMSIG_LIVING_ENTER_STAMCRIT, PROC_REF(on_exhausted))
	RegisterSignal(parent, COMSIG_HUMAN_CORETEMP_CHANGE, PROC_REF(on_core_temperature_changed))

/datum/component/dirt_sources/UnregisterFromParent()
	UnregisterSignal(parent, list(
		COMSIG_MOVABLE_MOVED,
		COMSIG_STEP_ON_BLOOD,
		COMSIG_CARBON_HELP_ACT,
		COMSIG_LIVING_START_PULL,
		COMSIG_ATOM_EX_ACT,
		COMSIG_LIVING_IGNITED,
		COMSIG_LIVING_EXTINGUISHED,
		COMSIG_CARBON_EXPOSED_TO_SMOKE,
		COMSIG_MOB_MINED,
		COMSIG_LIVING_THUD,
		COMSIG_LIVING_RESTING,
		COMSIG_ATOM_EXPOSE_REAGENTS,
		COMSIG_MOB_CLIMAXED,
		COMSIG_LIVING_ENTER_STAMCRIT,
		COMSIG_HUMAN_CORETEMP_CHANGE,
	))

/// Returns whether a source's cooldown on this person hasn't run out. cooldown_per is what splits the cooldown, such
/// as a material, or null for one cooldown.
/datum/component/dirt_sources/proc/cooling_down(source_type, cooldown_per)
	return cooldown_ends?[cooldown_key(source_type, cooldown_per)] > world.time

/// Starts a source's cooldown on this person, split by cooldown_per as in cooling_down().
/datum/component/dirt_sources/proc/start_cooldown(datum/dirt_source/source_type, cooldown_per)
	cooldown_ends ||= alist()
	cooldown_ends[cooldown_key(source_type, cooldown_per)] = world.time + initial(source_type.cooldown)

/// Returns the key a source's cooldown is kept under.
/datum/component/dirt_sources/proc/cooldown_key(source_type, cooldown_per)
	return isnull(cooldown_per) ? source_type : "[source_type] [cooldown_per]"

/**
 * Lands a game event's general dirt on a person through dirt_land(), as often as the event allows. Every source in a
 * round lands its dirt here, never through dirt_land() itself.
 *
 * It refuses anything but a human. It also refuses a body being deleted and the plain monkey species, which mess
 * leaves out too (dirt_mess_regions()). It refuses a human without a /datum/component/dirt_sources, such as a preview
 * dummy. It refuses a landing whose cooldown hasn't run out, and a landing that waits while DIRT_LANDINGS_WAITING
 * landings already wait. A refusal starts no cooldown. Past the refusals, it rolls the chance. The roll starts the
 * cooldown whether it passes or not. So a cooldown caps how often a source rolls, and a source sent every tick can't
 * call dirt_land() every tick. A dead body still takes dirt.
 *
 * Arguments:
 * - source_type: The source, a /datum/dirt_source subtype. Its values fill in cause, material, level and chance where
 *   they're null.
 * - colour: Slime's colour, "#RRGGBB", with DIRT_MATERIAL_SLIME.
 * - cooldown_per: What splits the source's cooldown, such as a material, or null for one cooldown.
 * - chance: The chance, in percent, that it lands.
 *
 * Returns how many carriers it landed on, as dirt_land() does. A carrier is what holds a person's dirt, such as the
 * skin or a worn item. A landing that waits returns 0.
 */
/proc/dirt_source_land(mob/living/carbon/human/target, datum/dirt_source/source_type, cause, material, level, colour, cooldown_per, chance)
	SHOULD_NOT_SLEEP(TRUE)
	if(!ishuman(target) || QDELETED(target) || target.dna?.species?.type == /datum/species/monkey)
		return 0
	var/datum/component/dirt_sources/sources = target.GetComponent(/datum/component/dirt_sources)
	var/cooldown = initial(source_type.cooldown)
	var/deferred = initial(source_type.deferred)
	if(!sources || (cooldown && sources.cooling_down(source_type, cooldown_per)) || (deferred && SSdirt.landings_waiting >= DIRT_LANDINGS_WAITING))
		return 0
	if(cooldown)
		sources.start_cooldown(source_type, cooldown_per)
	if(isnull(chance))
		chance = initial(source_type.chance)
	if(!prob(chance))
		return 0
	if(isnull(cause))
		cause = initial(source_type.cause)
	if(isnull(material))
		material = initial(source_type.material)
	if(isnull(level))
		level = initial(source_type.level)
	if(deferred)
		SSdirt.add(new /datum/dirt_job/landing(target, cause, material, level, colour))
		SSdirt.landings_waiting++
		return 0
	return dirt_land(target, cause, material, level, colour = colour)

/// A landing that waits for a later SSdirt fire (dirt_source_land()). What it lands is fixed when the event happens.
/datum/dirt_job/landing
	/// A weak reference to the person it lands on.
	var/datum/weakref/target_ref
	/// A DIRT_CAUSE_* define.
	var/cause
	/// A DIRT_MATERIAL_* define.
	var/material
	/// The deposit's level, which dirt_land() keeps from 1 up to the cause's top.
	var/level
	/// Slime's colour, "#RRGGBB", with DIRT_MATERIAL_SLIME.
	var/colour

/// Notes what lands, as dirt_land() takes it, and on whom.
/datum/dirt_job/landing/New(mob/living/carbon/human/target, cause, material, level, colour)
	target_ref = WEAKREF(target)
	src.cause = cause
	src.material = material
	src.level = level
	src.colour = colour

/// Lands it in one piece, unless the person was deleted or is now the plain monkey species.
/datum/dirt_job/landing/next_piece()
	var/mob/living/carbon/human/target = target_ref.resolve()
	if(target && target.dna?.species?.type != /datum/species/monkey)
		dirt_land(target, cause, material, level, colour = colour)
	return TRUE

/// Counts it out of SSdirt.landings_waiting.
/datum/dirt_job/landing/finished()
	SSdirt.landings_waiting--

/// Looks at the floor under the person who moved, unless they were moved by force, such as by a teleport.
/datum/component/dirt_sources/proc/on_moved(datum/source, atom/old_loc, movement_dir, forced)
	SIGNAL_HANDLER
	if(!forced && world.time >= next_floor_check)
		check_floor()

/**
 * Lands the dirt of a dirty decal on the floor (dirt_underfoot_material()) on the person over it, by chance. It lands
 * as walking, or as crawling while they lie down. It looks at most once in the floor decal source's
 * floor_check_interval, whether it finds dirt or not, because every step asks it to. Nothing lands on someone
 * buckled, thrown or off the ground.
 *
 * Arguments:
 * - walk_chance: The chance, in percent, that it lands on someone walking, or null for the floor decal source's.
 * - crawl_chance: The chance, in percent, that it lands on someone lying down, or null for the floor decal source's.
 *
 * Returns how many carriers it landed on.
 */
/datum/component/dirt_sources/proc/check_floor(walk_chance, crawl_chance)
	if(world.time < next_floor_check)
		return 0
	next_floor_check = world.time + /datum/dirt_source/floor_decal::floor_check_interval
	var/mob/living/carbon/human/walker = parent
	if(!dirt_touches_floor(walker))
		return 0
	var/material = dirt_underfoot_material(walker.loc)
	if(!material)
		return 0
	if(walker.body_position != LYING_DOWN)
		return dirt_source_land(walker, /datum/dirt_source/floor_decal, DIRT_CAUSE_WALK, material, chance = walk_chance)
	if(isnull(crawl_chance))
		crawl_chance = /datum/dirt_source/floor_decal::crawl_chance
	return dirt_source_land(walker, /datum/dirt_source/floor_decal, DIRT_CAUSE_CRAWL, material, chance = crawl_chance)

/// Lands a wet oil pool's oil on the person stepping or crawling into it. Other blood leaves nothing.
/datum/component/dirt_sources/proc/on_stepped_in_pool(mob/living/carbon/human/source, obj/effect/decal/cleanable/blood/pool)
	SIGNAL_HANDLER
	var/material = dirt_decal_materials()[pool.type]
	if(material && dirt_touches_floor(source))
		dirt_source_land(source, /datum/dirt_source/oil_pool, source.body_position == LYING_DOWN ? DIRT_CAUSE_CRAWL : DIRT_CAUSE_WALK, material)

/**
 * Lands a slime person's hug or head pat as slime on the other person, either way round (dirt_slime_touch()). A pat
 * lands on the head of the one patted and on the patting arm. A hug lands on both chests, at bear_hug_level for a bear
 * hug. Shaking someone awake and pulling a tail land nothing. The signal doesn't say which of these help_shake_act()
 * did, so this proc works it out again the way help_shake_act() picks it. It can't tell a fake tail ripped off a kitty
 * hat from a hug, so that lands as a hug.
 */
/datum/component/dirt_sources/proc/on_helped(mob/living/carbon/human/source, mob/living/carbon/helper)
	SIGNAL_HANDLER
	if(!ishuman(helper) || source.body_position == LYING_DOWN)
		return
	if(check_zone(helper.zone_selected) == BODY_ZONE_HEAD && source.get_bodypart(BODY_ZONE_HEAD))
		dirt_slime_touch(helper, source, /datum/dirt_source/slime/touch/head_pat, DIRT_CAUSE_SLIMED_HEAD, dirt_hand_slime_cause(helper))
		return
	if(helper.zone_selected == BODY_ZONE_PRECISE_GROIN && source.get_organ_by_type(/obj/item/organ/tail))
		return
	var/hug_level = /datum/dirt_source/slime/touch/hug::level
	if(helper.grab_state >= GRAB_AGGRESSIVE)
		hug_level = /datum/dirt_source/slime/touch/hug::bear_hug_level
	dirt_slime_touch(helper, source, /datum/dirt_source/slime/touch/hug, DIRT_CAUSE_SLIMED_CHEST, DIRT_CAUSE_SLIMED_CHEST, hug_level)

/// Lands a slime person's grab as slime, either way round (dirt_slime_touch()). It lands on the one grabbed where the
/// grabber aimed, folded onto its base zone, and on the grabbing arm.
/datum/component/dirt_sources/proc/on_started_pulling(mob/living/carbon/human/source, atom/movable/pulled)
	SIGNAL_HANDLER
	if(ishuman(pulled))
		dirt_slime_touch(source, pulled, /datum/dirt_source/slime/touch/grab, dirt_slime_cause(source.zone_selected), dirt_hand_slime_cause(source))

/// Lands a blast's soot at the explosion's severity. The signal comes before the blast acts, and the landing waits
/// until after it, so a body the blast gibs takes none.
/datum/component/dirt_sources/proc/on_blasted(mob/living/carbon/human/source, severity)
	SIGNAL_HANDLER
	if(severity)
		dirt_source_land(source, /datum/dirt_source/soot/blast, level = severity)

/// Lands soot on someone catching fire, unless they're burning already.
/datum/component/dirt_sources/proc/on_ignited(mob/living/carbon/human/source)
	SIGNAL_HANDLER
	if(!isnull(burning_since))
		return
	burning_since = world.time
	dirt_source_land(source, /datum/dirt_source/soot/fire)

/// Lands soot again on someone whose fire goes out after it burned for the fire source's burn_time or longer.
/datum/component/dirt_sources/proc/on_extinguished(mob/living/carbon/human/source)
	SIGNAL_HANDLER
	if(!isnull(burning_since) && world.time - burning_since >= /datum/dirt_source/soot/fire::burn_time)
		dirt_source_land(source, /datum/dirt_source/soot/fire)
	burning_since = null

/// Lands smoke's soot on someone in it.
/datum/component/dirt_sources/proc/on_smoked(mob/living/carbon/human/source)
	SIGNAL_HANDLER
	dirt_source_land(source, /datum/dirt_source/soot/smoke)

/// Lands dust on a miner who broke the rock from beside it, not from range.
/datum/component/dirt_sources/proc/on_mined(mob/living/carbon/human/source, turf/closed/mineral/rock)
	SIGNAL_HANDLER
	if(isturf(source.loc) && get_dist(source, rock) <= 1)
		dirt_source_land(source, /datum/dirt_source/mining)

/// Lands what's underfoot (dirt_fall_material()) on someone who falls from standing.
/datum/component/dirt_sources/proc/on_fell(mob/living/carbon/human/source)
	SIGNAL_HANDLER
	if(source.body_position != STANDING_UP || !dirt_touches_floor(source))
		return
	var/material = dirt_fall_material(source.loc)
	if(material)
		dirt_source_land(source, /datum/dirt_source/fall, material = material)

/// Lands a dirty spot's crawling marks on someone who lies down on it by choice. A knockdown is a fall (on_fell()).
/datum/component/dirt_sources/proc/on_resting_changed(mob/living/carbon/human/source, new_resting)
	SIGNAL_HANDLER
	if(new_resting && source.body_position == LYING_DOWN && !HAS_TRAIT(source, TRAIT_FLOORED))
		dirt_lie_on_spot(source, /datum/dirt_source/resting)

/// Lands the material of the reagents touching someone, for each material with the source's least_volume or more.
/// While they stand in liquid ankle deep or more, a touch from a holder with no atom is wading. That's because no
/// other such touch is expected to carry a reagent that dirties. Anything else is a splash.
/datum/component/dirt_sources/proc/on_exposed_to_reagents(mob/living/carbon/human/source, list/reagents, datum/reagents/source_holder, methods)
	SIGNAL_HANDLER
	if(!(methods & (TOUCH|VAPOR)))
		return
	var/wading_depth = ((methods & TOUCH) && source_holder && isnull(source_holder.my_atom)) ? dirt_wading_depth(source) : 0
	var/datum/dirt_source/reagents/source_type = wading_depth ? /datum/dirt_source/reagents/wading : /datum/dirt_source/reagents/splash
	var/alist/materials = dirt_reagent_materials()
	var/alist/volumes
	var/slime_colour
	for(var/datum/reagent/reagent as anything in reagents)
		var/material = materials[reagent.type]
		if(!material || cooling_down(source_type, material))
			continue
		if(material == DIRT_MATERIAL_SLIME)
			slime_colour = dirt_reagent_colour(reagent)
			if(!slime_colour)
				continue
		volumes ||= alist()
		volumes[material] += reagents[reagent]
	if(!volumes)
		return
	var/least_volume = initial(source_type.least_volume)
	for(var/material, volume in volumes)
		if(volume >= least_volume)
			dirt_reagent_land(source, material, volume, material == DIRT_MATERIAL_SLIME ? slime_colour : null, wading_depth)

/// Lands the sweat of a climax.
/datum/component/dirt_sources/proc/on_climaxed(mob/living/carbon/human/source)
	SIGNAL_HANDLER
	dirt_source_land(source, /datum/dirt_source/sweat/climax)

/// Lands the sweat of collapsing from exhaustion, unless they're in water.
/datum/component/dirt_sources/proc/on_exhausted(mob/living/carbon/human/source)
	SIGNAL_HANDLER
	if(!HAS_TRAIT(source, TRAIT_IMMERSED))
		dirt_source_land(source, /datum/dirt_source/sweat/exhaustion)

/// Works up a sweat on a body whose core is overheating (dirt_work_up_sweat()).
/datum/component/dirt_sources/proc/on_core_temperature_changed(mob/living/carbon/human/source, old_temperature, new_temperature)
	SIGNAL_HANDLER
	if(new_temperature > source.get_body_temp_normal(apply_change = FALSE) + /datum/dirt_source/sweat/worked_up::overheating_margin && source.stat != DEAD && !cooling_down(/datum/dirt_source/sweat/worked_up))
		dirt_work_up_sweat(source)

/// Returns whether a person touches the floor they're on.
/proc/dirt_touches_floor(mob/living/carbon/human/person)
	return isturf(person.loc) && !person.buckled && !person.throwing && !(person.movement_type & MOVETYPES_NOT_TOUCHING_GROUND)

/**
 * Returns what each dirty floor decal leaves on someone moving over it, by its type and each of its subtypes:
 * alist(decal type = DIRT_MATERIAL_* define). Glitter, vomit and every blood but oil leave nothing. You should NEVER
 * modify it.
 */
/proc/dirt_decal_materials()
	RETURN_TYPE(/alist)
	var/static/alist/materials
	if(!materials)
		// a subtype after its parent, so it keeps its own
		materials = dirt_with_subtypes(list(
			/obj/effect/decal/cleanable/dirt = DIRT_MATERIAL_GRIME,
			/obj/effect/decal/cleanable/dirt/dust = DIRT_MATERIAL_DUST,
			/obj/effect/decal/cleanable/ash = DIRT_MATERIAL_ASH,
			/obj/effect/decal/cleanable/food/flour = DIRT_MATERIAL_PLASTER,
			/obj/effect/decal/cleanable/concrete_dust = DIRT_MATERIAL_PLASTER,
			/obj/effect/decal/cleanable/garbage = DIRT_MATERIAL_GRIME,
			/obj/effect/decal/cleanable/rubble = DIRT_MATERIAL_DUST,
			/obj/effect/decal/cleanable/blood/oil = DIRT_MATERIAL_OIL,
		))
	return materials

/// Returns what the first dirty decal on a floor leaves (dirt_decal_materials()), or null. Blood is left out, because a
/// wet oil pool lands its oil as it's stepped in (/datum/component/dirt_sources/proc/on_stepped_in_pool()).
/proc/dirt_underfoot_material(turf/floor)
	var/alist/materials = dirt_decal_materials()
	for(var/obj/effect/decal/cleanable/decal in floor)
		if(!istype(decal, /obj/effect/decal/cleanable/blood) && materials[decal.type])
			return materials[decal.type]
	return null

/// Returns the slime cause for a BODY_ZONE_* define, precise or not, folded onto its base zone (check_zone()).
/proc/dirt_slime_cause(zone)
	var/static/alist/causes = alist(
		BODY_ZONE_HEAD = DIRT_CAUSE_SLIMED_HEAD,
		BODY_ZONE_CHEST = DIRT_CAUSE_SLIMED_CHEST,
		BODY_ZONE_R_ARM = DIRT_CAUSE_SLIMED_R_ARM,
		BODY_ZONE_L_ARM = DIRT_CAUSE_SLIMED_L_ARM,
		BODY_ZONE_R_LEG = DIRT_CAUSE_SLIMED_R_LEG,
		BODY_ZONE_L_LEG = DIRT_CAUSE_SLIMED_L_LEG,
	)
	return causes[check_zone(zone)]

/// Returns the slime cause for the arm of the hand a person is using.
/proc/dirt_hand_slime_cause(mob/living/carbon/human/person)
	return IS_LEFT_INDEX(person.active_hand_index) ? DIRT_CAUSE_SLIMED_L_ARM : DIRT_CAUSE_SLIMED_R_ARM

/// Returns the colour a slime's slime lands in, its type's rgb_code. A rainbow slime's own colour is grey, so it lands
/// a random slime type's.
/proc/dirt_slime_colour(colour, rainbow)
	if(!rainbow)
		return colour
	var/static/list/colours
	if(!colours)
		colours = list()
		for(var/datum/slime_type/slime_type as anything in subtypesof(/datum/slime_type))
			if(initial(slime_type.colour) != SLIME_TYPE_RAINBOW)
				colours |= initial(slime_type.rgb_code)
	return pick(colours)

/// Lands a slime's hit as slime in its colour on the zone it aimed at. A chest hit from behind lands on the back. For
/// a slime with no player, /datum/element/attack_zone_randomiser picks that zone.
/proc/dirt_slime_hit(mob/living/basic/slime/attacker, mob/living/carbon/human/victim)
	var/cause = dirt_slime_cause(attacker.zone_selected)
	if(cause == DIRT_CAUSE_SLIMED_CHEST && (get_dir(victim, attacker) & REVERSE_DIR(victim.dir)))
		cause = DIRT_CAUSE_SLIMED_BACK
	var/datum/slime_type/slime_type = attacker.slime_type
	return dirt_source_land(victim, /datum/dirt_source/slime/hit, cause, colour = dirt_slime_colour(slime_type.rgb_code, slime_type.colour == SLIME_TYPE_RAINBOW))

/// Returns a slime person's colour, their mutant colour, or null for anyone else and for a colour that isn't "#RRGGBB".
/proc/dirt_jelly_colour(mob/living/carbon/human/person)
	if(!isjellyperson(person))
		return null
	var/colour = person.dna.features[FEATURE_MUTANT_COLOR]
	return dirt_material(DIRT_MATERIAL_SLIME, colour) ? colour : null

/**
 * Lands slime where a slime person touched someone, in the slime person's colour. It works both ways. If the one
 * touched is the slime person, the one touching takes theirs, and two slime people each take the other's. Each kind of
 * touch keeps a cooldown for each slime cause it lands on. So a grab doesn't hold off the bear hug that follows it.
 *
 * Arguments:
 * - touch_type: What kind of touch it was, a /datum/dirt_source/slime/touch subtype.
 * - touched_cause: The slime cause for where it lands on the one touched.
 * - toucher_cause: The slime cause for where it lands on the one touching.
 * - level: The deposit's level, or null for the touch's own.
 */
/proc/dirt_slime_touch(mob/living/carbon/human/toucher, mob/living/carbon/human/touched, touch_type, touched_cause, toucher_cause, level)
	var/toucher_colour = dirt_jelly_colour(toucher)
	if(toucher_colour)
		dirt_source_land(touched, touch_type, touched_cause, level = level, colour = toucher_colour, cooldown_per = touched_cause)
	var/touched_colour = dirt_jelly_colour(touched)
	if(touched_colour)
		dirt_source_land(toucher, touch_type, toucher_cause, level = level, colour = touched_colour, cooldown_per = toucher_cause)

/**
 * Lands machine work's dirt on someone who finished a tool job, by chance. A machine leaves grease, and a vehicle, a
 * mech or a cyborg leaves oil. Only a job with a tool in dirty_tools counts, so a scan or a multitool link leaves
 * nothing. Engineers roll a lower chance. Someone with no mind or job isn't one.
 *
 * Arguments:
 * - tool_behaviour: The tool's TOOL_* behaviour, as tool_act() reads it.
 * - chance: The chance, in percent, that it lands on someone outside engineering, or null for the tool work source's.
 * - engineer_chance: The chance, in percent, that it lands on an engineer, or null for the tool work source's.
 *
 * Returns how many carriers it landed on.
 */
/proc/dirt_tool_work(mob/living/worker, atom/worked, tool_behaviour, chance, engineer_chance)
	var/static/list/dirty_tools = list(TOOL_WRENCH, TOOL_SCREWDRIVER, TOOL_CROWBAR, TOOL_WELDER, TOOL_WIRECUTTER)
	if(!(tool_behaviour in dirty_tools))
		return 0
	// TODO: ask the skill system in place of the department
	if(worker.mind?.assigned_role?.departments_bitflags & DEPARTMENT_BITFLAG_ENGINEERING)
		chance = engineer_chance
		if(isnull(chance))
			chance = /datum/dirt_source/tool_work::engineer_chance
	return dirt_source_land(worker, /datum/dirt_source/tool_work, material = ismachinery(worked) ? DIRT_MATERIAL_GREASE : DIRT_MATERIAL_OIL, chance = chance)

/// Returns alist(type = value) for each type listed and each of its subtypes. A subtype listed after its parent keeps
/// its own value.
/proc/dirt_with_subtypes(list/by_type)
	RETURN_TYPE(/alist)
	var/alist/expanded = alist()
	for(var/listed_type, value in by_type)
		for(var/subtype in typesof(listed_type))
			expanded[subtype] = value
	return expanded

/// Returns what falling on the ground itself leaves, by turf type: alist(type = DIRT_MATERIAL_* define, or null for
/// nothing). You should NEVER modify it.
/proc/dirt_ground_materials()
	RETURN_TYPE(/alist)
	var/static/alist/materials
	if(!materials)
		materials = dirt_with_subtypes(list(
			/turf/open/misc/dirt = DIRT_MATERIAL_DUST,
			/turf/open/misc/sandy_dirt = DIRT_MATERIAL_DUST,
			/turf/open/misc/beach = DIRT_MATERIAL_DUST,
			/turf/open/misc/beach/coast = null,
			/turf/open/misc/ironsand = DIRT_MATERIAL_DUST,
			/turf/open/misc/ironsand/ocean = null,
			/turf/open/misc/asteroid = DIRT_MATERIAL_DUST,
			/turf/open/misc/asteroid/basalt = null,
			/turf/open/misc/asteroid/forest = null,
			/turf/open/misc/asteroid/snow = null,
			/turf/open/misc/ashplanet = DIRT_MATERIAL_ASH,
			/turf/open/misc/ashplanet/wateryrock = null,
		))
	return materials

/// Returns what a fall onto a floor lands: a dirty decal's, else a wet oil pool's, else the ground's own, or null.
/proc/dirt_fall_material(turf/floor)
	var/material = dirt_underfoot_material(floor)
	if(material)
		return material
	var/alist/decal_materials = dirt_decal_materials()
	for(var/obj/effect/decal/cleanable/blood/pool in floor)
		if(!pool.dried && decal_materials[pool.type])
			return decal_materials[pool.type]
	return dirt_ground_materials()[floor.type]

/// Lands the dirt of the spot someone lies on (dirt_fall_material()) on them, as the source passed in, a
/// /datum/dirt_source subtype. If the spot is clean or they don't touch the floor, nothing lands.
/proc/dirt_lie_on_spot(mob/living/carbon/human/person, source_type)
	if(!dirt_touches_floor(person))
		return
	var/material = dirt_fall_material(person.loc)
	if(material)
		dirt_source_land(person, source_type, material = material)

/// Returns what each reagent that dirties leaves on someone it touches, by its type and each of its subtypes:
/// alist(reagent type = DIRT_MATERIAL_* define). You should NEVER modify it.
/proc/dirt_reagent_materials()
	RETURN_TYPE(/alist)
	var/static/alist/materials
	if(!materials)
		materials = dirt_with_subtypes(list(
			/datum/reagent/fuel/oil = DIRT_MATERIAL_OIL,
			/datum/reagent/drug/maint/tar = DIRT_MATERIAL_OIL,
			/datum/reagent/consumable/nutriment/fat/oil = DIRT_MATERIAL_GREASE,
			/datum/reagent/lube = DIRT_MATERIAL_GREASE,
			/datum/reagent/carbon = DIRT_MATERIAL_SOOT,
			/datum/reagent/ash = DIRT_MATERIAL_ASH,
			/datum/reagent/cement = DIRT_MATERIAL_PLASTER,
			/datum/reagent/concrete = DIRT_MATERIAL_PLASTER,
			/datum/reagent/concrete_mix = DIRT_MATERIAL_PLASTER,
			/datum/reagent/consumable/flour = DIRT_MATERIAL_PLASTER,
			/datum/reagent/toxin/slimejelly = DIRT_MATERIAL_SLIME,
		))
	return materials

/// Returns a reagent's colour as "#RRGGBB", its alpha left off, or null if it isn't one.
/proc/dirt_reagent_colour(datum/reagent/reagent)
	var/colour = reagent.color
	if(!istext(colour))
		return null
	if(copytext(colour, 1, 2) != "#")
		colour = "#[colour]"
	colour = copytext(colour, 1, 8)
	return dirt_material(DIRT_MATERIAL_SLIME, colour) ? colour : null

/// Returns how deep a person stands in liquid, a LIQUID_STATE_* define, or 0 under the ankles. Lying in it counts
/// deeper, as the liquid's own exposure counts it.
/proc/dirt_wading_depth(mob/living/carbon/human/person)
	var/turf/floor = person.loc
	if(!isturf(floor) || !floor.liquids || floor.liquids.liquid_state < LIQUID_STATE_ANKLES)
		return 0
	if(person.body_position == LYING_DOWN)
		return min(floor.liquids.liquid_state + LYING_DOWN_SUBMERGEMENT_STATE_BONUS, LIQUID_STATE_FULLTILE)
	return floor.liquids.liquid_state

/**
 * Lands a material from reagents on someone they touched, as wading in the liquid they stand in or as a splash.
 *
 * Arguments:
 * - volume: How much of the material's reagents touched them, in reagent units.
 * - colour: Slime's colour, "#RRGGBB", with DIRT_MATERIAL_SLIME.
 * - wading_depth: How deep they stand in the liquid that touched them (dirt_wading_depth()), or 0 for a splash.
 */
/proc/dirt_reagent_land(mob/living/carbon/human/person, material, volume, colour, wading_depth)
	if(!wading_depth)
		var/splash_level = 1
		if(volume >= /datum/dirt_source/reagents/splash::level_3_volume)
			splash_level = 3
		else if(volume >= /datum/dirt_source/reagents/splash::level_2_volume)
			splash_level = 2
		dirt_source_land(person, /datum/dirt_source/reagents/splash, material = material, level = splash_level, colour = colour, cooldown_per = material)
	else if(wading_depth == LIQUID_STATE_ANKLES)
		dirt_source_land(person, /datum/dirt_source/reagents/wading, DIRT_CAUSE_WALK, material, colour = colour, cooldown_per = material)
	else
		dirt_source_land(person, /datum/dirt_source/reagents/wading, DIRT_CAUSE_PLUNGE, material, wading_depth - LIQUID_STATE_ANKLES, colour = colour, cooldown_per = material)

/// Lands the sweat of working out or overheating, unless they're in water. The two share one cooldown.
/proc/dirt_work_up_sweat(mob/living/carbon/human/person)
	if(!HAS_TRAIT(person, TRAIT_IMMERSED))
		dirt_source_land(person, /datum/dirt_source/sweat/worked_up)

/// Returns whether a person's underclothes or anything they wear holds sweat. Bare skin never does.
/proc/dirt_wears_sweat(mob/living/carbon/human/person)
	for(var/datum/component/dirtiness/carrier as anything in dirt_carriers(person))
		for(var/list/splats as anything in carrier.splat_lists())
			for(var/datum/dirt_splat/splat as anything in splats)
				if(splat.material == DIRT_MATERIAL_SWEAT)
					return TRUE
	return FALSE

#ifdef DIRT_SOURCES
/// Lands slime from above in the slime's colour as the status takes hold.
/datum/status_effect/slimed/on_apply()
	. = ..()
	if(.)
		dirt_source_land(owner, /datum/dirt_source/slime/slimed_status, colour = dirt_slime_colour(slime_color, rainbow))

/// Lands a hit that did something on a person as slime where it hit (dirt_slime_hit()).
/mob/living/basic/slime/melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	. = ..()
	if(. && ishuman(target))
		dirt_slime_hit(src, target)

/// Dirties whoever finished a tool job on the machine, by chance (dirt_tool_work()).
/obj/machinery/tool_act(mob/living/user, obj/item/tool, list/modifiers)
	. = ..()
	if(. & ITEM_INTERACT_SUCCESS)
		dirt_tool_work(user, src, tool.tool_behaviour)

/// Dirties whoever finished a tool job on the vehicle or mech, by chance (dirt_tool_work()).
/obj/vehicle/tool_act(mob/living/user, obj/item/tool, list/modifiers)
	. = ..()
	if(. & ITEM_INTERACT_SUCCESS)
		dirt_tool_work(user, src, tool.tool_behaviour)

/// Dirties whoever finished a tool job on the cyborg, by chance (dirt_tool_work()).
/mob/living/silicon/robot/tool_act(mob/living/user, obj/item/tool, list/modifiers)
	. = ..()
	if(. & ITEM_INTERACT_SUCCESS)
		dirt_tool_work(user, src, tool.tool_behaviour)

/// Works up a sweat as a workout starts.
/datum/status_effect/exercised/on_apply()
	. = ..()
	if(.)
		dirt_work_up_sweat(owner)

/// Works up a sweat as a workout goes on.
/datum/status_effect/exercised/refresh(effect, bonus_time)
	. = ..()
	dirt_work_up_sweat(owner)

/// Lands the spot's dirt on the person as they roll on the floor to put out the fire.
/datum/status_effect/stop_drop_roll/reduce_firestacks(amt = 1)
	. = ..()
	dirt_lie_on_spot(owner, /datum/dirt_source/rolling)

/// Lands the spot's dirt on the person as they roll on the floor to put out the imagined fire.
/datum/status_effect/stop_drop_roll/hallucinating/reduce_firestacks(amt = 1)
	. = ..()
	dirt_lie_on_spot(owner, /datum/dirt_source/rolling)
#endif
