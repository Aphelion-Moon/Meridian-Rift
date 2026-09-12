/datum/psionic_rank_variant/kinetic_shove
	rank = PSIONIC_RANK_GAMMA
	variant_name = "shove"
	description = "A forceful shove that hurls one target back, knocking them down and hurting them if they crash into a wall or another person."
	strain_gain = 16
	cooldown_time = 12 SECONDS
	cast_range = 5
	/// Distance this form throws affected atoms.
	var/throw_distance = 4
	/// Whether thrown targets are harmless on impact.
	var/gentle_throw = FALSE
	/// Stamina damage dealt to living targets.
	var/stamina_damage = 30
	/// Knockdown applied to living targets.
	var/knockdown_time = 1.5 SECONDS
	/// If TRUE, this form erupts from the caster instead of requiring a target.
	var/radial_shove = FALSE
	/// Radius affected by radial forms.
	var/radial_range = 0
	block_charge_cost = 1
	block_message = "force dampened!"
	/// If TRUE, this form launches a wide advancing wave in a targeted direction.
	var/directional_wave = FALSE
	/// Distance travelled by directional waves.
	var/wave_range = 0
	/// Width of directional waves, centered on their travelling line.
	var/wave_width = 1
	/// Delay between each travelled wave tile.
	var/wave_step_delay = 0.2 SECONDS
	/// Brute damage dealt by directional waves.
	var/wave_brute_damage = 0
	/// Damage dealt to windows and grilles by directional waves.
	var/structure_damage = 0

/datum/psionic_rank_variant/kinetic_shove/epsilon
	rank = PSIONIC_RANK_EPSILON
	variant_name = "nudge"
	description = "A mild shove that bumps one target a short distance."
	strain_gain = 8
	cooldown_time = 8 SECONDS
	throw_distance = 2
	gentle_throw = TRUE
	stamina_damage = 8
	knockdown_time = 0

/datum/psionic_rank_variant/kinetic_shove/beta
	rank = PSIONIC_RANK_BETA
	variant_name = "kinetic wave"
	description = "A radial wave that shoves nearby things away from you."
	strain_gain = 30
	cooldown_time = 25 SECONDS
	throw_distance = 4
	gentle_throw = FALSE
	stamina_damage = 24
	knockdown_time = 1.5 SECONDS
	radial_shove = TRUE
	radial_range = 4
	block_charge_cost = 2

/datum/psionic_rank_variant/kinetic_shove/alpha
	rank = PSIONIC_RANK_ALPHA
	variant_name = "kinetic rupture"
	description = "A crushing wave that rolls forward, breaking bodies and structures in its path."
	strain_gain = 45
	cooldown_time = 45 SECONDS
	cast_range = 8
	throw_distance = 3
	stamina_damage = 0
	knockdown_time = 2 SECONDS
	block_charge_cost = 3
	directional_wave = TRUE
	wave_range = 8
	wave_width = 3
	wave_brute_damage = 35
	structure_damage = 75
	active_msg = "Space buckles around your hand. Pick a direction."
	deactive_msg = "The pressure in your hand collapses."

/datum/action/cooldown/psionic/pointed/kinetic_shove
	name = "Kinetic Shove"
	desc = "Throw a nearby target away with focused psionic force."
	button_icon_state = "psi_kinetic_shove"
	point_cost = 1
	psionic_flags = PSIONIC_KINETIC
	school = PSIONIC_SCHOOL_GRAVITY
	variant_type = /datum/psionic_rank_variant/kinetic_shove
	rank_variant_types = list(
		/datum/psionic_rank_variant/kinetic_shove/epsilon,
		/datum/psionic_rank_variant/kinetic_shove,
		/datum/psionic_rank_variant/kinetic_shove/beta,
		/datum/psionic_rank_variant/kinetic_shove/alpha,
	)

/datum/action/cooldown/psionic/pointed/kinetic_shove/is_self_cast_form()
	var/datum/psionic_rank_variant/kinetic_shove/form = get_form()
	return !!form?.radial_shove

/datum/action/cooldown/psionic/pointed/kinetic_shove/try_block_target(atom/target, datum/component/psionic_profile/profile)
	return FALSE

/datum/action/cooldown/psionic/pointed/kinetic_shove/is_valid_target(atom/target)
	var/datum/psionic_rank_variant/kinetic_shove/form = get_form()
	if(form?.radial_shove)
		return TRUE
	if(form?.directional_wave)
		return ..()

	. = ..()
	if(!.)
		return FALSE
	if(!ismovable(target))
		owner.balloon_alert(owner, "not movable!")
		return FALSE

	return TRUE

/datum/action/cooldown/psionic/pointed/kinetic_shove/psionic_activate(atom/target)
	var/mob/living/living_owner = owner
	if(!istype(living_owner))
		return FALSE

	var/datum/psionic_rank_variant/kinetic_shove/form = get_form()
	if(!form)
		return FALSE

	if(form.radial_shove)
		return radial_shove(living_owner, form)
	if(form.directional_wave)
		return start_kinetic_wave(living_owner, target, form)

	if(check_shove_block(target, form))
		return TRUE
	return shove_target(target, form)

/datum/action/cooldown/psionic/pointed/kinetic_shove/proc/check_shove_block(atom/target, datum/psionic_rank_variant/kinetic_shove/form, announce = TRUE)
	var/mob/living/living_target = target
	if(!istype(living_target))
		return FALSE
	if(!living_target.try_block_psionics(owner, PSIONIC_KINETIC, charge_cost = form.block_charge_cost, alert = form.block_message))
		return FALSE

	if(announce)
		to_chat(owner, span_warning("Your force breaks against [living_target]'s psionic dampening."))
	to_chat(living_target, span_warning("Invisible force breaks against your psionic dampening."))
	return TRUE

/datum/action/cooldown/psionic/pointed/kinetic_shove/proc/shove_target(atom/target, datum/psionic_rank_variant/kinetic_shove/form, announce = TRUE)
	var/atom/movable/movable_target = target
	if(!istype(movable_target))
		return FALSE

	var/mob/living/living_target = movable_target
	var/throw_direction = get_dir(owner, get_step_away(movable_target, owner))
	if(!throw_direction)
		throw_direction = get_dir(owner, movable_target)
	if(!throw_direction)
		throw_direction = pick(GLOB.cardinals)

	var/turf/throw_target = get_ranged_target_turf(movable_target, throw_direction, form.throw_distance)
	if(!throw_target)
		return FALSE

	if(announce)
		owner.visible_message(
			span_warning("[movable_target] lurches away from [owner] under invisible force."),
			span_notice("You shove [movable_target] with focused force."),
			ignored_mobs = movable_target,
		)
	if(istype(living_target))
		to_chat(living_target, span_userdanger("Invisible force slams into you!"))
		if(form.stamina_damage > 0)
			living_target.apply_damage(form.stamina_damage, STAMINA)
		if(form.knockdown_time > 0)
			living_target.Knockdown(form.knockdown_time)

	movable_target.safe_throw_at(throw_target, range = form.throw_distance, speed = 1, thrower = owner, gentle = form.gentle_throw)
	return TRUE

/** Launches a wave from a fixed turf, sharing hit and blocked-lane tracking between its delayed steps. */
/datum/action/cooldown/psionic/pointed/kinetic_shove/proc/start_kinetic_wave(mob/living/living_owner, atom/target, datum/psionic_rank_variant/kinetic_shove/form)
	var/turf/source_turf = get_turf(living_owner)
	var/turf/target_turf = get_turf(target)
	if(!source_turf || !target_turf)
		return FALSE

	var/wave_direction = get_cardinal_dir(source_turf, target_turf)
	if(!(wave_direction in GLOB.cardinals))
		wave_direction = living_owner.dir
	if(!(wave_direction in GLOB.cardinals))
		wave_direction = SOUTH

	living_owner.setDir(wave_direction)
	living_owner.visible_message(
		span_danger("The air in front of [living_owner] folds into a crushing wave!"),
		span_notice("You release a crushing wave of focused force."),
	)
	playsound(living_owner, 'sound/effects/magic/forcewall.ogg', 70, TRUE)

	var/manifestation_color = get_manifestation_color()
	var/list/hit_atoms = list()
	var/list/blocked_lanes = list()
	var/datum/weakref/owner_ref = WEAKREF(living_owner)
	for(var/step_number in 1 to form.wave_range)
		var/datum/callback/wave_step = new /datum/callback(
			src,
			PROC_REF(resolve_kinetic_wave_step),
			owner_ref,
			wave_direction,
			step_number,
			form,
			manifestation_color,
			hit_atoms,
			source_turf,
			blocked_lanes,
		)
		addtimer(wave_step, (step_number - 1) * form.wave_step_delay, TIMER_DELETE_ME)

	return TRUE

/** Resolves one wave row, stopping each lane at obstacles that survive its structural damage. */
/datum/action/cooldown/psionic/pointed/kinetic_shove/proc/resolve_kinetic_wave_step(datum/weakref/owner_ref, wave_direction, step_number, datum/psionic_rank_variant/kinetic_shove/form, manifestation_color, list/hit_atoms, turf/source_turf, list/blocked_lanes)
	var/mob/living/living_owner = owner_ref?.resolve()
	if(!istype(living_owner))
		return

	var/list/wave_turfs = get_kinetic_wave_turfs(source_turf, wave_direction, step_number, form)
	for(var/turf/wave_turf as anything in wave_turfs.Copy())
		var/lane_key = num2text((wave_direction & (NORTH|SOUTH)) ? wave_turf.x : wave_turf.y)
		if(blocked_lanes[lane_key])
			wave_turfs -= wave_turf
			continue

		damage_kinetic_wave_structures(wave_turf, living_owner, form, wave_direction)
		if(wave_turf.is_blocked_turf(exclude_mobs = TRUE))
			blocked_lanes[lane_key] = TRUE
			continue

		for(var/mob/living/living_target in wave_turf)
			if(living_target == living_owner || hit_atoms[living_target])
				continue

			hit_atoms[living_target] = TRUE
			hit_kinetic_wave_target(living_target, living_owner, wave_direction, form)

	if(length(wave_turfs))
		show_kinetic_wave_effects(wave_turfs, wave_direction, manifestation_color)
		playsound(wave_turfs[1], 'sound/effects/gravhit.ogg', 45, TRUE)

/** Returns a wave row relative to its launch turf, stopping at the map boundary. */
/datum/action/cooldown/psionic/pointed/kinetic_shove/proc/get_kinetic_wave_turfs(turf/source_turf, wave_direction, step_number, datum/psionic_rank_variant/kinetic_shove/form)
	var/turf/center_turf = get_ranged_target_turf(source_turf, wave_direction, step_number)
	if(!center_turf || get_dist(source_turf, center_turf) != step_number)
		return list()

	var/list/wave_turfs = list(center_turf)
	var/side_reach = max(0, round((form.wave_width - 1) / 2))
	if(side_reach <= 0)
		return wave_turfs

	for(var/side_direction in list(turn(wave_direction, 90), turn(wave_direction, -90)))
		var/turf/side_turf = center_turf
		for(var/offset in 1 to side_reach)
			side_turf = get_step(side_turf, side_direction)
			if(!side_turf)
				break
			wave_turfs += side_turf

	return wave_turfs

/datum/action/cooldown/psionic/pointed/kinetic_shove/proc/show_kinetic_wave_effects(list/wave_turfs, wave_direction, manifestation_color)
	for(var/turf/wave_turf as anything in wave_turfs)
		new /obj/effect/temp_visual/psionic/kinetic_fracture(wave_turf, manifestation_color)
		new /obj/effect/temp_visual/dir_setting/psionic/kinetic_distortion(wave_turf, wave_direction, manifestation_color)
		wave_turf.Shake(pixelshiftx = 1, pixelshifty = 1, duration = 0.4 SECONDS)

/** Damages structures from the wave's direction and attempts to break mineral turfs. */
/datum/action/cooldown/psionic/pointed/kinetic_shove/proc/damage_kinetic_wave_structures(turf/wave_turf, mob/living/living_owner, datum/psionic_rank_variant/kinetic_shove/form, wave_direction)
	for(var/obj/structure/window/window in wave_turf)
		window.take_damage(
			damage_amount = form.structure_damage,
			damage_type = BRUTE,
			damage_flag = MELEE,
			attack_dir = wave_direction,
			armour_penetration = 30,
		)
	for(var/obj/structure/grille/grille in wave_turf)
		grille.take_damage(
			damage_amount = form.structure_damage,
			damage_type = BRUTE,
			damage_flag = MELEE,
			attack_dir = wave_direction,
		)

	if(isindestructiblewall(wave_turf))
		return
	if(ismineralturf(wave_turf))
		var/turf/closed/mineral/mineral_turf = wave_turf
		mineral_turf.drill_aoe(living_owner)
		return
	if(!iswallturf(wave_turf))
		return

	var/turf/closed/wall/wall_turf = wave_turf
	wall_turf.add_dent(WALL_DENT_HIT)

/datum/action/cooldown/psionic/pointed/kinetic_shove/proc/hit_kinetic_wave_target(mob/living/living_target, mob/living/living_owner, wave_direction, datum/psionic_rank_variant/kinetic_shove/form)
	if(living_target.try_block_psionics(living_owner, PSIONIC_KINETIC, charge_cost = form.block_charge_cost, alert = form.block_message))
		to_chat(living_target, span_warning("Crushing force breaks against your psionic dampening."))
		return FALSE

	to_chat(living_target, span_userdanger("A crushing wave of invisible force slams into you!"))
	if(form.wave_brute_damage > 0)
		living_target.apply_damage(form.wave_brute_damage, BRUTE)
	if(form.knockdown_time > 0)
		living_target.Knockdown(form.knockdown_time)
	living_target.Shake(pixelshiftx = 2, pixelshifty = 2, duration = 0.5 SECONDS)

	var/turf/throw_target = get_ranged_target_turf(living_target, wave_direction, form.throw_distance)
	if(!throw_target)
		return TRUE

	living_target.safe_throw_at(
		throw_target,
		range = form.throw_distance,
		speed = 1,
		thrower = living_owner,
		spin = FALSE,
		force = MOVE_FORCE_STRONG,
		gentle = TRUE,
	)
	return TRUE

/datum/action/cooldown/psionic/pointed/kinetic_shove/proc/radial_shove(mob/living/living_owner, datum/psionic_rank_variant/kinetic_shove/form)
	living_owner.visible_message(
		span_warning("A wave of invisible force erupts from [living_owner]."),
		span_notice("You release a radial wave of focused force."),
	)
	show_radial_kinetic_effects(living_owner, get_manifestation_color())

	var/affected_anything = FALSE
	for(var/atom/movable/movable_target in view(form.radial_range, living_owner))
		if(movable_target == living_owner)
			continue
		if(movable_target.anchored)
			continue
		if(!isturf(movable_target.loc))
			continue
		if(check_shove_block(movable_target, form, announce = FALSE))
			continue

		if(shove_target(movable_target, form, announce = FALSE))
			affected_anything = TRUE

	if(!affected_anything)
		living_owner.balloon_alert(living_owner, "nothing moves")

	return TRUE

/datum/action/cooldown/psionic/pointed/kinetic_shove/proc/show_radial_kinetic_effects(mob/living/living_owner, manifestation_color)
	var/turf/center_turf = get_turf(living_owner)
	if(!center_turf)
		return

	var/center_direction = living_owner.dir
	if(!(center_direction in GLOB.cardinals))
		center_direction = SOUTH

	new /obj/effect/temp_visual/dir_setting/psionic/kinetic_distortion(center_turf, center_direction, manifestation_color)
	for(var/spark_direction in GLOB.cardinals)
		var/turf/spark_turf = get_step(center_turf, spark_direction)
		if(!spark_turf)
			continue

		new /obj/effect/temp_visual/dir_setting/psionic/kinetic_distortion(spark_turf, spark_direction, manifestation_color)

	living_owner.Shake(pixelshiftx = 1, pixelshifty = 1, duration = 0.4 SECONDS)

/obj/effect/temp_visual/psionic/kinetic_fracture
	name = "psionic fracture"
	icon_state = "purplecrack"
	duration = 1.5 SECONDS
	alpha = 180
	randomdir = TRUE
	psionic_light_range = 1.4

/obj/effect/temp_visual/dir_setting/psionic/kinetic_distortion
	name = "psionic distortion"
	icon_state = "shieldsparkles"
	duration = 0.6 SECONDS
	alpha = 140
	randomdir = FALSE

/obj/effect/temp_visual/dir_setting/psionic/kinetic_distortion/Initialize(mapload, set_dir, manifestation_color)
	. = ..()
	add_filter("psionic_kinetic_ripple", 1, list("type" = "ripple", "flags" = WAVE_BOUNDED, "radius" = 0, "size" = 2))
	animate(get_filter("psionic_kinetic_ripple"), radius = 16, size = 1, time = duration)
