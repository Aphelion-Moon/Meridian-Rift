/// A saved choice follows the server unless the player explicitly chooses a track.
#define LOBBY_MUSIC_SERVER "server"

GLOBAL_DATUM_INIT(lobby_music_catalog, /datum/lobby_music_catalog, new)

/// Shared allowlist. File fingerprints keep replaced/renamed songs from inheriting old preferences.
/datum/lobby_music_catalog
	var/list/tracks = list()
	var/next_refresh = 0
	// Runtime deployments need not retain the source sound directory alongside the compiled resources.
	var/static/list/builtin_tracks = list(
		'sound/music/lobby_music/title0.ogg',
		'sound/music/lobby_music/title1.mod',
		'sound/music/lobby_music/title2.ogg',
		'sound/music/lobby_music/title3.ogg',
		'sound/music/lobby_music/clown.ogg',
	)

/datum/lobby_music_catalog/proc/refresh()
	if(world.time < next_refresh)
		return
	next_refresh = world.time + 30 SECONDS
	tracks = list()
	var/directory = "[global.config.directory]/title_music/sounds/"
	for(var/filename in sort_list(flist(directory)))
		if(IS_SOUND_FILE(filename) && fexists("[directory][filename]"))
			add_track("[directory][filename]")
	// These remain available even on installations without custom title music.
	for(var/path in world.file2list("strings/round_start_sounds.txt", "\n"))
		var/source = available_source(path)
		if(source)
			add_track(source)

/// fexists() only checks the filesystem; compiled sound resources are valid without a disk file.
/datum/lobby_music_catalog/proc/available_source(path)
	if(isfile(path))
		return path
	if(istext(path) && length(path))
		for(var/resource in builtin_tracks)
			if("[resource]" == path)
				return resource
		if(fexists(path))
			return path
	return null

/datum/lobby_music_catalog/proc/add_track(path)
	path = available_source(path)
	if(!path)
		return
	var/id = track_id(path, md5(isfile(path) ? path : file(path)))
	tracks[id] = list("id" = id, "name" = lobby_music_name(path), "path" = path)

/datum/lobby_music_catalog/proc/track_id(path, fingerprint)
	return md5("[path]:[fingerprint]")

/datum/lobby_music_catalog/proc/get_track(id)
	refresh()
	var/list/track = tracks[id]
	if(track && available_source(track["path"]))
		return track
	return null

/datum/lobby_music_catalog/proc/server_track()
	var/source = available_source(SSticker.login_music)
	if(source)
		return source
	refresh()
	for(var/id in tracks)
		var/list/track = get_track(id)
		if(track)
			return track["path"]
	return null

/datum/lobby_music_catalog/proc/ui_tracks()
	refresh()
	var/list/result = list()
	for(var/id in tracks)
		var/list/track = get_track(id)
		if(track)
			result += list(list("id" = id, "name" = track["name"]))
	return result

/proc/lobby_music_name(path)
	if(!path)
		return "No track available"
	var/list/parts = splittext("[path]", "/")
	var/name = parts[length(parts)]
	var/extension = findlasttext(name, ".")
	if(extension)
		name = copytext(name, 1, extension)
	return replacetext(name, "_", " ")

/// The chat player owns this control; it is still stored with the account's game preferences.
/datum/preference/lobby_music_track
	savefile_key = "lobby_music_track"
	savefile_identifier = PREFERENCE_PLAYER

/datum/preference/lobby_music_track/create_default_value()
	return LOBBY_MUSIC_SERVER

/datum/preference/lobby_music_track/deserialize(input, datum/preferences/preferences)
	return is_valid(input) ? input : LOBBY_MUSIC_SERVER

/datum/preference/lobby_music_track/is_valid(value, datum/preferences/preferences)
	if(!istext(value))
		return FALSE
	if(value == LOBBY_MUSIC_SERVER)
		return TRUE
	var/static/regex/track_id_pattern = regex("^\[0-9a-f]{32}$")
	return length(value) == 32 && track_id_pattern.Find(value)

/datum/preference/lobby_music_track/is_accessible(datum/preferences/preferences)
	return FALSE

/datum/preference/lobby_music_track/apply_to_client_updated(client/client, value)
	client.get_lobby_music_player().play(restart = TRUE)
