/// AI commands use the same preference category and dispatcher from every authorized control endpoint.
/datum/keybinding/artificial_intelligence
	hotkey_keys = list(UNBOUND_KEY)
	/// Service label, registered verb metadata or an already-owned action type.
	var/command
	/// Camera bookmark slot for the save/recall families.
	var/camera_slot = 0

/datum/keybinding/artificial_intelligence/down(client/user, turf/target, mousepos_x, mousepos_y)
	. = ..()
	if(.)
		return
	var/mob/living/body = user.mob
	var/mob/living/silicon/ai/core = body.ai_controller()
	return core?.run_ai_command(command, camera_slot)

/datum/keybinding/artificial_intelligence/services
	name = "ai_services"
	keybind_signal = "key_ai_services"
	full_name = "AI Services"
	command = "AI services"

/datum/keybinding/artificial_intelligence/manage_uplink
	name = "ai_manage_uplink"
	keybind_signal = "key_ai_manage_uplink"
	full_name = "Manage Uplink Shell"
	command = "Manage Uplink"

/datum/keybinding/artificial_intelligence/resume_uplink
	name = "ai_resume_uplink"
	keybind_signal = "key_ai_resume_uplink"
	full_name = "Resume Uplink Shell"
	command = "Resume Uplink"

/datum/keybinding/artificial_intelligence/deploy_shell
	name = "ai_deploy_shell"
	keybind_signal = "key_ai_deploy_shell"
	full_name = "Deploy to Shell"
	command = "Deploy shell"

/datum/keybinding/artificial_intelligence/ai_view
	name = "ai_ai_view"
	keybind_signal = "key_ai_ai_view"
	full_name = "AI View / Leave Body"
	command = "AI View"

/datum/keybinding/artificial_intelligence/show_laws
	name = "ai_show_laws"
	keybind_signal = "key_ai_show_laws"
	full_name = "Show Laws Privately"
	command = "Show laws"

/datum/keybinding/artificial_intelligence/state_laws
	name = "ai_state_laws"
	keybind_signal = "key_ai_state_laws"
	full_name = "State Laws"
	command = "Laws"

/datum/keybinding/artificial_intelligence/status
	name = "ai_status"
	keybind_signal = "key_ai_status"
	full_name = "Core and Cyborg Status"
	command = "Core and cyborg status"

/datum/keybinding/artificial_intelligence/radio
	name = "ai_radio"
	keybind_signal = "key_ai_radio"
	full_name = "Transceiver Settings"
	command = "Transceiver"

/datum/keybinding/artificial_intelligence/alerts
	name = "ai_alerts"
	keybind_signal = "key_ai_alerts"
	full_name = "Station Alerts"
	command = "Station alerts"

/datum/keybinding/artificial_intelligence/manifest
	name = "ai_manifest"
	keybind_signal = "key_ai_manifest"
	full_name = "Crew Manifest"
	command = "Crew manifest"

/datum/keybinding/artificial_intelligence/crew_monitor
	name = "ai_crew_monitor"
	keybind_signal = "key_ai_crew_monitor"
	full_name = "Crew Monitor"
	command = "Crew monitor"

/datum/keybinding/artificial_intelligence/computer
	name = "ai_computer"
	keybind_signal = "key_ai_computer"
	full_name = "Integrated Computer"
	command = "Integrated computer"

/datum/keybinding/artificial_intelligence/robots
	name = "ai_robots"
	keybind_signal = "key_ai_robots"
	full_name = "Robot Control"
	command = "Robot control"

/datum/keybinding/artificial_intelligence/core_display
	name = "ai_core_display"
	keybind_signal = "key_ai_core_display"
	full_name = "Core Display"
	command = "Core display"

/datum/keybinding/artificial_intelligence/status_display
	name = "ai_status_display"
	keybind_signal = "key_ai_status_display"
	full_name = "Status Displays"
	command = "Status displays"

/datum/keybinding/artificial_intelligence/hologram
	name = "ai_hologram"
	keybind_signal = "key_ai_hologram"
	full_name = "Hologram Appearance"
	command = "Hologram appearance"

/datum/keybinding/artificial_intelligence/sensors
	name = "ai_sensors"
	keybind_signal = "key_ai_sensors"
	full_name = "Sensor Overlays"
	command = "Sensor overlays"

/datum/keybinding/artificial_intelligence/light
	name = "ai_light"
	keybind_signal = "key_ai_light"
	full_name = "Camera Light / Headlamp"
	command = "Camera light"

/datum/keybinding/artificial_intelligence/vox
	name = "ai_vox"
	keybind_signal = "key_ai_vox"
	full_name = "Vox Announcement"
	command = "Vox announcement"

/datum/keybinding/artificial_intelligence/shuttle
	name = "ai_shuttle"
	keybind_signal = "key_ai_shuttle"
	full_name = "Call Emergency Shuttle"
	command = "Call emergency shuttle"

/datum/keybinding/artificial_intelligence/photo
	name = "ai_photo"
	keybind_signal = "key_ai_photo"
	full_name = "Take Photograph"
	command = "Take photograph"

/datum/keybinding/artificial_intelligence/album
	name = "ai_album"
	keybind_signal = "key_ai_album"
	full_name = "Photo Album"
	command = "Photo album"

/datum/keybinding/artificial_intelligence/abilities
	name = "ai_abilities"
	keybind_signal = "key_ai_abilities"
	full_name = "Special Abilities"
	command = "Special abilities"

/datum/keybinding/artificial_intelligence/modules
	name = "ai_modules"
	keybind_signal = "key_ai_modules"
	full_name = "Malfunction Modules"
	command = "Malfunction modules"

/datum/keybinding/artificial_intelligence/network_mode
	name = "ai_network_mode"
	keybind_signal = "key_ai_network_mode"
	full_name = "Local Network Interaction"
	command = "Local network mode"

/datum/keybinding/artificial_intelligence/view_core
	name = "ai_view_core"
	keybind_signal = "key_ai_view_core"
	full_name = "View Core"
	command = "View core"

/datum/keybinding/artificial_intelligence/cameras
	name = "ai_cameras"
	keybind_signal = "key_ai_cameras"
	full_name = "Camera List"
	command = "Camera list"

/datum/keybinding/artificial_intelligence/track
	name = "ai_track"
	keybind_signal = "key_ai_track"
	full_name = "Track with Camera"
	command = "Track camera"

/datum/keybinding/artificial_intelligence/multicam
	name = "ai_multicam"
	keybind_signal = "key_ai_multicam"
	full_name = "Multicamera Mode"
	command = "Multicamera"

/datum/keybinding/artificial_intelligence/add_camera
	name = "ai_add_camera"
	keybind_signal = "key_ai_add_camera"
	full_name = "Add Camera"
	command = "Add camera"

/datum/keybinding/artificial_intelligence/camera_up
	name = "ai_camera_up"
	keybind_signal = "key_ai_camera_up"
	full_name = "Camera Up a Floor"
	command = "Camera up"

/datum/keybinding/artificial_intelligence/camera_down
	name = "ai_camera_down"
	keybind_signal = "key_ai_camera_down"
	full_name = "Camera Down a Floor"
	command = "Camera down"

/datum/keybinding/artificial_intelligence/camera_previous
	name = "ai_camera_previous"
	keybind_signal = "key_ai_camera_previous"
	full_name = "Previous Camera"
	command = "Previous camera"

/datum/keybinding/artificial_intelligence/announce_channel
	name = "ai_announce_channel"
	keybind_signal = "key_ai_announce_channel"
	full_name = "Automatic Announcement Channel"
	command = /datum/verb_metadata/mob/living/silicon/ai/set_automatic_say_channel

/datum/keybinding/artificial_intelligence/network
	name = "ai_network"
	keybind_signal = "key_ai_network"
	full_name = "Change Camera Network"
	command = /datum/verb_metadata/mob/living/silicon/ai/ai_network_change

/datum/keybinding/artificial_intelligence/acceleration
	name = "ai_acceleration"
	keybind_signal = "key_ai_acceleration"
	full_name = "Toggle Camera Acceleration"
	command = /datum/verb_metadata/mob/living/silicon/ai/toggle_acceleration

/datum/keybinding/artificial_intelligence/bolts
	name = "ai_bolts"
	keybind_signal = "key_ai_bolts"
	full_name = "Toggle Core Floor Bolts"
	command = /datum/verb_metadata/mob/living/silicon/ai/toggle_anchor

/datum/keybinding/artificial_intelligence/cryo
	name = "ai_cryo"
	keybind_signal = "key_ai_cryo"
	full_name = "AI Cryogenic Stasis"
	command = /datum/verb_metadata/mob/living/silicon/ai/ai_cryo

/datum/keybinding/artificial_intelligence/announcement_help
	name = "ai_announcement_help"
	keybind_signal = "key_ai_announcement_help"
	full_name = "Announcement Help"
	command = /datum/verb_metadata/mob/living/silicon/ai/announcement_help

/datum/keybinding/artificial_intelligence/vox_voice
	name = "ai_vox_voice"
	keybind_signal = "key_ai_vox_voice"
	full_name = "Switch Vox Voice"
	command = /datum/verb_metadata/mob/living/silicon/ai/switch_vox

/datum/keybinding/artificial_intelligence/vox_words
	name = "ai_vox_words"
	keybind_signal = "key_ai_vox_words"
	full_name = "Display Vox Word String"
	command = /datum/verb_metadata/mob/living/silicon/ai/display_word_string

/datum/keybinding/artificial_intelligence/vox_clear
	name = "ai_vox_clear"
	keybind_signal = "key_ai_vox_clear"
	full_name = "Clear Vox Word String"
	command = /datum/verb_metadata/mob/living/silicon/ai/clear_word_string

/datum/keybinding/artificial_intelligence/ability_nuke
	name = "ai_ability_nuke"
	keybind_signal = "key_ai_ability_nuke"
	full_name = "Doomsday Device"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/nuke_station

/datum/keybinding/artificial_intelligence/ability_lockdown
	name = "ai_ability_lockdown"
	keybind_signal = "key_ai_ability_lockdown"
	full_name = "Hostile Station Lockdown"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/lockdown

/datum/keybinding/artificial_intelligence/ability_override
	name = "ai_ability_override"
	keybind_signal = "key_ai_ability_override"
	full_name = "Override Machine"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/ranged/override_machine

/datum/keybinding/artificial_intelligence/ability_rcds
	name = "ai_ability_rcds"
	keybind_signal = "key_ai_ability_rcds"
	full_name = "Destroy RCDs"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/destroy_rcds

/datum/keybinding/artificial_intelligence/ability_overload
	name = "ai_ability_overload"
	keybind_signal = "key_ai_ability_overload"
	full_name = "Overload Machine"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/ranged/overload_machine

/datum/keybinding/artificial_intelligence/ability_blackout
	name = "ai_ability_blackout"
	keybind_signal = "key_ai_ability_blackout"
	full_name = "Blackout"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/blackout

/datum/keybinding/artificial_intelligence/ability_honk
	name = "ai_ability_honk"
	keybind_signal = "key_ai_ability_honk"
	full_name = "Honk"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/honk

/datum/keybinding/artificial_intelligence/ability_transformer
	name = "ai_ability_transformer"
	keybind_signal = "key_ai_ability_transformer"
	full_name = "Place Robotic Factory"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/place_transformer

/datum/keybinding/artificial_intelligence/ability_air_alarms
	name = "ai_ability_air_alarms"
	keybind_signal = "key_ai_ability_air_alarms"
	full_name = "Break Air Alarms"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/break_air_alarms

/datum/keybinding/artificial_intelligence/ability_fire_alarms
	name = "ai_ability_fire_alarms"
	keybind_signal = "key_ai_ability_fire_alarms"
	full_name = "Break Fire Alarms"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/break_fire_alarms

/datum/keybinding/artificial_intelligence/ability_emergency_lights
	name = "ai_ability_emergency_lights"
	keybind_signal = "key_ai_ability_emergency_lights"
	full_name = "Emergency Lights"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/emergency_lights

/datum/keybinding/artificial_intelligence/ability_reactivate_cameras
	name = "ai_ability_reactivate_cameras"
	keybind_signal = "key_ai_ability_reactivate_cameras"
	full_name = "Reactivate Cameras"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/reactivate_cameras

/datum/keybinding/artificial_intelligence/ability_voice_changer
	name = "ai_ability_voice_changer"
	keybind_signal = "key_ai_ability_voice_changer"
	full_name = "Voice Changer"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/voice_changer

/datum/keybinding/artificial_intelligence/ability_emag
	name = "ai_ability_emag"
	keybind_signal = "key_ai_ability_emag"
	full_name = "Remote Emag"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/ranged/emag

/datum/keybinding/artificial_intelligence/ability_core_tilt
	name = "ai_ability_core_tilt"
	keybind_signal = "key_ai_ability_core_tilt"
	full_name = "Roll Core"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/ranged/core_tilt

/datum/keybinding/artificial_intelligence/ability_vendor_tilt
	name = "ai_ability_vendor_tilt"
	keybind_signal = "key_ai_ability_vendor_tilt"
	full_name = "Tilt Vendor"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/ranged/remote_vendor_tilt

/datum/keybinding/artificial_intelligence/ability_power_apc
	name = "ai_ability_power_apc"
	keybind_signal = "key_ai_ability_power_apc"
	full_name = "Power APC"
	description = "Activates the acquired AI ability with its normal availability, uses and cooldown."
	command = /datum/action/innate/ai/ranged/power_apc

/datum/keybinding/artificial_intelligence/main_core
	name = "ai_main_core"
	keybind_signal = "key_ai_main_core"
	full_name = "Return to Main Core"
	command = /datum/action/innate/core_return

/datum/keybinding/artificial_intelligence/camera_recall
	command = "Recall camera"
	description = "Returns to AI View before using the selected camera bookmark."

/datum/keybinding/artificial_intelligence/camera_recall/slot1
	name = "ai_camera_recall_1"
	keybind_signal = "key_ai_camera_recall_1"
	full_name = "Recall Camera Group 1"
	camera_slot = 1

/datum/keybinding/artificial_intelligence/camera_recall/slot2
	name = "ai_camera_recall_2"
	keybind_signal = "key_ai_camera_recall_2"
	full_name = "Recall Camera Group 2"
	camera_slot = 2

/datum/keybinding/artificial_intelligence/camera_recall/slot3
	name = "ai_camera_recall_3"
	keybind_signal = "key_ai_camera_recall_3"
	full_name = "Recall Camera Group 3"
	camera_slot = 3

/datum/keybinding/artificial_intelligence/camera_recall/slot4
	name = "ai_camera_recall_4"
	keybind_signal = "key_ai_camera_recall_4"
	full_name = "Recall Camera Group 4"
	camera_slot = 4

/datum/keybinding/artificial_intelligence/camera_recall/slot5
	name = "ai_camera_recall_5"
	keybind_signal = "key_ai_camera_recall_5"
	full_name = "Recall Camera Group 5"
	camera_slot = 5

/datum/keybinding/artificial_intelligence/camera_recall/slot6
	name = "ai_camera_recall_6"
	keybind_signal = "key_ai_camera_recall_6"
	full_name = "Recall Camera Group 6"
	camera_slot = 6

/datum/keybinding/artificial_intelligence/camera_recall/slot7
	name = "ai_camera_recall_7"
	keybind_signal = "key_ai_camera_recall_7"
	full_name = "Recall Camera Group 7"
	camera_slot = 7

/datum/keybinding/artificial_intelligence/camera_recall/slot8
	name = "ai_camera_recall_8"
	keybind_signal = "key_ai_camera_recall_8"
	full_name = "Recall Camera Group 8"
	camera_slot = 8

/datum/keybinding/artificial_intelligence/camera_recall/slot9
	name = "ai_camera_recall_9"
	keybind_signal = "key_ai_camera_recall_9"
	full_name = "Recall Camera Group 9"
	camera_slot = 9

/datum/keybinding/artificial_intelligence/camera_save
	command = "Save camera"
	description = "Returns to AI View before using the selected camera bookmark."

/datum/keybinding/artificial_intelligence/camera_save/slot1
	name = "ai_camera_save_1"
	keybind_signal = "key_ai_camera_save_1"
	full_name = "Save Camera Group 1"
	camera_slot = 1

/datum/keybinding/artificial_intelligence/camera_save/slot2
	name = "ai_camera_save_2"
	keybind_signal = "key_ai_camera_save_2"
	full_name = "Save Camera Group 2"
	camera_slot = 2

/datum/keybinding/artificial_intelligence/camera_save/slot3
	name = "ai_camera_save_3"
	keybind_signal = "key_ai_camera_save_3"
	full_name = "Save Camera Group 3"
	camera_slot = 3

/datum/keybinding/artificial_intelligence/camera_save/slot4
	name = "ai_camera_save_4"
	keybind_signal = "key_ai_camera_save_4"
	full_name = "Save Camera Group 4"
	camera_slot = 4

/datum/keybinding/artificial_intelligence/camera_save/slot5
	name = "ai_camera_save_5"
	keybind_signal = "key_ai_camera_save_5"
	full_name = "Save Camera Group 5"
	camera_slot = 5

/datum/keybinding/artificial_intelligence/camera_save/slot6
	name = "ai_camera_save_6"
	keybind_signal = "key_ai_camera_save_6"
	full_name = "Save Camera Group 6"
	camera_slot = 6

/datum/keybinding/artificial_intelligence/camera_save/slot7
	name = "ai_camera_save_7"
	keybind_signal = "key_ai_camera_save_7"
	full_name = "Save Camera Group 7"
	camera_slot = 7

/datum/keybinding/artificial_intelligence/camera_save/slot8
	name = "ai_camera_save_8"
	keybind_signal = "key_ai_camera_save_8"
	full_name = "Save Camera Group 8"
	camera_slot = 8

/datum/keybinding/artificial_intelligence/camera_save/slot9
	name = "ai_camera_save_9"
	keybind_signal = "key_ai_camera_save_9"
	full_name = "Save Camera Group 9"
	camera_slot = 9
