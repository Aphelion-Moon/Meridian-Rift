/** PDA access to the user's authenticated savings, independent of inserted ID cards or device ownership. */
/datum/computer_file/program/persistent_savings
	filename = "ntbanking"
	filedesc = "NT Banking"
	extended_desc = "Manage your current and offshore accounts, review payments, and check settlement terms."
	downloader_category = PROGRAM_CATEGORY_DEVICE
	program_open_overlay = "generic"
	program_icon = "piggy-bank"
	size = 2
	tgui_id = "PersistentSavings"
	/// Stateless shared controller; account identity is resolved separately for every user and action.
	var/static/datum/savings_panel/savings_controller = new

/datum/computer_file/program/persistent_savings/ui_data(mob/user)
	return savings_controller.ui_data(user)

/datum/computer_file/program/persistent_savings/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(computer?.active_program != src || !computer.enabled)
		return FALSE
	return savings_controller.handle_action(ui.user, action, params)
