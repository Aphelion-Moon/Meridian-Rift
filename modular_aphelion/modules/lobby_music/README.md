# Lobby music

The player belongs to the client, so changing bodies does not interrupt its sound channel. Music repeats in the lobby. Joining or observing updates that channel to finish the current iteration; returning to the title screen restores repetition or starts playback if the track has ended. Volume and context updates use `SOUND_UPDATE` without seeking. Explicit stop, restart, and track selection are available in the chat Music player.

The account preference defaults to the current server selection. Available tracks come from `config/title_music/sounds/` (relative to the configured config directory) and `strings/round_start_sounds.txt`. Saved IDs include both the path and file fingerprint. Deleting, renaming, or replacing a selected file resets the preference to the server selection when next resolved. The shared catalog refreshes at most once every 30 seconds. The open controls refresh every five seconds; closed controls do not poll.

The server validates selections against this catalog and accepts no client-provided file paths. Existing lobby volume preferences and the server's `disallow_title_music` setting still apply. Sound queries and request generations prevent an older asynchronous play request from undoing a newer stop or selection.

Tests cover lobby/game transitions, playback position, explicit restart/stop, volume changes, asynchronous cancellation, preference validation, and missing/replaced tracks in `code/modules/unit_tests/lobby_music.dm`. Frontend interactions are covered in `tgui/packages/tgui-panel/audio/LobbyMusicControls.test.tsx`.
