/// Kills the player-facing import. Off by default, the verb wants the whitelist role anyway.
/datum/config_entry/flag/forbid_preferences_import
	default = FALSE

/// Seconds a player waits between attempts.
/datum/config_entry/number/seconds_cooldown_for_preferences_import
	default = 300
	min_val = 30

/// How many rotating .playerimportbac backups do we keep per player? Staff/legacy .importbac files are retained separately.
/datum/config_entry/number/preferences_import_backup_limit
	default = 5
	min_val = 1
