/datum/body_marking/akula
	icon = 'modular_nova/master_files/icons/mob/body_markings/akula_markings.dmi'
	leg_shapes = MARKING_LEG_PLANTIGRADE // Neither Akula marking has digitigrade art.

/datum/body_marking/akula/secondary
	name = "Akula"
	icon_state = "akula"
	affected_bodyparts = ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT | CHEST | HEAD
	color_mode = MARKING_COLOR_FOLLOWS_SECONDARY

/datum/body_marking/akula/tertiary
	name = "Akula Highlight"
	icon_state = "akula_highlight"
	affected_bodyparts = ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT | CHEST | HEAD
	color_mode = MARKING_COLOR_FOLLOWS_TERTIARY
