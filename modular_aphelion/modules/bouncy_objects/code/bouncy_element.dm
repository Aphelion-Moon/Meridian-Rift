/**
 * Delay between an impact and the rebound it causes.
 *
 * Must be nonzero. Impacts are handled inside [/datum/thrownthing/proc/finalize], and that throw's
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
 * - Landing on a hard floor can hop it onward in the same direction. Lava and soft or non-solid turfs
 *   (those without a `bullet_bounce_sound`, such as grass, carpet, water and space) absorb it.
 * - Objects can also hop away in a random direction when ejected: ammo casings from a ballistic gun, or
 *   anything thrown at its own tile with no thrower, such as a slimeperson's core when its body melts.
 *
 * Rebounds of a tile or more are real throws with a hop arc. A rebound under a tile cannot leave its
 * turf, so it becomes a decelerating slide within the turf, which ends the chain.
 *
 * The throw a player makes behaves exactly as before, including damage and catching. Only the
 * rebounds are new, and a rebound never strikes the obstacles it runs into: it does no damage, pushes
 * nothing, cannot be caught and sets off no hit reactions. Rebounds are skipped without gravity, where
 * thrown objects already drift.
 */
/datum/element/bouncy
	element_flags = ELEMENT_BESPOKE
	argument_hash_start_idx = 2
	/// Fraction (0 to 1) of the incoming travel distance each rebound keeps. Lower values settle sooner.
	var/restitution
	/// Most rebounds one throw or ejection can chain into.
	var/max_bounces
	/// Percent chance for each rebound to veer 45 degrees off its ideal direction.
	var/deflect_chance
	/// Sound played at each rebound, on top of the object's own landing sounds. Null for none.
	var/bounce_sound
	/// Volume of [/datum/element/bouncy/var/bounce_sound].
	var/bounce_sound_volume
	/// Tiles the object travels in a random direction when ejected from a ballistic gun as a casing. Zero disables ejection hops.
	var/eject_hop_range

/datum/element/bouncy/Attach(datum/target, restitution = 0.5, max_bounces = 2, deflect_chance = 0, bounce_sound = null, bounce_sound_volume = 30, eject_hop_range = 0)
	. = ..()
	if(!ismovable(target))
		return ELEMENT_INCOMPATIBLE
	src.restitution = clamp(restitution, 0, 1)
	src.max_bounces = max_bounces
	src.deflect_chance = deflect_chance
	src.bounce_sound = bounce_sound
	src.bounce_sound_volume = bounce_sound_volume
	src.eject_hop_range = eject_hop_range
	RegisterSignal(target, COMSIG_MOVABLE_IMPACT, PROC_REF(on_impact))
	if(eject_hop_range > 0)
		RegisterSignal(target, COMSIG_CASING_EJECTED, PROC_REF(on_ejected))

/datum/element/bouncy/Detach(datum/source)
	UnregisterSignal(source, list(COMSIG_MOVABLE_IMPACT, COMSIG_CASING_EJECTED))
	return ..()

/**
 * Queues the first rebound after an ordinary throw, unless the thing hit caught the object.
 *
 * A throw with no thrower aimed at the object's own tile, such as a slimeperson's core tossed loose by its
 * melting body, lands at once. The object then pops away in a random direction as far as the throw's range.
 */
/datum/element/bouncy/proc/on_impact(atom/movable/source, atom/hit_atom, datum/thrownthing/throwingdatum, caught)
	SIGNAL_HANDLER
	// throw_impact() is sometimes called without a throw, as when someone who trips hits themselves with what they hold.
	// Rebounds chain from [/datum/thrownthing/bounce/proc/finalize] instead.
	if(caught || isnull(throwingdatum) || istype(throwingdatum, /datum/thrownthing/bounce))
		return
	if(throwingdatum.init_dir || throwingdatum.get_thrower())
		queue_rebound(source, hit_atom, throwingdatum, max_bounces)
	else
		addtimer(CALLBACK(src, PROC_REF(rebound), WEAKREF(source), pick(GLOB.alldirs), throwingdatum.maxrange, throwingdatum.speed, max_bounces), BOUNCE_REBOUND_DELAY)

/**
 * Sends an ejected ammo casing hopping away from the gun.
 *
 * COMSIG_CASING_EJECTED is sent before the wielder tries to catch the casing, so a caught casing is in a hand
 * by the time [/datum/element/bouncy/proc/rebound] checks it, and stays there.
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
	var/turf/current_turf = source.loc
	if(bounces_left <= 0 || !throwingdatum.init_dir || !isturf(current_turf) || !source.has_gravity())
		return
	// Nearest of the eight directions. init_dir is diagonal whenever the target is off-axis at all.
	var/rebound_dir = angle2dir(get_angle(throwingdatum.starting_turf, throwingdatum.target_turf))
	var/incoming_distance = throwingdatum.dist_travelled
	if(hit_atom != current_turf)
		rebound_dir = reflect_direction(rebound_dir, get_dir(source, hit_atom))
		// A throw cut short by an obstacle rebounds with the distance it was meant to cover: the way to its
		// target (dist_x is the longer axis), but no further than its range.
		incoming_distance = min(throwingdatum.dist_x, throwingdatum.maxrange)
	else if(!current_turf.bullet_bounce_sound || islava(current_turf)) // Soft, non-solid or molten floors absorb the landing.
		return
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
	var/toward_obstacle = travel_dir & obstacle_dir
	if(!toward_obstacle)
		return REVERSE_DIR(travel_dir)
	return travel_dir ^ toward_obstacle ^ REVERSE_DIR(toward_obstacle)

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
	// Someone may have picked it up, grabbed it, thrown it again or anchored it since it landed, or gravity failed.
	if(isnull(source) || !isturf(source.loc) || source.throwing || source.anchored || source.pulledby || !source.has_gravity())
		return
	var/tiles = FLOOR(distance, 1)
	if(tiles < 1)
		slide_within_turf(source, direction, distance)
		return
	// Positional, as /obj/item and /atom/movable name the datum type parameter differently: no thrower, spin, not
	// diagonals first, no callback, default force, not gentle, and no quickstart, so it waits for the vars set below.
	source.throw_at(get_ranged_target_turf(source, direction, tiles), tiles, speed, null, TRUE, FALSE, null, MOVE_FORCE_STRONG, FALSE, FALSE, /datum/thrownthing/bounce)
	var/datum/thrownthing/bounce/rebound_throw = source.throwing
	if(!istype(rebound_throw)) // Refused, or a throw_at() override dropped the datum type and made an ordinary throw.
		return
	rebound_throw.bouncer = src
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
	var/slide_pixels = distance * ICON_SIZE_ALL * (ISDIAGONALDIR(direction) ? 0.7 : 1) // A diagonal slide splits across both axes.
	var/list/offset = dir2offset(direction)
	var/target_x = round(clamp(source.pixel_x + offset[1] * slide_pixels, source.base_pixel_x - BOUNCE_SLIDE_PIXEL_LIMIT, source.base_pixel_x + BOUNCE_SLIDE_PIXEL_LIMIT), 1)
	var/target_y = round(clamp(source.pixel_y + offset[2] * slide_pixels, source.base_pixel_y - BOUNCE_SLIDE_PIXEL_LIMIT, source.base_pixel_y + BOUNCE_SLIDE_PIXEL_LIMIT), 1)
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

/// A rebound thrown by [/datum/element/bouncy]. It strikes nothing: running into an obstacle only chains the next rebound.
/datum/thrownthing/bounce
	/// The element that threw this rebound.
	var/datum/element/bouncy/bouncer
	/// Rebounds this throw may still chain into after it ends.
	var/bounces_left = 0

/datum/thrownthing/bounce/finalize(hit, target)
	if(thrownthing)
		bouncer?.queue_rebound(thrownthing, target || get_turf(thrownthing), src, bounces_left)
	// Obstacles are never struck, so they get no hitby(), damage, pre-hit reactions or hit sounds. Floor landings still
	// reach the turf, so landing sounds play.
	return ..(hit, null)

#undef BOUNCE_REBOUND_DELAY
#undef BOUNCE_MINIMUM_DISTANCE
#undef BOUNCE_SLIDE_PIXEL_LIMIT
#undef BOUNCE_MAX_HOP_HEIGHT
