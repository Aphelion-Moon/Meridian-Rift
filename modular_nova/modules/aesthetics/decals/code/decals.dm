/obj/effect/turf_decal/stripes/blue
	icon_state = "warningline_blue"
	icon = 'modular_nova/modules/aesthetics/decals/icon/turf_decals.dmi'

/obj/effect/turf_decal/stripes/blue/line
	icon_state = "warningline_blue"

/obj/effect/turf_decal/stripes/blue/end
	icon_state = "warn_end_blue"

/obj/effect/turf_decal/stripes/blue/corner
	icon_state = "warninglinecorner_blue"

/obj/effect/turf_decal/stripes/blue/box
	icon_state = "warn_box_blue"

/obj/effect/turf_decal/stripes/blue/full
	icon_state = "warn_full_blue"

/obj/effect/turf_decal/bot_blue
	icon = 'modular_nova/modules/aesthetics/decals/icon/turf_decals.dmi'
	icon_state = "bot_blue"

/obj/effect/turf_decal/caution/stand_clear/blue
	icon = 'modular_nova/modules/aesthetics/decals/icon/turf_decals.dmi'
	icon_state = "stand_clear_blue"

/obj/effect/turf_decal/arrows/blue
	icon = 'modular_nova/modules/aesthetics/decals/icon/turf_decals.dmi'
	icon_state = "arrows_blue"

/obj/effect/turf_decal/box/blue
	icon = 'modular_nova/modules/aesthetics/decals/icon/turf_decals.dmi'
	icon_state = "box_blue"

/obj/effect/turf_decal/box/blue/corners
	icon = 'modular_nova/modules/aesthetics/decals/icon/turf_decals.dmi'
	icon_state = "box_corners_blue"


/obj/effect/turf_decal/delivery/blue
	icon = 'modular_nova/modules/aesthetics/decals/icon/turf_decals.dmi'
	icon_state = "delivery_blue"

/obj/effect/turf_decal/caution/blue
	icon = 'modular_nova/modules/aesthetics/decals/icon/turf_decals.dmi'
	icon_state = "caution_blue"

/// Automatically generates all subtypes for a decal with the given path.
#define TILE_DECAL_SUBTYPE_HELPER(path)\
##path/opposingcorners {\
	icon_state = "tile_opposing_corners";\
}\
##path/half {\
	icon_state = "tile_half";\
}\
##path/half/contrasted {\
	icon_state = "tile_half_contrasted";\
}\
##path/anticorner {\
	icon_state = "tile_anticorner";\
}\
##path/anticorner/contrasted {\
	icon_state = "tile_anticorner_contrasted";\
}\
##path/fourcorners {\
	icon_state = "tile_fourcorners";\
}\
##path/full {\
	icon_state = "tile_full";\
}\
##path/diagonal_centre {\
	icon_state = "diagonal_centre";\
}\
##path/diagonal_edge {\
	icon_state = "diagonal_edge";\
}\
##path/tram {\
	icon_state = "tile_tram";\
}

/obj/effect/turf_decal/tile/teal
	name = "teal tile decal"
	color = "#325C4B"

TILE_DECAL_SUBTYPE_HELPER(/obj/effect/turf_decal/tile/teal)

/obj/effect/turf_decal/tile/dark_purple
	name = "dark purple tile decal"
	color = "#A76DBF"

TILE_DECAL_SUBTYPE_HELPER(/obj/effect/turf_decal/tile/dark_purple)

#undef TILE_DECAL_SUBTYPE_HELPER

/// Automatically generates all trimlines for a decal with the given path.
#define TRIMLINE_SUBTYPE_HELPER(path)\
##path/line {\
	icon_state = "trimline";\
}\
##path/corner {\
	icon_state = "trimline_corner";\
}\
##path/end {\
	icon_state = "trimline_end";\
}\
##path/arrow_cw {\
	icon_state = "trimline_arrow_cw";\
}\
##path/arrow_ccw {\
	icon_state = "trimline_arrow_ccw";\
}\
##path/warning {\
	icon_state = "trimline_warn";\
}\
##path/tram {\
	icon_state = "trimline_tram";\
}\
##path/mid_joiner {\
	icon_state = "trimline_mid";\
}\
##path/corner_long {\
	icon_state = "trimline_corner_long";\
}\
##path/corner_long_alt {\
	icon_state = "trimline_corner_long_alt";\
}\
##path/filled {\
	icon_state = "trimline_box_fill";\
}\
##path/filled/line {\
	icon_state = "trimline_fill";\
}\
##path/filled/corner {\
	icon_state = "trimline_corner_fill";\
}\
##path/filled/end {\
	icon_state = "trimline_end_fill";\
}\
##path/filled/arrow_cw {\
	icon_state = "trimline_arrow_cw_fill";\
}\
##path/filled/arrow_ccw {\
	icon_state = "trimline_arrow_ccw_fill";\
}\
##path/filled/warning {\
	icon_state = "trimline_warn_fill";\
}\
##path/filled/warning/corner {\
	icon_state = "trimline_corner_warn_fill";\
}\
##path/filled/mid_joiner {\
	icon_state = "trimline_mid_fill";\
}\
##path/filled/shrink_cw {\
	icon_state = "trimline_shrink_cw";\
}\
##path/filled/shrink_ccw {\
	icon_state = "trimline_shrink_ccw";\
}

/obj/effect/turf_decal/trimline/dark_purple
	name = "dark purple trimline decal"
	color = "#A76DBF"

TRIMLINE_SUBTYPE_HELPER(/obj/effect/turf_decal/trimline/dark_purple)

/obj/effect/turf_decal/trimline/teal
	name = "teal trimline decal"
	color = "#325C4B"

TRIMLINE_SUBTYPE_HELPER(/obj/effect/turf_decal/trimline/teal)

#undef TRIMLINE_SUBTYPE_HELPER
