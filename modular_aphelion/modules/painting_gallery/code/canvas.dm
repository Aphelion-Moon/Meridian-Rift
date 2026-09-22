/obj/item/canvas
	/// Prevent overlapping finalization dialogs from claiming a canvas.
	var/finalizing = FALSE
	/// Block metadata edits while the first archive transaction is in flight.
	var/persistence_saving = FALSE

/// Serialize finalization prompts, release the guard, then save any successfully finalized artwork.
/obj/item/canvas/proc/gallery_finalize(mob/user)
	if(finalized || finalizing || persistence_saving || painting_metadata.loaded_from_json)
		return
	finalizing = TRUE
	try
		finish_finalization(user)
	catch(var/exception/error)
		stack_trace("Painting finalization failed: [error]")
	finalizing = FALSE
	save_to_gallery(user)

/// Save originals to their owner's gallery; a mounted archive frame also adds its rotation tag.
/obj/item/canvas/proc/save_to_gallery(mob/user)
	if(QDELETED(src) || !finalized || finalizing || persistence_saving || (no_save && !painting_metadata.loaded_from_json))
		return
	var/obj/structure/sign/painting/frame = loc
	var/tag = istype(frame) && frame.current_canvas == src ? frame.persistence_id : null
	if(painting_metadata.loaded_from_json && (!tag || (tag in painting_metadata.tags)))
		return
	var/list/result = SSpersistent_paintings.run_store_operation("archive", list("canvas" = src, "tag" = tag))
	if(!result["ok"])
		to_chat(user, span_warning("The painting could not be saved. Place it in an archive-enabled frame to retry, or contact an administrator."))
	else if(result["changed"])
		var/message = tag ? "Painting saved to My Artwork and the station's frame rotation." : "Painting saved to My Artwork. You can share it on the web gallery from Art Galaxy."
		to_chat(user, span_notice(message))
	else if(!QDELETED(src) && !painting_metadata.loaded_from_json)
		to_chat(user, span_warning("This image already exists in the archive or was deleted this round; this copy was not saved."))

/// Display-only frames never add paintings to the station's spawn rotation.
/obj/item/canvas/proc/archive_if_mounted(mob/user)
	var/obj/structure/sign/painting/frame = loc
	if(istype(frame) && frame.persistence_id && frame.current_canvas == src)
		save_to_gallery(user)

/// Confirm title and signature, recheck the player and canvas, and finalize with website visibility off.
/obj/item/canvas/proc/finish_finalization(mob/user)
	if(!user?.client)
		return
	if(!in_range(src, user))
		user.balloon_alert(user, "too far away!")
		return
	var/owner = user.ckey
	painting_metadata.creator_name = user.real_name
	if(!try_rename(user))
		return
	if(QDELETED(src) || !user?.client || user.ckey != owner || !in_range(src, user) || finalized || persistence_saving || painting_metadata.loaded_from_json)
		return
	painting_metadata.creator_ckey = owner
	painting_metadata.show_in_webgallery = FALSE
	painting_metadata.creation_date = time2text(world.realtime, "DDD MMM DD hh:mm:ss YYYY", TIMEZONE_UTC)
	painting_metadata.creation_round_id = GLOB.round_id
	generate_proper_overlay()
	finalized = TRUE

	SStgui.update_uis(src)

/// Commit archived patronage before payment distribution; refund the offer if persistence fails.
/obj/item/canvas/proc/persist_patronage(mob/user, datum/bank_account/account, offer_amount, sniped_amount)
	if(!painting_metadata.loaded_from_json)
		return TRUE
	var/list/result = SSpersistent_paintings.patch_painting(painting_metadata, list("patron_ckey" = user.ckey, "patron_name" = user.real_name, "credit_value" = offer_amount), expected = list("credit_value" = sniped_amount))
	if(!result["ok"])
		account.adjust_money(offer_amount, "Painting: failed patronage refund")
		to_chat(user, span_warning("The patronage could not be saved. Your payment was returned."))
		return FALSE
	return TRUE

/// Save an authorized cosmetic frame choice, rejecting stale patronage or unavailable storage.
/obj/item/canvas/proc/persist_frame_choice(mob/user, choice)
	if(!can_select_frame(user))
		return FALSE
	if(painting_metadata.loaded_from_json)
		var/list/saved = SSpersistent_paintings.patch_painting(painting_metadata, list("frame_type" = choice), expected = list("credit_value" = painting_metadata.credit_value))
		if(!saved["ok"])
			to_chat(user, span_warning("The frame change could not be saved. Please try again."))
			return FALSE
	else
		painting_metadata.frame_type = choice
	return !QDELETED(src) && istype(loc, /obj/structure/sign/painting)
