#define WATER_HEIGH_DIFFERENCE_SOUND_CHANCE 50
#define WATER_HEIGH_DIFFERENCE_DELTA_SPLASH 7 //Delta needed for the splash effect to be made in 1 go

#define REQUIRED_EVAPORATION_PROCESSES 80
#define EVAPORATION_CHANCE 30

/// Portion (out of 1) of reagents that are lost during the transfer from a mop/towel to a container.
#define SQUEEZING_DISPERSAL_RATIO 0.75

/// SSliquids fires per liquid fire run. It fires every second, so a fire run comes every 4 seconds.
#define REQUIRED_FIRE_PROCESSES 4
/// Power per unit a liquid mix must beat to burn. It sits low enough that weak drinks, at power 2, still light.
#define REQUIRED_FIRE_POWER_PER_UNIT 1
/// Share of a liquid mix that must be flammable for it to burn. Non-flammables smother a fire once they are half the mix.
#define REQUIRED_FIRE_FLAMMABLE_SHARE 0.5

// A liquid fire reaches a state only with both the power per unit and the flammable units listed for it.
// Power per unit caps how fierce the mix burns. The flammable units left shrink the fire as it burns out.
#define LIQUID_FIRE_POWER_MILD 2.5
#define LIQUID_FIRE_POWER_MEDIUM 4.5
#define LIQUID_FIRE_POWER_HUGE 6
#define LIQUID_FIRE_POWER_INFERNO 7.5
#define LIQUID_FIRE_UNITS_MILD 1.5
#define LIQUID_FIRE_UNITS_MEDIUM 3
#define LIQUID_FIRE_UNITS_HUGE 6
#define LIQUID_FIRE_UNITS_INFERNO 8

// Units of a reagent a burning tile uses up per fire run.
/// Fuels and strong spirits: 30 units on one tile burn out in a minute.
#define LIQUID_FIRE_BURNRATE_VOLATILE 2
/// Beer, wine and weak cocktails: 30 units on one tile flare out in about half a minute.
#define LIQUID_FIRE_BURNRATE_WEAK 4
/// Oils: 30 units on one tile burn for about ten minutes.
#define LIQUID_FIRE_BURNRATE_HEAVY 0.2
/// Tar: slower than oil, so 30 units on one tile burn for about twenty minutes.
#define LIQUID_FIRE_BURNRATE_TAR 0.1

/// Temperature a huge liquid fire exposes its tile to. The states below it run cooler.
#define LIQUID_FIRE_TEMPERATURE_HUGE 700
/// Temperature a liquid inferno exposes its tile to.
#define LIQUID_FIRE_TEMPERATURE_INFERNO 1000

/// Visual offset of the 48x48 fire art on both axes, centring it on its tile.
#define LIQUID_FIRE_PIXEL_OFFSET (-8)
/// Fire holders of each kind SSliquids keeps for reuse once their tiles stop burning: a 17x17 pool's worth.
#define LIQUID_FIRE_HOLDER_POOL_SIZE 300
/// How long a tile's ignite plays (25 frames of 0.4 ds). Its smoke starts when the ignite ends.
#define LIQUID_FIRE_IGNITE_TIME (1 SECONDS)

// Burning tiles light the floor one 2x2 block at a time: one light per block, at the centre of its burning tiles.
/// Light power of a burning block with big flames and no burning block around it.
#define LIQUID_FIRE_BLOCK_POWER 1.2
/// A block's power is divided by (1 + this x the burning blocks around it), so a big fire doesn't flatten into the light cap.
#define LIQUID_FIRE_BLOCK_SHARE 0.5
/// Light range of a block whose largest flames are big.
#define LIQUID_FIRE_BLOCK_RANGE_BIG 4
/// Light range of a block whose largest flames are medium.
#define LIQUID_FIRE_BLOCK_RANGE_MEDIUM 3
/// Light range of a block whose largest flames are small.
#define LIQUID_FIRE_BLOCK_RANGE_SMALL 3
/// Share of LIQUID_FIRE_BLOCK_POWER a block gives when its largest flames are big.
#define LIQUID_FIRE_BLOCK_POWER_BIG 1
/// Share of LIQUID_FIRE_BLOCK_POWER a block gives when its largest flames are medium.
#define LIQUID_FIRE_BLOCK_POWER_MEDIUM 0.7
/// Share of LIQUID_FIRE_BLOCK_POWER a block gives when its largest flames are small.
#define LIQUID_FIRE_BLOCK_POWER_SMALL 0.55

#define PARTIAL_TRANSFER_AMOUNT 0.3

#define LIQUID_MUTUAL_SHARE 1
#define LIQUID_NOT_MUTUAL_SHARE 2

#define LIQUID_GIVER 1
#define LIQUID_TAKER 2

//Required amount of a reagent to be simulated on turf exposures from liquids (to prevent gaming the system with cheap dillutions)
#define LIQUID_REAGENT_THRESHOLD_TURF_EXPOSURE 5

//Threshold at which the difference of height makes us need to climb/blocks movement/allows to fall down
#define TURF_HEIGHT_BLOCK_THRESHOLD 20

#define LIQUID_HEIGHT_DIVISOR 10

#define ONE_LIQUIDS_HEIGHT LIQUID_HEIGHT_DIVISOR

#define LIQUID_ATTRITION_TO_STOP_ACTIVITY 2

//Perceived heat capacity for calculations with atmos sharing
#define REAGENT_HEAT_CAPACITY		5

#define LIQUID_STATE_PUDDLE			1
#define LIQUID_STATE_ANKLES			2
#define LIQUID_STATE_WAIST			3
#define LIQUID_STATE_SHOULDERS		4
#define LIQUID_STATE_FULLTILE		5
#define TOTAL_LIQUID_STATES			5
#define LYING_DOWN_SUBMERGEMENT_STATE_BONUS			2

#define LIQUID_STATE_FOR_HEAT_EXCHANGERS LIQUID_STATE_WAIST

#define LIQUID_ANKLES_LEVEL_HEIGHT 8
#define LIQUID_WAIST_LEVEL_HEIGHT 19
#define LIQUID_SHOULDERS_LEVEL_HEIGHT 29
#define LIQUID_FULLTILE_LEVEL_HEIGHT 39

// Puddle surfaces, set per reagent by liquid_surface. A pool draws the class holding the most volume; ties go to the lower define.
#define LIQUID_SURFACE_CLEAR 1
#define LIQUID_SURFACE_OPAQUE 2
#define LIQUID_SURFACE_BLOOD 3
#define LIQUID_SURFACE_OIL 4
#define LIQUID_SURFACE_FUEL 5
#define LIQUID_SURFACE_MIRROR 6
#define LIQUID_SURFACE_TAR 7
/// How many LIQUID_SURFACE_* classes there are.
#define LIQUID_SURFACE_COUNT 7

// The pool's base art is one light grey, and each class's look was drawn over its own fill, so a pool's colour is its
// reagent mix times its class's factor.
/// Clear pools: a dark film, so a puddle darkens the floor instead of hazing it.
#define LIQUID_COLOR_FACTOR_CLEAR 0.322
/// Blood: a darker crimson under any blood colour.
#define LIQUID_COLOR_FACTOR_BLOOD 0.53
/// Opaque, oil, fuel, mirror and tar pools.
#define LIQUID_COLOR_FACTOR_OPAQUE 0.983

#define LIQUID_FIRE_STATE_NONE		0
#define LIQUID_FIRE_STATE_SMALL		1
#define LIQUID_FIRE_STATE_MILD		2
#define LIQUID_FIRE_STATE_MEDIUM	3
#define LIQUID_FIRE_STATE_HUGE		4
#define LIQUID_FIRE_STATE_INFERNO	5

//Threshold at which we "choke" on the water, instead of holding our breath
#define OXYGEN_DAMAGE_CHOKING_THRESHOLD 15

#define IMMUTABLE_LIQUID_SHARE 1

#define LIQUID_RECURSIVE_LOOP_SAFETY 100 //Hundred loops at maximum for adjacency checking

//Height at which we consider the tile "full" and dont drop liquids on it from the upper Z level
#define LIQUID_HEIGHT_CONSIDER_FULL_TILE 50

#define SSLIQUIDS_RUN_TYPE_TURFS 1
#define SSLIQUIDS_RUN_TYPE_GROUPS 2
#define SSLIQUIDS_RUN_TYPE_IMMUTABLES 3
#define SSLIQUIDS_RUN_TYPE_EVAPORATION 4
#define SSLIQUIDS_RUN_TYPE_FIRE 5
#define SSLIQUIDS_RUN_TYPE_FIRE_LIGHTS 6

#define LIQUID_GROUP_DECAY_TIME 3

//Scaled with how much a person is submerged
#define SUBMERGEMENT_REAGENTS_TOUCH_AMOUNT 60

#define CHOKE_REAGENTS_INGEST_ON_FALL_AMOUNT 4

#define CHOKE_REAGENTS_INGEST_ON_BREATH_AMOUNT 2

#define SUBMERGEMENT_PERCENT(carbon, liquids) min(1,(carbon.body_position == LYING_DOWN ? liquids.liquid_state+LYING_DOWN_SUBMERGEMENT_STATE_BONUS : liquids.liquid_state)/TOTAL_LIQUID_STATES)
