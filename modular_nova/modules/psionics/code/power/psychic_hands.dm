/datum/psionic_power/psychic_hands
	action_type = /datum/action/cooldown/psionic/psychic_hands
	required_powers = list(/datum/action/cooldown/psionic/pointed/telekinetic_hold)

/datum/psionic_rank_variant/psychic_hands
	rank = PSIONIC_RANK_GAMMA
	variant_name = "psychic hands"
	description = "Maintain additional hands, holding their items afloat beside you."
	maintained = TRUE
	cooldown_time = 0
	strain_gain = 0
	active_strain_gain_per_second = 1.5
	block_charge_cost = 0
	/// Largest item these hands can hold. Null removes the size limit.
	var/max_item_weight_class = WEIGHT_CLASS_NORMAL

/datum/psionic_rank_variant/psychic_hands/New()
	. = ..()
	description = "Maintain [PSIONIC_EXTRA_HAND_COUNT] additional hands, holding their items afloat beside you."
	description += isnull(max_item_weight_class) ? " No item size limit." : " Holds normal-sized items or smaller."

/datum/psionic_rank_variant/psychic_hands/alpha
	rank = PSIONIC_RANK_ALPHA
	variant_name = "unbound psychic hands"
	max_item_weight_class = null

/datum/action/cooldown/psionic/psychic_hands
	name = "Psychic Hands"
	desc = "Manifest extra hands. Toggle again to dismiss them and drop their contents."
	button_icon_state = "psi_psychic_hands"
	point_cost = 2
	psionic_flags = PSIONIC_KINETIC
	school = PSIONIC_SCHOOL_GRAVITY
	variant_type = /datum/psionic_rank_variant/psychic_hands
	rank_variant_types = list(
		/datum/psionic_rank_variant/psychic_hands,
		/datum/psionic_rank_variant/psychic_hands/alpha,
	)
	maintain_end_message = "Your psychic hands dissolve, releasing what they held."
	/// The slots present before this manifestation, including any other extra hands.
	var/original_hand_count
	/// Only the limbs owned by this action are removed during teardown.
	var/list/psychic_hands = list()

/datum/action/cooldown/psionic/psychic_hands/New(Target, original = TRUE)
	desc = "Manifest [PSIONIC_EXTRA_HAND_COUNT] extra hands for normal-sized items or smaller. The Alpha form has no item size limit. Select their inventory slots to use held items normally. Toggle again to dismiss them and drop their contents."
	return ..()

/mob/living/carbon/human
	/// Maintained action owning the temporary psychic hand slots.
	var/datum/action/cooldown/psionic/psychic_hands/psychic_hands_action

/// Check the destination slot, so the restriction never affects physical hands.
/mob/living/carbon/human/can_put_in_hand(obj/item/item, hand_index)
	if(!psychic_hand_allows_item(item, hand_index))
		return FALSE
	return ..()

/// Forced placement skips can_put_in_hand(), but must still respect psychic capacity.
/mob/living/carbon/human/put_in_hand(obj/item/item, hand_index, forced = FALSE, ignore_anim = TRUE, visuals_only = FALSE)
	if(!psychic_hand_allows_item(item, hand_index))
		balloon_alert(src, "too large for psychic hand!")
		return FALSE
	return ..()

/mob/living/carbon/human/proc/psychic_hand_allows_item(obj/item/item, hand_index)
	if(!psychic_hands_action || !hand_index || hand_index < 1 || hand_index > length(hand_bodyparts))
		return TRUE
	if(!istype(hand_bodyparts[hand_index], /obj/item/bodypart/arm/psychic))
		return TRUE
	return psychic_hands_action.can_hold_item(item)

/datum/action/cooldown/psionic/psychic_hands/proc/can_hold_item(obj/item/item)
	if(!istype(item))
		return FALSE
	var/datum/psionic_rank_variant/psychic_hands/form = get_form()
	if(!form)
		return FALSE
	return isnull(form.max_item_weight_class) || item.w_class <= form.max_item_weight_class

/// Switching back from Alpha immediately releases items that exceed the smaller form's capacity.
/datum/action/cooldown/psionic/psychic_hands/on_rank_variant_selected(mob/living/living_owner, datum/psionic_rank_variant/variant)
	. = ..()
	if(is_maintaining())
		release_oversized_items(living_owner)

/// Also account for held items changing size or the owner's available rank changing.
/datum/action/cooldown/psionic/psychic_hands/maintain_tick(mob/living/living_owner, datum/component/psionic_profile/profile, seconds_per_tick)
	. = ..()
	if(.)
		release_oversized_items(living_owner)

/datum/action/cooldown/psionic/psychic_hands/proc/release_oversized_items(mob/living/living_owner)
	for(var/obj/item/bodypart/arm/psychic/hand as anything in psychic_hands)
		if(QDELETED(hand) || hand.owner != living_owner)
			continue
		var/obj/item/item = living_owner.get_item_for_held_index(hand.held_index)
		if(item && !can_hold_item(item))
			to_chat(living_owner, span_warning("[item] is too large for your psychic hand and falls!"))
			living_owner.dropItemToGround(item, force = TRUE)

/mob/living/carbon/human/get_held_index_name(i)
	if(i > 0 && i <= length(hand_bodyparts))
		var/obj/item/bodypart/arm/psychic/hand = hand_bodyparts[i]
		if(istype(hand))
			return "[IS_RIGHT_INDEX(i) ? "right" : "left"] psychic hand #[hand.display_pair]"
	return ..()

/mob/living/carbon/human/get_active_hand()
	var/obj/item/bodypart/arm/hand = hand_bodyparts[active_hand_index]
	if(istype(hand, /obj/item/bodypart/arm/psychic))
		return hand
	return ..()

/mob/living/carbon/human/get_item_offsets_for_index(i)
	if(i > 0 && i <= length(hand_bodyparts) && istype(hand_bodyparts[i], /obj/item/bodypart/arm/psychic))
		// The floating effect positions these items; physical upper-arm offsets would lift them twice.
		return list("x" = 0, "y" = 0)
	return ..()

/mob/living/carbon/human/get_inactive_hand()
	var/hand_index = get_inactive_hand_index()
	if(hand_index)
		var/obj/item/bodypart/arm/hand = hand_bodyparts[hand_index]
		if(istype(hand, /obj/item/bodypart/arm/psychic))
			return hand
	return ..()

/datum/action/cooldown/psionic/psychic_hands/is_valid_target(atom/target)
	. = ..()
	if(!. || !ishuman(owner))
		return FALSE
	var/mob/living/carbon/human/human_owner = owner
	return !human_owner.psychic_hands_action

/datum/action/cooldown/psionic/psychic_hands/psionic_activate(atom/target)
	var/mob/living/carbon/human/human_owner = owner
	if(!istype(human_owner) || human_owner.psychic_hands_action)
		return FALSE

	original_hand_count = length(human_owner.held_items)
	human_owner.psychic_hands_action = src
	// Allocate slots directly: change_number_of_hands() would grow ordinary physical arms.
	human_owner.held_items.len = original_hand_count + PSIONIC_EXTRA_HAND_COUNT
	human_owner.hand_bodyparts.len = original_hand_count + PSIONIC_EXTRA_HAND_COUNT
	start_maintaining(human_owner)
	for(var/extra_index in 1 to PSIONIC_EXTRA_HAND_COUNT)
		var/obj/item/bodypart/arm/psychic/hand = new
		hand.held_index = original_hand_count + extra_index
		var/arm_zone = IS_RIGHT_INDEX(hand.held_index) ? BODY_ZONE_R_ARM : BODY_ZONE_L_ARM
		hand.body_zone = "[arm_zone]_[ceil(hand.held_index / 2)]"
		hand.body_part = IS_RIGHT_INDEX(hand.held_index) ? ARM_RIGHT : ARM_LEFT
		hand.display_pair = ceil(extra_index / 2)
		hand.manifestation_color = get_manifestation_color()
		psychic_hands += hand
		if(!hand.try_attach_limb(human_owner, special = TRUE))
			stop_maintaining(human_owner, silent = TRUE)
			return FALSE

	human_owner.hud_used?.build_hand_slots(update_hud = TRUE)
	human_owner.update_held_items()
	to_chat(human_owner, span_purple("[PSIONIC_EXTRA_HAND_COUNT] invisible hands manifest beside you."))
	return TRUE

/datum/action/cooldown/psionic/psychic_hands/can_maintain(mob/living/living_owner, datum/component/psionic_profile/profile)
	if(!..())
		return FALSE
	var/mob/living/carbon/human/human_owner = living_owner
	if(!istype(human_owner) || length(psychic_hands) != PSIONIC_EXTRA_HAND_COUNT)
		return FALSE
	for(var/obj/item/bodypart/arm/psychic/hand as anything in psychic_hands)
		if(QDELETED(hand) || hand.owner != human_owner)
			return FALSE
	return TRUE

/datum/action/cooldown/psionic/psychic_hands/on_maintain_stopped(mob/living/living_owner, silent = FALSE)
	var/mob/living/carbon/human/human_owner = living_owner
	if(!istype(human_owner))
		QDEL_LIST(psychic_hands)
		return

	human_owner.psychic_hands_action = null
	for(var/obj/item/bodypart/arm/psychic/hand as anything in psychic_hands)
		if(QDELETED(hand))
			continue
		if(hand.owner == human_owner)
			human_owner.dropItemToGround(human_owner.get_item_for_held_index(hand.held_index), force = TRUE)
			// Special removal avoids wounds, stumps, and releasing physical handcuffs.
			hand.drop_limb(special = TRUE)
		qdel(hand)
	psychic_hands.Cut()
	human_owner.held_items.len = original_hand_count
	human_owner.hand_bodyparts.len = original_hand_count
	if(human_owner.active_hand_index > original_hand_count)
		human_owner.active_hand_index = 1
	if(!QDELETED(human_owner))
		human_owner.hud_used?.build_hand_slots(update_hud = TRUE)
		human_owner.update_held_items()

/// Functional hand bodyparts with no physical limb sprite or severed remains.
/obj/item/bodypart/arm/psychic
	name = "psychic hand"
	desc = "A hand maintained through psionic focus."
	plaintext_zone = "psychic hand"
	limb_id = "psychic"
	bodypart_flags = BODYPART_PSEUDOPART | BODYPART_UNREMOVABLE | BODYPART_UNHUSKABLE
	biological_state = NONE
	bodytype = NONE
	bodyshape = NONE
	change_exempt_flags = BP_BLOCK_CHANGE_SPECIES
	scarrable = FALSE
	can_be_disabled = FALSE
	stump_typepath = null
	dmg_overlay_type = null
	should_draw_greyscale = FALSE
	// Initialization builds the dropped icon before this hand receives its extra slot index.
	is_actually_just_invisible = TRUE
	/// Vertical pair within the manifested hands.
	var/display_pair = 1
	/// Color captured from the psion's manifestation preference.
	var/manifestation_color
	/// Each hand owns its render target, so items never overwrite another hand's display.
	var/obj/effect/abstract/held_tk_effect/held_effect

/obj/item/bodypart/arm/psychic/Destroy()
	QDEL_NULL(held_effect)
	return ..()

/obj/item/bodypart/arm/psychic/proc/build_held_overlay(mob/living/carbon/human/holder, mutable_appearance/item_overlay)
	if(!held_effect)
		held_effect = new(holder)
		held_effect.is_right = IS_RIGHT_INDEX(held_index)
		held_effect.render_target = "*[REF(src)]_psychic_hand"
		held_effect.RegisterSignal(holder, COMSIG_ATOM_DIR_CHANGE, TYPE_PROC_REF(/obj/effect/abstract/held_tk_effect, on_parent_dir_change))
		holder.vis_contents += held_effect

	// Keep each pair distinct even in side views, above the cosmetic quirk's hands.
	var/side_offset = IS_RIGHT_INDEX(held_index) ? -8 : 8
	held_effect.base_x = list("south" = side_offset, "north" = -side_offset, "east" = side_offset, "west" = -side_offset)
	held_effect.base_y = list("south" = 6 + (display_pair - 1) * 14)
	animate(held_effect)
	held_effect.set_direction_facing(holder.dir)
	held_effect.overlays = list(item_overlay)
	var/mutable_appearance/hover = mutable_appearance(held_effect.icon, IS_RIGHT_INDEX(held_index) ? "hover_right" : "hover_left", HANDS_LAYER)
	// Match the height adjustment already applied to the held item overlay.
	holder.apply_height(hover, LOWER_BODY)
	hover.color = manifestation_color
	held_effect.underlays = list(hover)
	animate(held_effect, pixel_y = 2, time = 1 SECONDS, loop = -1, flags = ANIMATION_RELATIVE)
	animate(pixel_y = -2, time = 1 SECONDS, flags = ANIMATION_RELATIVE)
	var/mutable_appearance/result = mutable_appearance(layer = HANDS_LAYER, offset_spokesman = holder)
	result.render_source = held_effect.render_target
	return result
