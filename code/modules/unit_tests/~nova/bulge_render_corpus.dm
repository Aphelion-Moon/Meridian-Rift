/**
 * The bulge renderer's pixel corpus. Every case of a manifest is dressed on a wearer and drawn by the game, soft and
 * then aroused; per direction the cover and what the bulge look draws are flattened with getFlatIcon() onto the 32x32
 * tile, for a comparator outside the game that builds each expected image from the frozen reference and the approved
 * rules:
 * - c0: the cover's slot drawn soft, the garment as the game draws it.
 * - leaf, kids: the cover's drawn sprite alone (its leaf without children), and the rest of its appearance (the leaf's
 *   children and the root's other overlays), drawn soft: a print reads the one, a cut leaves the other.
 * - sib: the root's other overlays alone (what the cover draws over its sprite: blood, dirt), drawn soft, when any.
 * - e1: the cover's slot drawn aroused (cut, for a cut look) with the look's cloth over it (and the cover's blood over
 *   the cloth, for a bloody cover).
 * - e2: the anatomy the look draws over its cloth (exposed, or inside a skirt's clearance).
 * - e3: the anatomy the look draws behind its cover.
 * - nat: the penis's own front images drawn in the open (Custom visibility, above all clothing), the anatomy's source.
 * - cst: for a penis set to Custom below or above the underwear that draws no look (nothing in front of it covers it),
 *   the penis as Nova draws it at that layer.
 * Each case's facts (the look, the drawn sprite, the colour's sample source) go into a JSON file per batch.
 *
 * The full corpus and its comparator live outside the repository (the module readme says where, and how to run them);
 * bulge_render_corpus/pixels, below, checks 29 of its cases in every run of the suite.
 *
 * Runs only with world.params["bulge_render_corpus"]: "full", or "subset" with bulge_render_corpus_start and
 * bulge_render_corpus_count. Input: data/bulge_render_corpus/manifest.json, cases as lists of id, garment typepath,
 * suit typepath, suit worn state, body, penis shape typepath, skin tones (0 or 1), length in inches, hard (0 or 1),
 * underclothes colour and the cover's slot ("u" uniform, "b" underclothes, "s" suit). Bodies: plain, digi, vox_*,
 * custom_offset_* (tall), custom_layer_below / custom_layer_above (plain, with the penis set to Custom visibility
 * below or above the underwear), and plain_bloody (plain, its cover bloody). Output in its out/ folder.
 */
#define RENDER_CORPUS_DIR "data/bulge_render_corpus/"
#define RENDER_CORPUS_OUT "data/bulge_render_corpus/out/"
#define RENDER_CORPUS_CLOCK "bulge_render_corpus"
/// Cases per facts file.
#define RENDER_CORPUS_BATCH 250

/datum/unit_test/portal_test/bulge_render_corpus
	priority = TEST_LONGER
	/// Body name -> the wearer drawn for it, built on first use.
	var/list/wearers
	/// The current batch's case facts, in manifest order.
	var/list/batch_facts
	/// Export name -> the current case's image for it, one state facing four ways.
	var/list/case_icons
	/// Cases drawn.
	var/drawn = 0
	/// Cases that could not be drawn, each with its reason in its facts.
	var/failed = 0
	/// The directions every image is drawn facing, in a DMI's order.
	var/list/directions = list(SOUTH, NORTH, EAST, WEST)

/datum/unit_test/portal_test/bulge_render_corpus/Destroy()
	wearers = null
	batch_facts = null
	case_icons = null
	return ..()

/datum/unit_test/portal_test/bulge_render_corpus/Run()
	var/mode = world.params["bulge_render_corpus"]
	if(mode != "full" && mode != "subset")
		return
	TEST_ASSERT(fexists("[RENDER_CORPUS_DIR]manifest.json"), "The runner copies the corpus manifest")
	TEST_ASSERT(!fexists("[RENDER_CORPUS_OUT]summary.json"), "Corpus output must be fresh")
	var/list/manifest = json_decode(file2text("[RENDER_CORPUS_DIR]manifest.json"))
	var/list/rows = manifest["cases"]
	var/first = 1
	var/last = length(rows)
	if(mode == "subset")
		first = clamp(text2num(world.params["bulge_render_corpus_start"]) || 1, 1, last)
		last = clamp(first + (text2num(world.params["bulge_render_corpus_count"]) || 1) - 1, first, last)
	rustg_time_reset(RENDER_CORPUS_CLOCK)
	var/batch_first = first
	for(var/index in first to last)
		draw_case(rows[index], index)
		finish_case(index)
		if(index == last || index - batch_first + 1 == RENDER_CORPUS_BATCH)
			export_batch(batch_first)
			batch_first = index + 1
		CHECK_TICK
	rustg_file_write(json_encode(list(
		"first" = first,
		"last" = last,
		"drawn" = drawn,
		"failed" = failed,
		"elapsed_us" = rustg_time_microseconds(RENDER_CORPUS_CLOCK),
		"caches" = list(
			"print_patches" = length(GLOB.bulge_print_patches),
			"cut_covers" = length(GLOB.bulge_cut_covers),
			"flap_keeps" = length(GLOB.bulge_flap_keeps),
			"patch_keeps" = length(GLOB.bulge_patch_keeps),
			"masked_icons" = length(GLOB.bulge_masked_icons),
			"mask_tiles" = length(GLOB.bulge_mask_tiles),
			"print_templates" = length(GLOB.bulge_print_templates),
			"sheet_states" = length(GLOB.bulge_sheet_states),
			"samples" = LAZYLEN(GLOB.bulge_sample_cache.entries),
			"palettes" = LAZYLEN(GLOB.bulge_palette_cache.entries),
		),
	)), "[RENDER_CORPUS_OUT]summary.json")
	TEST_ASSERT_EQUAL(drawn + failed, last - first + 1, "Every requested case is drawn or recorded as failed")

/// Dresses one case's wearer, draws it soft and aroused, and adds its images and facts to the batch.
/datum/unit_test/portal_test/bulge_render_corpus/proc/draw_case(list/row, index)
	var/list/data = list("id" = row[1], "index" = index)
	LAZYADD(batch_facts, list(data))
	var/mob/living/carbon/human/owner = wearer(row[5])
	var/obj/item/organ/genital/penis/penis = owner?.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis?.bodypart_overlay
	if(!istype(overlay))
		return fail(data, "no wearer with a penis for [row[5]]")
	var/datum/sprite_accessory/genital/penis/shape_type = text2path(row[6])
	var/datum/sprite_accessory/genital/accessory = ispath(shape_type) ? SSaccessories.sprite_accessories[ORGAN_SLOT_PENIS][initial(shape_type.name)] : null
	if(!istype(accessory, shape_type))
		return fail(data, "no penis shape [row[6]]")
	// The penis, soft, built from the row's shape, skin tones and length.
	owner.dna.features["penis_uses_skintones"] = !!row[7]
	owner.dna.features["penis_size"] = row[8]
	owner.dna.mutant_bodyparts[ORGAN_SLOT_PENIS] = build_mutant_part(accessory.name, list("#FCCCB3"))
	penis.build_from_dna(owner.dna, ORGAN_SLOT_PENIS)
	if(!overlay.set_appearance_from_dna(owner.dna))
		return fail(data, "the penis takes no shape")
	penis.aroused = AROUSAL_NONE
	penis.set_size(row[8])
	penis.update_sprite_suffix()
	// The cover.
	var/obj/item/clothing/under/uniform
	var/obj/item/clothing/suit
	var/typepath = text2path(row[2])
	if(ispath(typepath, /datum/sprite_accessory/clothing/undershirt))
		var/datum/sprite_accessory/clothing/undershirt/shirt_type = typepath
		var/datum/sprite_accessory/clothing/undershirt/shirt = SSaccessories.undershirt_list[initial(shirt_type.name)]
		if(!istype(shirt, typepath))
			return fail(data, "no undershirt [row[2]]")
		owner.undershirt = shirt.name
		owner.undershirt_color = row[10] || COLOR_WHITE
	else if(ispath(typepath, /datum/sprite_accessory/clothing/underwear))
		var/datum/sprite_accessory/clothing/underwear/bottom_type = typepath
		var/datum/sprite_accessory/clothing/underwear/bottom = SSaccessories.underwear_list[initial(bottom_type.name)]
		if(!istype(bottom, typepath))
			return fail(data, "no underwear [row[2]]")
		owner.underwear = bottom.name
		owner.underwear_color = row[10] || COLOR_WHITE
	else if(ispath(typepath, /obj/item/clothing/under))
		uniform = new typepath(owner.loc)
		if(!QDELETED(uniform) && row[11] == "u" && findtext(row[5], "_bloody"))
			uniform.add_blood_DNA(list("Corpus DNA" = get_blood_type(/datum/blood_type/human/o_minus)))
		if(QDELETED(uniform) || !owner.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING))
			undress(owner, uniform, null)
			return fail(data, "cannot wear [row[2]]")
	else
		return fail(data, "no garment [row[2]]")
	if(row[3])
		var/suit_type = text2path(row[3])
		suit = ispath(suit_type, /obj/item/clothing/suit) ? new suit_type(owner.loc) : null
		if(suit && row[4])
			suit.worn_icon_state = row[4] // The suit's reviewed worn state the row names (its default or toggled one).
		if(suit && row[11] == "s" && findtext(row[5], "_bloody"))
			suit.add_blood_DNA(list("Corpus DNA" = get_blood_type(/datum/blood_type/human/o_minus)))
		if(!suit || QDELETED(suit) || !owner.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING))
			undress(owner, uniform, suit)
			return fail(data, "cannot wear suit [row[3]]")
	owner.update_body()
	var/slot = row[11] == "s" ? SUIT_LAYER : (row[11] == "u" ? UNIFORM_LAYER : BODY_LAYER)
	for(var/direction in directions)
		owner.setDir(direction)
		add_frame("c0", direction, flatten(slot_parts(owner, slot), direction))
		var/list/split = split_cover(owner.overlays_standing[slot])
		if(split)
			add_frame("leaf", direction, flatten(split[1], direction))
			add_frame("kids", direction, flatten(split[2], direction))
			if(length(split) > 2)
				add_frame("sib", direction, flatten(split[3], direction))
		if(direction == SOUTH)
			data["soft_leaf"] = describe_leaf(owner.overlays_standing[slot])
			data["over"] = describe_over(owner.overlays_standing[slot])
	data["soft_key"] = overlay.bulge_key

	// Aroused, as every arousal path does it: the suffix, then the body.
	penis.aroused = row[9] ? AROUSAL_FULL : AROUSAL_PARTIAL
	penis.update_sprite_suffix()
	owner.update_body()
	// Where the player layered the penis (Custom below or above the underwear), or null; with no look it is drawn there.
	var/custom_layer = overlay.bulge_custom_layer(overlay.bulge_layering(owner, penis))
	var/datum/cover = owner.bulge_cover(custom_layer)
	data["cover"] = cover ? "[cover.type]" : null
	data["cover_slot"] = bulge_cover_slot(cover)
	data["family"] = "[bulge_cover_family(cover)]"
	data["suffix"] = penis.sprite_suffix
	data["bodyshape"] = owner.bodyshape
	data["species"] = "[owner.dna.species.type]"
	data["height"] = owner.mob_height
	data["physique"] = owner.physique
	var/list/offsets = list()
	var/list/counts = list()
	var/anatomy = FALSE
	for(var/direction in directions)
		owner.setDir(direction)
		var/list/images = look_images(owner, overlay)
		add_frame("e1", direction, flatten(slot_parts(owner, slot) + images["cloth"], direction))
		if(length(images["over"]) || length(images["behind"]) || overlay.bulge_anatomy_mask || overlay.bulge_anatomy_behind)
			anatomy = TRUE
			add_frame("e2", direction, flatten(images["over"], direction))
			add_frame("e3", direction, flatten(images["behind"], direction))
		offsets["[direction]"] = list(overlay.bulge_cover_x, overlay.bulge_cover_y)
		counts["[direction]"] = list(length(images["cloth"]), length(images["over"]), length(images["behind"]))
		if(direction == SOUTH)
			data["leaf"] = describe_leaf(owner.overlays_standing[slot])
			data["look"] = describe_look(overlay)
		if(custom_layer && !overlay.bulge_key)
			// No look: the penis is drawn where the player layered it, as Nova draws it.
			add_frame("cst", direction, flatten(layer_images(owner, -custom_layer), direction))
	data["offsets"] = offsets
	data["image_counts"] = counts
	data["custom_layer"] = custom_layer
	if(cover)
		data["colour"] = owner.bulge_cover_colour(cover)
		data["sample"] = sample_source(owner, cover)
	// The anatomy's source: the penis's own front images, drawn in the open over everything.
	if(anatomy || (custom_layer && !overlay.bulge_key))
		data["native_layers"] = draw_native(owner, penis, overlay, index)
	undress(owner, uniform, suit)
	penis.aroused = AROUSAL_NONE
	penis.update_sprite_suffix()
	owner.setDir(SOUTH)
	owner.update_body()
	if(overlay.bulge_key || overlay.bulge_uniform_cut || overlay.bulge_body_cut)
		return fail(data, "the look outlived its cover")
	drawn++

/// Records a case that could not be drawn.
/datum/unit_test/portal_test/bulge_render_corpus/proc/fail(list/data, reason)
	data["error"] = reason
	failed++

/// Takes the case's garments off again.
/datum/unit_test/portal_test/bulge_render_corpus/proc/undress(mob/living/carbon/human/owner, obj/item/clothing/under/uniform, obj/item/clothing/suit)
	if(suit)
		owner.dropItemToGround(suit, force = TRUE)
		qdel(suit)
	if(uniform)
		owner.dropItemToGround(uniform, force = TRUE)
		qdel(uniform)
	owner.underwear = "Nude"
	owner.undershirt = "Nude"

/// The penis's front images drawn in the open, per direction, for the nat export; returns the layers they drew at.
/datum/unit_test/portal_test/bulge_render_corpus/proc/draw_native(mob/living/carbon/human/owner, obj/item/organ/genital/penis/penis, datum/bodypart_overlay/mutant/genital/penis/overlay, index)
	var/visibility = penis.visibility_preference
	var/layer_mode = overlay.layer_mode
	penis.visibility_preference = GENITAL_CUSTOM
	overlay.layer_mode = GENITAL_LAYER_ABOVE_ALL
	owner.update_body_parts()
	var/list/native
	var/list/layers
	for(var/image/part as anything in owner.limb_icon_cache[owner.icon_render_keys[BODY_ZONE_CHEST]])
		if(part.plane != FLOAT_PLANE || part.layer <= -3 || part.layer >= -2)
			continue
		LAZYADD(native, part)
		LAZYOR(layers, part.layer)
	for(var/direction in directions)
		add_frame("nat", direction, flatten(native, direction))
	penis.visibility_preference = visibility
	overlay.layer_mode = layer_mode
	owner.update_body_parts()
	return layers

/**
 * A slot's cover appearance split in two, as lists of appearances to flatten: its drawn sprite alone (the leaf without
 * its children), and everything else the appearance draws (the leaf's children and the root's other overlays); and for
 * a nested root, a third: the root's other overlays alone. Null when it draws no sprite.
 */
/datum/unit_test/portal_test/bulge_render_corpus/proc/split_cover(standing)
	var/image/root = bulge_drawn_root(standing)
	var/image/leaf = bulge_drawn_leaf(root)
	if(!leaf)
		return null
	var/mutable_appearance/alone = new(leaf)
	alone.overlays.Cut()
	alone.underlays.Cut()
	var/mutable_appearance/others = new(root)
	if(root == leaf)
		others.icon = null
		return list(list(alone), list(others))
	var/mutable_appearance/holder = new(root)
	holder.overlays = list(alone)
	holder.underlays.Cut()
	var/mutable_appearance/hollow = new(leaf)
	hollow.icon = null
	var/list/siblings = others.overlays.Copy()
	siblings[1] = hollow
	others.overlays = siblings
	var/mutable_appearance/case_icon = new(root)
	siblings = root.overlays.Copy()
	siblings.Cut(1, 2)
	case_icon.overlays = siblings
	case_icon.underlays.Cut()
	return list(list(holder), list(others), list(case_icon))

/// The appearances drawn in one of the wearer's slots, as a new list.
/datum/unit_test/portal_test/bulge_render_corpus/proc/slot_parts(mob/living/carbon/human/owner, slot)
	var/standing = owner.overlays_standing[slot]
	if(!standing)
		return list()
	if(islist(standing))
		var/list/standing_list = standing
		return standing_list.Copy()
	return list(standing)

/**
 * The images the wearer's chest draws for the look, from the chest's cached limb images: its cloth (with the cover's
 * blood over it: what carries the cloth's name), the anatomy it draws over the cloth (both at the layer just above the
 * cover), and the anatomy it draws behind the cover.
 */
/datum/unit_test/portal_test/bulge_render_corpus/proc/look_images(mob/living/carbon/human/owner, datum/bodypart_overlay/mutant/genital/penis/overlay)
	var/list/cloth = list()
	var/list/over = list()
	var/list/behind = list()
	if(overlay.bulge_key)
		var/front_layer = -(overlay.bulge_layer - BULGE_ABOVE_COVER)
		var/behind_layer = -(overlay.bulge_layer + BULGE_BEHIND_COVER)
		for(var/image/part as anything in owner.limb_icon_cache[owner.icon_render_keys[BODY_ZONE_CHEST]])
			if(part.plane != FLOAT_PLANE)
				continue
			if(part.layer == front_layer)
				if(part.name == BULGE_CLOTH_NAME)
					cloth += part
				else
					over += part
			else if(part.layer == behind_layer)
				behind += part
	return list("cloth" = cloth, "over" = over, "behind" = behind)

/// The chest's cached images on the float plane at `layer`, as a new list.
/datum/unit_test/portal_test/bulge_render_corpus/proc/layer_images(mob/living/carbon/human/owner, layer)
	. = list()
	for(var/image/part as anything in owner.limb_icon_cache[owner.icon_render_keys[BODY_ZONE_CHEST]])
		if(part.plane == FLOAT_PLANE && part.layer == layer)
			. += part

/// Flattens appearances onto the 32x32 tile facing `direction`; a blank tile for none.
/datum/unit_test/portal_test/bulge_render_corpus/proc/flatten(list/parts, direction)
	if(!length(parts))
		return icon('icons/blanks/32x32.dmi', "nothing")
	var/mutable_appearance/holder = mutable_appearance()
	holder.overlays = parts
	return getFlatIcon(holder, direction, no_anim = TRUE, clip_bounds = list(1, 1, 32, 32))

/// Adds one direction of the current case's image for an export.
/datum/unit_test/portal_test/bulge_render_corpus/proc/add_frame(export, direction, icon/frame)
	var/icon/case_icon = case_icons?[export]
	if(!case_icon)
		case_icon = icon()
		LAZYSET(case_icons, export, case_icon)
	case_icon.Insert(frame, "", direction)

/// Writes the case's images out, one DMI per export named by the case's manifest position, each one state facing
/// four ways. (Sheets of many such states failed to take a second state in this test's runs: "bad icon operation".)
/datum/unit_test/portal_test/bulge_render_corpus/proc/finish_case(index)
	for(var/export, case_icon in case_icons)
		if(!fcopy(case_icon, "[RENDER_CORPUS_OUT][export]_[index].dmi"))
			TEST_FAIL("Case [index] could not be exported to [export]")
	case_icons = null

/// Writes the batch's facts and starts the next batch.
/datum/unit_test/portal_test/bulge_render_corpus/proc/export_batch(batch_first)
	rustg_file_write(json_encode(batch_facts), "[RENDER_CORPUS_OUT]facts_[batch_first].json")
	batch_facts = null

/// The drawn sprite of a slot's appearance, as the look reads it.
/datum/unit_test/portal_test/bulge_render_corpus/proc/describe_leaf(standing)
	var/image/root = bulge_drawn_root(standing)
	var/image/leaf = bulge_drawn_leaf(root)
	if(!leaf)
		return null
	var/children = 0
	for(var/image/child as anything in leaf.overlays + leaf.underlays)
		if(child.plane == FLOAT_PLANE)
			children++
	return list(
		"icon" = "[leaf.icon]",
		"icon_ref" = ref(leaf.icon),
		"state" = leaf.icon_state,
		"color" = islist(leaf.color) ? "matrix" : leaf.color,
		"alpha" = leaf.alpha,
		"root_alpha" = root.alpha,
		"nested" = root != leaf,
		"children" = children,
		"root_children" = root == leaf ? 0 : length(root.overlays) - 1,
		"pixel" = list(root.pixel_x + root.pixel_w, root.pixel_y + root.pixel_z),
	)

/// What a slot's cover draws over its sprite (its root's other overlays on the float plane: blood, dirt), each as its
/// icon, state, colour and alpha; null for none.
/datum/unit_test/portal_test/bulge_render_corpus/proc/describe_over(standing)
	var/image/root = bulge_drawn_root(standing)
	var/image/leaf = bulge_drawn_leaf(root)
	if(!root || root == leaf)
		return null
	var/list/siblings = root.overlays
	for(var/index in 2 to length(siblings))
		var/image/part = siblings[index]
		if(part.plane == FLOAT_PLANE)
			LAZYADD(., list(list("[part.icon]", part.icon_state, part.color, part.alpha)))

/// What the look is: the pieces it draws and how.
/datum/unit_test/portal_test/bulge_render_corpus/proc/describe_look(datum/bodypart_overlay/mutant/genital/penis/overlay)
	if(!overlay.bulge_key)
		return null
	var/datum/bulge_print_template/template = overlay.bulge_template
	var/datum/bulge_sheet_state/patch = overlay.bulge_sheet_patch
	var/datum/bulge_sheet_state/mask = overlay.bulge_anatomy_mask
	return list(
		"layer" = overlay.bulge_layer,
		"template" = template ? "[template.icon]|[template.icon_state]" : null,
		"patch" = !!overlay.bulge_patch,
		"sheet_patch" = patch ? "[patch.icon]|[patch.icon_state]" : null,
		"palette" = overlay.bulge_cloth ? list(overlay.bulge_cloth, overlay.bulge_light, overlay.bulge_highlight, overlay.bulge_shade, overlay.bulge_deep_shade) : null,
		"mask" = mask ? "[mask.icon]|[mask.icon_state]" : null,
		"behind" = overlay.bulge_anatomy_behind,
		"alpha" = overlay.bulge_alpha,
		"uniform_cut" = describe_cut(overlay.bulge_uniform_cut),
		"body_cut" = describe_cut(overlay.bulge_body_cut),
	)

/// A cut by name: a flap template's sheet and state, or a loincloth cut's.
/datum/unit_test/portal_test/bulge_render_corpus/proc/describe_cut(datum/cut)
	if(istype(cut, /datum/bulge_print_template))
		var/datum/bulge_print_template/flap = cut
		return "flap:[flap.icon]|[flap.icon_state]"
	if(istype(cut, /datum/bulge_sheet_state))
		var/datum/bulge_sheet_state/patch = cut
		return "patch:[patch.icon]|[patch.icon_state]"
	return null

/**
 * The sprite an adaptive look's colour is sampled from, and the tints applied, so the comparator can sample it again:
 * the branches of bulge_cover_colour(), recording instead of sampling.
 */
/datum/unit_test/portal_test/bulge_render_corpus/proc/sample_source(mob/living/carbon/human/owner, datum/cover)
	if(istype(cover, /obj/item/clothing/under))
		var/obj/item/clothing/under/uniform = cover
		var/state = uniform.adjusted == ALT_STYLE ? "[uniform.icon_state]_d" : uniform.icon_state
		var/file = owner.bulge_uniform_file(uniform)
		var/config = file == uniform.worn_icon_digi ? uniform.greyscale_config_worn_digi : uniform.greyscale_config_worn
		var/tint = istext(uniform.color) ? uniform.color : null
		if(config)
			return gags_source(config, bulge_palette_text(uniform.greyscale_colors), state, uniform.bulge_cloth_layer, tint)
		return list("file" = "[file]", "state" = state, "tint" = tint)
	if(istype(cover, /obj/item/clothing))
		var/obj/item/clothing/suit = cover
		var/file = (owner.bodyshape & BODYSHAPE_DIGITIGRADE) && (suit.supports_variations_flags & CLOTHING_DIGITIGRADE_VARIATION) ? (suit.worn_icon_digi || DIGITIGRADE_SUIT_FILE) : (suit.worn_icon || DEFAULT_SUIT_FILE)
		var/config = file == suit.worn_icon_digi ? suit.greyscale_config_worn_digi : suit.greyscale_config_worn
		var/state = suit.worn_icon_state || suit.icon_state
		var/tint = istext(suit.color) ? suit.color : null
		if(config)
			return gags_source(config, bulge_palette_text(suit.greyscale_colors), state, 1, tint)
		return list("file" = "[file]", "state" = state, "tint" = tint)
	if(istype(cover, /datum/sprite_accessory/clothing))
		var/datum/sprite_accessory/clothing/accessory = cover
		var/shape = owner.bodyshape
		var/tint = owner.underwear_color
		if(istype(accessory, /datum/sprite_accessory/clothing/undershirt))
			tint = owner.undershirt_color
		else if(isvoxprimalis(owner))
			shape |= BODYSHAPE_DIGITIGRADE
		if(accessory.use_static)
			tint = null
		var/state = accessory.get_icon_state(owner.physique, shape)
		if(accessory.greyscale_config)
			return gags_source(accessory.greyscale_config, bulge_palette_text(accessory.greyscale_colors), state, 1, tint)
		return list("file" = "[accessory.icon]", "state" = state, "tint" = tint)
	return null

/// A GAGS garment's cloth layer: its greyscale sprite and the palette colour it is drawn in.
/datum/unit_test/portal_test/bulge_render_corpus/proc/gags_source(config_type, palette, state, layer, tint)
	var/datum/greyscale_config/config = SSgreyscale.configurations["[config_type]"]
	var/list/layers = config?.icon_states[state]
	if(layer < 1 || layer > length(layers))
		return list("gags" = "[config_type]", "error" = "no layer [layer] for [state]")
	var/datum/greyscale_layer/icon_state/cloth = layers[layer]
	if(!istype(cloth))
		return list("gags" = "[config_type]", "error" = "layer [layer] is no icon state")
	var/cloth_tint
	if(length(cloth.color_ids))
		var/colour_id = cloth.color_ids[1]
		cloth_tint = isnum(colour_id) ? copytext(palette, (colour_id - 1) * 7 + 1, colour_id * 7 + 1) : colour_id
	return list("gags" = "[config_type]", "file" = "[cloth.icon_file]", "state" = cloth.icon_state, "tint" = cloth_tint, "outer" = tint,
		"colour_ids" = length(cloth.color_ids))

/**
 * The wearer for a body, built the first time: a consistent human on plain or digitigrade legs (the legs
 * preference's), a Vox, a custom chest offset and tall height for the fit bodies, with the test penis; for the
 * custom_layer bodies, plain and of medium height, the penis set to Custom visibility below or above the underwear.
 */
/datum/unit_test/portal_test/bulge_render_corpus/proc/wearer(body)
	var/mob/living/carbon/human/owner = wearers?[body]
	if(owner)
		return owner
	var/mob/living/carbon/human/consistent/built = allocate(/mob/living/carbon/human/consistent)
	if(findtext(body, "digi"))
		var/datum/client_interface/mock_client = allocate(/datum/client_interface)
		var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
		var/datum/preference/choiced/digitigrade_legs/preference = GLOB.preference_entries[/datum/preference/choiced/digitigrade_legs]
		if(!preference.apply_to_human(built, DIGITIGRADE_LEGS, preferences))
			return null
	if(findtext(body, "vox_") == 1)
		built.set_species(/datum/species/vox)
	if(findtext(body, "custom_offset_") == 1)
		var/obj/item/bodypart/chest/chest = built.get_bodypart(BODY_ZONE_CHEST)
		if(chest.worn_uniform_offset)
			return null
		chest.worn_uniform_offset = new(chest, OFFSET_UNIFORM, list("south" = 2, "north" = -1, "east" = 3, "west" = -3), list("south" = 1, "north" = 0, "east" = 2, "west" = 2))
	var/custom_layer = findtext(body, "custom_layer_") == 1
	if(body != "plain" && body != "digi" && body != "plain_bloody" && !custom_layer)
		built.set_mob_height(HUMAN_HEIGHT_TALL)
	built.socks = "Nude"
	var/obj/item/organ/genital/penis/penis = configure_test_penis(built)
	if(!penis)
		return null
	if(custom_layer)
		var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
		penis.visibility_preference = GENITAL_CUSTOM
		overlay.layer_mode = body == "custom_layer_above" ? GENITAL_LAYER_ABOVE_UNDIES : GENITAL_LAYER_BELOW_UNDIES
	LAZYSET(wearers, body, built)
	return built

/**
 * The approved look in the repository: 29 cases of the pixel corpus above, drawn as the corpus draws them: an adaptive
 * look small and large (with the exposed tip), a printed uniform and printed underwear, the large hearts (over a human
 * and a knotted penis), each skirt
 * style half and hard, a loincloth reveal as underwear and as a uniform, digitigrade legs, a tall wearer, a suit as the
 * cover, a bloody cover and blood on a cut one, a big tentacle, and a penis layered above and below the underwear.
 * What the renderer makes of each (the e1, e2, e3 and cst images above) is hashed pixel by pixel and compared with the
 * hash of the images the corpus comparator expects, which it builds outside the game from the frozen reference and the
 * approved rules. A failure means an approved case is drawn differently: run the full corpus and its comparator on the
 * change (the module readme says where they live and how) before taking new hashes from it.
 */
/datum/unit_test/portal_test/bulge_render_corpus/pixels
	priority = TEST_DEFAULT

/datum/unit_test/portal_test/bulge_render_corpus/pixels/Run()
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Bulges need genitals, which the ERP config disables.")
		return
	// Corpus rows (id, garment, suit, suit worn state, body, penis shape, skin tones, length, hard, underclothes colour,
	// cover slot), each with the hash of its expected images.
	var/list/cases = list(
		list("cov:small_jumpsuit_f_4", "/obj/item/clothing/under/color/grey", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 1, null, "u", "dcc3802cf283864758ec11133d1a0837"), // adaptive small
		list("cov:large_jeans_f_6_human_jeans", "/obj/item/clothing/under/pants/jeans", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 49, 1, null, "u", "9a51430c1f85bcc77a99a565f4983a0b"), // adaptive large, exposed tip
		list("fa2:u_c148_07", "/obj/item/clothing/under/rank/prisoner", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 1, null, "u", "902732a7219ecb30cb490bec72021e78"), // printed uniform
		list("add:hearts:human:toned:plain:hard:1", "/datum/sprite_accessory/clothing/underwear/male_hearts", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 4, 1, "#34466b", "b", "58738597ec318a39e32c5c4f7ca88207"), // printed underwear
		list("cov:u02_plain_half_5", "/datum/sprite_accessory/clothing/underwear/male_hearts", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 37, 0, "#34466b", "b", "aa5821416b9fc5f4e68941f077403d59"), // large hearts
		list("cov:u02_plain_hard_6", "/datum/sprite_accessory/clothing/underwear/male_hearts", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 49, 1, "#34466b", "b", "ce164b1ea8384a555af1fa192f6b3acb"), // large hearts hard, mal's report
		list("add:hearts:knotted:toned:plain:hard:7", "/datum/sprite_accessory/clothing/underwear/male_hearts", null, null, "plain", "/datum/sprite_accessory/genital/penis/knotted", 1, 57, 1, "#34466b", "b", "d227271dde4849ac25250df8fe072111"), // large hearts hard, knotted
		list("add:hearts:flared:toned:plain:hard:7", "/datum/sprite_accessory/clothing/underwear/male_hearts", null, null, "plain", "/datum/sprite_accessory/genital/penis/flared", 1, 57, 1, "#34466b", "b", "0a33413211abc81e58b8053d6fc4f75d"), // large hearts hard, flared
		list("fa2:g050_a_plain_half_4", "/obj/item/clothing/under/costume/nova/kimono/sigmar", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 0, null, "u", "5178fda604db03ab3ea9fda26501935e"), // skirt/short_closed_lift half
		list("fa2:g050_a_plain_hard_4", "/obj/item/clothing/under/costume/nova/kimono/sigmar", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 1, null, "u", "9f0934a8f18b520a83e8d21391d8d375"), // skirt/short_closed_lift hard
		list("fa2:g022_b_plain_half_4", "/obj/item/clothing/under/costume/buttondown/skirt", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 0, null, "u", "922c7a92e35d7cb21defa3c3b0b2357e"), // skirt/short_reveal half
		list("fa2:g022_b_plain_hard_4", "/obj/item/clothing/under/costume/buttondown/skirt", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 1, null, "u", "965c359d5259d605fd3553e9cee3e8c8"), // skirt/short_reveal hard
		list("fa2:g028_c_plain_half_4", "/obj/item/clothing/under/costume/gladiator", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 0, null, "u", "b5bc99ab87054b2e791b362919003fc4"), // skirt/short_kilt_apron half
		list("fa2:g028_c_plain_hard_4", "/obj/item/clothing/under/costume/gladiator", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 1, null, "u", "a793291a241a7ecb91bd6b1dc24e89af"), // skirt/short_kilt_apron hard
		list("fa2:g001_a_plain_half_4", "/obj/item/clothing/under/bubbly_clown_skirt", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 0, null, "u", "8dcdab012b31fdc2800d9f3d2fa6ac78"), // skirt/long_cone half
		list("fa2:g001_a_plain_hard_4", "/obj/item/clothing/under/bubbly_clown_skirt", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 1, null, "u", "2ab6f6072add9bdd0ce4383d94251db5"), // skirt/long_cone hard
		list("fa2:g027_b_plain_half_4", "/obj/item/clothing/under/costume/geisha", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 0, null, "u", "f6d40954284aefb97dbee2637cbbeb8f"), // skirt/long_curtain half
		list("fa2:g027_b_plain_hard_4", "/obj/item/clothing/under/costume/geisha", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 1, null, "u", "1b5fe1af477732a1dc00647de6bdc6dc"), // skirt/long_curtain hard
		list("fa2:g025_c_plain_half_4", "/obj/item/clothing/under/costume/cybersleek/long", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 0, null, "u", "30671e6e6f18d8033ad686bd4db054a2"), // skirt/long_pressed half
		list("fa2:g025_c_plain_hard_4", "/obj/item/clothing/under/costume/cybersleek/long", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 1, null, "u", "32a050c20e06854f8cd3a75b6238f2cf"), // skirt/long_pressed hard
		list("cov:drape_loin_human_3_plain", "/datum/sprite_accessory/clothing/underwear/loincloth", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 1, "#34466b", "b", "05fb12d91a0998d2285d67970d3adfb3"), // loincloth reveal
		list("cov:small_athletic_f_1_dg", "/obj/item/clothing/under/shorts/red", null, null, "digi", "/datum/sprite_accessory/genital/penis/human", 1, 4, 1, null, "u", "962cfff49a42f187aac0d2e1c3bdd0db"), // digitigrade
		list("cov:suit_S303_1", "/obj/item/clothing/under/color/grey", "/obj/item/clothing/suit/apron/overalls", "overalls", "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 1, null, "s", "9fbfb339128f0a445bf077e761e3a61f"), // suit as cover
		list("fix:bloody:cov:small_jumpsuit_f_4", "/obj/item/clothing/under/color/grey", null, null, "plain_bloody", "/datum/sprite_accessory/genital/penis/human", 1, 12, 1, null, "u", "80a9d95d3ecee6fa8557916c3a31ccc3"), // bloody cover
		list("fix:bloody:fa2:g103_b_plain_hard_5", "/obj/item/clothing/under/dress/skirt/plaid", null, null, "plain_bloody", "/datum/sprite_accessory/genital/penis/human", 1, 37, 1, null, "u", "7a1ef231ad29535ec8aaeb925f920d6d"), // blood on a cut cover
		list("add:tentacle:underwear_male_boxers:tentacle:toned:plain:hard:5", "/datum/sprite_accessory/clothing/underwear/male_boxers", null, null, "plain", "/datum/sprite_accessory/genital/penis/tentacle", 1, 37, 1, "#34466b", "b", "31a6e85502b7458808107f92d95c6d54"), // big tentacle
		list("fix:custom_above:cov:drape_loin_human_3_plain", "/datum/sprite_accessory/clothing/underwear/loincloth", null, null, "custom_layer_above", "/datum/sprite_accessory/genital/penis/human", 1, 12, 1, "#34466b", "b", "3c8dc9de3f6c9d6f8d1b4462ff05302f"), // Custom above the underwear
		list("cov:drape_leather_human_3_plain", "/obj/item/clothing/under/costume/loincloth", null, null, "plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 1, null, "u", "4efd0bb3588238aab226ec3055c87a43"), // uniform loincloth reveal
		list("cov:fit_custom_offset_plain_jumpsuits_hard_4", "/obj/item/clothing/under/color/grey", null, null, "custom_offset_plain", "/datum/sprite_accessory/genital/penis/human", 1, 12, 1, null, "u", "0092ebff72161bf73734c2a5e84a050c"), // tall wearer
		list("fix:custom_below:cov:drape_loin_human_3_plain", "/datum/sprite_accessory/clothing/underwear/loincloth", null, null, "custom_layer_below", "/datum/sprite_accessory/genital/penis/human", 1, 12, 1, "#34466b", "b", "05fb12d91a0998d2285d67970d3adfb3"), // Custom below the underwear
	)
	for(var/index in 1 to length(cases))
		var/list/row = cases[index]
		draw_case(row, index)
		var/list/drawn = list()
		for(var/export in list("e1", "e2", "e3", "cst"))
			var/icon/frames = case_icons?[export]
			if(frames)
				drawn += "[export]:[pixel_text(frames)]"
		case_icons = null
		var/hash = md5(jointext(drawn, "|"))
		if(hash != row[12])
			TEST_FAIL("[row[1]] is drawn as [hash], not as approved ([row[12]]).")
	TEST_ASSERT_EQUAL(failed, 0, "Cases that could not be drawn")

/// An image's pixels facing each of the corpus's directions in turn, bottom row first, left to right: GetPixel()'s
/// "#rrggbb" (or "#rrggbbaa"), nothing for a clear pixel, joined by commas.
/datum/unit_test/portal_test/bulge_render_corpus/pixels/proc/pixel_text(icon/frames)
	var/list/pixels = list()
	for(var/direction in directions)
		for(var/y in 1 to 32)
			for(var/x in 1 to 32)
				pixels += frames.GetPixel(x, y, "", direction)
	return jointext(pixels, ",")

#undef RENDER_CORPUS_DIR
#undef RENDER_CORPUS_OUT
#undef RENDER_CORPUS_CLOCK
#undef RENDER_CORPUS_BATCH
