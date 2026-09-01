/datum/latejoin_menu/ui_data(mob/user)
	. = ..()
	var/datum/security_level/current_level = SSsecurity_level.current_security_level
	var/level_name = current_level?.name || "green"
	var/level_color = current_level?.announcement_color || "green"

	.["alert_level"] = list("name" = capitalize(level_name), "color" = level_color)
