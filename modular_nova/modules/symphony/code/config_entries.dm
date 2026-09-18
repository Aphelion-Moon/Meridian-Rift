/// Enables whitelist enforcement, role perks, and eligible Discord admin sync. Topics remain available.
/datum/config_entry/flag/symphony_enabled

/datum/config_entry/flag/symphony_enabled/set_default()
	. = ..()
	SSsymphony.enabled = config_entry_value

/datum/config_entry/flag/symphony_enabled/ValidateAndSet(str_val)
	. = ..()
	if(.)
		SSsymphony.enabled = config_entry_value

/// Where the panel lives, e.g. https://symphony.example.com
/datum/config_entry/string/symphony_url

/datum/config_entry/string/symphony_url/set_default()
	. = ..()
	SSsymphony.url = config_entry_value

/datum/config_entry/string/symphony_url/ValidateAndSet(str_val)
	. = ..()
	if(.)
		SSsymphony.url = config_entry_value

/// Seconds before returning an unwhitelisted player to the lobby.
/// Keep the cap below SSsymphony's five-minute sweep so repeated sweeps cannot postpone enforcement indefinitely.
/datum/config_entry/number/symphony_grace_seconds
	default = 30
	integer = TRUE
	min_val = 0
	max_val = 240

/datum/config_entry/number/symphony_grace_seconds/set_default()
	. = ..()
	SSsymphony.grace_seconds = config_entry_value

/datum/config_entry/number/symphony_grace_seconds/ValidateAndSet(str_val)
	. = ..()
	if(.)
		SSsymphony.grace_seconds = config_entry_value

/// Allows Discord role mappings to grant in-game admin ranks. Also requires symphony_enabled.
/datum/config_entry/flag/symphony_discord_admin_sync

/datum/config_entry/flag/symphony_discord_admin_sync/set_default()
	. = ..()
	SSsymphony.discord_admin_sync = config_entry_value

/datum/config_entry/flag/symphony_discord_admin_sync/ValidateAndSet(str_val)
	. = ..()
	if(.)
		SSsymphony.discord_admin_sync = config_entry_value

/// Only take Symphony topics from addresses we trust, so a leaked comms key isn't enough on its own.
/datum/config_entry/flag/symphony_topics_local_only

/datum/config_entry/flag/symphony_topics_local_only/set_default()
	. = ..()
	SSsymphony.topics_local_only = config_entry_value

/datum/config_entry/flag/symphony_topics_local_only/ValidateAndSet(str_val)
	. = ..()
	if(.)
		SSsymphony.topics_local_only = config_entry_value

/// Extra addresses the gate lets through, one per line. Loopback is always fine, so a single box leaves this empty.
/datum/config_entry/str_list/symphony_topics_allowed_addresses

/datum/config_entry/str_list/symphony_topics_allowed_addresses/set_default()
	. = ..()
	SSsymphony.topics_allowed_addresses = config_entry_value

/datum/config_entry/str_list/symphony_topics_allowed_addresses/ValidateAndSet(str_val)
	. = ..()
	if(.)
		SSsymphony.topics_allowed_addresses = config_entry_value

// Shared config entries keep their existing validation and protection.
/datum/config_entry/string/servername/set_default()
	. = ..()
	SSsymphony.server_name = config_entry_value

/datum/config_entry/string/servername/ValidateAndSet(str_val)
	. = ..()
	if(.)
		SSsymphony.server_name = config_entry_value

/datum/config_entry/string/banappeals/set_default()
	. = ..()
	SSsymphony.ban_appeals = config_entry_value

/datum/config_entry/string/banappeals/ValidateAndSet(str_val)
	. = ..()
	if(.)
		SSsymphony.ban_appeals = config_entry_value

/datum/config_entry/flag/admin_legacy_system/set_default()
	. = ..()
	SSsymphony.admin_legacy_system = config_entry_value

/datum/config_entry/flag/admin_legacy_system/ValidateAndSet(str_val)
	. = ..()
	if(.)
		SSsymphony.admin_legacy_system = config_entry_value

/datum/config_entry/string/comms_key/set_default()
	. = ..()
	SSsymphony.comms_key_set = !!config_entry_value
