/**
 * The recolourable finishes' sheets cut up for the colour editor's preview, which tints them on the client. Rebuilt only when a
 * sheet changes (the batched spritesheet's smart cache).
 *
 * Every sprite is one 32x32 view, class augment_paint32x32 and a name:
 * - <id>-<zone>-<layer>-<dir>: a finish's zone, `layer` skin (the human skin base), skinh (the humanoid one), paint or glow
 *   (only where the paint sheet holds the zone's packed state), `dir` south, north, east or west.
 * - body-<dir>: the Muscular body, the editor's silhouette.
 */
/datum/asset/spritesheet_batched/augment_paint
	name = "augment_paint"

/**
 * Inserts every recolourable finish's zones in four directions, from both skin sheets and from the paint sheet where it holds
 * the zone's packed state, and the Muscular body, put together from its parts, in four directions.
 */
/datum/asset/spritesheet_batched/augment_paint/create_spritesheets()
	var/list/sheets = list("skin" = BULKY_AUGMENTS_SHEET, "skinh" = BULKY_AUGMENTS_SHEET_HUMANOID)
	for(var/style_name, style in GLOB.robotic_styles_list)
		var/datum/robotic_style/recolorable/finish = style
		if(!istype(finish))
			continue
		var/id = finish.limb_id_override
		for(var/zone in BULKY_AUGMENT_ZONES)
			for(var/dir in GLOB.cardinals)
				var/dir_name = dir2text(dir)
				for(var/layer, sheet in sheets)
					insert_icon("[id]-[zone]-[layer]-[dir_name]", uni_icon(sheet, "[id]_[zone]", dir))
				for(var/layer in list("paint", "glow"))
					var/state = "[id]_[zone]_[layer]"
					if(icon_exists(BULKY_AUGMENTS_PAINT_SHEET, state))
						insert_icon("[id]-[zone]-[layer]-[dir_name]", uni_icon(BULKY_AUGMENTS_PAINT_SHEET, state, dir))
	var/list/body_parts = list(
		list('modular_aphelion/modules/fitness/icons/human_parts_muscular.dmi', "human_chest_m"),
		list(BODYPART_ICON_HUMAN, "human_head_m"),
		list('modular_aphelion/modules/fitness/icons/human_parts_muscular.dmi', "human_r_leg"),
		list('modular_aphelion/modules/fitness/icons/human_parts_muscular.dmi', "human_l_leg"),
		list('modular_aphelion/modules/fitness/icons/human_parts_muscular.dmi', "human_r_arm"),
		list('modular_aphelion/modules/fitness/icons/human_parts_muscular.dmi', "human_l_arm"),
		list('modular_aphelion/modules/fitness/icons/human_parts_muscular.dmi', "human_r_hand"),
		list('modular_aphelion/modules/fitness/icons/human_parts_muscular.dmi', "human_l_hand"),
	)
	for(var/dir in GLOB.cardinals)
		var/datum/universal_icon/body
		for(var/list/part as anything in body_parts)
			var/datum/universal_icon/piece = uni_icon(part[1], part[2], dir)
			if(body)
				body.blend_icon(piece, ICON_OVERLAY)
			else
				body = piece
		insert_icon("body-[dir2text(dir)]", body)

/**
 * Every brand style's augment limbs for the finish picker's try-on, kept out of the preferences window's own load: the window
 * asks for it once, ahead of the Augments room (/datum/preference_middleware/augment_paint/proc/send_augment_brand_sprites()).
 * Made and cached as the other batched spritesheets are.
 *
 * Every sprite is one 32x32 view, class augment_brands32x32 and the name brand-<key>-<zone>-<dir>: a brand style's limb
 * state as the game draws it (augment_brand_states()), `key` its augment_brand_key(), `zone` an arm, hand or leg, or
 * r_leg_digi and l_leg_digi for its digitigrade legs, `dir` south, north, east or west.
 */
/datum/asset/spritesheet_batched/augment_brands
	name = "augment_brands"

/**
 * Inserts every brand style's limb states in four directions.
 */
/datum/asset/spritesheet_batched/augment_brands/create_spritesheets()
	for(var/style_name, style in GLOB.robotic_styles_list)
		var/datum/robotic_style/brand = style
		var/key = brand.augment_brand_key()
		for(var/zone, state in brand.augment_brand_states())
			for(var/dir in GLOB.cardinals)
				insert_icon("brand-[key]-[zone]-[dir2text(dir)]", uni_icon(brand.icon, state, dir))

/**
 * Returns the style's id in the finish picker's brand sprites and data: the last part of its type, lowercase.
 */
/datum/robotic_style/proc/augment_brand_key()
	var/type_text = "[type]"
	return LOWER_TEXT(copytext(type_text, findlasttext(type_text, "/") + 1))

/**
 * Returns the states an augment limb in this style draws, zone -> state, as apply_style_to_limb() and get_limb_icon() resolve
 * them: <limb id>_<zone> in the style's icon, the limb id its limb_id_override or the robotic id every styled augment limb
 * has. An arm draws its hand along with it. A leg on a digitigrade body draws <limb id>_<leg>_digi, listed as <leg>_digi,
 * unless the style's bodyshape_override drops the digitigrade shape, when it draws the plain leg; a style without has_digi
 * can't be worn there. Only zones a slot can wear the style on and whose state has four directions are listed.
 */
/datum/robotic_style/proc/augment_brand_states()
	var/list/zones = list()
	if(supported_slots & ARM_RIGHT)
		zones += list(BODY_ZONE_R_ARM, BODY_ZONE_PRECISE_R_HAND)
	if(supported_slots & ARM_LEFT)
		zones += list(BODY_ZONE_L_ARM, BODY_ZONE_PRECISE_L_HAND)
	var/digi = has_digi && (!bodyshape_override || (bodyshape_override & BODYSHAPE_DIGITIGRADE))
	for(var/leg_zone, slot in list(BODY_ZONE_R_LEG = LEG_RIGHT, BODY_ZONE_L_LEG = LEG_LEFT))
		if(supported_slots & slot)
			zones += (digi ? list(leg_zone, "[leg_zone]_[ICON_KEY_DIGI]") : leg_zone)
	var/list/state_dirs = list()
	for(var/list/state_data as anything in icon_metadata(icon)?["states"])
		state_dirs[state_data["name"]] = state_data["dirs"]
	var/limb_id = limb_id_override || BODYPART_ID_ROBOTIC
	. = list()
	for(var/zone in zones)
		if(state_dirs["[limb_id]_[zone]"] >= 4)
			.[zone] = "[limb_id]_[zone]"

/**
 * A recolourable finish draws through its own sheets, so it has no brand states.
 */
/datum/robotic_style/recolorable/augment_brand_states()
	return list()
