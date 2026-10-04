/// Collect administrator input before queuing a mutation, then refresh frames and log the committed changes.
/datum/paintings_manager/proc/gallery_ui_act(action, list/params, datum/tgui/ui)
	var/client/administrator = ui.user?.client
	var/datum/painting/chosen = locate(params["ref"]) in SSpersistent_paintings.paintings
	if(!chosen || !administrator)
		return
	var/list/patch = list()
	var/list/expected = list()
	var/list/payload = list("id" = chosen.md5, "patch" = patch, "expected" = expected)
	var/kind = "patch"
	switch(action)
		if("delete")
			kind = "delete"
		if("rename")
			expected["title"] = chosen.title
			var/title = tgui_input_text(ui.user, "New painting title?", "Painting Rename", chosen.title, max_length = MAX_NAME_LEN)
			if(!title)
				return
			patch["title"] = title
		if("rename_author")
			expected["creator_name"] = chosen.creator_name
			var/name = tgui_input_text(ui.user, "New painting author name?", "Painting Rename", chosen.creator_name, max_length = MAX_NAME_LEN)
			if(!name)
				return
			patch["creator_name"] = name
		if("dumpit")
			patch["patron_name"] = ""
			patch["patron_ckey"] = ""
			patch["credit_value"] = 0
			patch["frame_type"] = initial(chosen.frame_type)
		if("remove_tag")
			if(!istext(params["tag"]))
				return
			payload["remove_tag"] = params["tag"]
		if("add_tag")
			var/tag_name = tgui_input_text(ui.user, "New tag name?", "Add Tag", max_length = MAX_NAME_LEN)
			if(!tag_name)
				return
			payload["add_tag"] = tag_name
		else
			return
	if(!administrator?.holder || !check_rights_for(administrator, R_ADMIN))
		return
	var/list/result = SSpersistent_paintings.run_store_operation(kind, payload)
	if(!result["ok"])
		to_chat(administrator, span_warning(SSpersistent_paintings.store_result_message(result)))
		return TRUE
	for(var/obj/structure/sign/painting/frame as anything in SSpersistent_paintings.painting_frames)
		if(frame.current_canvas?.painting_metadata != chosen)
			continue
		frame.update_appearance()
	var/list/log_changes = patch.Copy()
	for(var/tag_action in list("add_tag", "remove_tag"))
		if(tag_action in payload)
			log_changes[tag_action] = payload[tag_action]
	log_admin("[key_name(administrator)] applied painting action [action] to [chosen.md5], creator [chosen.creator_ckey]; changes [json_encode(log_changes)].")
	if(kind == "delete")
		message_admins(span_notice("[key_name_admin(administrator)] deleted a persistent painting made by [chosen.creator_ckey]."))
	SStgui.update_uis(src)
	return TRUE
