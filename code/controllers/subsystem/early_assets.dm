/// Initializes any assets that need to be loaded ASAP.
/// This houses preference menu assets, since they can be loaded at any time,
/// most dangerously before the atoms SS initializes.
/// Thus, we want it to fail consistently in CI as if it would've if a player
/// opened it up early.
SUBSYSTEM_DEF(early_assets)
	name = "Early Assets"
	dependencies = list(
		/datum/controller/subsystem/processing/reagents,
		/datum/controller/subsystem/greyscale_previews,
	)
	dependents = list(
		/datum/controller/subsystem/mapping,
		/datum/controller/subsystem/atoms,
	)
	init_stage = INITSTAGE_EARLY
	ss_flags = SS_NO_FIRE

/datum/controller/subsystem/early_assets/Initialize()
	var/init_source = "early assets"
	SSatoms.set_tracked_initalized(INITIALIZATION_INNEW_REGULAR, init_source)

	for (var/datum/asset/asset_type as anything in valid_subtypesof(/datum/asset))
		if (!initial(asset_type.early))
			continue

		if (!load_early_asset(asset_type)) // APHELION EDIT CHANGE - join required asynchronous early assets
			stack_trace("Could not initialize early asset [asset_type]!")

		CHECK_TICK

	SSatoms.clear_tracked_initalize(init_source)

	return SS_INIT_SUCCESS

// APHELION EDIT ADDITION START - required early asset readiness barrier
/// A preference request may have already published an asset datum whose register
/// is still asleep. Required early resources must finish before this SS does.
/datum/controller/subsystem/early_assets/proc/load_early_asset(asset_type)
	var/datum/asset/asset = load_asset_datum(asset_type)
	if(asset?.early_blocking)
		asset.ensure_ready()
	return asset
// APHELION EDIT ADDITION END
