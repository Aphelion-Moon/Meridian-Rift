// Modular turf stuff

// Reskinned soil to make it look like it's turf, but it's not!
/obj/machinery/hydroponics/soil/fake_turf
	desc = "A patch of fertile soil that you can plant stuff in."
	icon = 'icons/turf/floors.dmi' // This makes it look like the dirt floor
	icon_state = "dirt"
	layer = LOW_FLOOR_LAYER
	plane = FLOOR_PLANE
	self_sustaining = 1
	pixel_z = 0

/turf/open/floor/circuit/green/xenobio
	desc = "The air about this floor seems.. different?"
	initial_gas_mix = XENOBIO_BZ

/turf/open/floor/grass/fairy/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS
	baseturfs = /turf/open/misc/asteroid/snow/icemoon

/turf/open/floor/mineral/gold/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS
	baseturfs = /turf/open/misc/asteroid/snow/icemoon

/turf/open/floor/fakebasalt/crater
	icon_state = "basalt_dug"

// Looks like reinforced glass, but it's indestructible and you can't see through it
/turf/open/indestructible/reinforced_glass
	name = "reinforced glass floor"
	icon = 'icons/turf/floors/reinf_glass.dmi'
	icon_state = "reinf_glass-0"
	base_icon_state = "reinf_glass"

/turf/open/indestructible/hoteltile/dark
	icon_state = "darkfull"

/turf/open/indestructible/hoteltile/iron
	icon_state = "floor"

/turf/open/indestructible/hoteltile/plating
	icon_state = "plating"

/turf/open/indestructible/hoteltile/stairs_old
	icon_state = "stairs-old"

/turf/open/indestructible/hoteltile/white
	icon_state = "white"

/turf/closed/indestructible/normal_wall
	name = "wall"
	icon = 'modular_nova/modules/aesthetics/walls/icons/wall.dmi'
	icon_state = "wall-0"
	base_icon_state = "wall"
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_WALLS + SMOOTH_GROUP_CLOSED_TURFS
	canSmoothWith = SMOOTH_GROUP_AIRLOCK + SMOOTH_GROUP_WINDOW_FULLTILE + SMOOTH_GROUP_WALLS

/turf/closed/indestructible/fakedoor/blast_door
	name = /obj/machinery/door/poddoor::name
	desc = /obj/machinery/door/poddoor::desc
	icon = /obj/machinery/door/poddoor::icon
	icon_state = /obj/machinery/door/poddoor::icon_state

/turf/open/skyline
	name = "long way down"
	icon = 'modular_nova/master_files/icons/obj/skyscraper/background.dmi'
	base_icon_state = "0,34"

// Don't let things enter if they can't fly
/turf/open/skyline/Enter(atom/movable/movable, atom/oldloc)
	. = ..()
	if(.)
		if(HAS_TRAIT(src, TRAIT_CHASM_STOPPED)) // lets people walk on catwalks and such
			return
		return HAS_TRAIT(movable, TRAIT_MOVE_FLYING) || HAS_TRAIT(movable, TRAIT_MOVE_FLOATING)

