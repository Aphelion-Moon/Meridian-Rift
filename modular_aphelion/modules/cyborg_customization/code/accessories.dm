/// Native icon operations and bounded immutable outputs replace donor per-pixel loops.
/// Reuses Meridian accessories: no physical organ or bodypart overlay is constructed.
/proc/cyborg_dynamic_accessory_suffix(slot, datum/sprite_accessory/genital/accessory, sprite_size, arousal)
	var/size = cyborg_layout_sprite_size(sprite_size, slot)
	var/arousal_suffix = arousal == "full" ? 1 : 0
	switch(slot)
		if("penis")
			return "[accessory.icon_state]_[size]_[arousal_suffix]"
		if("testicles", "breasts")
			return "[accessory.icon_state]_[size]"
		if("vagina")
			return "[accessory.icon_state]_[arousal_suffix]"
	return accessory.get_sprite_suffix()

/proc/cyborg_dynamic_accessory_has_size(slot, datum/sprite_accessory/genital/accessory, sprite_size)
	var/list/states = icon_states(accessory.icon)
	var/list/arousals = slot == "penis" ? list("none", "full") : list("none")
	for(var/arousal in arousals)
		var/suffix = cyborg_dynamic_accessory_suffix(slot, accessory, sprite_size, arousal)
		for(var/layer in SSaccessories.all_layer_postfixes)
			var/base_state = "m_[slot]_[suffix]_[layer]"
			if(base_state in states)
				return TRUE
			for(var/channel in list("primary", "secondary", "tertiary"))
				if("[base_state]_[channel]" in states)
					return TRUE
	return FALSE

/proc/cyborg_accessory_size_values(slot, choice)
	var/static/list/size_cache = list()
	var/cache_key = "[slot]|[choice]"
	var/list/cached_sizes = size_cache[cache_key]
	if(cached_sizes)
		return cached_sizes.Copy()
	var/list/direct = cyborg_direct_accessories(slot)[choice]
	if(direct)
		var/list/direct_sizes = direct["sizes"]
		direct_sizes = direct_sizes ? direct_sizes.Copy() : list(cyborg_layout_default_sprite_size(slot))
		size_cache[cache_key] = direct_sizes
		return direct_sizes.Copy()
	var/datum/sprite_accessory/genital/accessory = SSaccessories.sprite_accessories[slot]?[choice]
	if(!istype(accessory) || !accessory.factual || !accessory.icon)
		return list()
	if(!(slot in list("penis", "testicles", "breasts")))
		var/list/fixed_sizes = list(cyborg_layout_default_sprite_size(slot))
		size_cache[cache_key] = fixed_sizes
		return fixed_sizes.Copy()
	var/list/result = list()
	for(var/sprite_size in CYBORG_LAYOUT_MIN_SPRITE_SIZE to CYBORG_LAYOUT_MAX_SPRITE_SIZE)
		if(cyborg_dynamic_accessory_has_size(slot, accessory, sprite_size))
			result += sprite_size
	if(!length(result))
		result += cyborg_layout_default_sprite_size(slot)
	size_cache[cache_key] = result
	return result.Copy()

/proc/cyborg_accessory_effective_size(slot, choice, requested)
	var/list/values = cyborg_accessory_size_values(slot, choice)
	if(requested in values)
		return requested
	return length(values) ? values[1] : cyborg_layout_default_sprite_size(slot)

/proc/cyborg_accessory_color_channels(slot, choice, sprite_size = 1, arousal = "none")
	var/list/direct = cyborg_direct_accessories(slot)[choice]
	if(direct)
		var/list/direct_channels = direct["channels"]
		var/list/direct_result = list()
		var/direct_size = cyborg_accessory_effective_size(slot, choice, sprite_size)
		var/state = replacetext(direct["state"], "SIZE", "[direct_size]")
		state = replacetext(state, "AROUSAL", arousal == "full" ? "2" : (arousal == "partial" ? "1" : "0"))
		var/list/direct_states = icon_states(direct["icon"])
		if(!islist(direct_channels))
			if(state in direct_states)
				direct_result += 1
			return direct_result
		var/index = 0
		for(var/channel in direct_channels)
			index++
			if("[state]_[channel]" in direct_states)
				direct_result += index
		return direct_result
	var/datum/sprite_accessory/genital/accessory = SSaccessories.sprite_accessories[slot]?[choice]
	if(!istype(accessory) || !accessory.factual || !accessory.icon)
		return list()
	var/list/states = icon_states(accessory.icon)
	var/list/result = list()
	var/suffix = cyborg_dynamic_accessory_suffix(slot, accessory, cyborg_accessory_effective_size(slot, choice, sprite_size), arousal)
	for(var/layer in SSaccessories.all_layer_postfixes)
		var/base_state = "m_[slot]_[suffix]_[layer]"
		if(base_state in states)
			if(accessory.color_src)
				result |= 1
			continue
		for(var/index in 1 to 3)
			var/channel = list("primary", "secondary", "tertiary")[index]
			if("[base_state]_[channel]" in states)
				result |= index
	return result

/proc/cyborg_accessory_metadata(slot, choice, list/colors, arousal, direction, requested_size = 1, include_icons = TRUE)
	var/list/result = list("sizes" = list(), "color_channels" = cyborg_accessory_color_channels(slot, choice, requested_size, arousal), "effective_size" = cyborg_accessory_effective_size(slot, choice, requested_size))
	var/list/size_values = cyborg_accessory_size_values(slot, choice)
	for(var/sprite_size in size_values)
		var/list/size_entry = list("value" = sprite_size, "label" = "Size [sprite_size]")
		var/list/rendered = include_icons ? cyborg_accessory_render(slot, choice, colors, arousal, direction, sprite_size) : null
		if(rendered)
			size_entry["icon"] = rendered["base64"]
		result["sizes"] += list(size_entry)
	return result

/proc/cyborg_accessory_render(slot, choice, list/colors, arousal, direction, sprite_size = 1)
	var/static/list/cache = list()
	var/static/list/states_by_icon = list()
	var/static/cache_bytes = 0
	var/effective_size = cyborg_accessory_effective_size(slot, choice, cyborg_layout_sprite_size(sprite_size, slot))
	var/cache_key = "[slot]|[choice]|[json_encode(colors)]|[arousal]|[direction]|[effective_size]"
	if(cache[cache_key])
		return cache[cache_key]
	var/list/direct_catalog = cyborg_direct_accessories(slot)
	var/list/direct = direct_catalog[choice]
	if(direct)
		return cyborg_direct_accessory_render(direct, colors, arousal, direction, effective_size)
	var/datum/sprite_accessory/genital/accessory = SSaccessories.sprite_accessories[slot]?[choice]
	if(!istype(accessory) || !accessory.factual || !accessory.icon)
		return null
	var/suffix = cyborg_dynamic_accessory_suffix(slot, accessory, effective_size, arousal)
	var/list/states = states_by_icon[accessory.icon]
	if(!states)
		states = icon_states(accessory.icon)
		states_by_icon[accessory.icon] = states
	var/icon/composite = icon('icons/blanks/32x32.dmi', "nothing")
	var/found = FALSE
	for(var/layer in SSaccessories.all_layer_postfixes)
		var/base_state = "m_[slot]_[suffix]_[layer]"
		if(base_state in states)
			var/icon/plain = icon(accessory.icon, base_state, direction, 1)
			if(accessory.color_src)
				plain.Blend(colors[1] || "#ffffff", ICON_MULTIPLY)
			composite.Blend(plain, ICON_OVERLAY)
			found = TRUE
		else
			var/index = 0
			for(var/channel in list("primary", "secondary", "tertiary"))
				index++
				if(!("[base_state]_[channel]" in states))
					continue
				var/icon/colored = icon(accessory.icon, "[base_state]_[channel]", direction, 1)
				colored.Blend(colors[index] || "#ffffff", ICON_MULTIPLY)
				composite.Blend(colored, ICON_OVERLAY)
				found = TRUE
	if(!found)
		return null
	var/base64 = icon2base64(composite)
	// At most 128 32x32 images and 2 MiB of encoded payload plus native icon estimates.
	var/bytes = length(base64) + 32 * 32 * 4
	while(length(cache) && (length(cache) >= 128 || cache_bytes + bytes > 2097152))
		var/list/old = cache[cache[1]]
		cache_bytes -= old["bytes"]
		cache.Cut(1, 2)
	var/list/result = list("icon" = composite, "base64" = base64, "bytes" = bytes)
	cache[cache_key] = result
	cache_bytes += bytes
	return result
