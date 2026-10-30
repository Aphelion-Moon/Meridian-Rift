/// The sequence currently running, if any.
GLOBAL_DATUM(self_destruct_sequence, /datum/self_destruct_sequence)

/**
 * Runs for as long as the station self-destruct terminal is counting down. Owns the announcement,
 * the point of no return, and the secondary detonations after it. The detonation itself belongs to
 * the terminal's own timer, which is pinned to [SELF_DESTRUCT_DURATION].
 */
/datum/self_destruct_sequence
	/// The terminal counting down. We do not outlive it.
	var/obj/machinery/nuclearbomb/selfdestruct/terminal
	/// world.time the sequence began. Every other time here is an offset from this.
	var/start_time
	/// Reserved sound channel, so an abort can silence the announcement mid-sentence.
	var/announcement_channel
	/// TRUE once the announcement has stated that cancellation is off the table.
	var/past_no_return = FALSE
	/// Station areas we put into their fire alarm state, so an abort can put them back.
	var/list/area/reddened_areas
	/// Clients already hearing the announcement, so we never restart it under one that has it.
	var/list/client/served

/datum/self_destruct_sequence/New(obj/machinery/nuclearbomb/selfdestruct/starting_terminal)
	. = ..()
	if(QDELETED(starting_terminal))
		CRASH("self-destruct sequence started without a terminal to hang off.")

	terminal = starting_terminal
	start_time = world.time
	served = list()
	announcement_channel = SSsounds.reserve_sound_channel_for_datum(src)

	RegisterSignal(terminal, COMSIG_QDELETING, PROC_REF(on_terminal_deleted))
	RegisterSignal(SSdcs, COMSIG_GLOB_PLAYER_LOGIN, PROC_REF(on_player_login))

	broadcast_announcement()
	addtimer(CALLBACK(src, PROC_REF(pass_point_of_no_return)), SELF_DESTRUCT_POINT_OF_NO_RETURN, TIMER_DELETE_ME)
	addtimer(CALLBACK(src, PROC_REF(detonate)), SELF_DESTRUCT_DURATION - SELF_DESTRUCT_CINEMATIC_INTRO, TIMER_DELETE_ME)

/datum/self_destruct_sequence/Destroy(force)
	silence_announcement()
	// A sequence that ran its course is torn down mid-detonation, where putting the lights back
	// would just un-redden a station that is already gone.
	if(isnull(terminal) || !terminal.exploding)
		restore_lighting()
	reddened_areas = null
	served = null
	terminal = null
	if(GLOB.self_destruct_sequence == src)
		GLOB.self_destruct_sequence = null
	return ..()

/// Deciseconds since the sequence began.
/datum/self_destruct_sequence/proc/elapsed()
	return world.time - start_time

/// No terminal means no bomb left to detonate.
/datum/self_destruct_sequence/proc/on_terminal_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// Drops anyone entering the round mid-sequence in at the right point in the track.
/datum/self_destruct_sequence/proc/on_player_login(datum/source, mob/player)
	SIGNAL_HANDLER
	if(elapsed() >= SELF_DESTRUCT_DURATION)
		return
	broadcast_announcement(list(player))

/// The announcement, seeked to however far into the sequence we already are.
/datum/self_destruct_sequence/proc/build_announcement()
	var/sound/announcement = sound('modular_nova/modules/self_destruct_sequence/sound/self_destruct_sequence.ogg')
	announcement.channel = announcement_channel
	announcement.repeat = FALSE
	announcement.wait = FALSE
	announcement.priority = 255 // the one sound in the sequence that must never be dropped
	announcement.offset = elapsed() / (1 SECONDS) // offset is in seconds, our clock is in deciseconds
	return announcement

/**
 * Sends the announcement out. Defaults to everyone in the round, which is what the first broadcast wants.
 *
 * Skips anyone already hearing it. Sound channels belong to the client rather than the mob, so
 * changing bodies does not interrupt playback - re-sending would only re-seek the track, which is
 * audible, and dying to a secondary detonation is a very common way to change bodies in here.
 */
/datum/self_destruct_sequence/proc/broadcast_announcement(list/players)
	var/list/targets = list()
	for(var/mob/player as anything in (players || GLOB.player_list))
		var/client/player_client = player.client
		if(isnull(player_client) || isnewplayer(player) || (player_client in served))
			continue
		targets += player
		served += player_client
		RegisterSignal(player_client, COMSIG_QDELETING, PROC_REF(on_client_gone))

	if(!length(targets))
		return

	alert_sound_to_playing(
		volume = 100,
		channel = announcement_channel,
		sound_to_use = build_announcement(),
		override_volume = TRUE,
		players = targets,
	)

/// A client that leaves takes its sound channels with it, so let a reconnect be served fresh.
/datum/self_destruct_sequence/proc/on_client_gone(client/gone)
	SIGNAL_HANDLER
	served -= gone

/// Cuts the announcement off everywhere.
/datum/self_destruct_sequence/proc/silence_announcement()
	if(!announcement_channel)
		return
	for(var/mob/player as anything in GLOB.player_list)
		player.stop_sound_channel(announcement_channel)

/// The announcement has just said cancellation has expired, so make that true.
/datum/self_destruct_sequence/proc/pass_point_of_no_return()
	past_no_return = TRUE

	INVOKE_ASYNC(src, PROC_REF(redden_lighting))
	minor_announce(
		"Self-destruct sequence has passed its abort window. Cancellation is no longer possible. All hands abandon station.",
		"Automated Self-Destruct System",
		alert = TRUE,
		should_play_sound = FALSE,
	)
	message_admins("The station self-destruct sequence has passed its point of no return and can no longer be cancelled.")
	log_game("The station self-destruct sequence passed its point of no return.")

	schedule_next_blast()

/// Flips every station area into its fire alarm state, which is what turns the lights red.
/datum/self_destruct_sequence/proc/redden_lighting()
	if(QDELETED(src))
		return

	var/list/station_area_types = list()
	for(var/area_type in GLOB.the_station_areas)
		station_area_types[area_type] = TRUE

	reddened_areas = list()
	for(var/area/station_area as anything in GLOB.areas)
		// Areas already burning are somebody else's to clear.
		if(!station_area_types[station_area.type] || station_area.fire)
			continue
		station_area.set_fire_effect(TRUE, AREA_FAULT_AUTOMATIC, "[terminal]")
		reddened_areas += station_area
		CHECK_TICK
		if(QDELETED(src)) // aborted mid-loop, restore_lighting already ran over what we had
			return

/datum/self_destruct_sequence/proc/restore_lighting()
	for(var/area/reddened as anything in reddened_areas)
		reddened.set_fire_effect(FALSE, AREA_FAULT_NONE)
	reddened_areas = null

/// Queues the next secondary detonation, tightening the interval as the terminal counts down.
/datum/self_destruct_sequence/proc/schedule_next_blast()
	var/into_terminal_phase = elapsed() - SELF_DESTRUCT_POINT_OF_NO_RETURN
	var/terminal_phase_length = SELF_DESTRUCT_DURATION - SELF_DESTRUCT_POINT_OF_NO_RETURN
	var/progress = clamp(into_terminal_phase / terminal_phase_length, 0, 1)

	var/delay = LERP(SELF_DESTRUCT_BLAST_INTERVAL_START, SELF_DESTRUCT_BLAST_INTERVAL_END, progress)
	addtimer(CALLBACK(src, PROC_REF(secondary_detonation)), delay, TIMER_DELETE_ME)

/// One of the station's own systems letting go. Light impact only, so it hurts without reliably killing.
/datum/self_destruct_sequence/proc/secondary_detonation()
	if(QDELETED(terminal) || terminal.exploding || elapsed() >= SELF_DESTRUCT_DURATION)
		return

	var/turf/epicenter = pick_blast_site()
	if(epicenter)
		var/blast_range = rand(2, 4)
		explosion(
			epicenter,
			light_impact_range = blast_range,
			flash_range = rand(3, 5),
			adminlog = FALSE,
			silent = TRUE,
			explosion_cause = terminal,
		)
		// Silenced above and sounded by hand, because explosion() only carries sound as far as the
		// heavy and devastation rings reach, and ours are zero.
		SSexplosions.shake_the_room(
			epicenter,
			near_distance = blast_range,
			far_distance = SELF_DESTRUCT_BLAST_AUDIBLE_RANGE,
			quake_factor = 0,
			// Not every blast reaches the far side of the station. By the end they land twice a
			// second, and one guaranteed sound per player per blast crowds out the announcement.
			echo_factor = prob(SELF_DESTRUCT_BLAST_ECHO_PROB),
			near_sound = quiet_blast(/datum/sound_effect/explosion),
			far_sound = quiet_blast('sound/effects/explosion/explosionfar.ogg'),
			echo_sound = quiet_blast('sound/effects/explosion/explosion_distant.ogg'),
		)

	schedule_next_blast()

/// An explosion sound built to lose. Nothing else sets priority, so these sit below every other sound.
/datum/self_destruct_sequence/proc/quiet_blast(blast_sound)
	var/sound/blast = sound(get_sfx(blast_sound))
	blast.priority = SELF_DESTRUCT_BLAST_SOUND_PRIORITY
	return blast

/// Weighted towards somebody who will actually witness it, since a blast nobody saw may as well not have happened.
/datum/self_destruct_sequence/proc/pick_blast_site()
	if(prob(SELF_DESTRUCT_BLAST_NEAR_CREW_PROB))
		var/turf/near_crew = pick_site_near_crew()
		if(near_crew)
			return near_crew
	return get_safe_random_station_turf()

/// A turf a room or two from somebody still aboard. Null if there is nobody left to play to.
/datum/self_destruct_sequence/proc/pick_site_near_crew()
	var/list/mob/living/witnesses = list()
	for(var/mob/living/crew in GLOB.alive_player_list)
		var/turf/crew_turf = get_turf(crew)
		if(isnull(crew_turf) || !is_station_level(crew_turf.z))
			continue
		witnesses += crew

	if(!length(witnesses))
		return null

	var/turf/origin = get_turf(pick(witnesses))
	var/angle = rand(0, 359)
	var/distance = rand(SELF_DESTRUCT_BLAST_CREW_RANGE_MIN, SELF_DESTRUCT_BLAST_CREW_RANGE_MAX)
	var/turf/site = locate(
		clamp(origin.x + round(cos(angle) * distance), 1, world.maxx),
		clamp(origin.y + round(sin(angle) * distance), 1, world.maxy),
		origin.z,
	)
	// Blowing up empty space next to somebody is neither seen nor heard.
	return (isnull(site) || isspaceturf(site)) ? null : site

/// Fires the terminal one cinematic intro before the announcement ends, so the 3-2-1 counts onto zero
/// and the blast lands on the end of the track instead of after it.
/datum/self_destruct_sequence/proc/detonate()
	if(QDELETED(terminal) || terminal.exploding || !terminal.timing)
		return
	terminal.explode()
