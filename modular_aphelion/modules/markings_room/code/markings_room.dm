/// The markers on the club mirror's counter, which a surprise paints with now and then.
GLOBAL_LIST_INIT(markings_room_paints, list(
	"#ff3fa4",
	"#ff4040",
	"#ffb020",
	"#f4f1e8",
	"#1d1a22",
	"#2ff3e0",
	"#3f8cff",
	"#a066ff",
	"#9dff4a",
))

/// In percent: how often a zone is left bare by a surprise, painted with a marker, or made to glow.
#define MARKINGS_ROOM_SURPRISE_BARE 25
#define MARKINGS_ROOM_SURPRISE_PAINT 30
#define MARKINGS_ROOM_SURPRISE_GLOW 12

/**
 * What the club mirror on the Markings tab needs beyond the markings data: the colour each marking starts in, the
 * custom drawings to show on its cards, which body region owns each pixel of the drawn character, and a surprise. See
 * module.md.
 */
/datum/preference_middleware/markings_room
	action_delegations = list(
		"markings_room_regions" = PROC_REF(send_regions),
		"surprise_markings" = PROC_REF(act_surprise_markings),
	)

/datum/preference_middleware/markings_room/get_ui_assets()
	return list(get_asset_datum(/datum/asset/simple/markings_room))

/**
 * The colour each marking with one of its own starts in, by name. Every other marking follows one of the character's
 * mutant colours, which get_ui_data() sends.
 */
/datum/preference_middleware/markings_room/get_constant_data()
	var/list/defaults = list()
	for(var/marking_name, marking_datum in GLOB.body_markings)
		var/datum/body_marking/marking = marking_datum
		if(marking.color_mode == MARKING_COLOR_FIXED_DEFAULT || marking.color_mode == MARKING_COLOR_LOCKED)
			defaults[marking_name] = sanitize_hexcolor(marking.default_color)
	return list(
		"marking_defaults" = defaults,
		"native_marking_icons" = custom_sprite_native_marking_icons(),
	)

/datum/preference_middleware/markings_room/get_ui_data(mob/user)
	preferences.load_custom_sprites()
	// Each custom drawing as it is saved, every view of it, for the cards' thumbnails and the mirror's highlight.
	var/list/views
	for(var/zone, drawing in preferences.custom_limb_markings)
		var/list/dirs = list()
		for(var/facing, direction in GLOB.character_preview_facings)
			dirs[facing] = drawing["dirs"]?["[direction]"]
		LAZYSET(views, zone, list(
			"width" = custom_sprite_width(drawing),
			"palette" = drawing["palette"],
			"dirs" = dirs,
		))
	return list(
		"marking_fur_colors" = fur_colors(),
		"custom_marking_views" = views,
		// The station's clock as the round's: Electra's mirror shows it. The page ticks it on from each update, which
		// sets it right again, so it goes with every one rather than once.
		"markings_room_clock" = STATION_TIME_PASSED(),
	)

/// The engine's record, for Hephaestus's tag: it holds all round, so it goes once a window.
/datum/preference_middleware/markings_room/get_ui_static_data(mob/user)
	return list(
		"markings_room_delam" = SSpersistence.rounds_since_engine_exploded,
	)

/**
 * Returns the three mutant colours a marking can follow, as the preview body wears them: what a new marking, a preset or
 * a colour reset gives it.
 *
 * Returns:
 * - list: three "#rrggbb" colours, or null without a preview body.
 */
/datum/preference_middleware/markings_room/proc/fur_colors()
	var/list/features = preferences.character_preview_view?.body?.dna?.features
	if(isnull(features))
		return null
	return list(
		sanitize_hexcolor(features[FEATURE_MUTANT_COLOR]),
		sanitize_hexcolor(features[FEATURE_MUTANT_COLOR_TWO]),
		sanitize_hexcolor(features[FEATURE_MUTANT_COLOR_THREE]),
	)

/**
 * The page asks, for the character drawing it shows (params["id"]), which body region owns each pixel of the preview
 * body, facing each way, for the mirror's halo and for pointing at a part. It gets the custom markings editor's region
 * map, cached by the body's geometry, in an update of its own: `markings_room_regions_for`, the drawing the map fits,
 * and the map itself only when the page doesn't hold it already (params["have"], the key of the one it holds). Most
 * drawings, a marking painted or swapped, leave the body's shape as it was, and its map with it.
 */
/datum/preference_middleware/markings_room/proc/send_regions(list/params, mob/user)
	var/datum/tgui/ui = SStgui.get_open_ui(user, preferences)
	var/mob/living/carbon/human/body = preferences.character_preview_view?.body
	if(isnull(ui) || isnull(body))
		return FALSE
	var/list/zones = custom_sprite_present_regions(body)
	// A taur organ widens the canvas, as the editor's does.
	var/width = custom_sprite_taur_overlay(body) ? CUSTOM_SPRITE_TAUR_WIDTH : 32
	var/list/region_map = custom_sprite_region_map(body, zones, width)
	var/list/rows = list()
	for(var/facing, direction in GLOB.character_preview_facings)
		rows[facing] = region_map["[direction]"]
	var/list/regions = list(
		"zones" = zones,
		"width" = width,
		"rows" = rows,
		"augments" = augment_overlay_map(body, width),
	)
	var/key = md5(json_encode(regions))
	var/list/update = list("markings_room_regions_for" = params["id"])
	if(params["have"] != key)
		regions["id"] = params["id"]
		regions["key"] = key
		update["markings_room_regions"] = regions
	ui.send_update(update)
	return FALSE

/**
 * The visible augments the preview body wears, mapped as its regions are (custom_sprite_region_map()): which one draws
 * each pixel, facing each way. A pair of eyes, an implant's overlay: the scan chamber's x-ray leaves each showing as it
 * is, in its own shape. Each one's images are filled with its ID colour and composed in draw order, and the result is
 * read once per view. Cached by the images that drew it.
 *
 * Arguments:
 * - body: The preview body.
 * - width: The canvas width, as the body's region map has it.
 *
 * Returns list("zones" = the augments' slots, "rows" = facing -> 32 row strings), or null when none draws.
 */
/datum/preference_middleware/markings_room/proc/augment_overlay_map(mob/living/carbon/human/body, width)
	// Bounded cache of composed augment maps, keyed by the images that drew them.
	var/static/list/maps = list()
	var/list/slots = list()
	// Each image the augments draw with: list(layer, index, x, y, icon, icon_state).
	var/list/parts = list()
	var/offset_x = (width - 32) / 2
	for(var/slot, augment_path in preferences.augments)
		// Organs and implants alike: character setup fits the ones that show (eyes, an implant with an overlay).
		var/datum/augment_item/augment = GLOB.augment_items[augment_path]
		if(isnull(augment))
			continue
		var/obj/item/organ/organ
		for(var/obj/item/organ/worn as anything in body.organs)
			if(worn.type == augment.path)
				organ = worn
				break
		var/index = length(slots) + 1
		var/drew = FALSE
		for(var/image/part as anything in augment_overlay_images(organ))
			if(!part.icon || !part.icon_state || !part.alpha || PLANE_TO_TRUE(part.plane) == EMISSIVE_PLANE)
				continue
			parts += list(list(part.layer, index, 1 + offset_x + part.pixel_x + part.pixel_w, 1 + part.pixel_y + part.pixel_z, part.icon, part.icon_state))
			drew = TRUE
		if(drew)
			slots += slot
	if(!length(slots))
		return null
	var/list/geometry = list(width, slots)
	for(var/list/part as anything in parts)
		geometry += list(list(part[1], part[2], part[3], part[4], "[part[5]]", part[6]))
	var/key = md5(json_encode(geometry))
	if(maps[key])
		return maps[key]
	var/list/entries = list()
	for(var/list/part as anything in parts)
		var/list/channels = rgb2num(custom_sprite_region_color(part[2]))
		var/icon/shape = icon(part[5], part[6])
		// Its ID colour wherever it draws, as solid as it is.
		shape.MapColors(0, 0, 0, 0, 0, 0, 0, 0, 0, channels[1] / 255, channels[2] / 255, channels[3] / 255)
		entries += list(list(part[1], part[2], part[3], part[4], shape))
	// Stable draw order: lower layers first, then augment order within a layer.
	var/list/ordered = sort_list(entries, GLOBAL_PROC_REF(cmp_custom_sprite_region_layer))
	var/icon/composite = custom_sprite_blank_icon(width)
	for(var/list/entry as anything in ordered)
		composite.Blend(entry[5], ICON_OVERLAY, entry[3], entry[4])
	var/list/ids = list()
	for(var/index in 1 to length(slots))
		ids[custom_sprite_region_color(index)] = "[index]"
	var/list/map = custom_sprite_icon_rows(composite, width, ids, ordered)
	var/list/rows = list()
	for(var/facing, direction in GLOB.character_preview_facings)
		rows[facing] = map["[direction]"]
	return custom_sprite_cache_put(maps, key, list("zones" = slots, "rows" = rows))

/**
 * What an augment draws on the body it's in: an eye's eyes on its head, an implant's overlay, an organ's own overlay.
 *
 * Returns a list of images, or null when it draws nothing.
 */
/datum/preference_middleware/markings_room/proc/augment_overlay_images(obj/item/organ/organ)
	if(isnull(organ))
		return null
	if(istype(organ, /obj/item/organ/eyes))
		var/obj/item/bodypart/head/head = organ.owner?.get_bodypart(BODY_ZONE_HEAD)
		if(isnull(head) || !(head.head_flags & HEAD_EYESPRITES))
			return null
		var/obj/item/organ/eyes/eyes = organ
		return eyes.generate_body_overlay(head)
	var/obj/item/bodypart/limb = organ.bodypart_owner
	if(isnull(limb))
		return null
	var/datum/bodypart_overlay/overlay = organ.bodypart_overlay
	if(istype(organ, /obj/item/organ/cyberimp))
		var/obj/item/organ/cyberimp/implant = organ
		overlay = implant.bodypart_aug
	// Only what the limb draws: a Teshari's implants keep their overlays off it.
	if(isnull(overlay) || !(overlay in limb.bodypart_overlays))
		return null
	return overlay.get_all_overlays(limb)

/**
 * Surprise me: a whole new set of markings the species is meant to wear, on every zone at once, in place of every marking
 * worn now. A zone is left bare MARKINGS_ROOM_SURPRISE_BARE percent of the time and otherwise gets one or two markings,
 * now and then in a marker's paint and, when the character allows glow, glowing. Legs under a taur body get none.
 */
/datum/preference_middleware/markings_room/proc/surprise_markings(list/params, mob/user)
	var/datum/species/species = GLOB.species_prototypes[preferences.read_preference(/datum/preference/choiced/species)]
	if(isnull(species))
		return FALSE
	var/list/features = preferences.character_preview_view?.body?.dna?.features
	var/allow_emissives = preferences.read_preference(/datum/preference/toggle/allow_emissives)
	var/datum/preference_middleware/limbs_and_markings/markings_middleware = locate() in preferences.middleware
	var/taur_legs = markings_middleware?.has_taur_legs()
	var/datum/body_marking_collection/surprise = new
	for(var/zone in GLOB.marking_zones)
		if(taur_legs && (zone == BODY_ZONE_L_LEG || zone == BODY_ZONE_R_LEG))
			continue
		if(prob(MARKINGS_ROOM_SURPRISE_BARE))
			continue
		var/wanted = rand(1, 2)
		var/list/pool = body_markings_of_zone_for_species(zone, species.id, FALSE)
		while(surprise.zone_length(zone) < wanted && length(pool))
			var/datum/body_marking/marking = GLOB.body_markings[pick_n_take(pool)]
			var/datum/body_marking_entry/entry = new(marking, zone, marking.seed_color(features, species), allow_emissives && prob(MARKINGS_ROOM_SURPRISE_GLOW))
			// A locked marking keeps its own colour.
			if(prob(MARKINGS_ROOM_SURPRISE_PAINT))
				entry.set_color(pick(GLOB.markings_room_paints))
			// One of a group already on the zone is refused.
			surprise.add_entry(entry)
	preferences.body_markings = surprise
	preferences.character_preview_view?.update_body()
	return TRUE

/// The window's side of Surprise me: the markings it put on go to the window alone, as every markings action's do.
/datum/preference_middleware/markings_room/proc/act_surprise_markings(list/params, mob/user)
	if(!surprise_markings(params, user))
		return FALSE
	var/datum/preference_middleware/limbs_and_markings/markings_middleware = locate() in preferences.middleware
	return markings_middleware ? markings_middleware.send_markings(user) : TRUE

#undef MARKINGS_ROOM_SURPRISE_BARE
#undef MARKINGS_ROOM_SURPRISE_PAINT
#undef MARKINGS_ROOM_SURPRISE_GLOW

/**
 * The rooms' textures and fonts, which the preferences window gets with its other assets: in tgui's bundle, which every
 * window loads, every room's would weigh on every window. A stylesheet written when the asset registers declares them
 * by the URLs the asset transport gives them: each texture as a custom property on the room, `--mr-` and its file's
 * name without the extension, and each font as a face. The window loads it as soon as it hears of it. The lists are in
 * markings_room_assets.dm.
 */
/datum/asset/simple/markings_room
	/// The textures the rooms draw with, by file name.
	var/list/textures
	/// The fonts the rooms letter with, by file name: list(family, weight, file).
	var/list/fonts

/datum/asset/simple/markings_room/register()
	for(var/file_name, texture in textures)
		assets["markings_room.[file_name]"] = texture
	for(var/file_name in fonts)
		var/list/face = fonts[file_name]
		assets["markings_room.[file_name]"] = face[3]
	..()
	var/list/properties = list()
	for(var/file_name in textures)
		properties += "--mr-[copytext(file_name, 1, findlasttext(file_name, "."))]:url('[asset_url("markings_room.[file_name]")]')"
	var/list/css = list(".AugmentsRoom{[jointext(properties, ";")]}")
	for(var/file_name in fonts)
		var/list/face = fonts[file_name]
		css += "@font-face{font-family:'[face[1]]';font-weight:[face[2]];font-display:block;src:url('[asset_url("markings_room.[file_name]")]')}"
	var/filename = "data/markings_room.css"
	fdel(filename)
	rustg_file_write(jointext(css, "\n"), filename)
	assets["markings_room.css"] = SSassets.transport.register_asset("markings_room.css", fcopy_rsc(filename))
	fdel(filename)

/// The URL the asset transport gives one of the asset's files.
/datum/asset/simple/markings_room/proc/asset_url(asset_name)
	return SSassets.transport.get_asset_url(asset_name, assets[asset_name])
