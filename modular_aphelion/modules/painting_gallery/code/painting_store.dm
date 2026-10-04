/datum/painting
	/// Explicit permission to publish on the account's public website gallery.
	var/show_in_webgallery = FALSE
	/// Retain fields introduced by other compatible writers.
	var/list/stored_data

/// Retain original fields and accept website consent only when its decoded numeric value is one.
/datum/painting/proc/load_gallery_metadata(list/json_data)
	stored_data = deep_copy_list(json_data)
	show_in_webgallery = isnum(json_data["show_in_webgallery"]) && json_data["show_in_webgallery"] == TRUE

/// Copy preserved metadata so known-field serialization cannot mutate the stored source record.
/datum/painting/proc/gallery_json_base()
	return stored_data ? deep_copy_list(stored_data) : list()

/// Painting persistence has one writer queue. No player dialog is held inside it.
/datum/controller/subsystem/persistent_paintings
	/// Owner UI data is populated on demand and invalidated after committed changes.
	var/list/owner_painting_data
	/// Committed painting datums by MD5; reused so open canvases keep their references.
	var/list/paintings_by_id
	/// Enabled only after the native helper recovers and validates the live store.
	var/store_writable = FALSE
	/// Initialization or recovery failure explaining why painting writes are disabled.
	var/store_error
	/// One queue worker owns mutations until every pending request completes.
	var/store_busy = FALSE
	/// FIFO requests with payload, completion flag, and result; released when drained.
	var/list/store_queue
	/// Live Art Galaxy programs to refresh after gallery or status changes.
	var/list/gallery_programs
	/// Include unframed canvases when checking conflicts with imported identities.
	var/list/pending_canvases
	/// Ckeys with an active confirmation/import flow, shared across devices.
	var/list/nova_import_busy
	/// Latest player-facing import outcome or progress message, keyed by ckey.
	var/list/nova_import_status
	/// Only IDs for accounts offered an import; null means not checked, an empty list means no matches.
	var/list/nova_painting_ids_by_owner

/// Build the common failure envelope used by the DM transaction queue and native calls.
/proc/painting_store_failure(message)
	return list("ok" = FALSE, "error" = list("message" = message))

/// Accept only the lowercase 32-character hexadecimal identities used for painting paths.
/proc/valid_painting_id(value)
	if(!istext(value) || length(value) != 32)
		return FALSE
	var/static/regex/invalid = regex(@"[^a-f0-9]")
	return !invalid.Find(value)

/// Isolated for unit tests; only the native helper resolves filesystem paths.
/datum/controller/subsystem/persistent_paintings/proc/store_call(list/request)
	request["api"] = 1
	var/library = world.system_type == UNIX ? "./libmeridian_painting_store.so" : "meridian_painting_store.dll"
	try
		var/response = call_ext(library, "painting_store_call")(json_encode(request))
		if(!istext(response))
			return painting_store_failure("Painting store returned no response.")
		var/list/result = json_decode(response)
		if(!islist(result))
			return painting_store_failure("Painting store returned an invalid response.")
		return result
	catch(var/exception/error)
		return painting_store_failure("Painting store unavailable: [error]")

/// Poll asynchronous native work cooperatively and release its caller lease after a failed response.
/datum/controller/subsystem/persistent_paintings/proc/store_request(list/request)
	var/list/result = store_call(request)
	var/job = result["job"]
	if(!result["ok"] || !job)
		return result
	// The native worker serializes commits; cancellation never interrupts a running write.
	while(TRUE)
		sleep(1)
		result = store_call(list("op" = "poll", "job" = job))
		if(!result["pending"])
			if(!result["ok"])
				store_call(list("op" = "cancel", "job" = job))
			return result

/// Extract a storage failure message with a safe fallback for incomplete responses.
/datum/controller/subsystem/persistent_paintings/proc/store_result_message(list/result)
	var/list/error = result?["error"]
	return error?["message"] || "The painting could not be saved. Please try again."

/// Recover and migrate through the native helper; failures leave writes disabled and allow intact v3 data to be viewed.
/datum/controller/subsystem/persistent_paintings/proc/initialize_store()
#ifdef AUTOWIKI
	// Wiki generation starts a world but does not use player painting storage.
	store_error = "Painting persistence is disabled during AutoWiki generation."
	return
#else
	var/list/info = store_call(list("op" = "info"))
	if(!info["ok"] || info["api"] != 1)
		store_error = store_result_message(info)
	else
		var/list/result = store_request(list("op" = "snapshot", "source" = "live"))
		if(result["ok"])
			store_writable = TRUE
			var/list/snapshot = result["snapshot"]
			if(snapshot["version"] != PAINTINGS_DATA_FORMAT_VERSION)
				result = run_store_operation("migrate")
				if(!result["ok"])
					store_writable = FALSE
					store_error = store_result_message(result)
					log_game("Painting migration failed; persistence is read-only: [store_error]")
				return
			apply_store_snapshot(snapshot)
			return
		store_error = store_result_message(result)
	log_game("Painting persistence is read-only: [store_error]")
	// A missing dependency must not prevent viewing an intact v3 collection.
	// Recovery failures must not reinterpret a missing/corrupt file as an empty one.
	if(!fexists("data/paintings.json"))
		return
	try
		var/list/snapshot = json_decode(file2text("data/paintings.json"))
		if(snapshot?["version"] == PAINTINGS_DATA_FORMAT_VERSION && islist(snapshot["paintings"]))
			apply_store_snapshot(snapshot)
	catch(var/exception/error)
		log_game("Unable to read existing painting collection: [error]")
#endif

/// Queue a mutation and wait for its result; player dialogs must finish before calling this proc.
/datum/controller/subsystem/persistent_paintings/proc/run_store_operation(kind, list/payload = list())
	if(!store_writable)
		return painting_store_failure(store_error || "Painting persistence is currently read-only.")
	var/list/request = list("kind" = kind, "payload" = payload, "done" = FALSE)
	LAZYADD(store_queue, list(request))
	if(!store_busy)
		store_busy = TRUE
		INVOKE_ASYNC(src, PROC_REF(process_store_queue))
	UNTIL(request["done"])
	return request["result"]

/// Drain mutations serially, report failures, and release temporary files and canvas save guards.
/datum/controller/subsystem/persistent_paintings/proc/process_store_queue()
	while(length(store_queue))
		var/list/request = store_queue[1]
		var/list/result
		try
			result = execute_store_operation(request["kind"], request["payload"])
		catch(var/exception/error)
			result = painting_store_failure("Painting transaction failed: [error]")
		if(!result?["ok"])
			log_game("Painting transaction failed: [store_result_message(result)]")
		var/list/payload = request["payload"]
		var/obj/item/canvas/canvas = payload["canvas"]
		if(!QDELETED(canvas))
			canvas.persistence_saving = FALSE
		for(var/staged_path in payload["stage_files"])
			fdel(staged_path)
		request["result"] = result
		request["done"] = TRUE
		store_queue.Cut(1, 2)
	store_queue = null
	store_busy = FALSE
	refresh_gallery_uis()

/// Rebuild each queued operation against the latest committed bytes, never a stale live-datum dump.
/datum/controller/subsystem/persistent_paintings/proc/execute_store_operation(kind, list/payload)
	var/list/current = store_request(list("op" = "snapshot", "source" = "live"))
	if(!current["ok"])
		return current
	var/list/candidate = current["snapshot"]
	var/list/rows = candidate["paintings"]
	var/list/images = list()
	var/list/deletes = list()
	var/list/changed_fields = list()
	var/datum/painting/archived_painting
	var/list/commit = list("op" = "submit_commit", "expected_sha256" = current["sha256"])
	if(kind == "migrate")
		var/old_version = candidate["version"]
		candidate = update_format(candidate, images)
		if(!candidate)
			return painting_store_failure("Legacy painting migration could not be prepared.")
		if(old_version >= 1)
			for(var/list/row as anything in candidate["paintings"])
				var/list/fields = list("title")
				if(old_version < 2)
					fields += list("frame_type", "tags")
				changed_fields += list(list("id" = row["md5"], "fields" = fields))
	else
		if(candidate["version"] != PAINTINGS_DATA_FORMAT_VERSION || !islist(rows))
			return painting_store_failure("Painting database needs a supported migration.")
		var/list/by_id = list()
		for(var/list/row as anything in rows)
			by_id[row["md5"]] = row
		switch(kind)
			if("patch", "delete")
				var/id = payload["id"]
				var/list/row = by_id[id]
				if(!row || (id in deleted_paintings_md5s))
					return painting_store_failure("That painting is no longer available.")
				if(payload["owner"] && row["creator_ckey"] != payload["owner"])
					return painting_store_failure("You can only manage your own paintings.")
				var/list/expected = payload["expected"]
				for(var/field in expected)
					if(row[field] != expected[field])
						return painting_store_failure("That painting changed. Please try again.")
				if(kind == "delete")
					rows -= list(row)
					deletes += id
				else
					var/list/patch = payload["patch"]
					var/list/fields = list()
					for(var/field in patch)
						row[field] = patch[field]
						fields += field
					if(payload["add_tag"] || payload["remove_tag"])
						var/list/tags = row["tags"]
						tags = islist(tags) ? tags.Copy() : list()
						if(payload["add_tag"])
							tags |= payload["add_tag"]
						if(payload["remove_tag"])
							tags -= payload["remove_tag"]
						row["tags"] = tags
						fields |= "tags"
					changed_fields += list(list("id" = id, "fields" = fields))
			if("archive")
				var/obj/item/canvas/canvas = payload["canvas"]
				if(QDELETED(canvas) || !canvas.finalized || canvas.finalizing || (canvas.no_save && !canvas.painting_metadata.loaded_from_json))
					return list("ok" = TRUE, "changed" = FALSE)
				var/tag = payload["tag"]
				if(tag)
					var/obj/structure/sign/painting/frame = canvas.loc
					if(!istype(frame) || frame.current_canvas != canvas || frame.persistence_id != tag || SANITIZE_FILENAME(tag) != tag)
						return painting_store_failure("The painting is no longer in that archive frame.")
				var/pixels = canvas.painting_metadata.loaded_from_json ? null : canvas.get_data_string()
				var/id = canvas.painting_metadata.loaded_from_json ? canvas.painting_metadata.md5 : md5(LOWER_TEXT(pixels))
				if(id in deleted_paintings_md5s)
					return painting_store_failure("That painting was deleted this round.")
				var/list/row = by_id[id]
				if(row)
					// Only a known saved canvas may join another rotation; duplicate originals never take ownership.
					if(!canvas.painting_metadata.loaded_from_json || row["creator_ckey"] != canvas.painting_metadata.creator_ckey || !tag)
						return list("ok" = TRUE, "changed" = FALSE)
					var/list/tags = row["tags"]
					if(tag in tags)
						return list("ok" = TRUE, "changed" = FALSE)
					row["tags"] = (islist(tags) ? tags.Copy() : list()) | list(tag)
					changed_fields += list(list("id" = id, "fields" = list("tags")))
				else
					if(canvas.painting_metadata.loaded_from_json || fexists("data/paintings/images/[id].png"))
						return painting_store_failure("The saved painting is missing or its image identity is already in use.")
					archived_painting = canvas.painting_metadata
					canvas.persistence_saving = TRUE
					row = archived_painting.to_json()
					row["md5"] = id
					row["tags"] = tag ? list(tag) : list()
					var/stage = md5("[world.realtime]-[REF(canvas)]-[rand(1, 1e9)]")
					var/png = "data/paintings/staging/[stage]/[id].png"
					// rust-g creates PNGs in an existing directory.
					var/marker = "data/paintings/staging/[stage]/.owner"
					payload["stage_files"] = list(png, marker)
					if(rustg_file_write(stage, marker))
						return painting_store_failure("Unable to create painting staging directory.")
					var/error = rustg_dmi_create_png(png, "[canvas.width]", "[canvas.height]", pixels)
					if(error)
						return painting_store_failure("Unable to stage painting image: [error]")
					images += list(list("id" = id, "source" = "staged", "stage" = stage))
					rows += list(row)
			if("import")
				var/list/source = payload["snapshot"]
				var/list/source_rows = source["paintings"]
				var/list/pending_ids = pending_canvas_ids()
				for(var/list/source_row as anything in source_rows)
					if(source_row["creator_ckey"] != payload["owner"])
						continue
					var/id = source_row["md5"]
					if(by_id[id] || (id in pending_ids) || (id in deleted_paintings_md5s) || fexists("data/paintings/images/[id].png"))
						continue
					var/list/row = deep_copy_list(source_row)
					row["show_in_webgallery"] = payload["public"] == TRUE ? TRUE : FALSE
					rows += list(row)
					by_id[id] = row
					images += list(list("id" = id, "source" = "nova"))
				if(!length(images))
					return list("ok" = TRUE, "changed" = FALSE, "imported" = 0)
				commit["nova_sha256"] = payload["sha256"]
			if("sync")
				apply_store_snapshot(candidate)
				return list("ok" = TRUE, "changed" = FALSE)
			else
				return painting_store_failure("Unknown painting operation.")
	commit["candidate"] = candidate
	commit["images"] = images
	commit["deletes"] = deletes
	commit["changed_fields"] = changed_fields
	var/list/result = store_request(commit)
	if(!result["ok"])
		return result
	if(result["cleanup_pending"])
		log_game("Painting transaction committed; cleanup will retry: [result["warning"]]")
	if(kind == "delete")
		deleted_paintings_md5s |= payload["id"]
		remove_deleted_painting_frames(payload["id"])
	if(archived_painting)
		archived_painting.md5 = images[1]["id"]
		LAZYSET(paintings_by_id, archived_painting.md5, archived_painting)
	apply_store_snapshot(result["snapshot"] || candidate)
	result["imported"] = kind == "import" ? length(images) : 0
	return result

/// Collect unsaved local pixel identities so imports cannot claim artwork still being created.
/datum/controller/subsystem/persistent_paintings/proc/pending_canvas_ids()
	var/list/result
	for(var/obj/item/canvas/canvas as anything in pending_canvases)
		if(canvas && !canvas.no_save && !canvas.painting_metadata.loaded_from_json)
			LAZYOR(result, md5(LOWER_TEXT(canvas.get_data_string())))
	return result

/// Reuse painting datums from committed metadata and refresh indexes, assets, and open galleries.
/datum/controller/subsystem/persistent_paintings/proc/apply_store_snapshot(list/snapshot)
	var/list/updated = list()
	for(var/list/row as anything in snapshot["paintings"])
		if(!islist(row) || !valid_painting_id(row["md5"]) || !isnum(row["width"]) || !isnum(row["height"]) || !("[row["width"]]x[row["height"]]" in GLOB.canvas_dimensions))
			continue
		var/datum/painting/painting = paintings_by_id?[row["md5"]]
		if(!painting)
			painting = new
		painting.load_from_json(row)
		updated += painting
	paintings = updated
	cache_paintings()
	var/datum/asset/simple/portraits/assets = GLOB.asset_datums[/datum/asset/simple/portraits]
	assets?.refresh_paintings()
	refresh_gallery_uis(rebuild = TRUE)

/// Invalidate searches after commits; only open Art Galaxy views need UI or new asset updates.
/datum/controller/subsystem/persistent_paintings/proc/refresh_gallery_uis(rebuild = FALSE)
	for(var/datum/computer_file/program/portrait_printer/program as anything in gallery_programs)
		if(rebuild)
			program.matching_paintings = null
		if(program.computer?.active_program != program || !length(program.computer.open_uis))
			continue
		SStgui.update_uis(program.computer)

/// Queue named metadata changes with optional ownership and stale-value checks at execution time.
/datum/controller/subsystem/persistent_paintings/proc/patch_painting(datum/painting/painting, list/patch, owner, list/expected)
	return run_store_operation("patch", list("id" = painting.md5, "patch" = patch, "owner" = owner, "expected" = expected))

/// Invalidate owner payloads; the ID index also lets snapshot loading reuse live painting datums.
/datum/controller/subsystem/persistent_paintings/proc/cache_gallery_owners()
	owner_painting_data = null
	paintings_by_id = null
	for(var/datum/painting/painting as anything in paintings)
		LAZYSET(paintings_by_id, painting.md5, painting)
	// Personal saves have no rotation tags and stay out of public in-game browsing/AI portraits.
	var/list/public_data = list()
	for(var/list/entry as anything in cached_painting_data)
		var/datum/painting/painting = paintings_by_id?[entry["md5"]]
		if(length(painting?.tags))
			public_data += list(entry)
	cached_painting_data = public_data

/// Remove displayed canvases only after deletion has committed, for player and administrator actions alike.
/datum/controller/subsystem/persistent_paintings/proc/remove_deleted_painting_frames(id)
	for(var/obj/structure/sign/painting/frame as anything in painting_frames)
		if(frame.current_canvas?.painting_metadata.md5 != id)
			continue
		QDEL_NULL(frame.current_canvas)
		frame.update_appearance()

/// Build only the authenticated owner's payload, once per committed snapshot.
/datum/controller/subsystem/persistent_paintings/proc/get_owned_paintings(owner)
	if(!owner)
		return list()
	var/list/owned = owner_painting_data?[owner]
	if(isnull(owned))
		owned = list()
		for(var/datum/painting/painting as anything in paintings)
			if(painting.creator_ckey != owner)
				continue
			owned += list(list(
				"title" = painting.title, "creator" = painting.creator_name,
				"md5" = painting.md5, "ref" = REF(painting),
				"width" = painting.width, "height" = painting.height, "ratio" = painting.width / painting.height,
				"creation_date" = painting.creation_date, "medium" = painting.medium,
				"show_in_webgallery" = painting.show_in_webgallery, "in_rotation" = !!length(painting.tags),
			))
		LAZYSET(owner_painting_data, owner, owned)
	// Frames can change without a database commit. Refresh counts without rebuilding metadata.
	var/list/framed_counts
	for(var/obj/structure/sign/painting/frame as anything in painting_frames)
		var/datum/painting/painting = frame.current_canvas?.painting_metadata
		if(painting?.creator_ckey == owner && painting.md5)
			LAZYSET(framed_counts, painting.md5, (framed_counts?[painting.md5] || 0) + 1)
	for(var/list/entry as anything in owned)
		entry["framed_count"] = framed_counts?[entry["md5"]] || 0
	return owned
