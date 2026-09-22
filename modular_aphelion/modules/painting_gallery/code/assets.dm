/// Register mid-round imports without rebuilding already registered portrait resources.
/datum/asset/simple/portraits/proc/refresh_paintings()
	for(var/datum/painting/painting as anything in SSpersistent_paintings.paintings)
		var/asset_name = "paintings_[painting.md5].png"
		if(assets[asset_name])
			continue
		var/png = "data/paintings/images/[painting.md5].png"
		if(!fexists(png))
			continue
		var/datum/asset_cache_item/item = SSassets.transport.register_asset(asset_name, png)
		if(item)
			assets[asset_name] = item
			cached_serialized_url_mappings = null
			. = TRUE
