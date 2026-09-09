/**
 * A single departmental OOC channel.
 *
 * One of these exists per channel in [GLOB.department_ooc_channels]. Adding a channel is a single
 * entry in that list - the verb, the admin toggle and the anonymous naming all read from here, so
 * nothing else needs touching.
 */
/datum/department_ooc_channel
	/// Short name used as the chat prefix and in the channel picker, e.g. "SEC-OOC".
	var/id
	/// Colour the channel prints in, unless the listener has an OOC colour of their own to use.
	var/color
	/// Departments whose members may speak and listen here. NONE for a channel gated only on antag status.
	var/department_flags = NONE
	/// Whether admins have left the channel switched on.
	var/allowed = TRUE
	/// ckey -> the anonymous name that ckey was handed here, so a speaker keeps one name all round.
	var/list/ckey_to_anon_name
	/// If TRUE, holding any antagonist datum grants access on top of department_flags.
	var/is_antag_channel = FALSE
	/// Leading word of an anonymous name here - "Deputy" gives you "Deputy Foxtrot 12".
	var/anon_prefix

/datum/department_ooc_channel/New(id, color, department_flags, is_antag_channel = FALSE, anon_prefix)
	. = ..()
	src.id = id
	src.color = color
	src.department_flags = department_flags
	src.is_antag_channel = is_antag_channel
	src.anon_prefix = anon_prefix

/**
 * Whether a client is allowed to speak on and listen to this channel.
 *
 * Admins always are. Everyone else needs either an antag datum on an antag channel, or a job in one
 * of the channel's departments. The antag check only asks whether they hold any antagonist datum at
 * all - a channel wanting a specific antag type would need this splitting into its own check.
 *
 * Arguments:
 * * user - the client being tested
 */
/datum/department_ooc_channel/proc/can_use(client/user)
	if(user.holder)
		return TRUE
	if(is_antag_channel && length(user.mob?.mind?.antag_datums))
		return TRUE
	var/datum/job/job = user.mob?.mind?.assigned_role
	if(job && (job.departments_bitflags & department_flags))
		return TRUE
	return FALSE

/// Every departmental OOC channel, keyed by the internal name used to look one up.
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

/// Listener is on the channel as one of its members.
#define DEPT_OOC_LISTEN_PLAYER 1
/// Listener is on the channel as an admin, and so gets to see through the anonymity.
#define DEPT_OOC_LISTEN_ADMIN 2

/**
 * Speaks a message onto one of the departmental OOC channels.
 *
 * Runs the sender through the channel's access check and the usual OOC mute/ban gates, then prints
 * to every admin and channel member online. Admins bypass the access and mute checks, as they are
 * expected to be able to talk into any channel they are asked to.
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
		if(sender.prefs.muted & MUTE_OOC)
			to_chat(sender, span_danger("You cannot use OOC (muted)."))
			return
	if(is_banned_from(sender.ckey, "OOC"))
		to_chat(sender, span_danger("You have been banned from OOC."))
		return
	if(QDELETED(sender))
		return

	msg = copytext_char(sanitize(msg), 1, MAX_MESSAGE_LEN)
	var/raw_msg = msg
	if(!msg)
		return
	msg = emoji_parse(msg)

	if(!(sender.prefs.chat_toggles & CHAT_OOC))
		to_chat(sender, span_danger("You have OOC muted."))
		return

	sender.mob.log_talk(raw_msg, LOG_OOC, tag = channel.id)

	var/keyname = sender.key
	var/anon = FALSE
	// Deadminned admins are anonymised alongside players, so stepping down does not out you.
	if((!sender.holder || sender.holder.deadmined) && sender.prefs?.read_preference(/datum/preference/toggle/department_ooc_anon))
		if(!LAZYACCESS(channel.ckey_to_anon_name, sender.key))
			LAZYSET(channel.ckey_to_anon_name, sender.key, "[channel.anon_prefix] [pick(GLOB.phonetic_alphabet)] [rand(1, 99)]")
		keyname = LAZYACCESS(channel.ckey_to_anon_name, sender.key)
		anon = TRUE

	var/list/listeners = list()

	// Admins first, so a listener who is both an admin and a member is marked as the admin.
	// An admin with OOC muted has opted out of hearing this, unlike a member, who may be being
	// spoken to by staff and does not get the choice.
	for(var/mob/iterated_mob as anything in GLOB.player_list)
		var/client/iterated_client = iterated_mob.client
		if(iterated_client.holder && !iterated_client.holder.deadmined && (iterated_client.prefs?.chat_toggles & CHAT_OOC))
			listeners[iterated_client] = DEPT_OOC_LISTEN_ADMIN
			continue
		var/datum/job/job = iterated_mob.mind?.assigned_role
		if(channel.department_flags && (job?.departments_bitflags & channel.department_flags))
			listeners[iterated_client] = DEPT_OOC_LISTEN_PLAYER
			continue
		if(channel.is_antag_channel && iterated_mob.is_antag())
			listeners[iterated_client] = DEPT_OOC_LISTEN_PLAYER
			continue

	for(var/client/iterated_client as anything in listeners)
		var/mode = listeners[iterated_client]
		var/listener_color = iterated_client.prefs?.read_preference(/datum/preference/color/ooc_color)
		var/msg_color = (!anon && CONFIG_GET(flag/allow_admin_ooccolor) && listener_color) ? listener_color : channel.color
		// Admins see the ckey behind an anonymous name, so they can act on what is said.
		var/display_name = (mode == DEPT_OOC_LISTEN_ADMIN && anon) ? "([sender.key])[keyname]" : keyname
		to_chat(iterated_client, span_oocplain("<font color='[msg_color]'><b><span class='prefix'>[channel.id]:</span> <EM>[display_name]:</EM> <span class='message linkify'>[msg]</span></b></font>"), avoid_highlighting = (iterated_client == sender))

#undef DEPT_OOC_LISTEN_PLAYER
#undef DEPT_OOC_LISTEN_ADMIN

/// Picks a channel out of the ones you have access to, then a message to say on it.
GAME_VERB_DESC(/client, department_ooc, "Department OOC", "Speak on one of the OOC channels your role has access to.", "OOC")
	var/list/available = list()
	for(var/channel_key in GLOB.department_ooc_channels)
		var/datum/department_ooc_channel/channel = GLOB.department_ooc_channels[channel_key]
		if(!channel.can_use(src))
			continue
		available[channel.id] = channel_key

	if(!length(available))
		to_chat(src, span_danger("You have no OOC channels available to you."))
		return

	var/picked_id = tgui_input_list(mob, "Select a channel", "Department OOC", available)
	if(isnull(picked_id))
		return

	// Sanitised on the way out in send_department_ooc(), so this is left raw to avoid encoding twice.
	var/msg = tgui_input_text(mob, "Message to send on [picked_id]", "Department OOC", max_length = MAX_MESSAGE_LEN, encode = FALSE)
	if(isnull(msg))
		return

	send_department_ooc(src, available[picked_id], msg)

/**
 * Switches one of the departmental OOC channels on or off, and says so in chat.
 *
 * Arguments:
 * * channel_key - key into [GLOB.department_ooc_channels]
 * * toggle - TRUE or FALSE to set the state outright, null to flip whatever it currently is
 */
/proc/toggle_department_ooc(channel_key, toggle = null)
	var/datum/department_ooc_channel/channel = GLOB.department_ooc_channels[channel_key]
	if(isnull(channel))
		return
	if(isnull(toggle))
		channel.allowed = !channel.allowed
		return
	channel.allowed = toggle

	// Carried over from the SOOC and AOOC verbs this replaces: the announcement is deliberately
	// server-wide rather than channel-only, so nobody is left talking into a dead channel.
	var/list/listeners = list()
	for(var/mob/iterated_mob as anything in GLOB.player_list)
		var/client/iterated_client = iterated_mob.client
		if(iterated_client.holder && !iterated_client.holder.deadmined)
			listeners[iterated_client] = TRUE
			continue
		var/datum/job/job = iterated_mob.mind?.assigned_role
		if(channel.department_flags && (job?.departments_bitflags & channel.department_flags))
			listeners[iterated_client] = TRUE
			continue
		if(channel.is_antag_channel && iterated_mob.is_antag())
			listeners[iterated_client] = TRUE
			continue

	for(var/client/iterated_client as anything in listeners)
		to_chat(iterated_client, span_oocplain("<b>The [channel.id] channel has been globally [channel.allowed ? "enabled" : "disabled"].</b>"))

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
