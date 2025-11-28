/obj/item/organ/genital/penis
	name = "penis"
	desc = "A male reproductive organ."
	icon_state = "penis"
	icon = 'modular_nova/master_files/icons/obj/genitals/penis.dmi'
	zone = BODY_ZONE_PRECISE_GROIN
	slot = ORGAN_SLOT_PENIS
	mutantpart_key = ORGAN_SLOT_PENIS
	drop_when_organ_spilling = FALSE
	bodypart_overlay = /datum/bodypart_overlay/mutant/genital/penis
	var/girth = 9

/datum/bodypart_overlay/mutant/genital/penis
	feature_key = ORGAN_SLOT_PENIS
	layers = list(
		EXTERNAL_FRONT_UNDER_CLOTHES = PENIS_LAYER,
		EXTERNAL_BEHIND = BODY_BEHIND_LAYER,
	)
	genital_stack_rank = 2
	offset_location = ENTIRE_BODY
	/// The shaft accessory as picked in prefs. sprite_datum points here when unsheathed.
	var/datum/sprite_accessory/genital/shaft_datum
	/// The sheath accessory, or null for sheathless penises.
	var/datum/sprite_accessory/genital/sheath/sheath_datum

// taur_penis_onmob.dmi only has art for the BEHIND layer (it renders tucked behind the
/datum/bodypart_overlay/mutant/genital/penis/get_all_overlays(obj/item/bodypart/limb)
	var/datum/sprite_accessory/genital/genital_datum = sprite_datum
	if(genital_datum?.uses_taur_sprite(limb?.owner))
		set_layers(list(EXTERNAL_BEHIND = BODY_BEHIND_LAYER - (genital_stack_rank * GENITAL_STACK_STEP)))
	else
		set_layers(list(
			EXTERNAL_FRONT_UNDER_CLOTHES = PENIS_LAYER,
			EXTERNAL_BEHIND = BODY_BEHIND_LAYER,
		))
	return ..()

/obj/item/organ/genital/penis/get_description_string(datum/sprite_accessory/genital/penis/penis)
	var/returned_string = ""
	var/genital_descriptor = LOWER_TEXT(get_genital_descriptor(penis))
	var/pname = genital_descriptor + "[length(get_genital_descriptor(penis)) ? " " : ""]"
	if(is_sheathed())
		var/datum/bodypart_overlay/mutant/genital/penis/our_overlay = bodypart_overlay
		returned_string = "You see a [LOWER_TEXT(our_overlay.sheath_datum.name)]."
		if(aroused == AROUSAL_PARTIAL)
			returned_string += " There's a [pname]penis poking out of it."
	else
		returned_string = "You see a [pname]penis. You estimate it's [genital_size] inches long, and [girth] inches in circumference."
		switch(aroused)
			if(AROUSAL_NONE)
				returned_string += " It seems flaccid."
			if(AROUSAL_PARTIAL)
				returned_string += " It's partially erect."
			if(AROUSAL_FULL)
				returned_string += " It's fully erect."
	return returned_string

/obj/item/organ/genital/penis/update_genital_icon_state()
	var/size_affix
	var/measured_size = floor(genital_size)
	if(measured_size < 1)
		measured_size = 1
	switch(measured_size)
		if(1 to 8)
			size_affix = "1"
		if(9 to 15)
			size_affix = "2"
		if(16 to 24)
			size_affix = "3"
		else
			size_affix = "4"
	var/passed_string = "penis_[genital_type]_[size_affix]"
	if(uses_skintones)
		passed_string += "_s"
	icon_state = passed_string

/datum/bodypart_overlay/mutant/genital/penis/set_appearance_from_dna(datum/dna/dna, accessory_name, feature_key, obj/item/bodypart/limb)
	. = ..()
	if(!.)
		return
	// The base proc just set sprite_datum to the shaft - remember it so we can swap back.
	shaft_datum = sprite_datum
	var/sheath_name = dna.features["penis_sheath"]
	sheath_datum = null
	if(sheath_name && sheath_name != SPRITE_ACCESSORY_NONE)
		var/datum/sprite_accessory/genital/sheath/style = SSaccessories.sprite_accessories[FEATURE_SHEATH][sheath_name]
		if(istype(style))
			sheath_datum = style

/// Points sprite_datum at the sheath or the shaft
/datum/bodypart_overlay/mutant/genital/penis/proc/set_sheathed(sheathed)
	if(sheathed && !sheath_datum)
		sheathed = FALSE // Can't sheath without a sheath.
	sprite_datum = sheathed ? sheath_datum : shaft_datum

/// Resolves and applies a sheath style by accessory name. Null/"None" clears it.
/datum/bodypart_overlay/mutant/genital/penis/proc/set_sheath_style(sheath_name)
	sheath_datum = null
	if(sheath_name && sheath_name != SPRITE_ACCESSORY_NONE)
		var/datum/sprite_accessory/genital/sheath/style = SSaccessories.sprite_accessories[FEATURE_SHEATH]?[sheath_name]
		if(istype(style))
			sheath_datum = style

/// Re-resolves the sheath from the owner's DNA and refreshes the sprite.
/obj/item/organ/genital/penis/proc/refresh_sheath()
	var/datum/bodypart_overlay/mutant/genital/penis/our_overlay = bodypart_overlay
	our_overlay?.set_sheath_style(owner?.dna?.features["penis_sheath"])
	update_sprite_suffix()
	owner?.update_body()

/// Re-syncs taur mode (e.g. after the "penis_taur_mode" DNA feature was toggled) and refreshes the sprite.
/obj/item/organ/genital/penis/proc/refresh_taur_mode()
	update_sprite_suffix()
	owner?.update_body()

/// Whether this penis has a sheath at all, regardless of arousal state.
/// Contrast is_sheathed(), which is whether it's currently retracted into it.
/obj/item/organ/genital/penis/proc/has_sheath()
	var/datum/bodypart_overlay/mutant/genital/penis/our_overlay = bodypart_overlay
	return !isnull(our_overlay?.sheath_datum)

/// Whether the penis is currently hidden in its sheath.
/obj/item/organ/genital/penis/proc/is_sheathed()
	var/datum/bodypart_overlay/mutant/genital/penis/our_overlay = bodypart_overlay
	return our_overlay?.sheath_datum && aroused != AROUSAL_FULL

/// Whether this penis should currently render using its taur art (if the shaft has any).
/obj/item/organ/genital/penis/proc/uses_taur_mode()
	var/datum/bodypart_overlay/mutant/genital/penis/our_overlay = bodypart_overlay
	return !!our_overlay?.shaft_datum?.uses_taur_sprite(owner)

/obj/item/organ/genital/penis/update_sprite_suffix()
	// Swap the active datum BEFORE the base proc computes/stamps the suffix,
	// so the suffix and the datum can never describe different sprites.
	var/datum/bodypart_overlay/mutant/genital/penis/our_overlay = bodypart_overlay
	our_overlay?.set_sheathed(is_sheathed())
	return ..()

/obj/item/organ/genital/penis/on_mob_insert(mob/living/carbon/organ_owner, special, movement_flags)
	. = ..()
	update_sprite_suffix()

/obj/item/organ/genital/penis/get_sprite_size_string(minimum_sprite_affix = 1)
	if(is_sheathed())
		var/datum/bodypart_overlay/mutant/genital/penis/our_overlay = bodypart_overlay
		var/poking_out = (aroused == AROUSAL_PARTIAL) ? 1 : 0
		var/sheath_state = our_overlay.sheath_datum.uses_taur_sprite(owner) ? (our_overlay.sheath_datum.taur_icon_state || our_overlay.sheath_datum.icon_state) : our_overlay.sheath_datum.icon_state
		return "[sheath_state]_[poking_out]"

	var/size_affix
	var/measured_size = floor(genital_size)
	var/is_erect = (aroused == AROUSAL_FULL) ? 1 : 0
	if(measured_size < 1)
		measured_size = 1
	switch(measured_size)
		if(1 to 6)
			size_affix = "1"
		if(7 to 11)
			size_affix = "2"
		if(12 to 36)
			size_affix = "3"
		if(37 to 48)
			size_affix = "4"
		if(49 to 56)
			size_affix = "5"
		if(57 to 64)
			size_affix = "6"
		else
			size_affix = "7"
	var/datum/bodypart_overlay/mutant/genital/penis/our_overlay = bodypart_overlay
	var/taur_mode = uses_taur_mode()
	var/base_name
	if(taur_mode)
		// there's no distinct erect/non erect version for taur mode
		is_erect = 0
		base_name = our_overlay.shaft_datum.taur_icon_state || genital_type
	// taur_penis_onmob.dmi only goes up to size 4, and has no skintoned "_s" variants.
	var/affix_cap = taur_mode ? our_overlay.shaft_datum.taur_max_sprite_size_affix : max_sprite_size_affix
	affix_cap = max(affix_cap, 1)
	var/minimum_affix = clamp(minimum_sprite_affix, 1, affix_cap)
	size_affix = "[clamp(text2num(size_affix), minimum_affix, affix_cap)]"
	if(isnull(base_name))
		base_name = genital_type
	var/passed_string = "[base_name]_[size_affix]_[is_erect]"
	if(uses_skintones && !taur_mode)
		passed_string += "_s"
	return passed_string

/obj/item/organ/genital/penis/build_from_dna(datum/dna/DNA, associated_key)
	girth = DNA.features["penis_girth"]
	uses_skin_color = DNA.features["penis_uses_skincolor"]
	genital_size = DNA.features["penis_size"]

	return ..()

/obj/item/organ/genital/penis/build_from_accessory(datum/sprite_accessory/genital/accessory, datum/dna/DNA)
	uses_skintones = DNA.features["penis_uses_skintones"] ? accessory.has_skintone_shading : FALSE
	return ..()

/datum/bodypart_overlay/mutant/genital/penis/get_global_feature_list()
	return SSaccessories.sprite_accessories[ORGAN_SLOT_PENIS]
