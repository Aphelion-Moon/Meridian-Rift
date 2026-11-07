/turf/open/floor/sandstone/cobbled
	name = "cobbled sandstone floor"
	icon = 'modular_aphelion/modules/metamorphicstation/metamorphic_turfs.dmi'
	icon_state = "sandstone_cobbled"
	floor_tile = /obj/item/stack/tile/mineral/sandstone/cobbled

/obj/item/stack/tile/mineral/sandstone/cobbled
	name = "cobbled sandstone tile"
	singular_name = "sandstone cobbled floor tile"
	icon = 'modular_aphelion/modules/metamorphicstation/metamorphic_tiles.dmi'
	icon_state = "sandstone_cobbled"
	inhand_icon_state = "tile-sandstone"
	turf_type = /turf/open/floor/sandstone/cobbled
	merge_type = /obj/item/stack/tile/mineral/sandstone/cobbled

/turf/closed/wall/mineral/stone/necropolis
	name = "necropolis wall"
	desc = "A wall made of solid stone bricks."
	icon = 'icons/turf/walls/boss_wall.dmi'
	icon_state = "boss_wall-0"
	base_icon_state = "boss_wall"
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_CLOSED_TURFS + SMOOTH_GROUP_BOSS_WALLS
	canSmoothWith = SMOOTH_GROUP_BOSS_WALLS
	sheet_type = /obj/item/stack/sheet/mineral/stone
