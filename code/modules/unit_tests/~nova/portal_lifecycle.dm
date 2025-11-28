#define PORTAL_TEST_WALLSTUCK "wallstuck"
#define PORTAL_TEST_GLORYHOLE "gloryhole"

/**
 * Focused lifecycle coverage for LustWish portal pairs and their borrowed/owned
 * references. UI and configured interaction behavior are covered separately.
 */
/datum/unit_test/portal_lifecycle
	parent_type = /datum/unit_test/portal_test
	abstract_type = /datum/unit_test/portal_lifecycle

/// Returns TRUE when both matrices have exactly the same six components.
/datum/unit_test/portal_lifecycle/proc/matrices_equal(matrix/left, matrix/right)
	return left?.a == right?.a \
		&& left?.b == right?.b \
		&& left?.c == right?.c \
		&& left?.d == right?.d \
		&& left?.e == right?.e \
		&& left?.f == right?.f

/// Returns TRUE when two rendered icons contain identical RGBA pixels.
/datum/unit_test/portal_lifecycle/proc/icons_pixel_equal(icon/left, icon/right)
	if(!left || !right || left.Width() != right.Width() || left.Height() != right.Height())
		return FALSE
	for(var/x in 1 to left.Width())
		for(var/y in 1 to left.Height())
			if(left.GetPixel(x, y) != right.GetPixel(x, y))
				return FALSE
	return TRUE

/// Returns TRUE when an icon contains at least one non-transparent pixel.
/datum/unit_test/portal_lifecycle/proc/icon_has_visible_pixels(icon/rendered_icon)
	for(var/x in 1 to rendered_icon.Width())
		for(var/y in 1 to rendered_icon.Height())
			if(rendered_icon.GetPixel(x, y))
				return TRUE
	return FALSE

/// Returns TRUE when the supplied overlay list contains the portal test marker.
/datum/unit_test/portal_lifecycle/proc/contains_portal_test_overlay(list/overlays)
	for(var/image/overlay as anything in overlays)
		if(overlay:icon == 'modular_nova/modules/modular_items/lewd_items/icons/obj/lewd_structures/lewd_portals.dmi' \
			&& overlay:icon_state == "portal" \
			&& overlay:color == "#123456")
			return TRUE
	return FALSE

/// Whether every cached appearance is present in the visible overlays.
/datum/unit_test/portal_lifecycle/proc/contains_overlay_cache(list/visible_overlays, cache_entry)
	if(islist(cache_entry))
		var/list/cache_group = cache_entry
		for(var/image/cached_appearance as anything in cache_group)
			if(!(cached_appearance.appearance in visible_overlays))
				return FALSE
		return length(cache_group) > 0
	var/image/cached_appearance = cache_entry
	return cached_appearance && (cached_appearance.appearance in visible_overlays)

/// Returns the first cached appearance missing from the mob's overlays.
/datum/unit_test/portal_lifecycle/proc/missing_overlay_cache_description(mob/living/carbon/human/occupant)
	for(var/cache_index in 1 to length(occupant.overlays_standing))
		var/cache_entry = occupant.overlays_standing[cache_index]
		var/list/cache_group = islist(cache_entry) ? cache_entry : list(cache_entry)
		for(var/image/cached_appearance as anything in cache_group)
			if(cached_appearance && !(cached_appearance.appearance in occupant.overlays))
				return "cache layer [cache_index], icon [cached_appearance:icon], state [cached_appearance:icon_state], appearance layer [cached_appearance:layer]"
	return null

/// Whether the standing cache contains the realized appearance.
/datum/unit_test/portal_lifecycle/proc/overlay_cache_contains(list/cache, image/searched_appearance)
	for(var/cache_entry in cache)
		var/list/cache_group = islist(cache_entry) ? cache_entry : list(cache_entry)
		for(var/image/cached_appearance as anything in cache_group)
			if(cached_appearance?.appearance == searched_appearance.appearance)
				return TRUE
	return FALSE

/// Runs one exact-state restoration case for an endpoint direction and portal mode.
/datum/unit_test/portal_lifecycle/proc/check_exact_state_restoration(portal_mode, endpoint_direction)
	var/list/portal_pair = make_portal_pair(portal_mode)
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/obj/structure/lewd_portal/receiving_portal = portal_pair[2]
	var/mob/living/carbon/human/consistent/occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/test_case = "[portal_mode] endpoint direction [endpoint_direction]"

	source_portal.setDir(endpoint_direction)
	receiving_portal.setDir(endpoint_direction)
	occupant.setDir(REVERSE_DIR(endpoint_direction))
	occupant.transform = matrix(1.25, 0.1, 3, -0.05, 0.8, -4)
	occupant.pixel_x = 5
	occupant.pixel_y = -7

	var/obj/item/organ/genital/penis/test_penis
	if(portal_mode == PORTAL_TEST_GLORYHOLE)
		test_penis = configure_test_penis(occupant)
		if(isnull(test_penis))
			TEST_FAIL("Could not deterministically configure an exposed penis for [test_case].")
			return

	var/mutable_appearance/test_overlay = mutable_appearance(
		'modular_nova/modules/modular_items/lewd_items/icons/obj/lewd_structures/lewd_portals.dmi',
		"portal",
		layer = ABOVE_MOB_LAYER,
	)
	test_overlay.color = "#123456"
	occupant.add_overlay(test_overlay)

	var/initial_dir = occupant.dir
	var/matrix/initial_transform = matrix(occupant.transform)
	var/initial_pixel_x = occupant.pixel_x
	var/initial_pixel_y = occupant.pixel_y
	var/initial_overlay_count = length(occupant.overlays)
	var/initial_penis_visibility = test_penis?.visibility_preference

	if(!source_portal.buckle_mob(occupant, force = TRUE, check_loc = FALSE))
		TEST_FAIL("The portal could not start [test_case].")
		return
	TEST_ASSERT_NOTNULL(source_portal.relayed_body, "A successful buckle did not create a relay for [test_case].")
	if(test_penis)
		TEST_ASSERT_EQUAL(test_penis.visibility_preference, initial_penis_visibility, "Portal rendering did not preserve the active penis visibility preference for [test_case].")

	source_portal.unbuckle_mob(occupant, force = TRUE, can_fall = FALSE)

	TEST_ASSERT_NULL(occupant.buckled, "Teardown left the occupant buckled for [test_case].")
	TEST_ASSERT_EQUAL(occupant.dir, initial_dir, "Teardown did not restore the exact direction for [test_case].")
	TEST_ASSERT(matrices_equal(occupant.transform, initial_transform), "Teardown did not restore the exact transform for [test_case].")
	TEST_ASSERT_EQUAL(occupant.pixel_x, initial_pixel_x, "Teardown did not restore pixel_x for [test_case].")
	TEST_ASSERT_EQUAL(occupant.pixel_y, initial_pixel_y, "Teardown did not restore pixel_y for [test_case].")
	TEST_ASSERT_EQUAL(length(occupant.overlays), initial_overlay_count, "Teardown did not restore the overlay count for [test_case].")
	TEST_ASSERT(contains_portal_test_overlay(occupant.overlays), "Teardown did not restore the exact marker overlay for [test_case].")
	if(test_penis)
		TEST_ASSERT_EQUAL(test_penis.visibility_preference, initial_penis_visibility, "Teardown changed the occupant's visibility setting for [test_case].")
	TEST_ASSERT(!QDELETED(source_portal) && !QDELETED(receiving_portal), "Normal teardown deleted a portal endpoint for [test_case].")

/// Verifies the genital source contract required for a gloryhole relay to render.
/datum/unit_test/portal_lifecycle/gloryhole_visual_contract/Run()
	if(CONFIG_GET(flag/disable_lewd_items))
		return

	var/list/portal_pair = make_portal_pair(PORTAL_TEST_GLORYHOLE)
	var/obj/structure/lewd_portal/receiving_portal = portal_pair[2]
	var/mob/living/carbon/human/consistent/occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/organ/genital/penis/test_penis = configure_test_penis(occupant)
	var/test_penis_value = "[test_penis]"
	var/test_penis_exposed = !QDELETED(test_penis) && test_penis.is_exposed()
	var/obj/item/bodypart/test_penis_bodypart_owner = test_penis?.bodypart_owner
	var/test_penis_bodypart_owner_value = "[test_penis_bodypart_owner]"
	var/test_penis_bodypart_owner_owner = test_penis_bodypart_owner?.owner
	var/test_penis_bodypart_owner_owner_value = "[test_penis_bodypart_owner_owner]"

	TEST_ASSERT(test_penis_exposed, "Gloryhole test penis exposure contract failed: penis=[test_penis_value], is_exposed=[test_penis_exposed].")
	TEST_ASSERT_NOTNULL(test_penis_bodypart_owner, "Gloryhole test penis bodypart_owner is null: penis=[test_penis_value], bodypart_owner=[test_penis_bodypart_owner_value], bodypart_owner.owner=[test_penis_bodypart_owner_owner_value], expected_owner=[occupant].")
	TEST_ASSERT_EQUAL(test_penis_bodypart_owner_owner, occupant, "Gloryhole test penis bodypart_owner has the wrong owner: penis=[test_penis_value], bodypart_owner=[test_penis_bodypart_owner_value], bodypart_owner.owner=[test_penis_bodypart_owner_owner_value], expected_owner=[occupant].")

	var/datum/bodypart_overlay/mutant/genital/penis/penis_overlay = test_penis?.bodypart_overlay
	var/datum/sprite_accessory/genital/shaft_datum = penis_overlay?.shaft_datum
	var/datum/sprite_accessory/genital/sprite_datum = penis_overlay?.sprite_datum
	var/shaft_datum_value = "[shaft_datum]"
	var/sprite_datum_value = "[sprite_datum]"
	TEST_ASSERT_NOTNULL(shaft_datum, "Gloryhole test penis shaft_datum is null: penis=[test_penis_value], bodypart_owner=[test_penis_bodypart_owner_value], shaft_datum=[shaft_datum_value], sprite_datum=[sprite_datum_value].")
	TEST_ASSERT_NOTNULL(sprite_datum, "Gloryhole test penis sprite_datum is null: penis=[test_penis_value], bodypart_owner=[test_penis_bodypart_owner_value], shaft_datum=[shaft_datum_value], sprite_datum=[sprite_datum_value].")

	var/list/generated_overlays = penis_overlay?.get_all_overlays(test_penis_bodypart_owner)
	var/generated_overlay_count = length(generated_overlays)
	TEST_ASSERT(generated_overlay_count > 0, "Gloryhole test penis generated no overlays: penis=[test_penis_value], bodypart_owner=[test_penis_bodypart_owner_value], shaft_datum=[shaft_datum_value], sprite_datum=[sprite_datum_value], generated_overlay_count=[generated_overlay_count].")

	var/overlay_index = 0
	var/compatible_overlay_count = 0
	var/front_under_compatible_index = 0
	var/image/front_under_overlay
	var/list/invalid_overlay_details = list()
	for(var/image/generated_overlay as anything in generated_overlays)
		overlay_index++
		var/generated_icon = generated_overlay.icon
		var/generated_icon_state = generated_overlay.icon_state
		var/generated_icon_exists = FALSE
		if(generated_icon && !isnull(generated_icon_state))
			generated_icon_exists = icon_exists(generated_icon, generated_icon_state)
		if(generated_icon && !isnull(generated_icon_state) && generated_icon_exists)
			compatible_overlay_count++
			if(findtext(generated_icon_state, "_FRONT_UNDER"))
				front_under_compatible_index = compatible_overlay_count
				front_under_overlay = generated_overlay
		else
			invalid_overlay_details += "overlay #[overlay_index]: icon=[generated_icon], icon_state=[generated_icon_state], icon_exists=[generated_icon_exists]"
	TEST_ASSERT(compatible_overlay_count > 0, "Gloryhole test penis generated no compatible overlays: penis=[test_penis_value], bodypart_owner=[test_penis_bodypart_owner_value], shaft_datum=[shaft_datum_value], sprite_datum=[sprite_datum_value], generated_overlay_count=[generated_overlay_count], compatible_overlay_count=[compatible_overlay_count], invalid_layers=[jointext(invalid_overlay_details, "; ")].")
	TEST_ASSERT_NOTNULL(front_under_overlay, "Gloryhole test penis generated no compatible FRONT_UNDER layer.")
	TEST_ASSERT(!icon_has_visible_pixels(getFlatIcon(front_under_overlay, defdir = NORTH, no_anim = TRUE)), "The Human FRONT_UNDER source unexpectedly contains north-facing pixels; north is intentionally transparent.")

	for(var/render_direction in list(SOUTH, EAST, WEST))
		receiving_portal.setDir(render_direction == SOUTH ? SOUTH : REVERSE_DIR(render_direction))
		var/obj/effect/lewd_portal_relay/gloryhole_relay = allocate(/obj/effect/lewd_portal_relay, receiving_portal.loc, occupant, receiving_portal)
		var/gloryhole_relay_overlay_count = length(gloryhole_relay?.overlays)
		TEST_ASSERT(!QDELETED(gloryhole_relay), "Gloryhole relay failed to initialize for render direction [render_direction]: relay=[gloryhole_relay], relay_deleted=[QDELETED(gloryhole_relay)], penis=[test_penis_value], bodypart_owner=[test_penis_bodypart_owner_value], shaft_datum=[shaft_datum_value], sprite_datum=[sprite_datum_value], generated_overlay_count=[generated_overlay_count], compatible_overlay_count=[compatible_overlay_count].")
		TEST_ASSERT_EQUAL(gloryhole_relay.dir, render_direction, "Gloryhole relay selected the wrong render direction for receiver direction [receiving_portal.dir].")
		TEST_ASSERT_EQUAL(gloryhole_relay_overlay_count, compatible_overlay_count, "Gloryhole relay overlay count did not match compatible generated layers for render direction [render_direction]: relay=[gloryhole_relay], relay_deleted=[QDELETED(gloryhole_relay)], relay_overlay_count=[gloryhole_relay_overlay_count], generated_overlay_count=[generated_overlay_count], compatible_overlay_count=[compatible_overlay_count], shaft_datum=[shaft_datum_value], sprite_datum=[sprite_datum_value].")
		var/image/relay_front_under_overlay = gloryhole_relay.overlays[front_under_compatible_index]
		TEST_ASSERT_EQUAL(relay_front_under_overlay.layer, front_under_overlay.layer, "Gloryhole relay changed the FRONT_UNDER layer for render direction [render_direction].")
		var/icon/source_pixels = getFlatIcon(front_under_overlay, defdir = render_direction, no_anim = TRUE)
		var/icon/relay_pixels = getFlatIcon(relay_front_under_overlay, defdir = render_direction, no_anim = TRUE)
		TEST_ASSERT(icon_has_visible_pixels(source_pixels), "The Human FRONT_UNDER source has no visible pixels for supported render direction [render_direction].")
		TEST_ASSERT(icons_pixel_equal(source_pixels, relay_pixels), "Gloryhole relay FRONT_UNDER pixels differ from the source for render direction [render_direction].")
		qdel(gloryhole_relay)

/// Exact mob state survives every endpoint direction in both rendering modes.
/datum/unit_test/portal_lifecycle/exact_state_restoration/Run()
	for(var/portal_mode in list(PORTAL_TEST_WALLSTUCK, PORTAL_TEST_GLORYHOLE))
		if(portal_mode == PORTAL_TEST_GLORYHOLE && CONFIG_GET(flag/disable_lewd_items))
			continue
		for(var/endpoint_direction in list(NORTH, SOUTH, EAST, WEST))
			check_exact_state_restoration(portal_mode, endpoint_direction)

/// A preference changed through its real setter survives teardown before the queued refresh.
/datum/unit_test/portal_lifecycle/live_visibility_teardown/Run()
	if(CONFIG_GET(flag/disable_lewd_items))
		return

	var/list/portal_pair = make_portal_pair(PORTAL_TEST_GLORYHOLE)
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/mob/living/carbon/human/consistent/occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/organ/genital/penis/test_penis = configure_test_penis(occupant)
	TEST_ASSERT_NOTNULL(test_penis, "The visibility teardown test could not create its exposed organ.")
	TEST_ASSERT(source_portal.buckle_mob(occupant, force = TRUE, check_loc = FALSE), "The visibility teardown session could not start.")
	var/obj/effect/lewd_portal_relay/session_relay = source_portal.relayed_body

	TEST_ASSERT(test_penis.apply_visibility_label("Never show"), "The visibility menu setter rejected a valid setting.")
	// Teardown can happen before the deferred visual refresh observes the new setting.
	source_portal.unbuckle_mob(occupant, force = TRUE, can_fall = FALSE)

	TEST_ASSERT_EQUAL(test_penis.visibility_preference, GENITAL_NEVER_SHOW, "Immediate teardown overwrote the occupant's new visibility setting.")
	TEST_ASSERT_NULL(occupant.buckled, "Immediate visibility teardown left the occupant buckled.")
	TEST_ASSERT(QDELETED(session_relay), "Immediate visibility teardown left its relay alive.")

/// Either endpoint owns the pair, and repeated same-tick deletion stays idempotent.
/datum/unit_test/portal_lifecycle/pair_deletion/Run()
	var/list/first_pair = make_portal_pair()
	var/obj/structure/lewd_portal/first_source = first_pair[1]
	var/obj/structure/lewd_portal/first_receiver = first_pair[2]

	qdel(first_source)
	qdel(first_receiver)
	qdel(first_source)
	TEST_ASSERT(QDELETED(first_source), "Deleting the first endpoint did not delete it.")
	TEST_ASSERT(QDELETED(first_receiver), "Deleting the first endpoint did not delete its peer.")

	var/list/second_pair = make_portal_pair()
	var/obj/structure/lewd_portal/second_source = second_pair[1]
	var/obj/structure/lewd_portal/second_receiver = second_pair[2]

	qdel(second_receiver)
	TEST_ASSERT(QDELETED(second_source), "Deleting the second endpoint did not delete its peer.")
	TEST_ASSERT(QDELETED(second_receiver), "Deleting the second endpoint did not delete it.")

/// Normal teardown owns the relay, borrows the occupant, and preserves the pair.
/datum/unit_test/portal_lifecycle/normal_session_teardown/Run()
	var/list/portal_pair = make_portal_pair()
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/obj/structure/lewd_portal/receiving_portal = portal_pair[2]
	var/mob/living/carbon/human/consistent/occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)

	TEST_ASSERT(source_portal.buckle_mob(occupant, force = TRUE, check_loc = FALSE), "The wallstuck portal could not start a deterministic test session.")
	var/obj/effect/lewd_portal_relay/session_relay = source_portal.relayed_body
	var/datum/component/interactable/interaction_component = occupant.GetComponent(/datum/component/interactable)
	TEST_ASSERT_NOTNULL(session_relay, "A successful buckle did not create its owned relay.")
	TEST_ASSERT_EQUAL(interaction_component?.resolve_body_relay(), session_relay, "The interaction component did not observe the active relay.")

	source_portal.unbuckle_mob(occupant, force = TRUE, can_fall = FALSE)

	TEST_ASSERT_NULL(source_portal.current_mob, "Normal unbuckle retained the borrowed occupant reference.")
	TEST_ASSERT_NULL(source_portal.relayed_body, "Normal unbuckle retained the owned relay reference.")
	TEST_ASSERT(QDELETED(session_relay), "Normal unbuckle did not delete the owned relay.")
	TEST_ASSERT_NULL(interaction_component.resolve_body_relay(), "Normal unbuckle left a stale interaction-component relay.")
	TEST_ASSERT_NULL(occupant.buckled, "Normal teardown left the occupant buckled.")
	TEST_ASSERT(!QDELETED(source_portal) && !QDELETED(receiving_portal), "Normal teardown deleted a portal endpoint.")
	TEST_ASSERT(source_portal.linked_portal == receiving_portal && receiving_portal.linked_portal == source_portal, "Normal teardown broke the reciprocal portal pair.")

/// Preserves equipment changes through portal teardown.
/datum/unit_test/portal_lifecycle/live_appearance_restoration/Run()
	var/list/portal_pair = make_portal_pair()
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/mob/living/carbon/human/consistent/occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	TEST_ASSERT(source_portal.buckle_mob(occupant, force = TRUE, check_loc = FALSE), "The live-appearance portal session could not start.")

	var/obj/item/clothing/shoes/sneakers/black/test_shoes = allocate(/obj/item/clothing/shoes/sneakers/black, occupant.loc)
	TEST_ASSERT(occupant.equip_to_slot_if_possible(test_shoes, ITEM_SLOT_FEET), "The portal occupant could not equip the appearance-test shoes.")
	source_portal.flush_current_mob_visual_refresh()
	var/shoes_cache = occupant.overlays_standing[SHOES_LAYER]
	TEST_ASSERT_NOTNULL(shoes_cache, "Equipping shoes during the portal session did not populate the standing-overlay cache.")

	source_portal.unbuckle_mob(occupant, force = TRUE, can_fall = FALSE)
	TEST_ASSERT(contains_overlay_cache(occupant.overlays, shoes_cache), "Portal teardown restored a display that did not match the updated shoes cache.")

	occupant.update_worn_shoes()
	shoes_cache = occupant.overlays_standing[SHOES_LAYER]
	TEST_ASSERT(contains_overlay_cache(occupant.overlays, shoes_cache), "A post-teardown shoes refresh exposed an inconsistent standing-overlay cache.")
	TEST_ASSERT(occupant.transferItemToLoc(test_shoes, occupant.loc, force = TRUE, silent = TRUE), "The portal occupant could not remove the appearance-test shoes.")
	TEST_ASSERT_NULL(occupant.overlays_standing[SHOES_LAYER], "Removing shoes after portal teardown left a stale standing-overlay cache entry.")
	TEST_ASSERT(!contains_overlay_cache(occupant.overlays, shoes_cache), "Removing shoes after portal teardown left their stale visible overlay.")

/// Starts a new session after an old relay is gone, then invalidates its source through the visual signal path.
/datum/unit_test/portal_lifecycle/proc/check_signal_invalidated_session(invalidate_anatomy = FALSE)
	if(CONFIG_GET(flag/disable_lewd_items))
		return

	var/list/portal_pair = make_portal_pair(PORTAL_TEST_GLORYHOLE)
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/obj/structure/lewd_portal/receiving_portal = portal_pair[2]
	var/mob/living/carbon/human/consistent/occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/organ/genital/penis/test_penis = configure_test_penis(occupant)
	var/datum/component/interactable/interaction_component = occupant.GetComponent(/datum/component/interactable)

	TEST_ASSERT_NOTNULL(test_penis, "The signal invalidation test could not create its exposed penis.")
	TEST_ASSERT_NOTNULL(interaction_component, "The signal invalidation test human is missing its interaction component.")
	if(isnull(test_penis) || isnull(interaction_component))
		return

	occupant.setDir(EAST)
	occupant.transform = matrix(1.25, 0.1, 3, -0.05, 0.8, -4)
	occupant.pixel_x = 5
	occupant.pixel_y = -7
	var/mutable_appearance/test_overlay = mutable_appearance(
		'modular_nova/modules/modular_items/lewd_items/icons/obj/lewd_structures/lewd_portals.dmi',
		"portal",
		layer = ABOVE_MOB_LAYER,
	)
	test_overlay.color = "#123456"
	occupant.add_overlay(test_overlay)

	var/initial_dir = occupant.dir
	var/matrix/initial_transform = matrix(occupant.transform)
	var/initial_pixel_x = occupant.pixel_x
	var/initial_pixel_y = occupant.pixel_y
	TEST_ASSERT(source_portal.buckle_mob(occupant, force = TRUE, check_loc = FALSE), "The portal could not start the first signal invalidation session.")
	var/obj/effect/lewd_portal_relay/old_relay = source_portal.relayed_body
	TEST_ASSERT(source_portal.is_active_session(occupant, old_relay), "The first signal invalidation session was not active.")

	// End and restart so the old, deleted relay is an explicit stale-session value.
	source_portal.end_session()
	TEST_ASSERT(QDELETED(old_relay), "Ending the first signal invalidation session did not delete its relay.")
	TEST_ASSERT(!source_portal.is_active_session(occupant, old_relay), "is_active_session accepted the deleted relay from the previous session.")
	TEST_ASSERT_NULL(interaction_component.resolve_body_relay(), "Ending the first signal invalidation session left a relay weak reference.")

	TEST_ASSERT(source_portal.buckle_mob(occupant, force = TRUE, check_loc = FALSE), "The portal could not restart after the first signal invalidation session.")
	var/obj/effect/lewd_portal_relay/session_relay = source_portal.relayed_body
	TEST_ASSERT(source_portal.is_active_session(occupant, session_relay), "The restarted signal invalidation session was not active.")
	TEST_ASSERT(!source_portal.is_active_session(occupant, old_relay), "is_active_session accepted a stale relay for the restarted session.")
	var/list/invalidated_penis_overlays = test_penis.bodypart_overlay?.get_all_overlays(test_penis.bodypart_owner)

	if(invalidate_anatomy)
		qdel(test_penis)
	else
		var/datum/bodypart_overlay/mutant/genital/penis/penis_overlay = test_penis.bodypart_overlay
		TEST_ASSERT_NOTNULL(penis_overlay, "The visual invalidation test penis is missing its bodypart overlay.")
		if(isnull(penis_overlay))
			return
		// Keep the organ alive but remove every supported visual datum. The relay
		// must fail closed instead of retaining an empty or misleading old image.
		penis_overlay.shaft_datum = null
		penis_overlay.sprite_datum = null
		occupant.update_body()

	source_portal.flush_current_mob_visual_refresh()

	TEST_ASSERT_NULL(source_portal.current_mob, "Invalidating a required session resource retained the borrowed occupant.")
	TEST_ASSERT_NULL(source_portal.relayed_body, "Invalidating a required session resource retained the owned relay reference.")
	TEST_ASSERT(QDELETED(session_relay), "Invalidating a required session resource did not delete the owned relay.")
	TEST_ASSERT_NULL(interaction_component.resolve_body_relay(), "Invalidating a required session resource left the component relay weak reference.")
	TEST_ASSERT_NULL(occupant.buckled, "Invalidating a required session resource left the occupant buckled.")
	TEST_ASSERT(!QDELETED(occupant), "Invalidating a required session resource deleted the borrowed occupant.")
	TEST_ASSERT(!QDELETED(source_portal) && !QDELETED(receiving_portal), "Invalidating a required session resource deleted the portal pair.")
	TEST_ASSERT_EQUAL(occupant.dir, initial_dir, "Signal invalidation did not restore the occupant's exact direction.")
	TEST_ASSERT(matrices_equal(occupant.transform, initial_transform), "Signal invalidation did not restore the occupant's exact transform.")
	TEST_ASSERT_EQUAL(occupant.pixel_x, initial_pixel_x, "Signal invalidation did not restore the occupant's exact pixel_x.")
	TEST_ASSERT_EQUAL(occupant.pixel_y, initial_pixel_y, "Signal invalidation did not restore the occupant's exact pixel_y.")
	TEST_ASSERT(contains_portal_test_overlay(occupant.overlays), "Signal invalidation did not restore the original test overlay.")
	var/cache_mismatch = missing_overlay_cache_description(occupant)
	TEST_ASSERT_NULL(cache_mismatch, "Signal invalidation restored visible overlays which did not match the current standing-overlay cache: [cache_mismatch].")
	for(var/image/stale_penis_overlay as anything in invalidated_penis_overlays)
		var/stale_in_cache = overlay_cache_contains(occupant.overlays_standing, stale_penis_overlay)
		TEST_ASSERT(!(stale_penis_overlay.appearance in occupant.overlays), "Signal invalidation retained a stale penis overlay; current cache contains it: [stale_in_cache].")
	if(!invalidate_anatomy)
		TEST_ASSERT(!QDELETED(test_penis), "Visual support invalidation deleted the borrowed genital organ.")

/// Removing the required anatomy through a live mob update ends the session cleanly.
/datum/unit_test/portal_lifecycle/anatomy_signal_invalidation/Run()
	check_signal_invalidated_session(invalidate_anatomy = TRUE)

/// Losing every supported sprite datum fails closed through the live mob signal path.
/datum/unit_test/portal_lifecycle/visual_signal_invalidation/Run()
	check_signal_invalidated_session(invalidate_anatomy = FALSE)

/// Externally deleting the relay ends only its source session.
/datum/unit_test/portal_lifecycle/direct_relay_deletion/Run()
	var/list/portal_pair = make_portal_pair()
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/obj/structure/lewd_portal/receiving_portal = portal_pair[2]
	var/mob/living/carbon/human/consistent/occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)

	TEST_ASSERT(source_portal.buckle_mob(occupant, force = TRUE, check_loc = FALSE), "The wallstuck portal could not start a relay-deletion session.")
	var/obj/effect/lewd_portal_relay/session_relay = source_portal.relayed_body
	qdel(session_relay)
	source_portal.end_session()

	TEST_ASSERT(QDELETED(session_relay), "The externally deleted relay is still live.")
	TEST_ASSERT_NULL(source_portal.current_mob, "Relay deletion retained the borrowed occupant reference.")
	TEST_ASSERT_NULL(source_portal.relayed_body, "Relay deletion retained the owned relay reference.")
	TEST_ASSERT_NULL(occupant.buckled, "Relay deletion left the occupant buckled.")
	TEST_ASSERT(!QDELETED(source_portal) && !QDELETED(receiving_portal), "Relay deletion destroyed the portal pair.")
	TEST_ASSERT(source_portal.linked_portal == receiving_portal && receiving_portal.linked_portal == source_portal, "Relay deletion broke the reciprocal portal pair.")

/// Deleting the borrowed occupant ends the session without deleting either endpoint.
/datum/unit_test/portal_lifecycle/occupant_deletion/Run()
	var/list/portal_pair = make_portal_pair()
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/obj/structure/lewd_portal/receiving_portal = portal_pair[2]
	var/mob/living/carbon/human/consistent/occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)

	TEST_ASSERT(source_portal.buckle_mob(occupant, force = TRUE, check_loc = FALSE), "The wallstuck portal could not start an occupant-deletion session.")
	var/obj/effect/lewd_portal_relay/session_relay = source_portal.relayed_body
	qdel(occupant)

	TEST_ASSERT(QDELETED(occupant), "The test occupant was not deleted.")
	TEST_ASSERT(QDELETED(session_relay), "Occupant deletion did not delete the owned relay.")
	TEST_ASSERT_NULL(source_portal.current_mob, "Occupant deletion retained the borrowed occupant reference.")
	TEST_ASSERT_NULL(source_portal.relayed_body, "Occupant deletion retained the owned relay reference.")
	TEST_ASSERT(!source_portal.has_buckled_mobs(), "Occupant deletion left a stale buckle entry on the portal.")
	TEST_ASSERT(!QDELETED(source_portal) && !QDELETED(receiving_portal), "Occupant deletion destroyed the portal pair.")
	TEST_ASSERT(source_portal.linked_portal == receiving_portal && receiving_portal.linked_portal == source_portal, "Occupant deletion broke the reciprocal portal pair.")

/// Deleting the non-owning interaction component does not own or strand the session.
/datum/unit_test/portal_lifecycle/component_deletion/Run()
	var/list/portal_pair = make_portal_pair()
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/obj/structure/lewd_portal/receiving_portal = portal_pair[2]
	var/mob/living/carbon/human/consistent/occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)

	TEST_ASSERT(source_portal.buckle_mob(occupant, force = TRUE, check_loc = FALSE), "The wallstuck portal could not start a component-deletion session.")
	var/obj/effect/lewd_portal_relay/session_relay = source_portal.relayed_body
	var/datum/component/interactable/interaction_component = occupant.GetComponent(/datum/component/interactable)
	TEST_ASSERT_NOTNULL(interaction_component, "The active session is missing its interaction component.")

	qdel(interaction_component)
	TEST_ASSERT(!QDELETED(session_relay), "Deleting a non-owning interaction component deleted the session relay.")
	TEST_ASSERT_EQUAL(source_portal.current_mob, occupant, "Deleting a non-owning interaction component ended the session.")
	TEST_ASSERT_EQUAL(source_portal.relayed_body, session_relay, "Deleting a non-owning interaction component cleared the owned relay.")

	source_portal.end_session()
	TEST_ASSERT(QDELETED(session_relay), "Session teardown did not delete its relay after component deletion.")
	TEST_ASSERT_NULL(source_portal.current_mob, "Session teardown retained its occupant after component deletion.")
	TEST_ASSERT_NULL(occupant.buckled, "Session teardown left the occupant buckled after component deletion.")
	TEST_ASSERT(!QDELETED(source_portal) && !QDELETED(receiving_portal), "Component deletion or teardown destroyed the portal pair.")

/// Deleting an occupied endpoint restores the borrowed mob and deletes both endpoints.
/datum/unit_test/portal_lifecycle/occupied_endpoint_deletion/Run()
	var/list/portal_pair = make_portal_pair()
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/obj/structure/lewd_portal/receiving_portal = portal_pair[2]
	var/mob/living/carbon/human/consistent/occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	occupant.setDir(EAST)
	occupant.transform = matrix(0.75, 0.15, -2, -0.2, 1.4, 6)
	occupant.pixel_x = -3
	occupant.pixel_y = 9
	var/initial_dir = occupant.dir
	var/matrix/initial_transform = matrix(occupant.transform)
	var/initial_pixel_x = occupant.pixel_x
	var/initial_pixel_y = occupant.pixel_y

	TEST_ASSERT(source_portal.buckle_mob(occupant, force = TRUE, check_loc = FALSE), "The wallstuck portal could not start an endpoint-deletion session.")
	var/obj/effect/lewd_portal_relay/session_relay = source_portal.relayed_body
	qdel(source_portal)

	TEST_ASSERT(QDELETED(source_portal) && QDELETED(receiving_portal), "Deleting an occupied endpoint did not delete the whole pair.")
	TEST_ASSERT(QDELETED(session_relay), "Deleting an occupied endpoint did not delete its owned relay.")
	TEST_ASSERT(!QDELETED(occupant), "Deleting an occupied endpoint deleted its borrowed occupant.")
	TEST_ASSERT_NULL(occupant.buckled, "Deleting an occupied endpoint left its occupant buckled.")
	TEST_ASSERT_EQUAL(occupant.dir, initial_dir, "Endpoint deletion did not restore the occupant's exact direction.")
	TEST_ASSERT(matrices_equal(occupant.transform, initial_transform), "Endpoint deletion did not restore the occupant's exact transform.")
	TEST_ASSERT_EQUAL(occupant.pixel_x, initial_pixel_x, "Endpoint deletion did not restore the occupant's exact pixel_x.")
	TEST_ASSERT_EQUAL(occupant.pixel_y, initial_pixel_y, "Endpoint deletion did not restore the occupant's exact pixel_y.")

/// An obsolete relay may not clear a newer relay's weak observer reference.
/datum/unit_test/portal_lifecycle/old_relay_weakref/Run()
	var/mob/living/carbon/human/consistent/occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/structure/lewd_portal/receiving_portal = allocate(/obj/structure/lewd_portal, get_step(run_loc_floor_bottom_left, EAST))
	receiving_portal.portal_mode = PORTAL_TEST_WALLSTUCK
	var/datum/component/interactable/interaction_component = occupant.GetComponent(/datum/component/interactable)
	TEST_ASSERT_NOTNULL(interaction_component, "The test human is missing its interaction component.")

	var/obj/effect/lewd_portal_relay/old_relay = allocate(/obj/effect/lewd_portal_relay, receiving_portal.loc, occupant, receiving_portal)
	var/obj/effect/lewd_portal_relay/new_relay = allocate(/obj/effect/lewd_portal_relay, receiving_portal.loc, occupant, receiving_portal)
	TEST_ASSERT(!QDELETED(old_relay) && !QDELETED(new_relay), "The deterministic wallstuck relays failed to initialize.")
	TEST_ASSERT_EQUAL(interaction_component.resolve_body_relay(), new_relay, "The newest relay was not installed as the observer target.")

	qdel(old_relay)
	TEST_ASSERT_EQUAL(interaction_component.resolve_body_relay(), new_relay, "An obsolete relay cleared the newer relay's weak reference.")
	qdel(new_relay)
	TEST_ASSERT_NULL(interaction_component.resolve_body_relay(), "Deleting the current relay left a stale weak reference.")

/// The bore mounts through the public wallframe path and restarts if its first portal disappears.
/datum/unit_test/portal_lifecycle/wallframe_staging/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/turf/closed/west_support = get_step(user, WEST)
	var/turf/closed/south_support = get_step(user, SOUTH)
	var/obj/item/wallframe/lewd_portal/portal_bore = allocate(/obj/item/wallframe/lewd_portal, user.loc)

	TEST_ASSERT(isclosedturf(west_support) && isclosedturf(south_support), "The wallframe test fixture is missing its expected supports.")
	TEST_ASSERT_EQUAL(portal_bore.interact_with_atom(west_support, user), ITEM_INTERACT_SUCCESS, "The bore could not mount its first endpoint.")
	TEST_ASSERT(!QDELETED(portal_bore), "The bore was consumed after its first endpoint.")
	var/obj/structure/lewd_portal/first_portal = portal_bore.first_portal
	TEST_ASSERT_NOTNULL(first_portal, "The bore did not track its first endpoint.")
	var/datum/component/atom_mounted/first_mount = first_portal.GetComponent(/datum/component/atom_mounted)
	TEST_ASSERT_NOTNULL(first_mount, "The first endpoint was not mounted through the wallframe path.")
	TEST_ASSERT_EQUAL(first_mount?.hanging_support_atom, west_support, "The first endpoint mounted to the wrong support.")
	TEST_ASSERT_EQUAL(portal_bore.interact_with_atom(west_support, user), ITEM_INTERACT_FAILURE, "The bore mounted through an occupied wall position.")
	TEST_ASSERT_EQUAL(portal_bore.first_portal, first_portal, "A failed placement changed the staged endpoint.")
	qdel(first_portal)
	TEST_ASSERT_NULL(portal_bore.first_portal, "External deletion left the staged endpoint on the bore.")
	TEST_ASSERT_NULL(portal_bore.second_portal, "External deletion left a sister endpoint on the bore.")

	TEST_ASSERT_EQUAL(portal_bore.interact_with_atom(west_support, user), ITEM_INTERACT_SUCCESS, "The bore could not replace its deleted first endpoint.")
	TEST_ASSERT(!QDELETED(portal_bore), "The bore was consumed while replacing its deleted first endpoint.")
	var/obj/structure/lewd_portal/replacement_portal = portal_bore.first_portal
	TEST_ASSERT_NOTNULL(replacement_portal, "The bore did not restart staging after its first endpoint disappeared.")
	var/datum/component/atom_mounted/replacement_mount = replacement_portal.GetComponent(/datum/component/atom_mounted)
	TEST_ASSERT_NOTNULL(replacement_mount, "The replacement endpoint was not mounted through the wallframe path.")
	TEST_ASSERT_EQUAL(replacement_mount?.hanging_support_atom, west_support, "The replacement endpoint mounted to the wrong support.")

	TEST_ASSERT_EQUAL(portal_bore.interact_with_atom(south_support, user), ITEM_INTERACT_SUCCESS, "The bore could not mount its second endpoint.")
	TEST_ASSERT(!QDELETED(portal_bore), "The bore was consumed after completing its portal pair.")
	var/obj/structure/lewd_portal/final_portal = replacement_portal.linked_portal
	TEST_ASSERT_NOTNULL(final_portal, "The replacement endpoint was not linked after the second placement.")
	var/datum/component/atom_mounted/final_mount = final_portal.GetComponent(/datum/component/atom_mounted)
	TEST_ASSERT_NOTNULL(final_mount, "The final endpoint was not mounted through the wallframe path.")
	TEST_ASSERT_EQUAL(final_mount?.hanging_support_atom, south_support, "The final endpoint mounted to the wrong support.")
	TEST_ASSERT(replacement_portal.linked_portal == final_portal && final_portal.linked_portal == replacement_portal, "The bore did not create a reciprocal replacement pair.")
	TEST_ASSERT_EQUAL(portal_bore.first_portal, replacement_portal, "The bore lost its first completed endpoint.")
	TEST_ASSERT_EQUAL(portal_bore.second_portal, final_portal, "The bore lost its second completed endpoint.")

	portal_bore.attack_self(user)
	TEST_ASSERT(!QDELETED(portal_bore), "Collapsing the pair deleted its bore.")
	TEST_ASSERT(QDELETED(replacement_portal) && QDELETED(final_portal), "Using the bore in hand did not delete both endpoints.")
	TEST_ASSERT_NULL(portal_bore.first_portal, "Collapsing the pair left the first endpoint on the bore.")
	TEST_ASSERT_NULL(portal_bore.second_portal, "Collapsing the pair left the second endpoint on the bore.")

	TEST_ASSERT_EQUAL(portal_bore.interact_with_atom(west_support, user), ITEM_INTERACT_SUCCESS, "The bore could not stage a new pair after collapsing the old one.")
	TEST_ASSERT_EQUAL(portal_bore.interact_with_atom(south_support, user), ITEM_INTERACT_SUCCESS, "The bore could not complete a new pair after collapsing the old one.")
	var/obj/structure/lewd_portal/external_first = portal_bore.first_portal
	var/obj/structure/lewd_portal/external_second = portal_bore.second_portal
	qdel(external_second)
	TEST_ASSERT(QDELETED(external_first) && QDELETED(external_second), "External endpoint deletion did not remove its sister portal.")
	TEST_ASSERT_NULL(portal_bore.first_portal, "External endpoint deletion left the first endpoint on the bore.")
	TEST_ASSERT_NULL(portal_bore.second_portal, "External endpoint deletion left the second endpoint on the bore.")

	TEST_ASSERT_EQUAL(portal_bore.interact_with_atom(west_support, user), ITEM_INTERACT_SUCCESS, "The bore could not stage a pair after external deletion.")
	TEST_ASSERT_EQUAL(portal_bore.interact_with_atom(south_support, user), ITEM_INTERACT_SUCCESS, "The bore could not complete a pair after external deletion.")
	var/obj/structure/lewd_portal/owned_first = portal_bore.first_portal
	var/obj/structure/lewd_portal/owned_second = portal_bore.second_portal
	qdel(portal_bore)
	TEST_ASSERT(QDELETED(owned_first) && QDELETED(owned_second), "Deleting the bore did not delete its completed pair.")

	var/obj/item/wallframe/lewd_portal/staging_bore = allocate(/obj/item/wallframe/lewd_portal, user.loc)
	TEST_ASSERT_EQUAL(staging_bore.interact_with_atom(west_support, user), ITEM_INTERACT_SUCCESS, "The bore could not mount an endpoint for deletion ownership coverage.")
	var/obj/structure/lewd_portal/staged_portal = staging_bore.first_portal
	TEST_ASSERT_NOTNULL(staged_portal, "The bore did not stage an endpoint for deletion ownership coverage.")
	var/datum/component/atom_mounted/staged_mount = staged_portal.GetComponent(/datum/component/atom_mounted)
	TEST_ASSERT_NOTNULL(staged_mount, "The deletion-ownership endpoint was not mounted through the wallframe path.")
	TEST_ASSERT_EQUAL(staged_mount?.hanging_support_atom, west_support, "The deletion-ownership endpoint mounted to the wrong support.")
	qdel(staging_bore)
	TEST_ASSERT(QDELETED(staged_portal), "Deleting a bore left its unpaired staged endpoint behind.")

/// Losing a real wall support tears down the occupied pair and releases its reusable bore.
/datum/unit_test/portal_lifecycle/wall_support_destruction/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/turf/west_support = get_step(user, WEST)
	var/turf/south_support = get_step(user, SOUTH)
	var/obj/item/wallframe/lewd_portal/portal_bore = allocate(/obj/item/wallframe/lewd_portal, user.loc)
	portal_bore.creation_mode = PORTAL_TEST_WALLSTUCK
	TEST_ASSERT(isclosedturf(west_support) && isclosedturf(south_support), "The wall destruction fixture is missing its expected supports.")
	TEST_ASSERT_EQUAL(portal_bore.interact_with_atom(west_support, user), ITEM_INTERACT_SUCCESS, "The bore could not mount its first wall destruction endpoint.")
	TEST_ASSERT_EQUAL(portal_bore.interact_with_atom(south_support, user), ITEM_INTERACT_SUCCESS, "The bore could not mount its second wall destruction endpoint.")
	var/obj/structure/lewd_portal/first_portal = portal_bore.first_portal
	var/obj/structure/lewd_portal/second_portal = portal_bore.second_portal
	TEST_ASSERT(first_portal.buckle_mob(user, force = TRUE, check_loc = FALSE), "The wall destruction fixture could not start an occupied session.")
	var/obj/effect/lewd_portal_relay/session_relay = first_portal.relayed_body
	var/datum/component/interactable/interaction_component = user.GetComponent(/datum/component/interactable)

	var/original_support_type = west_support.type
	var/original_baseturfs = islist(west_support.baseturfs) ? west_support.baseturfs.Copy() : west_support.baseturfs
	var/turf/destroyed_support = west_support.ChangeTurf(/turf/open/floor/plating)
	// Restore the shared fixture before any assertion can return from this test.
	west_support = destroyed_support.ChangeTurf(original_support_type, original_baseturfs)

	TEST_ASSERT(QDELETED(first_portal) && QDELETED(second_portal), "Destroying a mounted endpoint's wall left its portal pair alive.")
	TEST_ASSERT(QDELETED(session_relay), "Destroying the supporting wall left an active relay alive.")
	TEST_ASSERT_NULL(user.buckled, "Destroying the supporting wall left the occupant buckled.")
	TEST_ASSERT_NULL(interaction_component?.resolve_body_relay(), "Destroying the supporting wall left a stale interaction relay.")
	TEST_ASSERT_NULL(portal_bore.first_portal, "Destroying the supporting wall left the first endpoint on its bore.")
	TEST_ASSERT_NULL(portal_bore.second_portal, "Destroying the supporting wall left the second endpoint on its bore.")
	TEST_ASSERT(!QDELETED(portal_bore), "Destroying the supporting wall consumed its reusable bore.")
	TEST_ASSERT_EQUAL(portal_bore.interact_with_atom(west_support, user), ITEM_INTERACT_SUCCESS, "The bore could not mount again after its support was rebuilt.")

/// Ordinary frames remain single-use, while only opted-in frames work without floors.
/datum/unit_test/portal_lifecycle/wallframe_defaults
	normal_floor_required = TRUE

/datum/unit_test/portal_lifecycle/wallframe_defaults/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
	var/turf/closed/east_support = get_step(user, EAST)
	var/turf/closed/north_support = get_step(user, NORTH)
	var/obj/item/wallframe/fish/ordinary_wallframe = allocate(/obj/item/wallframe/fish, user.loc)
	var/obj/item/wallframe/lewd_portal/portal_bore = allocate(/obj/item/wallframe/lewd_portal, user.loc)
	var/obj/item/wallframe/torch_mount/torch_mount = allocate(/obj/item/wallframe/torch_mount, user.loc)

	TEST_ASSERT(isclosedturf(east_support) && isclosedturf(north_support), "The wallframe test fixture is missing its expected supports.")
	TEST_ASSERT(ordinary_wallframe.requires_floor, "Ordinary wallframes no longer require floor placement.")
	TEST_ASSERT(!portal_bore.requires_floor, "The portal bore lost its non-floor placement opt-in.")
	TEST_ASSERT(!torch_mount.requires_floor, "The torch mount lost its existing non-floor placement behavior.")
	TEST_ASSERT_EQUAL(ordinary_wallframe.interact_with_atom(east_support, user), ITEM_INTERACT_SUCCESS, "An ordinary wallframe could not mount through the public interaction path.")
	TEST_ASSERT(QDELETED(ordinary_wallframe), "An ordinary wallframe survived its first successful placement.")

	var/obj/structure/fish_mount/mounted_fish_frame = locate() in user.loc
	TEST_ASSERT_NOTNULL(mounted_fish_frame, "The ordinary wallframe did not create its configured result.")
	var/datum/component/atom_mounted/fish_mount_component = mounted_fish_frame.GetComponent(/datum/component/atom_mounted)
	TEST_ASSERT_NOTNULL(fish_mount_component, "The ordinary wallframe result was not mounted.")
	TEST_ASSERT_EQUAL(fish_mount_component?.hanging_support_atom, east_support, "The ordinary wallframe result mounted to the wrong support.")
	qdel(mounted_fish_frame)
	var/turf/original_user_turf = get_turf(user)
	var/original_user_turf_type = original_user_turf.type
	var/original_user_turf_baseturfs = islist(original_user_turf.baseturfs) ? original_user_turf.baseturfs.Copy() : original_user_turf.baseturfs
	var/turf/open/space/floorless_turf = original_user_turf.ChangeTurf(/turf/open/space)
	user.forceMove(floorless_turf)

	var/obj/item/wallframe/fish/floor_restricted_frame = allocate(/obj/item/wallframe/fish, user.loc)
	var/ordinary_floorless_valid = floor_restricted_frame.try_build(east_support, user)
	var/portal_floorless_result = portal_bore.interact_with_atom(east_support, user)
	var/obj/structure/lewd_portal/floorless_portal = portal_bore.first_portal
	var/torch_floorless_result = torch_mount.interact_with_atom(north_support, user)
	var/obj/structure/wall_torch/mounted_torch = locate() in floorless_turf
	floorless_turf.ChangeTurf(original_user_turf_type, original_user_turf_baseturfs)

	TEST_ASSERT(!ordinary_floorless_valid, "An ordinary wallframe accepted a floorless placement.")
	TEST_ASSERT_EQUAL(portal_floorless_result, ITEM_INTERACT_SUCCESS, "The portal bore rejected a valid floorless placement.")
	TEST_ASSERT(!QDELETED(portal_bore), "The portal bore was consumed after its first floorless placement.")
	TEST_ASSERT_NOTNULL(floorless_portal, "The portal bore did not create a floorless endpoint.")
	var/datum/component/atom_mounted/floorless_portal_mount = floorless_portal.GetComponent(/datum/component/atom_mounted)
	TEST_ASSERT_NOTNULL(floorless_portal_mount, "The floorless portal endpoint was not mounted.")
	TEST_ASSERT_EQUAL(floorless_portal_mount?.hanging_support_atom, east_support, "The floorless portal endpoint mounted to the wrong support.")
	TEST_ASSERT_EQUAL(torch_floorless_result, ITEM_INTERACT_SUCCESS, "The torch mount rejected a historically valid floorless placement.")
	TEST_ASSERT_NOTNULL(mounted_torch, "The torch mount did not create its configured floorless result.")
	var/datum/component/atom_mounted/torch_mount_component = mounted_torch.GetComponent(/datum/component/atom_mounted)
	TEST_ASSERT_NOTNULL(torch_mount_component, "The floorless torch result was not mounted.")
	TEST_ASSERT_EQUAL(torch_mount_component?.hanging_support_atom, north_support, "The floorless torch result mounted to the wrong support.")
	TEST_ASSERT(QDELETED(torch_mount) && !QDELETED(mounted_torch), "The torch mount did not consume into its configured result on a floorless turf.")

#undef PORTAL_TEST_WALLSTUCK
#undef PORTAL_TEST_GLORYHOLE
