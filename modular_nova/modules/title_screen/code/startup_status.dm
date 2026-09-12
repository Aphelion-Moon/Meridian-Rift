/// Display name of the subsystem currently initializing, used by the lobby prompt.
/datum/controller/subsystem/title/var/startup_subsystem_name

/// Subsystem types marked ready after their master initialization has returned.
/// Track completion separately: SSatoms also uses initialized as a map-loading mode.
/datum/controller/subsystem/title/var/list/startup_completed_subsystems = list()

/// Count completed initializers, including those that do not print a message.
/datum/controller/subsystem/title/proc/get_startup_status()
	var/initialized_subsystems = 0
	var/total_subsystems = 0
	for(var/datum/controller/subsystem/subsystem as anything in Master.subsystems)
		if(subsystem.ss_flags & SS_NO_INIT)
			continue
		total_subsystems++
		if(subsystem.type in startup_completed_subsystems)
			initialized_subsystems++
	return list(
		"initializedSubsystems" = initialized_subsystems,
		"totalSubsystems" = total_subsystems,
		"startupSubsystem" = startup_subsystem_name,
	)

/// Status updates also occur when an initializer is silent or still running.
/datum/controller/subsystem/title/proc/send_startup_status()
	if(!length(GLOB.lobby_menus))
		return
	var/list/status = get_startup_status()
	for(var/datum/lobby_menu/menu as anything in GLOB.lobby_menus)
		menu.send_update(status)

/// Wrap the upstream proc so startup presentation stays owned by the lobby module.
/datum/controller/master/init_subsystem(datum/controller/subsystem/subsystem)
	if(subsystem.ss_flags & SS_NO_INIT)
		return ..()

	var/previous_startup_subsystem_name = SStitle.startup_subsystem_name
	if(!subsystem.initialized)
		SStitle.startup_completed_subsystems -= subsystem.type
		SStitle.startup_subsystem_name = subsystem.name
		SStitle.send_startup_status()
	. = ..()
	if(subsystem.initialized)
		SStitle.startup_completed_subsystems |= subsystem.type
	SStitle.startup_subsystem_name = previous_startup_subsystem_name
	SStitle.send_startup_status()
