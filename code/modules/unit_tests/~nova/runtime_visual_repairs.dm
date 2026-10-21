#define RUNTIME_VISUAL_HALO 'modular_nova/master_files/icons/mob/sprite_accessory/halo.dmi'
#define RUNTIME_VISUAL_HALO_STATE "m_head_acc_halo_FRONT"

/** Regressions for generated icon publication and immutable character-preview animation recipes. */
/datum/unit_test/runtime_visual_repairs
	abstract_type = /datum/unit_test/runtime_visual_repairs

/// Keeps checking independent ownership invariants after a failed assertion.
/datum/unit_test/runtime_visual_repairs/proc/check(condition, message)
	if(!condition)
		Fail(message, __FILE__, __LINE__)

/// Reads the real animated halo before testing patch recipes, independent of subsystem scheduling.
/datum/unit_test/runtime_visual_repairs/proc/read_halo()
	var/datum/preview_animation_reading/reading = preview_animation_reading(RUNTIME_VISUAL_HALO, RUNTIME_VISUAL_HALO_STATE)
	if(!reading)
		Fail("The animated halo fixture must have readable animation metadata.", __FILE__, __LINE__)
		return FALSE
	while(!reading.read_next())
		continue
	GLOB.character_preview_animations["[RUNTIME_VISUAL_HALO]|[RUNTIME_VISUAL_HALO_STATE]"] = reading.result()
	return TRUE

/** Different generated resources must publish different valid, content-addressed DMI files. */
/datum/unit_test/runtime_visual_repairs/generated_content/Run()
	var/icon/red = icon('icons/blanks/32x32.dmi', "nothing")
	red.DrawBox("#ff0000", 1, 1, 32, 32)
	var/icon/green = icon('icons/blanks/32x32.dmi', "nothing")
	green.DrawBox("#00ff00", 1, 1, 32, 32)
	var/image/red_appearance = image(red)
	var/image/green_appearance = image(green)
	var/datum/universal_icon/red_flat = get_flat_uni_icon(red_appearance, SOUTH)
	var/datum/universal_icon/green_flat = get_flat_uni_icon(green_appearance, SOUTH)
	check("[red_flat.icon_file]" != "[green_flat.icon_file]", "Different generated icons shared a cache file.")
	check(length("[red_flat.icon_file]") == length("tmp/uni_icon-.dmi") + 32, "A generated icon was published without a complete content hash.")
	var/icon/green_drawn = green_flat.to_icon()
	check(green_drawn.GetPixel(1, 1) == "#00ff00", "A generated icon reused another icon's pixels.")
	var/list/metadata = icon_metadata(green_flat.icon_file)
	check(metadata["width"] == 32 && metadata["height"] == 32, "A generated icon lost its valid DMI dimensions.")
	var/datum/universal_icon/red_again = get_flat_uni_icon(red_appearance, SOUTH)
	check("[red_again.icon_file]" == "[red_flat.icon_file]", "An immutable resource did not reuse its published file.")

	// /icon datums can mutate, unlike the resource snapshots kept by appearances.
	var/datum/universal_icon/datum_before = get_flat_uni_icon(image(red), SOUTH)
	red.DrawBox("#0000ff", 1, 1, 32, 32)
	var/datum/universal_icon/datum_after = get_flat_uni_icon(image(red), SOUTH)
	check("[datum_before.icon_file]" != "[datum_after.icon_file]", "A changed /icon retained the old content file.")
	var/icon/blue_drawn = datum_after.to_icon()
	check(blue_drawn.GetPixel(1, 1) == "#0000ff", "A changed /icon retained the old pixels.")

/** Shared transformers and nested leaves retain their identity and gain no duplicate crops or frame markers. */
/datum/unit_test/runtime_visual_repairs/shared_animation/Run()
	if(!read_halo())
		return
	var/datum/universal_icon/leaf = uni_icon(RUNTIME_VISUAL_HALO, RUNTIME_VISUAL_HALO_STATE, UP)
	var/datum/universal_icon/root = uni_icon('icons/blanks/32x32.dmi', "nothing", UP)
	root.blend_icon(leaf, ICON_OVERLAY)
	var/datum/universal_icon/other = uni_icon('icons/blanks/32x32.dmi', "nothing", UP)
	other.transform = root.transform
	var/before = root.to_json()
	var/list/transforms = root.transform.transforms
	var/list/animation = character_preview_animation(list("south" = root, "north" = other), FALSE, 32, 48)
	check(before == root.to_json() && before == other.to_json(), "Animating shared recipes changed their transforms.")
	check(root.transform == other.transform && root.transform.transforms == transforms, "Animating a recipe changed caller-owned list identity.")
	check(isnull(leaf.frame), "Animating a shared leaf left a frame marker on the source.")
	var/list/patches = json_decode("{[jointext(animation["json"], "")]}")["moving"]["transform"]
	check(length(patches[2]["icon"]["transform"]) == 2 && length(patches[3]["icon"]["transform"]) == 2, "Shared transformers received more than one crop per detached recipe.")
	check(patches[2]["icon"]["transform"][1]["icon"]["frame"] == 2, "A nested animated leaf did not use the second frame.")

/** A serialization failure must propagate without leaving temporary mutations in shared recipes. */
/datum/unit_test/runtime_visual_repairs/failed_animation/Run()
	if(!read_halo())
		return
	var/datum/universal_icon/leaf = uni_icon(RUNTIME_VISUAL_HALO, RUNTIME_VISUAL_HALO_STATE, UP)
	var/datum/universal_icon/runtime_visual_failure/root = new('icons/blanks/32x32.dmi', "nothing", UP)
	root.blend_icon(leaf, ICON_OVERLAY)
	var/before = root.to_json()
	var/exception/expected_error = new("Runtime visual test serialization failure")
	root.serialization_error = expected_error
	var/exception/caught
	try
		character_preview_animation(list("south" = root), TRUE, 32, 48)
	catch(var/exception/error)
		caught = error
	root.serialization_error = null
	check(caught == expected_error, "A serialization failure did not propagate its original exception.")
	check(before == root.to_json(), "Failed serialization left changes in the caller's recipe.")
	check(isnull(leaf.frame), "Failed serialization left a frame marker on a shared leaf.")
	var/list/retried = character_preview_animation(list("south" = root), TRUE, 32, 48)
	check(length(retried?["json"]), "An unchanged recipe could not be retried after serialization failed.")

/** An explicit serializer failure for testing caller ownership; never instantiated by production code. */
/datum/universal_icon/runtime_visual_failure
	/// Exception to raise from serialization, or null for normal serialization.
	var/exception/serialization_error

/datum/universal_icon/runtime_visual_failure/to_list()
	if(serialization_error)
		throw serialization_error
	return ..()

/** Missing-limb previews replace the concrete subtype in both directions for organic and synthetic bodies. */
/datum/unit_test/runtime_visual_repairs/stump_preview/Run()
	var/list/stump_augments = list(
		/datum/augment_item/limb/l_arm/stump,
		/datum/augment_item/limb/r_arm/stump,
		/datum/augment_item/limb/l_leg/stump,
		/datum/augment_item/limb/r_leg/stump,
	)
	for(var/species_type in list(/datum/species/human, /datum/species/synthetic))
		var/mob/living/carbon/human/dummy/consistent/body = allocate(/mob/living/carbon/human/dummy/consistent)
		body.set_species(species_type)
		for(var/augment_type in stump_augments)
			var/datum/augment_item/limb/stump_augment = GLOB.augment_items[augment_type]
			var/zone = stump_augment.body_zone
			var/obj/item/bodypart/original = body.get_bodypart(zone)
			var/original_type = original.type
			var/datum/augment_item/limb/restore = new
			restore.path = original_type
			restore.uses_greyscale = original.should_draw_greyscale
			check(stump_augment.apply(body, character_setup = TRUE) == zone, "Missing [zone] did not report the changed preview zone for [species_type].")
			var/obj/item/bodypart/stump = body.get_bodypart(zone, include_stumps = TRUE)
			check(stump.type == stump_augment.path, "Missing [zone] retained a real-limb subtype on [species_type].")
			check(QDELETED(original), "Replacing [zone] with a stump did not release the old bodypart on [species_type].")
			check(isnull(body.get_bodypart(zone)), "Missing [zone] remained an available bodypart on [species_type].")
			check(!length(stump.get_limb_icon()), "Missing [zone] still drew a bodypart on [species_type].")
			stump_augment.apply(body, character_setup = TRUE)
			check(body.get_bodypart(zone, include_stumps = TRUE) == stump, "Reapplying the same missing [zone] needlessly replaced its stump.")

			restore.apply(body, character_setup = TRUE)
			var/obj/item/bodypart/restored = body.get_bodypart(zone)
			check(restored && restored.type == original_type, "Restoring [zone] left the wrong concrete bodypart on [species_type].")
			check(QDELETED(stump), "Restoring [zone] did not release the stump on [species_type].")
			if(restored)
				check(length(restored.get_limb_icon()), "Restoring [zone] did not restore its visible bodypart on [species_type].")
				restore.apply(body, character_setup = TRUE)
				check(body.get_bodypart(zone) == restored, "An ordinary [zone] preview no longer used the existing limb.")
			qdel(restore)

#undef RUNTIME_VISUAL_HALO
#undef RUNTIME_VISUAL_HALO_STATE
