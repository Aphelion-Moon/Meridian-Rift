/// Both halves of the bridge in one place, for when the whitelist "just stops working".
ADMIN_VERB(symphony_status, R_ADMIN, "Symphony Status", "Version and link state of the SSymphony bridge.", ADMIN_CATEGORY_SERVER)
	var/list/out = list("<b>SSymphony bridge</b>")
	out += "Game module: <b>version [SYMPHONY_MODULE_VERSION]</b>"

	var/list/panel = SSsymphony.panel
	if(!length(panel))
		out += "Panel: <b>no contact</b> since the last restart."
	else
		// Both came off a topic, so they're encoded before they reach anyone's chat.
		var/from = html_encode(panel["addr"]) || "this machine"
		var/version = html_encode(panel["version"])
		if(version)
			out += "Panel: <b>version [version]</b>, from [from], last heard [symphony_ago(panel["at"])]."
			out += symphony_version_verdict(panel["needs"], panel["wants"])
		else
			// Older panels can authenticate successfully without supplying version metadata.
			out += "Panel: in touch from [from], last heard [symphony_ago(panel["at"])], but too old to give a version."

	var/list/barred = SSsymphony.panel_refused
	if(length(barred))
		out += span_warning("A topic from [html_encode(barred["addr"])] was refused [symphony_ago(barred["at"])], not an allowed address.")

	out += "&nbsp;"
	out += "Whitelist enforcement: [CONFIG_GET(flag/symphony_enabled) ? "on" : "<b>off</b>"]"
	out += "Panel URL: [CONFIG_GET(string/symphony_url) || "<b>not set</b>"]"
	out += "Comms key: [CONFIG_GET(string/comms_key) ? "set" : "<b>not set</b>, every topic is refused"]"
	var/list/allowed = CONFIG_GET(str_list/symphony_topics_allowed_addresses)
	if(!CONFIG_GET(flag/symphony_topics_local_only))
		out += "Topics: any address with the key"
	else
		out += "Topics: local only[length(allowed) ? ", plus [length(allowed)] allowed" : ""]"

	to_chat(user, boxed_message(out.Join("<br>")))
	BLACKBOX_LOG_ADMIN_VERB("Symphony Status")
