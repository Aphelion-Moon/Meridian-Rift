PROCESSING_SUBSYSTEM_DEF(greyscale)
	name = "Greyscale"
	ss_flags = SS_BACKGROUND
	wait = 3 SECONDS
	init_stage = INITSTAGE_EARLY
	var/list/datum/greyscale_config/configurations = list()
	var/list/datum/greyscale_layer/layer_types = list()
#ifdef USE_RUSTG_ICONFORGE_GAGS
	/// Cache containing a list of [UID (config path + colors)] -> [DMI file / RSC object] in the tmp directory from iconforge
	var/list/gags_cache = list()
#endif

/datum/controller/subsystem/processing/greyscale/Initialize()
	for(var/datum/greyscale_layer/greyscale_layer as anything in subtypesof(/datum/greyscale_layer))
		layer_types[initial(greyscale_layer.layer_type)] = greyscale_layer

	for(var/greyscale_type in subtypesof(/datum/greyscale_config))
		var/datum/greyscale_config/config = new greyscale_type()
		configurations["[greyscale_type]"] = config

	// We do this after all the types have been loaded into the listing so reference layers don't care about init order
	for(var/greyscale_type in configurations)
		CHECK_TICK
		var/datum/greyscale_config/config = configurations[greyscale_type]
		config.Refresh()

#ifdef USE_RUSTG_ICONFORGE_GAGS
	var/list/job_ids = list()
#endif

	// This final verification step is for things that need other greyscale configurations to be finished loading
	for(var/greyscale_type in configurations)
		CHECK_TICK
		var/datum/greyscale_config/config = configurations[greyscale_type]
		config.CrossVerify()
#ifdef USE_RUSTG_ICONFORGE_GAGS
		job_ids += rustg_iconforge_load_gags_config_async(greyscale_type, config.raw_json_string, config.string_icon_file)
		// APHELION EDIT ADDITION START - DOGMOS
		// rust-g starts one thread per job; bound in-flight jobs so 32-bit DreamDaemon keeps address space for Dogmos.
		if(length(job_ids) >= 32)
			UNTIL(jobs_completed(job_ids))
		// APHELION EDIT ADDITION END

	UNTIL(jobs_completed(job_ids))
#endif

	return SS_INIT_SUCCESS

#ifdef USE_RUSTG_ICONFORGE_GAGS
/datum/controller/subsystem/processing/greyscale/proc/jobs_completed(list/job_ids)
	for(var/job in job_ids)
		var/result = rustg_iconforge_check(job)
		if(result == RUSTG_JOB_NO_RESULTS_YET)
			return FALSE
		if(result != "OK")
			stack_trace("Error during rustg_iconforge_load_gags_config job: [result]")
		job_ids -= job
	return TRUE
#endif

/datum/controller/subsystem/processing/greyscale/proc/RefreshConfigsFromFile()
	for(var/i in configurations)
		configurations[i].Refresh(TRUE)

/datum/controller/subsystem/processing/greyscale/proc/GetColoredIconByType(type, list/colors)
	if(!ispath(type, /datum/greyscale_config))
		CRASH("An invalid greyscale configuration was given to `GetColoredIconByType()`: [type]")
	if(!initialized)
		CRASH("GetColoredIconByType() called before greyscale subsystem initialized!")
	type = "[type]"
	if(istype(colors)) // It's the color list format
		colors = colors.Join()
	else if(!istext(colors))
		CRASH("Invalid colors were given to `GetColoredIconByType()`: [colors]")
#ifdef USE_RUSTG_ICONFORGE_GAGS
	var/uid = "[replacetext(replacetext(type, "/datum/greyscale_config/", ""), "/", "-")]-[colors]"
	var/cached_file = gags_cache[uid]
	if(cached_file)
		return cached_file
	var/output_path = "tmp/gags/icons/gags-[uid].dmi"
	var/iconforge_output = rustg_iconforge_gags(type, colors, output_path)
	// Handle errors from IconForge
	if(iconforge_output != "OK")
		CRASH(iconforge_output)
	// We'll just explicitly do fcopy_rsc here, so the game doesn't have to do it again later from the cached file.
	var/rsc_gags_icon = fcopy_rsc(file(output_path))
	gags_cache[uid] = rsc_gags_icon
	return rsc_gags_icon
#else
	return configurations[type].Generate(colors)
#endif

/datum/controller/subsystem/processing/greyscale/proc/GetColoredIconByTypeUniversalIcon(type, list/colors, target_icon_state)
	if(!ispath(type, /datum/greyscale_config))
		CRASH("An invalid greyscale configuration was given to `GetColoredIconByTypeUniversalIcon()`: [type]")
	type = "[type]"
	if(istype(colors)) // It's the color list format
		colors = colors.Join()
	else if(!istext(colors))
		CRASH("Invalid colors were given to `GetColoredIconByTypeUniversalIcon()`: [colors]")
	return configurations[type].GenerateUniversalIcon(colors, target_icon_state)

/datum/controller/subsystem/processing/greyscale/proc/ParseColorString(color_string)
	. = list()
	var/list/split_colors = splittext(color_string, "#")
	for(var/color in 2 to length(split_colors))
		. += "#[split_colors[color]]"

// APHELION EDIT ADDITION START - Read-only provenance check for the bulge cloth sampler.
/// Verifies the existing compiled-config Rust output. Never creates or repairs a cache entry.
/// Kept before the local macro's undef, so this query reads the producer the subsystem uses.
/datum/controller/subsystem/processing/greyscale/proc/bulge_cached_output_matches(config_type, colors, current_output)
	if(!initialized || !ispath(config_type, /datum/greyscale_config) || !isfile(current_output))
		return FALSE
	if(islist(colors))
		var/list/color_list = colors
		colors = color_list.Join()
	else if(!istext(colors))
		return FALSE
	var/datum/greyscale_config/config = configurations["[config_type]"]
	if(!config)
		return FALSE
	if(!isnull(config.json_config_hash) || !isnull(config.icon_file_hash))
		// Refreshed from disk (an admin's live editing, RefreshConfigsFromFile()): its layers read the files on disk now,
		// while its garments' iconforge outputs stay those of the compiled files. Trusted while both files on disk are
		// the compiled ones. Refresh() records the json's hash, read from its path, but an empty one for the icon (it
		// hands rust-g the icon as a file object), so the icon is hashed here, from its path. Asked only on a look's full
		// resolve, and only after such a refresh.
		if(config.json_config_hash != md5(initial(config.json_config)) || rustg_hash_file(RUSTG_HASH_MD5, config.string_icon_file) != md5(initial(config.icon_file)))
			return FALSE
#ifdef USE_RUSTG_ICONFORGE_GAGS
	var/type_text = "[config_type]"
	var/uid = "[replacetext(replacetext(type_text, "/datum/greyscale_config/", ""), "/", "-")]-[colors]"
	var/cached_output = gags_cache[uid]
	return !isnull(cached_output) && cached_output == current_output
#else
	// Legacy Generate returns icon(cached_resource), a fresh mutable copy. Equality cannot prove that copy's origin.
	return FALSE
#endif

// APHELION EDIT ADDITION END
#undef USE_RUSTG_ICONFORGE_GAGS
