/**
 * Delay between an impact and the rebound it causes.
 *
 * Must be nonzero. Impact signals fire inside [/datum/thrownthing/proc/finalize], and that throw's
 * Destroy() clears `throwing` and the SSthrowing entry of its movable. A rebound started synchronously
 * would be cancelled by that cleanup.
 */
#define BOUNCE_REBOUND_DELAY (0.1 SECONDS)
/// Rebounds shorter than this many tiles are dropped rather than animated as an imperceptible twitch.
#define BOUNCE_MINIMUM_DISTANCE 0.15
/// Furthest, in pixels, a sub-tile slide may move an object from its base offset, so it stays over its own tile.
#define BOUNCE_SLIDE_PIXEL_LIMIT 12
/// Tallest hop arc, in pixels.
#define BOUNCE_MAX_HOP_HEIGHT 12

/**
 * # Bouncy element
 *
 * Makes a thrown movable rebound after it hits something, losing distance on every rebound.
 *
 * - Striking a wall, structure or mob reflects the object off the obstacle's side.
 * - Landing on a hard floor can hop it onward in the same direction. Soft or non-solid turfs
 *   (those without a `bullet_bounce_sound`, such as grass, carpet, water, lava and space) absorb it.
 * - Objects can also hop away when ejected: ammo casings from a ballistic gun, or anything sent
 *   COMSIG_MOVABLE_BOUNCY_EJECTED, such as a slimeperson's core when its body melts.
 *
 * Rebounds of a tile or more are real throws with a hop arc. A rebound under a tile cannot leave its
 * turf, so it becomes a decelerating slide within the turf, which ends the chain.
 *
 * The throw a player makes behaves exactly as before, including damage and catching. Only the
 * rebounds are new, and a rebound striking an obstacle never calls hitby(): it does no damage, pushes
 * nothing and cannot be caught. Rebounds are skipped without gravity, where thrown objects already drift.
 */
/datum/element/bouncy
	element_flags = ELEMENT_BESPOKE
	argument_hash_start_idx = 2
	/// Fraction (0 to 1) of the incoming travel distance each rebound keeps. Lower values settle sooner.
	var/restitution
	/// Most rebounds one throw or ejection can chain into.
	var/max_bounces
	/// Whether landing on a hard floor hops the object onward, instead of only obstacles causing rebounds.
	var/floor_bounces
	/// Percent chance for each rebound to veer 45 degrees off its ideal direction.
	var/deflect_chance
	/// Sound played at each rebound, on top of the object's own landing sounds. Null for none.
	var/bounce_sound
	/// Volume of [/datum/element/bouncy/var/bounce_sound].
	var/bounce_sound_volume
	/// Tiles the object travels in a random direction when ejected: a casing from a ballistic gun, or anything sent COMSIG_MOVABLE_BOUNCY_EJECTED. Zero disables ejection hops.
	var/eject_hop_range

/datum/element/bouncy/Attach(datum/target, restitution = 0.5, max_bounces = 2, floor_bounces = TRUE, deflect_chance = 0, bounce_sound = null, bounce_sound_volume = 30, eject_hop_range = 0)
	. = ..()
	if(!ismovable(target))
		return ELEMENT_INCOMPATIBLE
	src.restitution = clamp(restitution, 0, 1)
	src.max_bounces = max_bounces
	src.floor_bounces = floor_bounces
	src.deflect_chance = deflect_chance
	src.bounce_sound = bounce_sound
	src.bounce_sound_volume = bounce_sound_volume
	src.eject_hop_range = eject_hop_range
	RegisterSignal(target, COMSIG_MOVABLE_PRE_IMPACT, PROC_REF(on_pre_impact))
	RegisterSignal(target, COMSIG_MOVABLE_IMPACT, PROC_REF(on_impact))
	if(eject_hop_range > 0)
		RegisterSignals(target, list(COMSIG_CASING_EJECTED, COMSIG_MOVABLE_BOUNCY_EJECTED), PROC_REF(on_ejected))

/datum/element/bouncy/Detach(datum/source)
	UnregisterSignal(source, list(COMSIG_MOVABLE_PRE_IMPACT, COMSIG_MOVABLE_IMPACT, COMSIG_CASING_EJECTED, COMSIG_MOVABLE_BOUNCY_EJECTED))
	return ..()

/**
 * Stops a rebound that strikes an obstacle from hitting it, and chains the next rebound instead.
 *
 * Rebound landings on the floor are left alone, so turf reactions such as lava igniting items still apply.
 * Those continue through [/datum/element/bouncy/proc/on_impact].
 */
/datum/element/bouncy/proc/on_pre_impact(atom/movable/source, atom/hit_atom, datum/thrownthing/throwingdatum)
	SIGNAL_HANDLER
	if(!istype(throwingdatum, /datum/thrownthing/bounce) || hit_atom == source.loc)
		return NONE
	var/datum/thrownthing/bounce/rebound_throw = throwingdatum
	queue_rebound(source, hit_atom, rebound_throw, rebound_throw.bounces_left)
	return COMPONENT_MOVABLE_IMPACT_NEVERMIND

/// Queues a rebound after an ordinary hit or a floor landing, unless the thing hit caught the object.
/datum/element/bouncy/proc/on_impact(atom/movable/source, atom/hit_atom, datum/thrownthing/throwingdatum, caught)
	SIGNAL_HANDLER
	if(caught)
		return
	var/bounces_left = max_bounces
	if(istype(throwingdatum, /datum/thrownthing/bounce))
		var/datum/thrownthing/bounce/rebound_throw = throwingdatum
		bounces_left = rebound_throw.bounces_left
	queue_rebound(source, hit_atom, throwingdatum, bounces_left)

/**
 * Sends a freshly ejected object off in a random direction.
 *
 * The launch is deferred. COMSIG_CASING_EJECTED is sent before the wielder tries to catch the casing, so a
 * caught casing is in a hand by the time [/datum/element/bouncy/proc/rebound] checks it, and stays there.
 */
/datum/element/bouncy/proc/on_ejected(atom/movable/source)
	SIGNAL_HANDLER
	addtimer(CALLBACK(src, PROC_REF(rebound), WEAKREF(source), pick(GLOB.alldirs), eject_hop_range, source.throw_speed, max_bounces), BOUNCE_REBOUND_DELAY)

/**
 * Works out where the rebound from one impact goes and schedules it.
 *
 * Arguments:
 * * source - The bouncing movable.
 * * hit_atom - What the throw struck. Its own turf when it landed on the floor.
 * * throwingdatum - The throw that just ended.
 * * bounces_left - Rebounds still allowed, including the one being queued.
 */
/datum/element/bouncy/proc/queue_rebound(atom/movable/source, atom/hit_atom, datum/thrownthing/throwingdatum, bounces_left)
	if(bounces_left <= 0 || !isturf(source.loc) || !source.has_gravity())
		return
	var/travel_dir = throwingdatum.init_dir
	if(!travel_dir)
		return
	var/rebound_dir
	var/incoming_distance
	if(hit_atom == source.loc)
		var/turf/landing_turf = hit_atom
		if(!floor_bounces || !landing_turf.bullet_bounce_sound)
			return
		rebound_dir = travel_dir
		incoming_distance = throwingdatum.dist_travelled
	else
		rebound_dir = reflect_direction(travel_dir, get_dir(source, hit_atom))
		// A throw cut short by an obstacle rebounds with the distance it was meant to cover.
		incoming_distance = max(throwingdatum.dist_travelled, throwingdatum.dist_x, throwingdatum.dist_y)
	var/rebound_distance = incoming_distance * restitution
	if(rebound_distance < BOUNCE_MINIMUM_DISTANCE)
		return
	if(prob(deflect_chance))
		rebound_dir = turn(rebound_dir, pick(45, -45))
	if(bounce_sound)
		playsound(source, bounce_sound, bounce_sound_volume, TRUE, -1)
	addtimer(CALLBACK(src, PROC_REF(rebound), WEAKREF(source), rebound_dir, rebound_distance, throwingdatum.speed, bounces_left - 1), BOUNCE_REBOUND_DELAY)

/**
 * Reflects a travel direction off an obstacle.
 *
 * Flips each axis of travel that points toward the obstacle, like a ball glancing off a wall. An obstacle
 * that no travel axis points toward, such as one sharing the object's turf, sends it straight back.
 *
 * Arguments:
 * * travel_dir - Direction the object was travelling.
 * * obstacle_dir - Direction from the object to the obstacle, or 0 when they share a turf.
 */
/datum/element/bouncy/proc/reflect_direction(travel_dir, obstacle_dir)
	var/reflected_dir = travel_dir
	if((obstacle_dir & (EAST|WEST)) && (travel_dir & (EAST|WEST)))
		reflected_dir ^= (EAST|WEST)
	if((obstacle_dir & (NORTH|SOUTH)) && (travel_dir & (NORTH|SOUTH)))
		reflected_dir ^= (NORTH|SOUTH)
	if(reflected_dir == travel_dir)
		return REVERSE_DIR(travel_dir)
	return reflected_dir

/**
 * Performs one rebound, if the object is still loose where it landed.
 *
 * A rebound of at least one tile is thrown. A shorter one slides within the turf instead and ends the chain.
 *
 * Arguments:
 * * source_ref - Weak reference to the bouncing movable.
 * * direction - Direction of the rebound.
 * * distance - Tiles the rebound travels. May be fractional.
 * * speed - Throw speed, in tiles per decisecond.
 * * bounces_left - Rebounds this rebound may chain into after it lands.
 */
/datum/element/bouncy/proc/rebound(datum/weakref/source_ref, direction, distance, speed, bounces_left)
	var/atom/movable/source = source_ref.resolve()
	// Someone may have picked it up, grabbed it, thrown it again or anchored it since it landed.
	if(isnull(source) || !isturf(source.loc) || source.throwing || source.anchored || source.pulledby)
		return
	var/tiles = FLOOR(distance, 1)
	if(tiles < 1)
		slide_within_turf(source, direction, distance)
		return
	var/turf/destination = get_ranged_target_turf(source, direction, tiles)
	// Arguments are positional because several throw_at() overrides lack these keyword parameters.
	// No thrower, spin, not diagonals first, no callback, default force, not gentle. quickstart is FALSE
	// so the throw does not move before bounces_left is set below.
	if(!source.throw_at(destination, tiles, speed, null, TRUE, FALSE, null, MOVE_FORCE_STRONG, FALSE, FALSE, /datum/thrownthing/bounce))
		return
	var/datum/thrownthing/bounce/rebound_throw = source.throwing
	// A throw_at() override that drops the datum type leaves an ordinary throw, which hits things normally.
	if(!istype(rebound_throw))
		return
	rebound_throw.bounces_left = bounces_left
	hop(source, height = min(2 + tiles * 2, BOUNCE_MAX_HOP_HEIGHT), duration = max(tiles / speed, 1))

/**
 * Slides the object part of a tile in a direction, decelerating to rest without leaving its turf.
 *
 * Arguments:
 * * source - The bouncing movable.
 * * direction - Direction of the slide.
 * * distance - Fraction of a tile, below 1, that the slide would cover unobstructed.
 */
/datum/element/bouncy/proc/slide_within_turf(atom/movable/source, direction, distance)
	var/slide_pixels = distance * ICON_SIZE_ALL
	if(ISDIAGONALDIR(direction))
		slide_pixels *= 0.7 // Split the slide across both axes.
	var/x_sign = (direction & EAST) ? 1 : ((direction & WEST) ? -1 : 0)
	var/y_sign = (direction & NORTH) ? 1 : ((direction & SOUTH) ? -1 : 0)
	var/target_x = round(clamp(source.pixel_x + x_sign * slide_pixels, source.base_pixel_x - BOUNCE_SLIDE_PIXEL_LIMIT, source.base_pixel_x + BOUNCE_SLIDE_PIXEL_LIMIT), 1)
	var/target_y = round(clamp(source.pixel_y + y_sign * slide_pixels, source.base_pixel_y - BOUNCE_SLIDE_PIXEL_LIMIT, source.base_pixel_y + BOUNCE_SLIDE_PIXEL_LIMIT), 1)
	var/duration = 2 + distance * 4 // Deciseconds; a longer slide coasts for longer.
	animate(source, pixel_x = target_x, pixel_y = target_y, time = duration, easing = QUAD_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)
	hop(source, height = round(distance * 6, 1), duration = duration * 0.6)

/**
 * Plays a rise-and-fall arc on the object's vertical draw offset, without moving it.
 *
 * Uses relative pixel_z steps in parallel, so it composes with spin animations, movement gliding and the
 * pixel_x/pixel_y offsets items rest at.
 *
 * Arguments:
 * * source - The bouncing movable.
 * * height - Peak of the arc, in pixels. Below 1 plays nothing.
 * * duration - Deciseconds for the whole arc.
 */
/datum/element/bouncy/proc/hop(atom/movable/source, height, duration)
	if(height < 1)
		return
	animate(source, pixel_z = height, time = duration / 2, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
	animate(pixel_z = -height, time = duration / 2, easing = SINE_EASING | EASE_IN, flags = ANIMATION_RELATIVE)

/// A rebound thrown by [/datum/element/bouncy]. Its impacts with obstacles only chain further rebounds.
/datum/thrownthing/bounce
	/// Rebounds this throw may still chain into after it ends.
	var/bounces_left = 0

#undef BOUNCE_REBOUND_DELAY
#undef BOUNCE_MINIMUM_DISTANCE
#undef BOUNCE_SLIDE_PIXEL_LIMIT
#undef BOUNCE_MAX_HOP_HEIGHT
