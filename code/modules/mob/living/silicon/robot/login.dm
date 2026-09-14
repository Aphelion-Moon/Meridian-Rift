
/mob/living/silicon/robot/Login()
	. = ..()
	if(!. || !client)
		return FALSE
	regenerate_icons()
	apply_cyborg_customization(src, client.prefs, "login")
	show_laws(0)
