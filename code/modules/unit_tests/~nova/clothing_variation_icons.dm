/**
 * Checks that supports_variations_flags is being used correctly for clothing items that set it.
 *
 * Also covers the BODYSHAPE_CUSTOM species (Vox, Vox Primalis, Teshari, Monkey), which aren't gated by any flag -
 * they read worn_icon_vox and friends through generate_custom_worn_icon(), so what gets checked there is the
 * icon files, the greyscale_config_worn_* configs that bake into them, and templates that exist but go unreferenced.
 *
 * TODO: phasing out the runtime icon_exists() checks for special icons in favor of running CI against them
 */
/datum/unit_test/clothing_variation_icons

/datum/unit_test/clothing_variation_icons/Run()
	var/list/blacklist = runtime_assigned_types()
	var/list/variants = species_variants()

	for(var/obj/item/item_path as anything in (valid_subtypesof(/obj/item) - blacklist))
		if(initial(item_path.item_flags) & ABSTRACT)
			continue

		var/icon_state = worn_state_of(item_path)
		if(!icon_state)
			continue

		check_digitigrade(item_path, icon_state)
		check_big_legs(item_path, icon_state)
		check_snouted(item_path, icon_state)
		check_species_files(item_path, icon_state, variants)

/// Creates a blacklist of items that get their variation icons at runtime, so whatever they're compiled with is meaningless.
/// MOD parts get theirs from the theme (mod_theme.dm); the sleeping bag is the same kind of item.
/// There's probably going to be more like this, add as needed when they start failing.
/datum/unit_test/clothing_variation_icons/proc/runtime_assigned_types()
	var/list/blacklist = valid_typesof(/obj/item/mod)
	blacklist += valid_typesof(/obj/item/clothing/suit/mod)
	blacklist += valid_typesof(/obj/item/clothing/shoes/mod)
	blacklist += valid_typesof(/obj/item/clothing/head/mod)
	blacklist += valid_typesof(/obj/item/clothing/gloves/mod)
	blacklist += valid_typesof(/obj/item/clothing/glasses/mod)
	blacklist += valid_typesof(/obj/item/clothing/suit/straight_jacket/kinky_sleepbag)
	blacklist += valid_typesof(/obj/item/belly_function)
	return blacklist

/*
 * Working out which icon_state actually gets drawn
 */

/// The icon_state build_worn_icon() draws from.
/datum/unit_test/clothing_variation_icons/proc/worn_state_of(obj/item/item_path)
	var/post_init_state = initial(item_path.post_init_icon_state) || initial(item_path.icon_state)
	if(ispath(item_path, /obj/item/clothing/under)) // uniforms always pass override_state
		return post_init_state
	return initial(item_path.worn_icon_state) || post_init_state

/// Returns the second icon_state a suit draws from once it's opened up or has its hood raised, or null if it has neither.
/datum/unit_test/clothing_variation_icons/proc/worn_state_swapped(obj/item/item_path)
	if(initial(item_path.worn_icon_state))
		return null

	// /datum/component/toggle_icon
	if(ispath(item_path, /obj/item/clothing/suit/toggle))
		var/toggle_base = initial(item_path.base_icon_state) || worn_state_of(item_path)
		return toggle_base ? "[toggle_base]_t" : null

	// /datum/component/toggle_attached_clothing
	if(ispath(item_path, /obj/item/clothing/suit/hooded))
		var/obj/item/clothing/suit/hooded/hooded_path = item_path
		var/affix = initial(hooded_path.hood_up_affix)
		var/hood_base = worn_state_of(item_path)
		return (affix && hood_base) ? "[hood_base][affix]" : null

	return null

/// The icon_state a uniform draws from while it's rolled down, or null if it can't be adjusted.
/datum/unit_test/clothing_variation_icons/proc/worn_state_adjusted(obj/item/item_path)
	if(!ispath(item_path, /obj/item/clothing/under))
		return null

	var/obj/item/clothing/under/under_path = item_path
	if(!initial(under_path.can_adjust))
		return null

	var/base = worn_state_of(item_path)
	return base ? "[base]_d" : null

/*
 * Checks digitigrade-related things
 */
/datum/unit_test/clothing_variation_icons/proc/check_digitigrade(obj/item/item_path, icon_state)
	var/is_under = ispath(item_path, /obj/item/clothing/under)
	var/is_suit = ispath(item_path, /obj/item/clothing/suit)
	var/is_shoes = ispath(item_path, /obj/item/clothing/shoes)

	var/flags = initial(item_path.supports_variations_flags)
	var/wants_variation = (flags & CLOTHING_DIGITIGRADE_VARIATION)
	var/wants_mask = (flags & CLOTHING_DIGITIGRADE_MASK)
	var/lists_digi_bodyshape = (initial(item_path.bodyshapes_with_variations) & BODYSHAPE_DIGITIGRADE)

	// generate_digitigrade_icons() is only implemented for uniforms, suits and shoes.
	if(wants_mask && !is_under && !is_suit && !is_shoes)
		TEST_FAIL("[item_path] sets CLOTHING_DIGITIGRADE_MASK but nothing implements generate_digitigrade_icons() for its slot - it would stack_trace in game.")
	var/has_gags_digi = initial(item_path.greyscale_colors) && initial(item_path.greyscale_config_worn_digi)
	if(has_gags_digi && !wants_variation)
		TEST_FAIL("[item_path] sets greyscale_config_worn_digi but not CLOTHING_DIGITIGRADE_VARIATION - the generated digi sprite can never be used.")

	var/stray_bodyshapes = initial(item_path.bodyshapes_with_variations) & ~BODYSHAPE_DIGITIGRADE
	if(stray_bodyshapes)
		report(FALSE, "[item_path] lists bodyshapes get_bodyshape_icon() can't act on in bodyshapes_with_variations ([stray_bodyshapes]) - only BODYSHAPE_DIGITIGRADE does anything there.")

	// GAGS owns the sprite from here, see check_gags_config().
	if(has_gags_digi || !(is_under || is_suit || is_shoes))
		return

	// Uniforms fall back to the human dmi when the digi sprite is missing (human_update_icons.dm, update_worn_undersuit). Suits and shoes just render blank in that case.
	var/hard_fail = is_suit || is_shoes

	var/worn_icon_digi = initial(item_path.worn_icon_digi)
	var/digi_file = worn_icon_digi || (is_under ? DIGITIGRADE_UNIFORM_FILE : (is_suit ? DIGITIGRADE_SUIT_FILE : DIGITIGRADE_SHOES_FILE))
	var/digi_sprite_exists = icon_exists(digi_file, icon_state)

	if(wants_variation && !digi_sprite_exists)
		report(hard_fail, "[item_path] sets CLOTHING_DIGITIGRADE_VARIATION but has no matching digi sprite - \"[icon_state]\" not found in '[digi_file]'. Either supports_variations_flags is wrong, or the icon_state is missing.")

	var/holds_file_for_subtypes = worn_icon_digi && has_digi_subtype(item_path)
	if(!wants_variation && digi_sprite_exists && !holds_file_for_subtypes)
		TEST_FAIL("[item_path] has a \"[icon_state]\" sprite in '[digi_file]' but does not set CLOTHING_DIGITIGRADE_VARIATION - the sprite is going unused in-game.")

	if((flags & CLOTHING_DIGITIGRADE_VARIATION_NO_NEW_ICON) && worn_icon_digi && !holds_file_for_subtypes)
		report(FALSE, "[item_path] sets CLOTHING_DIGITIGRADE_VARIATION_NO_NEW_ICON but also sets worn_icon_digi = '[worn_icon_digi]', and no subtype uses it - the file reference does nothing.")

	if(wants_mask && !lists_digi_bodyshape)
		TEST_FAIL("[item_path] sets CLOTHING_DIGITIGRADE_MASK but bodyshapes_with_variations doesn't include BODYSHAPE_DIGITIGRADE, so the mask is never generated.")

	// get_bodyshape_icon() only masks when CLOTHING_DIGITIGRADE_VARIATION is absent.
	if(wants_mask && wants_variation)
		TEST_FAIL("[item_path] sets both CLOTHING_DIGITIGRADE_MASK and CLOTHING_DIGITIGRADE_VARIATION - the variation wins and the mask never applies.")

	// With a digi variation there's nothing for get_bodyshape_icon() to do, the icons are already premade
	if((flags & (CLOTHING_DIGITIGRADE_VARIATION|CLOTHING_DIGITIGRADE_VARIATION_NO_NEW_ICON)) && lists_digi_bodyshape)
		report(FALSE, "[item_path] sets a digitigrade variation flag but still lists BODYSHAPE_DIGITIGRADE in bodyshapes_with_variations - that should be NONE, the mask is only for CLOTHING_DIGITIGRADE_MASK.")

	if(!wants_variation)
		return

	var/base_file = initial(item_path.worn_icon) || (is_under ? DEFAULT_UNIFORM_FILE : (is_suit ? DEFAULT_SUIT_FILE : DEFAULT_SHOES_FILE))

	var/swapped_state = worn_state_swapped(item_path)
	if(swapped_state && icon_exists(base_file, swapped_state) && !icon_exists(digi_file, swapped_state))
		report(hard_fail, "[item_path] has an opened sprite \"[swapped_state]\" in '[base_file]' but not in '[digi_file]' - opening it up renders nothing on digitigrade legs.")

	var/adjusted_state = worn_state_adjusted(item_path)
	if(adjusted_state && icon_exists(base_file, adjusted_state) && !icon_exists(digi_file, adjusted_state))
		report(FALSE, "[item_path] has a rolled-down sprite \"[adjusted_state]\" in '[base_file]' but not in '[digi_file]' - adjusting it renders nothing on digitigrade legs.")

/*
 * Checks big legs (taur) related things
 */
/datum/unit_test/clothing_variation_icons/proc/check_big_legs(obj/item/item_path, icon_state)
	var/flags = initial(item_path.supports_variations_flags)
	var/wants_variation = (flags & CLOTHING_BIG_LEGS_VARIATION)

	if(wants_variation && (flags & CLOTHING_BIG_LEGS_MASK))
		TEST_FAIL("[item_path] sets both CLOTHING_BIG_LEGS_MASK and CLOTHING_BIG_LEGS_VARIATION - the variation wins and the mask never applies.")

	if(!wants_variation)
		return

	if(!ispath(item_path, /obj/item/clothing/under))
		TEST_FAIL("[item_path] sets CLOTHING_BIG_LEGS_VARIATION but only uniforms swap to the big-legs sheets - the flag does nothing on this slot.")
		return

	if(!icon_exists(BIG_LEGS_UNIFORM_FILE, icon_state))
		TEST_FAIL("[item_path] sets CLOTHING_BIG_LEGS_VARIATION but \"[icon_state]\" is missing from '[BIG_LEGS_UNIFORM_FILE]'.")
	if(!icon_exists(BIG_LEGS_STANCED_UNIFORM_FILE, icon_state))
		TEST_FAIL("[item_path] sets CLOTHING_BIG_LEGS_VARIATION but \"[icon_state]\" is missing from '[BIG_LEGS_STANCED_UNIFORM_FILE]'.")

/*
 * Snouted
 */
/datum/unit_test/clothing_variation_icons/proc/check_snouted(obj/item/item_path, icon_state)
	var/is_head = ispath(item_path, /obj/item/clothing/head)
	var/is_mask = ispath(item_path, /obj/item/clothing/mask)
	var/is_neck = ispath(item_path, /obj/item/clothing/neck)
	if(!is_head && !is_mask && !is_neck)
		return

	var/flags = initial(item_path.supports_variations_flags)
	var/wants_variation = (flags & CLOTHING_SNOUTED_VARIATION)

	var/has_gags_muzzled = initial(item_path.greyscale_colors) && initial(item_path.greyscale_config_worn_muzzled)
	if(has_gags_muzzled && !wants_variation)
		TEST_FAIL("[item_path] sets greyscale_config_worn_muzzled but not CLOTHING_SNOUTED_VARIATION - the generated muzzled sprite can never be used.")

	// GAGS owns the sprite from here, see check_gags_config().
	if(has_gags_muzzled)
		return

	var/worn_icon_muzzled = initial(item_path.worn_icon_muzzled)
	var/muzzled_file = worn_icon_muzzled || (is_head ? SNOUTED_HEAD_FILE : (is_mask ? SNOUTED_MASK_FILE : null))
	var/muzzled_sprite_exists = icon_exists(muzzled_file, icon_state)

	if(wants_variation && !muzzled_sprite_exists)
		var/file_description = muzzled_file ? "'[muzzled_file]'" : "any file (worn_icon_muzzled is unset and this slot has no fallback file)"
		TEST_FAIL("[item_path] sets CLOTHING_SNOUTED_VARIATION but has no matching snouted sprite - \"[icon_state]\" not found in [file_description]. Either supports_variations_flags is wrong, or the icon_state is missing.")

	var/holds_file_for_subtypes = worn_icon_muzzled && has_snouted_subtype(item_path)
	if(!wants_variation && muzzled_sprite_exists && !holds_file_for_subtypes)
		TEST_FAIL("[item_path] has a \"[icon_state]\" sprite in '[muzzled_file]' but does not set CLOTHING_SNOUTED_VARIATION - the sprite is going unused in-game.")

	if((flags & CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON) && worn_icon_muzzled && !holds_file_for_subtypes)
		report(FALSE, "[item_path] sets CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON but also sets worn_icon_muzzled = '[worn_icon_muzzled]', and no subtype uses it - the file reference does nothing.")

/*
 * Vox, Vox Primalis, Teshari and Monkey all use generate_custom_worn_icon()
 */

/**
 * Everything the species checks need to know about one item, worked out once and passed down.
 *
 * Arguments:
 * * item_path: The item typepath being checked.
 * * icon_state: The icon_state build_worn_icon() draws from, per worn_state_of().
 */
/datum/unit_test/clothing_variation_icons/proc/item_context(obj/item/item_path, icon_state)
	return list(
		"state" = icon_state,
		"swapped" = worn_state_swapped(item_path),
		"adjusted" = worn_state_adjusted(item_path),
		"colors" = initial(item_path.greyscale_colors),
		"base_config" = initial(item_path.greyscale_config_worn),
		"slot" = loadout_slot_of(item_path),
	)

/**
 * The constant half of the species table - one row per BODYSHAPE_CUSTOM species that generate_custom_worn_icon() serves.
 *
 * None of this varies per item, so it is built once. initial() has no by-name form, so the per-item values can't live
 * here: the caller pairs each row with its own spelled-out initial() reads, and the key names the var those reads come from.
 * "suffixes" are the greyscale_config subtype names this repo uses for the species - both spellings are in play, see greyscale_configs.dm.
 * "species" is the prototype whose custom_worn_icons sheet generate_custom_worn_icon() falls back to, or null if it has none.
 */
/datum/unit_test/clothing_variation_icons/proc/species_variants()
	return list(
		"worn_icon_vox" = list(
			"icon_var" = "worn_icon_vox",
			"config_var" = "greyscale_config_worn_vox",
			"suffixes" = list("vox", "oldvox"),
			"species" = /datum/species/vox,
		),
		"worn_icon_better_vox" = list(
			"icon_var" = "worn_icon_better_vox",
			"config_var" = "greyscale_config_worn_better_vox",
			"suffixes" = list("better_vox", "newvox"),
			"species" = /datum/species/vox_primalis,
		),
		"worn_icon_teshari" = list(
			"icon_var" = "worn_icon_teshari",
			"config_var" = "greyscale_config_worn_teshari",
			"suffixes" = list("teshari"),
			"species" = /datum/species/teshari,
		),
		"worn_icon_monkey" = list(
			"icon_var" = "worn_icon_monkey",
			"config_var" = "greyscale_config_worn_monkey",
			"suffixes" = list("monkey"),
			"species" = null, // monkeys read worn_icon_monkey but have no custom_worn_icons sheet to fall back to
		),
	)

/**
 * Arguments:
 * * item_path: The item typepath being checked.
 * * icon_state: The icon_state build_worn_icon() draws from.
 * * variants: species_variants(), built once by Run() since it is the same for every item.
 */
/datum/unit_test/clothing_variation_icons/proc/check_species_files(obj/item/item_path, icon_state, list/variants)
	var/list/context = item_context(item_path, icon_state)

	check_species_variant(item_path, context, variants["worn_icon_vox"], initial(item_path.worn_icon_vox), initial(item_path.greyscale_config_worn_vox))
	check_species_variant(item_path, context, variants["worn_icon_better_vox"], initial(item_path.worn_icon_better_vox), initial(item_path.greyscale_config_worn_better_vox))
	check_species_variant(item_path, context, variants["worn_icon_teshari"], initial(item_path.worn_icon_teshari), initial(item_path.greyscale_config_worn_teshari))
	check_species_variant(item_path, context, variants["worn_icon_monkey"], initial(item_path.worn_icon_monkey), initial(item_path.greyscale_config_worn_monkey))

	// Not species files, but these two die the same way when there's nothing to colour and nobody else checks them.
	check_gags_config(item_path, context, "greyscale_config_worn_digi", initial(item_path.greyscale_config_worn_digi))
	check_gags_config(item_path, context, "greyscale_config_worn_muzzled", initial(item_path.greyscale_config_worn_muzzled))

/**
 * Checks one species' worn icon file and GAGS config on an item.
 *
 * Arguments:
 * * item_path: The item typepath being checked.
 * * context: The item_context() list for this item.
 * * variant: One row out of species_variants().
 * * icon_value: This item's value for the row's icon var.
 * * config_value: This item's value for the row's greyscale config var.
 */
/datum/unit_test/clothing_variation_icons/proc/check_species_variant(obj/item/item_path, list/context, list/variant, icon_value, config_value)
	var/icon_var = variant["icon_var"]
	var/config_var = variant["config_var"]

	var/datum/greyscale_config/live_config = check_gags_config(item_path, context, config_var, config_value)
	var/species_sheet = species_sheet_for(variant["species"], context["slot"])

	if(icon_value)
		if(!live_config)
			check_species_file(item_path, context, icon_var, icon_value)
		// Declaring the sheet the config draws from is the house style - worn_icon sits next to greyscale_config_worn
		// the same way - so only say something when the two actually disagree and update_greyscale() silently wins.
		else if("[icon_value]" != "[live_config.icon_file]")
			report(FALSE, "[item_path] sets [icon_var] = '[icon_value]' but [config_var] generates from '[live_config.icon_file]' - update_greyscale() overwrites [icon_var], so the file named here never renders.")

	check_unwired_template(item_path, context, variant, icon_value, live_config, species_sheet)

/**
 * The item has a GAGS template for this species sitting right next to the one it already uses, but nothing points at it.
 * Reported as a notice rather than a failure: this is a backlog, not a broken item.
 *
 * Arguments:
 * * item_path: The item typepath being checked.
 * * context: The item_context() list for this item.
 * * variant: One row out of species_variants().
 * * icon_value: This item's value for the row's icon var.
 * * live_config: TRUE if the species config on this item actually renders.
 * * species_sheet: The species-wide sheet for this slot, per species_sheet_for().
 */
/datum/unit_test/clothing_variation_icons/proc/check_unwired_template(obj/item/item_path, list/context, list/variant, icon_value, live_config, species_sheet)
	var/base_config = context["base_config"]
	if(live_config || !base_config || !context["colors"])
		return

	var/icon_state = context["state"]
	if(icon_value && icon_exists(icon_value, icon_state))
		return // Already handled by a hand-picked file.
	if(species_sheet && icon_exists(species_sheet, icon_state))
		return // generate_custom_worn_icon() picks the species sheet up on its own, there's nothing to wire.

	var/config_var = variant["config_var"]
	for(var/suffix in variant["suffixes"])
		var/datum/greyscale_config/sibling = SSgreyscale.configurations["[base_config]/[suffix]"]
		if(!sibling || !sibling.icon_states[icon_state])
			continue
		report(FALSE, "[item_path] could set [config_var] = [base_config]/[suffix] - that template covers \"[icon_state]\" but nothing references it, so the species falls back to the human sprite.")
		return

/**
 * A species GAGS config only renders when there are colours to render it with, and it has to hold the states the item draws.
 * Returns the config datum when it is set and actually live, so callers can compare what it generates from.
 *
 * The missing-colours and missing-sprite cases are notices for now because there is a backlog of both - promote them to
 * TEST_FAIL once it is cleared. A config path that does not resolve at all is always a typo, so that one stays a failure.
 *
 * Arguments:
 * * item_path: The item typepath being checked.
 * * context: The item_context() list for this item.
 * * config_var: Name of the var being checked, for the message.
 * * config_value: The config typepath the item has assigned.
 */
/datum/unit_test/clothing_variation_icons/proc/check_gags_config(obj/item/item_path, list/context, config_var, config_value)
	if(!config_value)
		return FALSE

	if(!context["colors"])
		report(FALSE, "[item_path] sets [config_var] = [config_value] but has no greyscale_colors - update_greyscale() returns before the assignment, so the config never renders.")
		return FALSE

	var/datum/greyscale_config/config = SSgreyscale.configurations["[config_value]"]
	if(!config)
		TEST_FAIL("[item_path] sets [config_var] = [config_value], which isn't a registered greyscale config.")
		return FALSE

	var/icon_state = context["state"]
	if(!config.icon_states[icon_state])
		report(FALSE, "[config.DebugName()] is missing a sprite for [config_var] on [item_path]. Expected icon state: \"[icon_state]\"")

	// Only worth raising when the item's own worn config has the state to begin with.
	var/base_config_path = context["base_config"]
	var/datum/greyscale_config/base_config = SSgreyscale.configurations["[base_config_path]"]
	if(!base_config)
		return config

	var/swapped_state = context["swapped"]
	if(swapped_state && base_config.icon_states[swapped_state] && !config.icon_states[swapped_state])
		report(FALSE, "[config.DebugName()] has no opened sprite \"[swapped_state]\" for [config_var] on [item_path] - opening it up renders nothing.")

	var/adjusted_state = context["adjusted"]
	if(adjusted_state && base_config.icon_states[adjusted_state] && !config.icon_states[adjusted_state])
		report(FALSE, "[config.DebugName()] has no rolled-down sprite \"[adjusted_state]\" for [config_var] on [item_path] - adjusting it renders nothing.")

	return config

/**
 * Sanity checks a singular species file.
 *
 * Arguments:
 * * item_path: The item typepath being checked.
 * * context: The item_context() list for this item.
 * * var_name: Name of the var holding the file, for the messages.
 * * icon_value: The file itself.
 */
/datum/unit_test/clothing_variation_icons/proc/check_species_file(obj/item/item_path, list/context, var_name, icon_value)
	var/icon_state = context["state"]
	if(!icon_exists(icon_value, icon_state))
		report(FALSE, "[item_path] sets [var_name] = '[icon_value]' but \"[icon_state]\" does not exist in that file.")

	var/base_file = initial(item_path.worn_icon)

	// generate_custom_worn_icon() and the icon_exists() guard in human_update_icons.dm both test the base state only,
	// so a file that has the base state but not these renders nothing once the item is opened up or rolled down.
	var/swapped_state = context["swapped"]
	if(swapped_state && icon_exists(base_file, swapped_state) && !icon_exists(icon_value, swapped_state))
		report(FALSE, "[item_path] has an opened sprite \"[swapped_state]\" but [var_name] = '[icon_value]' doesn't - opening it up falls back to the human sprite.")

	var/adjusted_state = context["adjusted"]
	if(adjusted_state && icon_exists(base_file, adjusted_state) && !icon_exists(icon_value, adjusted_state))
		report(FALSE, "[item_path] has a rolled-down sprite \"[adjusted_state]\" but [var_name] = '[icon_value]' doesn't - adjusting it falls back to the human sprite.")

/**
 * The species-wide worn sheet generate_custom_worn_icon() falls back to for this slot, or null if there isn't one.
 *
 * Arguments:
 * * species_type: The species prototype to read custom_worn_icons off.
 * * slot: One of LOADOUT_ITEM_HEAD, etc.
 */
/datum/unit_test/clothing_variation_icons/proc/species_sheet_for(species_type, slot)
	if(!species_type || !slot)
		return null

	var/datum/species/prototype = GLOB.species_prototypes[species_type]
	if(!prototype)
		return null
	return prototype.custom_worn_icons[slot]

/**
 * The LOADOUT_ITEM_* key human_update_icons.dm passes to generate_custom_worn_icon() for this item, or null if it has no such slot.
 *
 * Arguments:
 * * item_path: The item typepath being checked.
 */
/datum/unit_test/clothing_variation_icons/proc/loadout_slot_of(obj/item/item_path)
	if(ispath(item_path, /obj/item/clothing/under))
		return LOADOUT_ITEM_UNIFORM
	if(ispath(item_path, /obj/item/clothing/suit))
		return LOADOUT_ITEM_SUIT
	if(ispath(item_path, /obj/item/clothing/head))
		return LOADOUT_ITEM_HEAD
	if(ispath(item_path, /obj/item/clothing/mask))
		return LOADOUT_ITEM_MASK
	if(ispath(item_path, /obj/item/clothing/gloves))
		return LOADOUT_ITEM_GLOVES
	if(ispath(item_path, /obj/item/clothing/shoes))
		return LOADOUT_ITEM_SHOES
	if(ispath(item_path, /obj/item/clothing/glasses))
		return LOADOUT_ITEM_GLASSES
	if(ispath(item_path, /obj/item/clothing/neck))
		return LOADOUT_ITEM_NECK
	if(ispath(item_path, /obj/item/clothing/ears))
		return LOADOUT_ITEM_EARS

	// Belts and backpacks aren't a single subtree, so go by where they're worn.
	var/slot_flags = initial(item_path.slot_flags)
	if(slot_flags & ITEM_SLOT_BELT)
		return LOADOUT_ITEM_BELT
	if(slot_flags & ITEM_SLOT_BACK)
		return LOADOUT_ITEM_MISC

	return null

/*
 * Shared helpers
 */

/// TRUE if any subtype of this has supports_variations_flags set to claim a digi sprite
/datum/unit_test/clothing_variation_icons/proc/has_digi_subtype(obj/item/item_path)
	for(var/obj/item/subtype as anything in subtypesof(item_path))
		if(initial(subtype.supports_variations_flags) & CLOTHING_DIGITIGRADE_VARIATION)
			return TRUE
	return FALSE

/// TRUE if any subtype of this has supports_variations_flags set to claim a snouted sprite
/datum/unit_test/clothing_variation_icons/proc/has_snouted_subtype(obj/item/item_path)
	for(var/obj/item/subtype as anything in subtypesof(item_path))
		if(initial(subtype.supports_variations_flags) & CLOTHING_SNOUTED_VARIATION)
			return TRUE
	return FALSE

/// Fails or sends a notice depending on what the caller passes. A failure is blocking, whereas a notice is not.
/datum/unit_test/clothing_variation_icons/proc/report(hard_fail, message)
	if(hard_fail)
		TEST_FAIL(message)
	else
		TEST_NOTICE(src, message)
