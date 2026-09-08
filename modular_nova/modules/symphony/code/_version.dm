/// What this module can do, in one number. Bump with SSymphony's EXPECTED_GAME_MODULE.
#define SYMPHONY_MODULE_VERSION 9

/// Which half is behind, if either. needs/wants are what the panel asked for.
/proc/symphony_version_verdict(needs, wants)
	if(needs && SYMPHONY_MODULE_VERSION < needs)
		return span_warning("This module is older than the panel needs ([needs]+). Update it and recompile.")
	if(wants && SYMPHONY_MODULE_VERSION > wants)
		return span_warning("The panel is older than this module (built for [wants]). Update SSymphony.")
	// Meeting the minimum is compatible, even when the panel targets a newer module.
	if(wants && SYMPHONY_MODULE_VERSION < wants)
		return "Behind the [wants] the panel was built for, but new enough for it."
	return "Both halves match."
