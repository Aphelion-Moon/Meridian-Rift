/**
 * A single departmental OOC channel.
 *
 * [GLOB.department_ooc_channels] defines the channels used by the chat verb and admin toggle.
 */
/datum/department_ooc_channel
	/// Short name used as the chat prefix and in the channel picker, e.g. "SEC-OOC".
	var/id
	/// Default chat colour; non-anonymous messages may use the listener's OOC colour.
	var/color
	/// Departments whose members may speak and listen here. NONE for a channel gated only on antag status.
	var/department_flags = NONE
	/// Whether non-admins may send messages on this channel.
	var/allowed = TRUE
	/// BYOND key -> anonymous name, stable for the round within this channel.
	var/list/key_to_anon_name
	/// If TRUE, holding any antagonist datum grants access on top of department_flags.
	var/is_antag_channel = FALSE
	/// Prefix for anonymous names, e.g. "Deputy" in "Deputy Foxtrot 12".
	var/anon_prefix

/datum/department_ooc_channel/New(id, color, department_flags, is_antag_channel = FALSE, anon_prefix)
	. = ..()
	src.id = id
	src.color = color
	src.department_flags = department_flags
	src.is_antag_channel = is_antag_channel
	src.anon_prefix = anon_prefix

/**
 * Checks channel membership by department or antagonist datum, without admin privileges.
 *
 * Shared by sending and receiving. Antagonist datums include antag silicons that mob/is_antag() excludes.
 */
/datum/department_ooc_channel/proc/is_member(client/user)
	var/mob/user_mob = user?.mob
	if(isnull(user_mob))
		return FALSE

	if(is_antag_channel && length(user_mob.mind?.antag_datums))
		return TRUE

	var/datum/job/job = user_mob.mind?.assigned_role
	if(job && (job.departments_bitflags & department_flags))
		return TRUE
	return FALSE

/**
 * Allows admins to use any channel; other clients must be members.
 */
/datum/department_ooc_channel/proc/can_use(client/user)
	if(user.holder)
		return TRUE
	return is_member(user)

/// Channel member; sees anonymous names.
#define DEPT_OOC_LISTEN_PLAYER 1
/// Admin listener; also sees the keys behind anonymous names.
#define DEPT_OOC_LISTEN_ADMIN 2

/**
 * Returns listening clients mapped to their DEPT_OOC_LISTEN_* mode.
 *
 * Active admins with OOC enabled receive messages as staff. Members always receive messages, even with OOC
 * hidden, so staff can reach them. This also applies to admins who are members but have OOC hidden.
 */
/datum/department_ooc_channel/proc/get_listeners()
	var/list/listeners = list()
	for(var/mob/player_mob as anything in GLOB.player_list)
		var/client/listener = player_mob.client
		// A disconnecting mob may remain in player_list after losing its client.
		if(isnull(listener))
			continue

		if(listener.holder && !listener.holder.deadmined && (get_chat_toggles(listener) & CHAT_OOC))
			listeners[listener] = DEPT_OOC_LISTEN_ADMIN
			continue
		if(is_member(listener))
			listeners[listener] = DEPT_OOC_LISTEN_PLAYER
	return listeners

/// Departmental OOC channels, indexed by their internal keys.
GLOBAL_LIST_INIT(department_ooc_channels, list(
	"security" = new /datum/department_ooc_channel("SEC-OOC", "#ff5454", DEPARTMENT_BITFLAG_SECURITY, anon_prefix = "Deputy"),
	"medical" = new /datum/department_ooc_channel("MED-OOC", "#57b8f0", DEPARTMENT_BITFLAG_MEDICAL, anon_prefix = "Doctor"),
	"engineering" = new /datum/department_ooc_channel("ENG-OOC", "#f37746", DEPARTMENT_BITFLAG_ENGINEERING, anon_prefix = "Engineer"),
	"research" = new /datum/department_ooc_channel("SCI-OOC", "#c68cfa", DEPARTMENT_BITFLAG_SCIENCE, anon_prefix = "Researcher"),
	"service" = new /datum/department_ooc_channel("SRV-OOC", "#6ca729", DEPARTMENT_BITFLAG_SERVICE, anon_prefix = "Civil Servant"),
	"command" = new /datum/department_ooc_channel("CMD-OOC", "#fcdf03", DEPARTMENT_BITFLAG_COMMAND | DEPARTMENT_BITFLAG_CAPTAIN, anon_prefix = "Commander"),
	"supply" = new /datum/department_ooc_channel("CAR-OOC", "#b88646", DEPARTMENT_BITFLAG_CARGO, anon_prefix = "Cratepusher"),
	"silicon" = new /datum/department_ooc_channel("AI-OOC", "#20c20e", DEPARTMENT_BITFLAG_SILICON, anon_prefix = "Intelligence"),
	"antagonist" = new /datum/department_ooc_channel("ANTAG-OOC", "#de3c8c", NONE, is_antag_channel = TRUE, anon_prefix = "Operator"),
	"central_command" = new /datum/department_ooc_channel("CC-OOC", "#00bfff", DEPARTMENT_BITFLAG_CENTRAL_COMMAND, anon_prefix = "Agent"),
	"backstage" = new /datum/department_ooc_channel("Backstage", "#ff0080", DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_COMMAND | DEPARTMENT_BITFLAG_CAPTAIN, is_antag_channel = TRUE, anon_prefix = "Actor"),
))

/**
 * Validates and sends a message to a departmental OOC channel.
 *
 * Applies channel access, OOC bans, mutes, and chat filters.
 * Admins bypass membership, channel disables, and moderation mutes.
 *
 * Arguments:
 * * sender - the client speaking
 * * channel_key - key into [GLOB.department_ooc_channels]
 * * msg - the raw, unsanitised message
 */
/proc/send_department_ooc(client/sender, channel_key, msg)
	var/datum/department_ooc_channel/channel = GLOB.department_ooc_channels[channel_key]
	if(!channel)
		return
	if(GLOB.say_disabled)
		to_chat(sender, span_danger("Speech is currently admin-disabled."))
		return
	if(!sender.mob)
		return

	if(!sender.holder)
		if(!channel.can_use(sender))
			if(channel.is_antag_channel)
				to_chat(sender, span_danger("You're not an antagonist or authorized role!"))
			else
				to_chat(sender, span_danger("You're not a [channel.id] role!"))
			return
		if(!channel.allowed)
			to_chat(sender, span_danger("[channel.id] is globally muted."))
			return
		if(sender.prefs?.muted & MUTE_OOC)
			to_chat(sender, span_danger("You cannot use OOC (muted)."))
			return
	if(is_banned_from(sender.ckey, "OOC"))
		to_chat(sender, span_danger("You have been banned from OOC."))
		return
	if(QDELETED(sender))
		return

	msg = trim(copytext_char(sanitize(msg), 1, MAX_MESSAGE_LEN))
	var/raw_msg = msg
	if(!msg)
		return

	// Keep the filter checks consistent with the main OOC verb.
	var/list/filter_result = is_ooc_filtered(msg)
	if(!CAN_BYPASS_FILTER(sender.mob) && filter_result)
		REPORT_CHAT_FILTER_TO_USER(sender.mob, filter_result)
		log_filter(channel.id, msg, filter_result)
		return

	// Filter bypassers still confirm hard-filtered messages through the soft-filter prompt.
	var/list/soft_filter_result = filter_result || is_soft_ooc_filtered(msg)
	if(soft_filter_result)
		if(tgui_alert(sender.mob, "Your message contains \"[soft_filter_result[CHAT_FILTER_INDEX_WORD]]\". \"[soft_filter_result[CHAT_FILTER_INDEX_REASON]]\", Are you sure you want to say it?", "Soft Blocked Word", list("Yes", "No")) != "Yes")
			return
		message_admins("[ADMIN_LOOKUPFLW(sender.mob)] has passed the soft filter for \"[soft_filter_result[CHAT_FILTER_INDEX_WORD]]\" they may be using a disallowed term on [channel.id]. Message: \"[html_encode(msg)]\"")
		log_admin_private("[key_name(sender)] has passed the soft filter for \"[soft_filter_result[CHAT_FILTER_INDEX_WORD]]\" they may be using a disallowed term on [channel.id]. Message: \"[msg]\"")

	msg = emoji_parse(msg)

	if(!sender.holder)
		if(sender.handle_spam_prevention(msg, MUTE_OOC))
			return
		if(findtext(msg, "byond://"))
			to_chat(sender, span_boldannounce("Advertising other servers is not allowed."))
			log_admin("[key_name(sender)] has attempted to advertise in [channel.id]: [msg]")
			message_admins("[key_name_admin(sender)] has attempted to advertise in [channel.id]: [msg]")
			return

	if(!(get_chat_toggles(sender) & CHAT_OOC))
		to_chat(sender, span_danger("You have OOC muted."))
		return

	sender.mob.log_talk(raw_msg, LOG_OOC, tag = channel.id)

	var/speaker_name = sender.key
	var/is_anonymous = FALSE
	// Deadminned staff follow the same anonymity preference as other players.
	if((!sender.holder || sender.holder.deadmined) && sender.prefs?.read_preference(/datum/preference/toggle/department_ooc_anon))
		if(!LAZYACCESS(channel.key_to_anon_name, sender.key))
			LAZYSET(channel.key_to_anon_name, sender.key, "[channel.anon_prefix] [pick(GLOB.phonetic_alphabet)] [rand(1, 99)]")
		speaker_name = LAZYACCESS(channel.key_to_anon_name, sender.key)
		is_anonymous = TRUE

	var/list/listeners = channel.get_listeners()
	for(var/client/listener as anything in listeners)
		var/listener_mode = listeners[listener]
		var/listener_color = listener.prefs?.read_preference(/datum/preference/color/ooc_color)
		var/msg_color = (!is_anonymous && CONFIG_GET(flag/allow_admin_ooccolor) && listener_color) ? listener_color : channel.color
		var/display_name = (listener_mode == DEPT_OOC_LISTEN_ADMIN && is_anonymous) ? "([sender.key])[speaker_name]" : speaker_name
		to_chat(listener, span_oocplain("<font color='[msg_color]'><b><span class='prefix'>[channel.id]:</span> <EM>[display_name]:</EM> <span class='message linkify'>[msg]</span></b></font>"), avoid_highlighting = (listener == sender))

/// Prompts for a message and, if needed, a channel the client can access.
GAME_VERB_DESC(/client, department_ooc, "Department OOC", "Speak on one of the OOC channels your role has access to.", "OOC")
	var/list/available_channels = list()
	for(var/channel_key in GLOB.department_ooc_channels)
		var/datum/department_ooc_channel/channel = GLOB.department_ooc_channels[channel_key]
		if(!channel.can_use(src))
			continue
		available_channels[channel.id] = channel_key

	if(!length(available_channels))
		to_chat(src, span_danger("You have no OOC channels available to you."))
		return

	var/selected_channel_id = available_channels[1]
	if(length(available_channels) > 1)
		selected_channel_id = tgui_input_list(mob, "Select a channel", "Department OOC", available_channels)
		if(isnull(selected_channel_id))
			return

	// send_department_ooc() sanitises the message; leave it raw here to avoid double encoding.
	var/msg = tgui_input_text(mob, "Message to send on [selected_channel_id]", "Department OOC", max_length = MAX_MESSAGE_LEN, encode = FALSE)
	if(isnull(msg))
		return

	send_department_ooc(src, available_channels[selected_channel_id], msg)

/**
 * Enables or disables a channel and notifies its listeners when the state changes.
 *
 * Arguments:
 * * channel_key - key into [GLOB.department_ooc_channels]
 * * toggle - TRUE to enable, FALSE to disable, or null to toggle the current state
 */
/proc/toggle_department_ooc(channel_key, toggle = null)
	var/datum/department_ooc_channel/channel = GLOB.department_ooc_channels[channel_key]
	if(isnull(channel))
		return

	var/new_state = isnull(toggle) ? !channel.allowed : toggle
	if(new_state == channel.allowed)
		return
	channel.allowed = new_state

	// Keep the notice within the channel; the admin verb handles staff logging.
	for(var/client/listener as anything in channel.get_listeners())
		to_chat(listener, span_oocplain("<b>The [channel.id] channel has been globally [channel.allowed ? "enabled" : "disabled"].</b>"))

#undef DEPT_OOC_LISTEN_PLAYER
#undef DEPT_OOC_LISTEN_ADMIN

ADMIN_VERB(toggledeptooc, R_ADMIN, "Toggle Department OOC", "Toggles a department OOC channel.", ADMIN_CATEGORY_SERVER)
	var/list/options = list()
	for(var/channel_key in GLOB.department_ooc_channels)
		var/datum/department_ooc_channel/channel = GLOB.department_ooc_channels[channel_key]
		options["[channel.id] ([channel.allowed ? "Enabled" : "Disabled"])"] = channel_key
	var/picked = tgui_input_list(usr, "Select a channel to toggle", "Toggle Department OOC", options)
	if(isnull(picked))
		return
	var/channel_key = options[picked]
	toggle_department_ooc(channel_key)
	var/datum/department_ooc_channel/channel = GLOB.department_ooc_channels[channel_key]
	log_admin("[key_name(usr)] toggled [channel.id] Department OOC.")
	message_admins("[key_name_admin(usr)] toggled [channel.id] Department OOC.")
	SSblackbox.record_feedback("nested tally", "admin_toggle", 1, list("Toggle Department OOC", "[channel.id]: [channel.allowed ? "Enabled" : "Disabled"]"))
