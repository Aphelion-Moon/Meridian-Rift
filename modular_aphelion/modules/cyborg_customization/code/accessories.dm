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

/// Whether a genital accessory has art at this size, in any layer or color channel
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

/// Returns the sizes an accessory has art for, cached by slot and choice. The caller gets its own copy
/proc/cyborg_accessory_size_values(slot, choice)
	var/static/list/size_cache = list()
	var/cache_key = "[slot]|[choice]"
	var/list/cached_sizes = size_cache[cache_key]
	if(cached_sizes)
		return cached_sizes.Copy()
	var/list/direct = cyborg_direct_accessories(slot)?[choice]
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

/// Returns the requested size when the accessory has art for it, or else the first size it has
/proc/cyborg_accessory_effective_size(slot, choice, requested)
	var/list/values = cyborg_accessory_size_values(slot, choice)
	if(requested in values)
		return requested
	return length(values) ? values[1] : cyborg_layout_default_sprite_size(slot)

/// Returns the color channels an accessory's art uses at this size and arousal state, by channel number
/proc/cyborg_accessory_color_channels(slot, choice, sprite_size = 1, arousal = "none")
	var/list/direct = cyborg_direct_accessories(slot)?[choice]
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

/// Returns what the editor shows for a part's sprite - its color channels and its sizes, with a thumbnail of each unless include_icons is off
/proc/cyborg_accessory_metadata(slot, choice, list/colors, arousal, direction, requested_size = 1, include_icons = TRUE)
	var/list/result = list("sizes" = list(), "color_channels" = cyborg_accessory_color_channels(slot, choice, requested_size, arousal))
	var/list/size_values = cyborg_accessory_size_values(slot, choice)
	for(var/sprite_size in size_values)
		var/list/size_entry = list("value" = sprite_size, "label" = "Size [sprite_size]")
		var/list/rendered = include_icons ? cyborg_accessory_render(slot, choice, colors, arousal, direction, sprite_size) : null
		if(rendered)
			size_entry["icon"] = rendered["base64"]
		result["sizes"] += list(size_entry)
	return result

/// Returns a part's colored art as an icon and its base64, or null when it has none. Cached, up to 128 images and 2 MiB
/proc/cyborg_accessory_render(slot, choice, list/colors, arousal, direction, sprite_size = 1)
	var/static/list/cache = list()
	var/static/list/states_by_icon = list()
	var/static/cache_bytes = 0
	var/effective_size = cyborg_accessory_effective_size(slot, choice, cyborg_layout_sprite_size(sprite_size, slot))
	var/list/direct = cyborg_direct_accessories(slot)?[choice]
	if(direct)
		return cyborg_direct_accessory_render(direct, colors, arousal, direction, effective_size)
	var/cache_key = "[slot]|[choice]|[colors.Join(",")]|[arousal]|[direction]|[effective_size]"
	if(cache[cache_key])
		return cache[cache_key]
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

/// The silicon-only accessories of a slot by name, null for a slot without any - these donor sheets never enter human accessory selection
/proc/cyborg_direct_accessories(slot)
	var/static/list/catalog = list(
		"penis" = list(
			"Dogborg Knotted" = list("icon" = 'modular_aphelion/modules/cyborg_customization/icons/accessories/penis_dogborg_onmob.dmi', "state" = "m_penis_knotted_SIZE_AROUSAL_FRONT", "channels" = list("primary"), "sizes" = list(1, 2, 3, 4, 5, 6, 7)),
			"Dogborg Massive" = list("icon" = 'modular_aphelion/modules/cyborg_customization/icons/accessories/massive_dogborg_cock.dmi', "state" = "massive_cock", "sizes" = list(1)),
		),
		"sheath" = list("Dogborg Knotted Sheath" = list("icon" = 'modular_aphelion/modules/cyborg_customization/icons/accessories/penis_dogborg_onmob.dmi', "state" = "m_penis_knotted_sheeth_SIZE_0_FRONT", "channels" = list("UNDER_primary", "UNDER_secondary", "OVER_primary"), "sizes" = list(1, 2, 3, 4, 5, 6, 7, 9))),
		"testicles" = list(
			"Dogborg Sheathed Pair" = list("icon" = 'modular_aphelion/modules/cyborg_customization/icons/accessories/testicles_dogborg_onmob.dmi', "state" = "m_testicles_sheath_SIZE", "channels" = list("PRIMARY", "SECONDARY"), "sizes" = list(1, 2, 3, 4, 5, 6, 7, 8)),
			"Dogborg Pair" = list("icon" = 'modular_aphelion/modules/cyborg_customization/icons/accessories/testicles_dogborg_onmob.dmi', "state" = "m_testicles_SIZE", "channels" = list("PRIMARY", "SECONDARY"), "sizes" = list(1, 2, 3, 4, 5, 6, 7, 8)),
			"Dogborg Pair (Alt)" = list("icon" = 'modular_aphelion/modules/cyborg_customization/icons/accessories/testicles_dogborg_onmob.dmi', "state" = "m_testicles_alt_SIZE", "channels" = list("PRIMARY", "SECONDARY"), "sizes" = list(1, 2, 3, 4, 5, 6, 7, 8)),
			"Dogborg Sheathed Pair (Alt)" = list("icon" = 'modular_aphelion/modules/cyborg_customization/icons/accessories/testicles_dogborg_onmob.dmi', "state" = "m_testicles_sheath_alt_SIZE", "channels" = list("PRIMARY", "SECONDARY"), "sizes" = list(1, 2, 3, 4, 5, 6, 7, 8, 9)),
		),
		"anus" = list(
			"Donut" = list("icon" = 'modular_aphelion/modules/cyborg_customization/icons/accessories/anus.dmi', "state" = "m_anus_donut_SIZE_FRONT", "channels" = list("primary"), "sizes" = list(1, 2, 3, 4, 5, 6, 7, 8)),
			"Squished" = list("icon" = 'modular_aphelion/modules/cyborg_customization/icons/accessories/anus.dmi', "state" = "m_anus_squished_SIZE_FRONT", "channels" = list("primary"), "sizes" = list(1, 2, 3, 4, 5, 6, 7, 8)),
		),
	)
	return catalog[slot]

/// Returns a silicon-only accessory's colored art as an icon and its base64, or null when it has none. Keeps the last 32
/proc/cyborg_direct_accessory_render(list/descriptor, list/colors, arousal, direction, sprite_size = 1)
	var/static/list/cache = list()
	var/static/list/states_by_icon = list()
	var/cache_key = "[descriptor["icon"]]|[descriptor["state"]]|[colors.Join(",")]|[arousal]|[direction]|[sprite_size]"
	if(cache[cache_key])
		return cache[cache_key]
	// Worst case: 32 native 128x64 RGBA frames, at most 1 MiB before engine overhead.
	if(length(cache) >= 32)
		cache.Cut(1, 2)
	var/state = replacetext(descriptor["state"], "SIZE", "[sprite_size]")
	state = replacetext(state, "AROUSAL", arousal == "full" ? "2" : (arousal == "partial" ? "1" : "0"))
	var/list/states = states_by_icon[descriptor["icon"]]
	if(!states)
		states = icon_states(descriptor["icon"])
		states_by_icon[descriptor["icon"]] = states
	var/list/channels = descriptor["channels"]
	if(!channels)
		if(!(state in states))
			return null
		var/icon/plain = icon(descriptor["icon"], state, direction, 1)
		plain.Blend(colors[1] || "#ffffff", ICON_MULTIPLY)
		cache[cache_key] = list("icon" = plain, "base64" = icon2base64(plain))
		return cache[cache_key]
	var/icon/result = icon('icons/blanks/32x32.dmi', "nothing")
	var/index = 0
	var/found = FALSE
	for(var/channel in channels)
		index++
		if(!("[state]_[channel]" in states))
			continue
		var/icon/part = icon(descriptor["icon"], "[state]_[channel]", direction, 1)
		part.Blend(colors[index] || "#ffffff", ICON_MULTIPLY)
		result.Blend(part, ICON_OVERLAY)
		found = TRUE
	if(!found)
		return null
	cache[cache_key] = list("icon" = result, "base64" = icon2base64(result))
	return cache[cache_key]
