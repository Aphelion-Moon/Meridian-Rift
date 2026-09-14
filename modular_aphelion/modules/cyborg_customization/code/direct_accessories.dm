/// Separate silicon catalog: these donor sheets never enter human accessory selection.
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
	return catalog[slot] || list()

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
