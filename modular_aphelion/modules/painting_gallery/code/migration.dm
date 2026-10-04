/// Updates paintings data format to latest if necessary
/datum/controller/subsystem/persistent_paintings/proc/update_format(list/current_data, list/images = list())
	if(current_data["version"] && current_data["version"] == PAINTINGS_DATA_FORMAT_VERSION)
		return current_data

	var/version = current_data["version"]
	if(version < 1)
		current_data = migrate_to_version_1(current_data, images)
		if(!current_data)
			return null
	if(version < 2) //Makes sure old paintings get a cosmetic frame type from their patronage tiers.
		current_data =  migrate_to_version_2(current_data)
	if(version < 3) //Reduces the allowed length of titles from 1000 characters circa to 42.
		current_data["version"] = 3
		for(var/list/painting_data as anything in current_data["paintings"])
			var/new_title = reject_bad_name(painting_data["title"], allow_numbers = TRUE, ascii_only = FALSE, strict = TRUE, cap_after_symbols = FALSE)
			painting_data["title"] = new_title || "Illegibly Titled Artwork"

	return current_data

/// Merge legacy category entries by identity and prepare image copies for the shared transaction.
/datum/controller/subsystem/persistent_paintings/proc/migrate_to_version_1(list/current_data, list/images)
	var/list/result = list()
	result["version"] = 1
	var/list/data = list()
	var/list/rows_by_id
	// Squash categories into tags
	for(var/category, data_entry in current_data)
		if(category == "version")
			continue
		if(!(category in list("library", "library_secure", "library_private", "library_large", "library_large_private")))
			return null
		for(var/old_data in data_entry)
			if(!valid_painting_id(old_data["md5"]))
				return null
			var/list/existing = rows_by_id?[old_data["md5"]]
			if(existing)
				existing["tags"] |= category
				continue
			var/old_png_path = "data/paintings/[category]/[old_data["md5"]].png"
			var/new_png_path = "data/paintings/images/[old_data["md5"]].png"
			var/icon/painting_icon = new(fexists(new_png_path) ? new_png_path : old_png_path)
			if(!fexists(new_png_path))
				images += list(list("id" = old_data["md5"], "source" = "legacy", "category" = category))
			var/width = painting_icon.Width()
			var/height = painting_icon.Height()
			var/list/new_data = list()
			new_data["md5"] = old_data["md5"]
			new_data["title"] = old_data["title"] || "Untitled Artwork"
			new_data["creator_ckey"] = old_data["ckey"] || ""
			new_data["creator_name"] = "Anonymous"
			new_data["creation_date"] = time2text(world.realtime, "DDD MMM DD hh:mm:ss YYYY", TIMEZONE_UTC) // Could use creation/modified file helpers in rustg
			new_data["creation_round_id"] = GLOB.round_id
			new_data["tags"] = list(category,"Migrated from version 0")
			new_data["patron_ckey"] = ""
			new_data["patron_name"] = ""
			new_data["credit_value"] = 0
			new_data["width"] = width
			new_data["height"] = height
			new_data["medium"] = "Spraypaint on canvas" //Let's go with most common tool.
			new_data["show_in_webgallery"] = FALSE
			data += list(new_data)
			LAZYSET(rows_by_id, old_data["md5"], new_data)
	result["paintings"] = data
	// The shared writer journals and commits the entire migration atomically.
	// Legacy source PNGs are retained as recovery material.
	return result

/// Add patronage-tier cosmetic frames to version-1 records without writing files directly.
/datum/controller/subsystem/persistent_paintings/proc/migrate_to_version_2(list/current_data)
	current_data["version"] = 2
	for(var/painting_data in current_data["paintings"])
		painting_data["tags"] |= "Migrated from version 1"
		var/credit_value = painting_data["credit_value"]
		var/list/possible_frame_types = get_available_frames(credit_value, only_current_tier = TRUE)
		painting_data["frame_type"] = pick(possible_frame_types) || "simple"
	return current_data
