/// Detached values only. This datum cannot load or save a player's preferences.
/datum/preferences/uplink_snapshot
	load_and_save = FALSE
	var/list/snapshot_character
	var/list/snapshot_player

/datum/preferences/uplink_snapshot/New(datum/preferences/source)
	value_cache = deep_copy_list(source.value_cache)
	snapshot_character = deep_copy_list(source.get_save_data_for_savefile_identifier(PREFERENCE_CHARACTER) || list())
	snapshot_player = deep_copy_list(source.get_save_data_for_savefile_identifier(PREFERENCE_PLAYER) || list())
	body_markings = deep_copy_list(source.body_markings)
	augments = deep_copy_list(source.augments)
	augment_limb_styles = deep_copy_list(source.augment_limb_styles)
	all_quirks = source.all_quirks.Copy()
	default_slot = source.default_slot
	unlock_content = source.unlock_content
	donator_status = source.donator_status
	for(var/datum/preference/preference as anything in get_preferences_in_priority_order())
		read_preference(preference.type)

/datum/preferences/uplink_snapshot/get_save_data_for_savefile_identifier(identifier)
	return identifier == PREFERENCE_CHARACTER ? snapshot_character : snapshot_player

/datum/preferences/uplink_snapshot/read_preference(preference_type)
	if(preference_type in value_cache)
		return value_cache[preference_type]
	var/datum/preference/preference = GLOB.preference_entries[preference_type]
	if(!preference)
		return null
	var/value = preference.read(get_save_data_for_savefile_identifier(preference.savefile_identifier), src)
	if(isnull(value))
		value = preference.create_informed_default_value(src)
	value_cache[preference_type] = islist(value) ? deep_copy_list(value) : value
	return value_cache[preference_type]

/datum/preferences/uplink_snapshot/write_preference(datum/preference/preference, value)
	return FALSE

/datum/uplink_blueprint
	var/datum/preferences/uplink_snapshot/preferences
	var/profile_name
	var/preset_name
	var/display_label
	var/include_loadout
	/// Native map view preserves body transforms, height filters and external anatomy.
	var/atom/movable/screen/map_view/char_preview/uplink/preview_view
	var/fingerprint
	var/loadout_policy
	var/list/adjustments

/datum/uplink_blueprint/New(datum/preferences/source, label, with_loadout)
	preferences = new(source)
	profile_name = preferences.read_preference(/datum/preference/name/real_name)
	preset_name = "Preset [preferences.read_preference(/datum/preference/loadout_index)]"
	display_label = label
	include_loadout = with_loadout
	fingerprint = preferences_fingerprint(source)
	adjustments = list("Synthetic physiology and power are retained. Saved chassis, head, limbs, external anatomy, markings and compatible augments configure the body.", "The AI brain, left-arm power cord and right-arm engineering toolkit replace conflicting implants.", "Personal items use the selected preset and its customizations, delivered in a suitcase; baseline clothing remains equipped.", "Body quirks persist between connections. Remaining quirk effects initialize on first connection; quirk supplies are issued only with the first body.", "Species powers, employment records, credentials, bank account and character mind are not copied.")
	if(length(preferences.all_quirks))
		adjustments += "Saved quirks: [jointext(preferences.all_quirks, ", ")]."

/datum/uplink_blueprint/Destroy()
	QDEL_NULL(preview_view)
	QDEL_NULL(preferences)
	return ..()

/datum/uplink_blueprint/proc/preferences_fingerprint(datum/preferences/source)
	return md5(json_encode(list(source.default_slot, source.value_cache, source.get_save_data_for_savefile_identifier(PREFERENCE_CHARACTER), source.body_markings, source.augments, source.augment_limb_styles, source.all_quirks, CONFIG_GET(flag/disable_erp_preferences), CONFIG_GET(flag/disable_mismatched_parts))))

/datum/uplink_blueprint/proc/matches_preferences(datum/preferences/source)
	return fingerprint == preferences_fingerprint(source)

/datum/uplink_blueprint/proc/loadout_policy_fingerprint(mob/living/carbon/human/body, client/player)
	var/list/presets = preferences.read_preference(/datum/preference/loadout)
	var/list/selected = presets[preferences.read_preference(/datum/preference/loadout_index)]
	var/list/items = loadout_list_to_datums(selected)
	var/list/eligibility = list()
	preferences.parent = player
	for(var/datum/loadout_item/item as anything in items)
		eligibility[item.item_path] = item.can_be_applied_to(body, preferences, SSjob.get_job_type(/datum/job/ai), visuals_only = TRUE) && item.is_equippable(body, selected?[item.item_path] || list()) && !(item.erp_box && CONFIG_GET(flag/disable_erp_preferences))
	preferences.parent = null
	return md5(json_encode(eligibility))

/// Shared with live customization: no species changes, limb/organ creation or equipment/resource reset.
/datum/uplink_blueprint/proc/apply_appearance(mob/living/carbon/human/body, fresh = FALSE)
	var/static/list/simple_preferences = list(/datum/preference/choiced/gender, /datum/preference/choiced/body_type, /datum/preference/choiced/mob_height, /datum/preference/choiced/skin_tone, /datum/preference/color/eye_color, /datum/preference/choiced/hairstyle, /datum/preference/color/hair_color, /datum/preference/choiced/hair_gradient, /datum/preference/color/hair_gradient, /datum/preference/choiced/facial_hairstyle, /datum/preference/color/facial_hair_color, /datum/preference/choiced/facial_hair_gradient, /datum/preference/color/facial_hair_gradient, /datum/preference/tri_color/mutant_colors, /datum/preference/choiced/voice, /datum/preference/numeric/tts_voice_pitch, /datum/preference/choiced/tts_blip_base)
	var/static/list/cosmetic_parts = list(FEATURE_TAIL, FEATURE_TAUR, FEATURE_WINGS, FEATURE_EARS, FEATURE_SNOUT, FEATURE_HORNS, FEATURE_FRILLS, FEATURE_SPINES, FEATURE_FLUFF, FEATURE_SYNTH_CHASSIS, FEATURE_SYNTH_HEAD, FEATURE_SYNTH_SCREEN, FEATURE_SYNTH_ANTENNA, FEATURE_MOTH_MARKINGS)
	for(var/datum/preference/preference as anything in get_preferences_in_priority_order())
		if(preference.type in simple_preferences)
			preference.apply_to_human(body, preferences.read_preference(preference.type), preferences)
		else if(preference.relevant_mutant_bodypart in cosmetic_parts)
			if(istype(preference, /datum/preference/choiced/mutant_choice))
				var/datum/preference/choiced/mutant_choice/choice = preference
				var/value = choice.is_visible(body, preferences) ? preferences.read_preference(choice.type) : choice.create_default_value()
				var/datum/mutant_bodypart/part = body.dna.mutant_bodyparts[choice.relevant_mutant_bodypart]
				// Native preference application skips None; live edits must also hide an existing part.
				if(part && value == SPRITE_ACCESSORY_NONE)
					part.name = SPRITE_ACCESSORY_NONE
			if(istype(preference, /datum/preference/choiced/mutant_choice) || istype(preference, /datum/preference/color/mutant) || istype(preference, /datum/preference/tri_color) || istype(preference, /datum/preference/tri_bool))
				preference.apply_to_human(body, preferences.read_preference(preference.type), preferences)
	body.dna.body_markings = deep_copy_list(preferences.body_markings)
	if(fresh)
		var/datum/preference/size_preference = GLOB.preference_entries[/datum/preference/numeric/body_size]
		size_preference.apply_to_human(body, preferences.read_preference(size_preference.type), preferences)
		var/datum/preference/skin_preference = GLOB.preference_entries[/datum/preference/toggle/skin_tone_toggle]
		skin_preference.apply_to_human(body, preferences.read_preference(skin_preference.type), preferences)
		var/datum/preference/eyes_preference = GLOB.preference_entries[/datum/preference/toggle/eye_emissives]
		eyes_preference.apply_to_human(body, preferences.read_preference(eyes_preference.type), preferences)
		body.dna.features[FEATURE_LEGS] = preferences.read_preference(/datum/preference/choiced/digitigrade_legs)
		body.dna.species.replace_body(body, body.dna.species)
		body.dna.species.regenerate_organs(body, body.dna.species, visual_only = TRUE)
		var/datum/preference_middleware/limbs_and_markings/limbs = new(preferences)
		limbs.apply_to_human(body, preferences, visuals_only = body.visual_only_organs)
		qdel(limbs)
	var/species_path = preferences.read_preference(/datum/preference/choiced/species)
	var/datum/species/presentation = GLOB.species_prototypes[species_path]
	if(TRAIT_USES_SKINTONES in presentation?.inherent_traits)
		ADD_TRAIT(body, TRAIT_USES_SKINTONES, "uplink_presentation")
		REMOVE_TRAIT(body, TRAIT_MUTANT_COLORS, "uplink_presentation")
	else
		REMOVE_TRAIT(body, TRAIT_USES_SKINTONES, "uplink_presentation")
		ADD_TRAIT(body, TRAIT_MUTANT_COLORS, "uplink_presentation")
	if(ispath(species_path, /datum/species/synthetic))
		for(var/obj/item/bodypart/limb as anything in body.bodyparts)
			// Preview augments restyle native limbs in place; retain their selected appearance.
			if(initial(limb.limb_id) == SPECIES_SYNTH && (!fresh || !body.visual_only_organs || limb.limb_id == SPECIES_SYNTH))
				limb.remove_color_override(LIMB_COLOR_SYNTH)
				// Sprite IDs are presentation, not physiology; restore the native synthetic styling input.
				limb.reset_appearance(update_owner = FALSE)
		body.dna.species.apply_supplementary_body_changes(body, preferences, !fresh)
	else
		for(var/obj/item/bodypart/limb as anything in body.bodyparts)
			if(!(limb.bodytype & BODYTYPE_SYNTHETIC))
				continue
			if(fresh && body.visual_only_organs && limb.limb_id != SPECIES_SYNTH)
				continue
			limb.remove_color_override(LIMB_COLOR_SYNTH)
			var/obj/item/bodypart/style = presentation?.bodypart_overrides[limb.body_zone]
			if(ispath(style, /obj/item/bodypart/leg) && (limb.bodyshape & BODYSHAPE_DIGITIGRADE))
				var/obj/item/bodypart/leg/leg_style = style
				style = initial(leg_style.digitigrade_type)
			if(!style || !(initial(style.bodyshape) & BODYSHAPE_HUMANOID))
				continue
			var/sprite = initial(style.should_draw_greyscale) ? initial(style.icon_greyscale) : initial(style.icon_static)
			var/sprite_id = initial(style.limb_id)
			var/dimorphic = initial(style.is_dimorphic)
			var/limb_gender = body.physique == FEMALE ? "f" : "m"
			if(icon_exists(sprite, "[sprite_id]_[limb.body_zone][dimorphic ? "_[limb_gender]" : ""][(limb.bodyshape & BODYSHAPE_DIGITIGRADE) ? "_[ICON_KEY_DIGI]" : ""]"))
				limb.change_appearance(sprite, sprite_id, initial(style.should_draw_greyscale), dimorphic, FALSE)
		body.dna.mutant_bodyparts -= list(FEATURE_SYNTH_CHASSIS, FEATURE_SYNTH_HEAD, FEATURE_SYNTH_SCREEN, FEATURE_SYNTH_ANTENNA)
	body.real_name = display_label
	body.name = display_label
	body.dna.real_name = display_label
	if(!fresh)
		for(var/obj/item/organ/organ as anything in body.organs)
			if(organ.bodypart_overlay)
				organ.bodypart_overlay.set_appearance_from_dna(body.dna, limb = organ.bodypart_owner)
	// This refreshes render data on existing limbs; it does not create missing physical parts.
	body.update_body(is_creating = TRUE)
	body.update_hair()
	body.dna.update_body_size()
	if(istype(body, /mob/living/carbon/human/uplink))
		var/mob/living/carbon/human/uplink/uplink = body
		uplink.apply_uplink_protections()

/datum/uplink_blueprint/proc/build(obj/effect/uplink_delivery/delivery, datum/uplink_registry/registry, client/loadout_client)
	var/mob/living/carbon/human/uplink/body = new(delivery)
	body.set_species(/datum/species/synthetic)
	apply_appearance(body, TRUE)
	if(!install_control_organs(body, registry))
		qdel(body)
		return null
	body.nutrition = NUTRITION_LEVEL_FULL
	if(include_loadout && loadout_client)
		loadout_policy = loadout_policy_fingerprint(body, loadout_client)
		var/obj/item/storage/briefcase/empty/overflow = new(delivery)
		// Client exists only for existing eligibility checks; it is never kept in the blueprint.
		preferences.parent = loadout_client
		body.equip_outfit_and_loadout(/datum/outfit/uplink_shell, preferences, equipping_job = SSjob.get_job_type(/datum/job/ai), uplink_container = overflow)
		preferences.parent = null
	else
		body.equipOutfit(/datum/outfit/uplink_shell)
	body.uplink_camera = new(body)
	body.uplink_camera.c_tag = "[display_label] — personal Uplink"
	body.apply_uplink_protections()
	body.issue_quirk_items = !!loadout_client
	if(loadout_client)
		QDEL_NULL(preview_view)
		preview_view = new(null, null, preferences)
		preview_view.generate_view("uplink_preview_[REF(preview_view)]_map")
		preview_view.create_body()
		var/mob/living/carbon/human/dummy/preview = preview_view.body
		preview.set_species(/datum/species/synthetic)
		apply_appearance(preview, TRUE)
		preview.equipOutfit(/datum/outfit/uplink_shell, visuals_only = TRUE)
		apply_quirks(preview, visual_only = TRUE)
		install_control_organs(preview, registry)
		preview_view.update_body()
	return body

/// Required mounts are identical in the displayed preview and the physical body.
/datum/uplink_blueprint/proc/install_control_organs(mob/living/carbon/human/body, datum/uplink_registry/registry)
	var/obj/item/organ/brain/cybernetic/ai/brain = new
	if(!brain.Insert(body, movement_flags = DELETE_IF_REPLACED))
		qdel(brain)
		return FALSE
	var/obj/item/organ/cyberimp/arm/toolkit/power_cord/left_arm/cord = new
	cord.Insert(body, movement_flags = DELETE_IF_REPLACED)
	var/obj/item/organ/cyberimp/arm/toolkit/toolset/uplink/toolkit = new
	toolkit.registry = registry
	toolkit.Insert(body, movement_flags = DELETE_IF_REPLACED)
	return TRUE

/// This view owns a configured dummy; it must not reload the player's job or species selection.
/atom/movable/screen/map_view/char_preview/uplink/update_body()
	body.dna.update_body_size()
	body.apply_height(body, ENTIRE_BODY)
	update_canvas()

/// Use the same visual-quirk filter as character setup; never borrow or mutate the player's live preferences.
/datum/uplink_blueprint/proc/apply_quirks(mob/living/carbon/human/body, visual_only = FALSE)
	var/datum/client_interface/source = new
	source.prefs = preferences
	for(var/quirk_name in preferences.all_quirks)
		var/datum/quirk/quirk_type = SSquirks.quirks[quirk_name]
		if(!quirk_type || (visual_only && !(initial(quirk_type.quirk_flags) & QUIRK_CHANGES_APPEARANCE)))
			continue
		var/datum/quirk/prototype = SSquirks.quirk_prototypes[quirk_type]
		if(!prototype.is_species_appropriate(body.dna.species.type))
			continue
		body.add_quirk(quirk_type, source, announce = FALSE)
	if(visual_only && !isdummy(body))
		var/datum/quirk/belly/belly = locate() in body.quirks
		belly?.add()
	source.prefs = null
	qdel(source)

/datum/outfit/uplink_shell
	name = "Personal Uplink baseline"
	uniform = /obj/item/clothing/under/color/grey
	shoes = /obj/item/clothing/shoes/sneakers/black
	back = /obj/item/storage/backpack/industrial

/mob/living/carbon/human/uplink
	var/datum/uplink_registry/registry
	var/registration_generation = 0
	var/retired = FALSE
	var/obj/machinery/camera/silicon/uplink/uplink_camera
	var/provisional = TRUE
	var/uplink_light_on = FALSE
	var/next_attention_request = 0
	/// Unique quirk supplies belong to the first issuance, independently of reconnects.
	var/issue_quirk_items = FALSE
	/// Mind-dependent effects initialize only once, after the first successful connection.
	var/quirks_initialized = FALSE

/// Keep quirk datums on their physical holder throughout later control transfers.
/mob/living/carbon/human/uplink/proc/initialize_uplink_quirks()
	if(quirks_initialized || provisional || !mind || !registry?.is_current(src))
		return
	quirks_initialized = TRUE
	registry.blueprint?.apply_quirks(src)
	if(issue_quirk_items)
		var/datum/quirk/item_quirk/family_heirloom/heirloom_quirk = locate() in quirks
		registry.quirk_heirloom = heirloom_quirk?.heirloom

/mob/living/carbon/human/uplink/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_SPECIES_GAIN, PROC_REF(on_uplink_species_change))

/mob/living/carbon/human/uplink/proc/on_uplink_species_change()
	SIGNAL_HANDLER
	apply_uplink_protections()

/mob/living/carbon/human/uplink/Life(seconds_per_tick = SSMOBS_DT)
	if(provisional)
		return
	. = ..()
	registry?.body_changed(src)

/mob/living/carbon/human/uplink/proc/apply_uplink_protections()
	var/static/list/protections = list(TRAIT_SHOCKIMMUNE, TRAIT_NO_SLIP_ALL, TRAIT_STUNIMMUNE, TRAIT_RESISTHEAT, TRAIT_RESISTCOLD)
	if(istype(dna?.species, /datum/species/synthetic))
		add_traits(protections, "uplink_chassis")
	else
		remove_traits(protections, "uplink_chassis")

/mob/living/carbon/human/uplink/proc/stow_uplink_tools()
	var/obj/item/organ/cyberimp/arm/toolkit/toolset/uplink/toolkit = get_organ_by_type(/obj/item/organ/cyberimp/arm/toolkit/toolset/uplink)
	toolkit?.Retract()

/// Registration, physical location and live power must allow the feed even between update ticks.
/mob/living/carbon/human/uplink/proc/uplink_camera_available()
	return registry?.is_current(src) && !QDELETED(registry.core) && registry.core.stat != DEAD && stat != DEAD && nutrition > 0 && isturf(loc)

/mob/living/carbon/human/uplink/proc/update_uplink_camera()
	if(QDELETED(uplink_camera))
		return
	var/allowed = uplink_camera_available()
	if(uplink_camera.camera_enabled != !!allowed)
		uplink_camera.toggle_cam(null, FALSE)
	if(!allowed && uplink_light_on)
		uplink_light_on = FALSE
		uplink_camera.set_light(0)

/mob/living/carbon/human/uplink/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	update_uplink_camera()
	if(!QDELETED(uplink_camera))
		SScameras.camera_moved(uplink_camera, get_turf(old_loc), get_turf(src))

/mob/living/carbon/human/uplink/examine(mob/user)
	. = ..()
	. += span_notice("Uplink chassis. Owner: [registry?.core || "unregistered"]. Registration: [retired ? "retired" : registry?.is_current(src) ? "current" : "provisional"]. Control: [ai_shell_session ? "connected" : "unattended"].")
	if(registry?.is_current(src) && user.Adjacent(src))
		. += "<a href='byond://?src=[REF(src)];uplink_attention=1'>Request the owning AI's attention.</a>"

/mob/living/carbon/human/uplink/Topic(href, list/href_list)
	. = ..()
	if(!href_list["uplink_attention"] || !isliving(usr) || usr.incapacitated || !usr.Adjacent(src) || !registry?.is_current(src) || world.time < next_attention_request)
		return
	next_attention_request = world.time + 30 SECONDS
	to_chat(registry.identity.current, span_notice("[usr] requests your attention at your personal Uplink in [get_area_name(src)]."))

/obj/machinery/camera/silicon/uplink
	start_active = FALSE
	camera_enabled = FALSE
	custom_materials = null
	use_power = NO_POWER_USE

/obj/machinery/camera/silicon/uplink/can_use()
	var/mob/living/carbon/human/uplink/body = living_host
	return ..() && istype(body) && body.uplink_camera_available()

/obj/item/organ/brain/cybernetic/ai
	var/datum/uplink_registry/personal_registry
	var/personal_authorization_revoked = FALSE

/mob/living/carbon/human/uplink/can_adjust_stamina_loss(amount, forced, required_biotype = ALL)
	if(amount > 0 && !forced && istype(dna?.species, /datum/species/synthetic))
		return FALSE
	return ..()
