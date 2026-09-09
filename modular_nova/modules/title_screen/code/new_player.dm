/mob/dead/new_player/Login()
	. = ..()
	show_title_screen()

/**
 * Shows the lobby menu to a new player. the lobby menu itself
 * already knows how to show/hide based on the client's mob type
 * (see /datum/lobby_menu/proc/update_visibility).
 */
/mob/dead/new_player/proc/show_title_screen()
	if(isnull(client))
		return
	if(client.interviewee)
		return

	client.lobby_menu?.update_visibility()

/**
 * Removes the lobby menu entirely from a mob.
 */
/mob/dead/new_player/proc/hide_title_screen()
	client?.lobby_menu?.update_visibility()

/mob/dead/new_player/proc/play_lobby_button_sound()
	SEND_SOUND(src, sound('modular_nova/master_files/sound/effects/save.ogg'))

/**
 * Allows the player to select a server to join from any loaded servers.
 */
/mob/dead/new_player/proc/server_swap()
	var/list/servers = CONFIG_GET(keyed_list/cross_server)
	if(LAZYLEN(servers) == 1)
		var/server_name = servers[1]
		var/server_ip = servers[server_name]
		var/confirm = tgui_alert(src, "Are you sure you want to swap to [server_name] ([server_ip])?", "Swapping server!", list("Send me there", "Stay here"))
		if(confirm == "Connect me!")
			to_chat_immediate(src, "So long, spaceman.")
			client << link(server_ip)
		return
	var/server_name = tgui_input_list(src, "Please select the server you wish to swap to:", "Swap servers!", servers)
	if(!server_name)
		return
	var/server_ip = servers[server_name]
	var/confirm = tgui_alert(src, "Are you sure you want to swap to [server_name] ([server_ip])?", "Swapping server!", list("Connect me!", "Stay here!"))
	if(confirm == "Connect me!")
		to_chat_immediate(src, "So long, spaceman.")
		src.client << link(server_ip)
