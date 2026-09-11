/// ## A bunch of turf subtypes used to really make this ruin work.

/// Define of the specific gas mix we want across all of the turfs.
// TEMP=T20C was a literal string, not the T20C define - text2num() on it always returned null,
// so these turfs were never actually room temperature. initial_gas_mix must be a compile-time
// constant, so the define can't be concatenated in (DM won't fold string+number or "[T20C]" as
// constant); this is T20C's literal value (code/__DEFINES/atmospherics/atmos_core.dm).
#define CO2_PRESSURIZED_MIX GAS_O2 + "=22;" + GAS_N2 + "=82;" + GAS_CO2 + "=500;TEMP=293.15"

/turf/open/floor/iron/co2_pressurized
	initial_gas_mix = CO2_PRESSURIZED_MIX

/turf/open/floor/iron/dark/co2_pressurized
	initial_gas_mix = CO2_PRESSURIZED_MIX

/turf/open/floor/iron/dark/corner/co2_pressurized
	initial_gas_mix = CO2_PRESSURIZED_MIX

/turf/open/floor/iron/dark/side/co2_pressurized
	initial_gas_mix = CO2_PRESSURIZED_MIX

/turf/open/floor/plating/co2_pressurized
	initial_gas_mix = CO2_PRESSURIZED_MIX

/turf/open/floor/engine/co2/equalized_with_regular_air // you come up with a better name and we can change this
	initial_gas_mix = CO2_PRESSURIZED_MIX

#undef CO2_PRESSURIZED_MIX
