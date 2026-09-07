/// Enables whitelist enforcement, role perks, and eligible Discord admin sync. Topics remain available.
/datum/config_entry/flag/symphony_enabled

/// Where the panel lives, e.g. https://symphony.example.com
/datum/config_entry/string/symphony_url

/// Seconds before returning an unwhitelisted player to the lobby.
/// Keep the cap below SSsymphony's five-minute sweep so repeated sweeps cannot postpone enforcement indefinitely.
/datum/config_entry/number/symphony_grace_seconds
	default = 30
	integer = TRUE
	min_val = 0
	max_val = 240

/// Allows Discord role mappings to grant in-game admin ranks. Also requires symphony_enabled.
/datum/config_entry/flag/symphony_discord_admin_sync
	default = FALSE

/// Only take Symphony topics from addresses we trust, so a leaked comms key isn't enough on its own.
/datum/config_entry/flag/symphony_topics_local_only
	default = FALSE

/// Extra addresses the gate lets through, one per line. Loopback is always fine, so a single box leaves this empty.
/datum/config_entry/str_list/symphony_topics_allowed_addresses
