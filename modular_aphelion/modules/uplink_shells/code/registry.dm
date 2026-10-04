#define UPLINK_LOADOUT_OPEN "not_committed"
#define UPLINK_LOADOUT_ISSUED "issued"
#define UPLINK_LOADOUT_DECLINED "declined_at_first_issue"

/datum/config_entry/flag/enable_personal_uplink_shells
	default = FALSE

/datum/config_entry/number/uplink_replacement_delay
	default = 5 MINUTES
	min_val = 0

/datum/mind
	var/datum/uplink_registry/uplink_registry

/mob/living/silicon/ai
	var/datum/uplink_registry/uplink_registry

/// Round history is owned by the mind, never by a removable brain or a disposable core.
/datum/uplink_registry
	var/datum/mind/identity
	var/mob/living/silicon/ai/core
	var/datum/weakref/personal_body
	var/datum/weakref/bound_brain
	var/registration_generation = 0
	var/request_generation = 0
	var/replacement_deadline = 0
	var/request_pending = FALSE
	var/issuing = FALSE
	var/loadout_outcome = UPLINK_LOADOUT_OPEN
	var/datum/uplink_blueprint/blueprint
	var/datum/uplink_blueprint/candidate
	var/mob/living/carbon/human/uplink/provisional_body
	var/obj/effect/uplink_delivery/provisional_delivery
	var/include_loadout = TRUE
	var/shell_label
	var/datum/action/innate/manage_uplink/manage_action
	var/last_status
	var/last_warning = 0
	var/last_health = 100
	var/low_charge_warned = FALSE

/datum/uplink_registry/New(datum/mind/new_identity, mob/living/silicon/ai/new_core)
	identity = new_identity
	identity.uplink_registry = src
	RegisterSignal(identity, COMSIG_MIND_TRANSFERRED, PROC_REF(identity_moved))
	RegisterSignal(identity, COMSIG_QDELETING, PROC_REF(identity_deleted))
	manage_action = new(src)
	bind_core(new_core)
	manage_action.Grant(new_core)

/datum/uplink_registry/Destroy()
	clear_candidate()
	QDEL_NULL(blueprint)
	QDEL_NULL(manage_action)
	if(identity)
		UnregisterSignal(identity, list(COMSIG_MIND_TRANSFERRED, COMSIG_QDELETING))
		identity.uplink_registry = null
	if(core)
		UnregisterSignal(core, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_LIVING_REVIVE))
		core.uplink_registry = null
	observe_body(null)
	identity = null
	core = null
	return ..()

/datum/uplink_registry/proc/identity_deleted()
	SIGNAL_HANDLER
	qdel(src)

/datum/uplink_registry/proc/bind_core(mob/living/silicon/ai/new_core)
	if(core == new_core)
		return
	if(core)
		UnregisterSignal(core, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_LIVING_REVIVE))
		core.uplink_registry = null
	core = new_core
	core.uplink_registry = src
	RegisterSignals(core, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING), PROC_REF(core_failed))
	RegisterSignal(core, COMSIG_LIVING_REVIVE, PROC_REF(core_revived))
	refresh_binding()

/datum/uplink_registry/proc/identity_moved(datum/source, mob/old_body)
	SIGNAL_HANDLER
	if(isAI(identity.current))
		bind_core(identity.current)
	if(manage_action.owner)
		manage_action.Remove(manage_action.owner)
	if(identity.current)
		manage_action.Grant(identity.current)
	clear_candidate()

/datum/uplink_registry/proc/core_failed(datum/source)
	SIGNAL_HANDLER
	cancel_request()
	clear_candidate()
	var/mob/living/carbon/human/uplink/body = personal_body?.resolve()
	body?.update_uplink_camera()

/datum/uplink_registry/proc/core_revived()
	SIGNAL_HANDLER
	refresh_binding()

/datum/uplink_registry/proc/viewer_valid(mob/living/user)
	return !QDELETED(identity) && user?.client && identity.current == user && user.mind == identity && (user == core || user.ai_shell_session?.core == core)

/datum/uplink_registry/proc/delivery_denial()
	if(!CONFIG_GET(flag/enable_personal_uplink_shells))
		return "New Uplink issuance is disabled. Existing bodies may still return safely."
	if(QDELETED(core) || core.stat == DEAD || core.uplink_registry != src)
		return "Your authoritative AI core is offline."
	var/service_denial = core.shell_service_denial()
	if(service_denial)
		return service_denial
	if(!viewer_valid(identity.current))
		return "Delivery is ready but requires your connected AI identity."
	return null

/datum/uplink_registry/proc/is_current(mob/living/carbon/human/uplink/body)
	return body && personal_body?.resolve() == body && body.registry == src && !body.retired && body.registration_generation == registration_generation

/datum/uplink_registry/proc/authorize(mob/living/carbon/human/uplink/body, obj/item/organ/brain/cybernetic/ai/brain, mob/living/silicon/ai/requester)
	if(QDELETED(identity) || QDELETED(brain) || QDELETED(requester) || requester != core || core.uplink_registry != src)
		return FALSE
	// A different mind occupying the same physical core does not inherit this allocation.
	var/datum/mind/controller = core.shell_session?.identity || core.mind
	return controller == identity && is_current(body) && core.stat != DEAD && bound_brain?.resolve() == brain && brain.owner == body && body.get_organ_slot(ORGAN_SLOT_BRAIN) == brain

/// Surgery only refreshes availability; it never starts a control session.
/datum/uplink_registry/proc/refresh_binding()
	var/mob/living/carbon/human/uplink/body = personal_body?.resolve()
	if(!is_current(body))
		return
	var/obj/item/organ/brain/cybernetic/ai/brain = body.get_organ_by_type(/obj/item/organ/brain/cybernetic/ai)
	var/obj/item/organ/brain/cybernetic/ai/old = bound_brain?.resolve()
	if(old != brain)
		if(old)
			old.personal_authorization_revoked = TRUE
		registration_generation++
		body.registration_generation = registration_generation
		bound_brain = brain ? WEAKREF(brain) : null
	if(brain)
		brain.personal_registry = src
		brain.personal_authorization_revoked = FALSE
		brain.connected_ai = core
	body.update_uplink_camera()

/datum/uplink_registry/proc/observe_body(mob/living/carbon/human/uplink/body)
	var/mob/living/carbon/human/uplink/old = personal_body?.resolve()
	if(old)
		UnregisterSignal(old, list(COMSIG_LIVING_HEALTH_UPDATE, COMSIG_QDELETING, COMSIG_CARBON_GAIN_ORGAN, COMSIG_LIVING_REVIVE))
	personal_body = body ? WEAKREF(body) : null
	if(body)
		RegisterSignal(body, COMSIG_LIVING_HEALTH_UPDATE, PROC_REF(body_changed))
		RegisterSignal(body, COMSIG_QDELETING, PROC_REF(body_deleted))
		RegisterSignals(body, list(COMSIG_CARBON_GAIN_ORGAN, COMSIG_LIVING_REVIVE), PROC_REF(body_repaired))

/datum/uplink_registry/proc/body_repaired()
	SIGNAL_HANDLER
	refresh_binding()

/datum/uplink_registry/proc/body_changed(mob/living/carbon/human/uplink/body)
	SIGNAL_HANDLER
	if(!is_current(body))
		return
	var/low_charge = body.nutrition < NUTRITION_LEVEL_STARVING
	if(world.time >= last_warning && (body.health <= last_health - 10 || (low_charge && !low_charge_warned)))
		last_warning = world.time + 30 SECONDS
		to_chat(identity.current, span_warning("Personal Uplink: integrity [round(body.health)]/[body.maxHealth], charge [round(100 * body.nutrition / NUTRITION_LEVEL_FULL)]%. Treatment and charging do not redeploy you."))
		last_health = body.health
		low_charge_warned = low_charge
	if(body.health > last_health)
		last_health = body.health
	if(!low_charge)
		low_charge_warned = FALSE
	body.update_uplink_camera()

/datum/uplink_registry/proc/body_deleted()
	SIGNAL_HANDLER
	to_chat(identity.current, span_warning("Your personal Uplink body was destroyed. Manage Uplink Shell can schedule a replacement."))
	observe_body(null)
	bound_brain = null

/datum/uplink_registry/proc/clear_candidate()
	if(issuing)
		request_generation++
		return
	// The private container owns all unpublished outputs, including the preview body.
	provisional_body = null
	QDEL_NULL(provisional_delivery)
	QDEL_NULL(candidate)

/datum/uplink_registry/proc/prepare(mob/user)
	if(!viewer_valid(user) || issuing || loadout_outcome != UPLINK_LOADOUT_OPEN || delivery_denial())
		return
	clear_candidate()
	issuing = TRUE
	var/token = ++request_generation
	candidate = new(user.client.prefs, shell_label || core.real_name, include_loadout)
	provisional_delivery = new(null)
	try
		provisional_body = candidate.build(provisional_delivery, src, user.client)
	catch(var/exception/error)
		log_runtime("Uplink preview construction failed: [error]")
	issuing = FALSE
	if(QDELETED(src) || !provisional_body || token != request_generation || !viewer_valid(user))
		clear_candidate()
		last_status = "Could not construct a compatible preview. No claim was spent."

/datum/uplink_registry/ui_close(mob/user)
	if(!issuing)
		clear_candidate()

/// No yields from final revalidation through publication and ledger commit.
/datum/uplink_registry/proc/deliver(mob/user, expected_request)
	if(issuing || !viewer_valid(user))
		return FALSE
	var/reason = delivery_denial()
	if(reason)
		last_status = reason
		return FALSE
	var/initial_issue = loadout_outcome == UPLINK_LOADOUT_OPEN
	if(!initial_issue && (!request_pending || expected_request != request_generation || world.time < replacement_deadline))
		return FALSE
	if(personal_body?.resolve())
		last_status = "A personal shell is already registered. Retire it before requesting another."
		return FALSE
	// A blocked tile should neither discard a confirmed preview nor build a replacement in nullspace.
	if(!core.find_uplink_delivery_turf())
		last_status = "Delivery blocked: free a connected floor tile near your AI core, then retry. Your preview and allowance are unchanged."
		return FALSE
	if(initial_issue)
		if(!candidate || !provisional_body || !candidate.matches_preferences(user.client.prefs) || candidate.include_loadout != include_loadout || (include_loadout && candidate.loadout_policy != candidate.loadout_policy_fingerprint(provisional_body, user.client)))
			prepare(user)
			last_status = "Configuration changed. Review and confirm the refreshed preview."
			return FALSE
	else
		issuing = TRUE
		provisional_delivery = new(null)
		try
			provisional_body = blueprint.build(provisional_delivery, src)
		catch(var/exception/error)
			log_runtime("Uplink replacement construction failed: [error]")
	issuing = TRUE
	var/turf/destination = core?.find_uplink_delivery_turf()
	var/obj/item/organ/brain/cybernetic/ai/brain = provisional_body?.get_organ_by_type(/obj/item/organ/brain/cybernetic/ai)
	if(QDELETED(src) || !destination || delivery_denial() || (!initial_issue && expected_request != request_generation) || QDELETED(provisional_body) || QDELETED(provisional_delivery) || !brain || !brain.is_sufficiently_augmented() || provisional_body.mind || provisional_body.stat)
		issuing = FALSE
		clear_candidate()
		last_status = "Delivery blocked. Free a reachable tile near the core, restore the core link, then retry. Your allowance and deadline are unchanged."
		return FALSE
	var/mob/living/carbon/human/uplink/body = provisional_body
	var/obj/effect/uplink_delivery/delivery = provisional_delivery
	registration_generation++
	body.registry = src
	body.registration_generation = registration_generation
	body.provisional = FALSE
	observe_body(body)
	if(initial_issue)
		blueprint = candidate
		candidate = null
		loadout_outcome = include_loadout ? UPLINK_LOADOUT_ISSUED : UPLINK_LOADOUT_DECLINED
	request_pending = FALSE
	request_generation++
	replacement_deadline = 0
	provisional_body = null
	provisional_delivery = null
	issuing = FALSE
	for(var/atom/movable/item as anything in delivery.contents.Copy())
		item.forceMove(destination)
	qdel(delivery)
	refresh_binding()
	last_status = "Delivered at [get_area_name(body)]. Connect when ready. AI View leaves this body unattended; Resume returns to it. Your loadout decision is final."
	log_game("UPLINK delivered identity=[REF(identity)] registration=[registration_generation] loadout=[loadout_outcome] at [AREACOORD(body)]")
	return TRUE

/datum/uplink_registry/proc/retire_and_request(mob/user)
	if(!viewer_valid(user) || request_pending || issuing || loadout_outcome == UPLINK_LOADOUT_OPEN)
		return
	var/token = request_generation
	var/wait_time = replacement_deadline ? max(0, replacement_deadline - world.time) : CONFIG_GET(number/uplink_replacement_delay)
	var/confirmation = tgui_alert(user, "Accepting retires your current personal shell and disables its connection, camera and toolkit immediately. Its body and possessions remain where they are. A baseline replacement can arrive in [DisplayTimeText(wait_time)]. Canceling delivery will not undo retirement or restart this wait. Continue?", "Schedule Uplink replacement", list("Schedule replacement", "Cancel"))
	if(confirmation != "Schedule replacement" || !viewer_valid(user) || token != request_generation || request_pending || delivery_denial())
		return
	var/mob/living/carbon/human/uplink/body = personal_body?.resolve()
	if(body?.ai_shell_session?.core == core)
		if(!body.ai_shell_session.finish("Personal shell retirement"))
			last_status = "Cannot safely return to the core. Retirement was not accepted."
			return
	if(QDELETED(core) || core.stat == DEAD)
		return
	var/obj/item/organ/brain/cybernetic/ai/brain = bound_brain?.resolve()
	if(brain)
		brain.personal_authorization_revoked = TRUE
	if(body)
		body.retired = TRUE
		body.stow_uplink_tools()
		body.update_uplink_camera()
		if(core.uplink_resume?.resolve() == body)
			core.uplink_resume = null
	observe_body(null)
	bound_brain = null
	registration_generation++
	if(!replacement_deadline)
		replacement_deadline = world.time + CONFIG_GET(number/uplink_replacement_delay)
	request_pending = TRUE
	request_generation++
	addtimer(CALLBACK(src, PROC_REF(replacement_ready), request_generation), max(0, replacement_deadline - world.time))
	log_game("UPLINK replacement accepted identity=[REF(identity)] request=[request_generation] not_before=[replacement_deadline]")
	last_status = "Personal registration retired. The replacement deadline survives cancellation and reconnect."
	// Returning the mind closed its old UI; keep the accepted request visible in the receiving core.
	ui_interact(identity.current)

/datum/uplink_registry/proc/replacement_ready(token)
	if(token != request_generation || !request_pending)
		return
	if(!deliver(identity.current, token))
		to_chat(identity.current, span_notice("Your replacement request is ready or blocked. Use Manage Uplink Shell to retry; the deadline is retained."))

/datum/uplink_registry/proc/cancel_request()
	if(!request_pending)
		return
	request_pending = FALSE
	request_generation++
	last_status = "Request canceled. Retirement and the accepted not-before deadline remain in force."

/datum/uplink_registry/ui_state(mob/user)
	return GLOB.always_state

/datum/uplink_registry/ui_status(mob/user, datum/ui_state/state)
	return viewer_valid(user) ? UI_INTERACTIVE : UI_CLOSE

/datum/uplink_registry/ui_interact(mob/user, datum/tgui/ui)
	if(!viewer_valid(user))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "UplinkShell", "Manage Uplink Shell")
		ui.open()

/datum/uplink_registry/ui_data(mob/user)
	var/mob/living/carbon/human/uplink/body = personal_body?.resolve()
	var/obj/item/organ/brain/cybernetic/ai/brain = bound_brain?.resolve()
	var/controlling_shell = core?.shell_session?.matches()
	return list(
		"status" = last_status,
		"denial" = delivery_denial(),
		"loadout" = loadout_outcome,
		"includeLoadout" = include_loadout,
		"initial" = loadout_outcome == UPLINK_LOADOUT_OPEN,
		"pending" = request_pending,
		"replacementStarted" = !!replacement_deadline,
		"replacementDelay" = CONFIG_GET(number/uplink_replacement_delay) / (1 SECONDS),
		"remaining" = max(0, CEILING((replacement_deadline - world.time) / (1 SECONDS), 1)),
		"hasBody" = !!body,
		"controllingShell" = !!controlling_shell,
		"control" = controlling_shell ? "[core.shell_session.endpoint]" : "AI core",
		"connectionDenial" = body ? core?.shell_connection_denial(body, brain) : "Issue a personal shell first.",
		"returnDenial" = controlling_shell ? core.shell_return_denial(identity) : null,
		"body" = body ? "[body] — [get_area_name(body)], integrity [round(body.health)]/[body.maxHealth], charge [round(body.nutrition / NUTRITION_LEVEL_FULL * 100)]%" : "No current personal body",
		"core" = core ? "[core] — integrity [round(core.health)]/[core.maxHealth], backup [core.battery]/200" : "Core unavailable",
	)

/** The body preview is immutable between preparations; do not resend its PNG on every status tick. */
/datum/uplink_registry/ui_static_data(mob/user)
	return list("preview" = candidate?.preview_icon, "profile" = candidate?.profile_name, "preset" = candidate?.preset_name, "adjustments" = candidate?.adjustments)

/datum/uplink_registry/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !viewer_valid(usr) || issuing)
		return
	switch(action)
		if("label")
			if(loadout_outcome != UPLINK_LOADOUT_OPEN)
				return
			var/new_label = tgui_input_text(usr, "Public shell label. Examination will still identify the owning AI.", "Uplink label", shell_label || core.real_name, MAX_NAME_LEN)
			if(!viewer_valid(usr) || loadout_outcome != UPLINK_LOADOUT_OPEN)
				return
			new_label = reject_bad_name(new_label)
			if(new_label)
				shell_label = new_label
				prepare(usr)
		if("preview")
			prepare(usr)
		if("loadout")
			if(loadout_outcome == UPLINK_LOADOUT_OPEN)
				include_loadout = !include_loadout
				prepare(usr)
		if("issue")
			deliver(usr, request_generation)
		if("replace")
			retire_and_request(usr)
		if("cancel")
			cancel_request()
		if("connect")
			var/mob/living/carbon/human/uplink/body = personal_body?.resolve()
			var/obj/item/organ/brain/cybernetic/ai/brain = bound_brain?.resolve()
			if(usr == core && authorize(body, brain, core))
				core.connect_shell(body, brain)
		if("return")
			core.shell_session?.finish("AI View", ai_view = TRUE)
	if(action in list("label", "preview", "loadout", "issue"))
		update_static_data(usr, ui, always_instant = TRUE)
	return TRUE

/datum/action/innate/manage_uplink
	name = "Manage Uplink Shell"
	desc = "Preview, issue, connect to or retire your personal synthetic body."
	button_icon = 'icons/mob/actions/actions_AI.dmi'
	button_icon_state = "ai_shell"
	var/datum/uplink_registry/registry

/datum/action/innate/manage_uplink/New(datum/uplink_registry/new_registry)
	..()
	registry = new_registry

/datum/action/innate/manage_uplink/Trigger(mob/clicker, trigger_flags)
	if(!..())
		return FALSE
	registry.ui_interact(owner)
	return TRUE

/mob/living/silicon/ai/proc/initialize_personal_uplink()
	if(!mind)
		return
	if(mind.uplink_registry)
		mind.uplink_registry.bind_core(src)
	else
		new /datum/uplink_registry(mind, src)

/// Explicit map landmarks are preferred; the bounded same-area search uses connected open floor.
/obj/effect/landmark/uplink_delivery
	name = "Uplink shell delivery"

/mob/living/silicon/ai/proc/find_uplink_delivery_turf()
	var/turf/start = get_turf(src)
	if(!start || !isturf(loc))
		return null
	var/list/queue = list(start)
	var/list/visited = list(start)
	var/list/valid = list()
	while(length(queue) && length(visited) <= 100)
		var/turf/current = queue[1]
		queue.Cut(1, 2)
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || next in visited || get_area(next) != get_area(start) || !isfloorturf(next) || next.density)
				continue
			visited += next
			var/blocked = FALSE
			for(var/atom/movable/obstacle in next)
				if(obstacle.density || isliving(obstacle))
					blocked = TRUE
					break
			if(blocked)
				continue
			queue += next
			valid += next
	for(var/obj/effect/landmark/uplink_delivery/landmark in GLOB.landmarks_list)
		if(get_turf(landmark) in valid)
			return get_turf(landmark)
	return length(valid) ? valid[1] : null

/obj/effect/uplink_delivery
	name = "provisional Uplink delivery"

/datum/uplink_registry/vv_get_dropdown()
	. = ..()
	VV_DROPDOWN_OPTION("uplink_inspect", "Uplink: inspect current body")
	VV_DROPDOWN_OPTION("uplink_return", "Uplink: safe return")
	VV_DROPDOWN_OPTION("uplink_retry", "Uplink: retry ready delivery")

/datum/uplink_registry/vv_do_topic(list/href_list)
	. = ..()
	if(!. || !check_rights(R_ADMIN))
		return
	if(href_list["uplink_inspect"])
		var/mob/body = personal_body?.resolve()
		to_chat(usr, span_notice("Identity [REF(identity)], registration [registration_generation], request [request_generation], deadline [replacement_deadline], loadout [loadout_outcome]. Body: [body ? "[body] at [AREACOORD(body)]" : "unavailable"]."))
		if(body)
			usr.client.debug_variables(body)
	if(href_list["uplink_return"])
		core?.shell_session?.finish("Administrator recovery")
		log_admin("[key_name(usr)] requested Uplink safe return for [REF(identity)]")
	if(href_list["uplink_retry"])
		if(request_pending && world.time >= replacement_deadline)
			deliver(identity.current, request_generation)
		log_admin("[key_name(usr)] retried Uplink request [request_generation] for [REF(identity)] without resetting claims")

#undef UPLINK_LOADOUT_OPEN
#undef UPLINK_LOADOUT_ISSUED
#undef UPLINK_LOADOUT_DECLINED
