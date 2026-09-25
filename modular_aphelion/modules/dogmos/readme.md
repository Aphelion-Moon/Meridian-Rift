# Dogmos integration

Module ID: `DOGMOS`

PR: https://github.com/Aphelion-Moon/Meridian-Rift/pull/138

Derived from [Putnam3145/auxmos](https://github.com/Putnam3145/auxmos); native maintenance is in [Aphelion-Dogmos](https://github.com/Aphelion-Moon/aphelion-dogmos).

This module initializes the in-process native gas registry, preserves controller recovery, schedules active turfs, and supplies gameplay and diagnostic adapters. Numerical state lives in the native engine inside DreamDaemon; DM retains scheduling and gameplay ownership.

Use [the in-process build contract](../../../docs/agent/dogmos-in-process.md), [integration ownership](../../../docs/agent/dogmos-integration.md) and [verification guide](../../../docs/agent/dogmos-verification.md). Native bindings and artifact defines are generated; never edit them by hand.


## Experimental mixture fusion

The `dogmos_mixture_fusion` startup flag is absent/off by default. Registration
requires the matching Aphelion native capability. It is a commissioning feature,
not a qualified recipe or an HFR replacement. The generated profile constants
come from the native `dogmos-core` fusion kernel. Native source documentation
`docs/agent/fusion-profile.md` records provisional values, provenance, accounting
and the remaining acceptance gates.

Eligible turfs, portable containers, tanks and pipelines use their existing
reaction processing. HFR-owned internal mixtures are explicitly excluded.
Hypernoblium and portable-container suppression retain their existing meaning.
One mixture admits at most one opportunity per two seconds, without catch-up;
existing processing owners remain awake while an eligible opportunity is waiting.
Changing the startup flag requires the normal shutdown/new-world lifecycle.

The gas analyzer reports current status and recent instability. Kennel's
on-demand inspection shows generic requirements, suppression/immutability,
holder status and the loaded profile/build identity. It never executes a reaction
body for inspection, and a requirement pass is not evidence of an earlier reaction.
No useful operating range or player recipe has yet been demonstrated.

## Modular ownership and integration

- `code/air.dm` owns the added SSair fields and bounded maintenance, settlement, initialization and health helpers. The shared chunk bound is `DOGMOS_ACTIVE_TURFS_WALK_BATCH_SIZE` in `code/__DEFINES/dogmos_defines.dm`.
- `code/dogmos_kennel.dm` and `code/dogmos_kennel_events.dm` own the Kennel datum, overlays, event history and diagnostics.
- `modular_aphelion/master_files/code/controllers/subsystem/air.dm` extends `Recover()` after its parent and preserves continuation, event and native graph state. It does not copy the inherited recovery implementation or reset the native arena.
- `modular_aphelion/master_files/code/controllers/configuration/entries/config_entries.dm` owns the locked `dogmos_async_stages` compatibility flag. It is retained for configuration compatibility; the in-process backend has no consumer for it.
- `code/controllers/subsystem/air.dm` retains marked integration into initialization, resumable stages, native-backed gas consumers, machine processing and UI data. These edits replace LINDA behavior or operate inside its hot loops; copying the inherited procs into overrides would hide upstream changes.
- The hand-maintained native constants are in `code/__DEFINES/dogmos_defines.dm`; bindings and contract defines remain generator-owned. The only atmosphere source exceptions are the gas-mixture and environmental simulation subtrees documented in the integration guide.
- Module includes are regenerated with `modular_aphelion/tools/update_module_includes.py --write`. The fusion tests are included by the unit-test harness, never directly by the DME. Native libraries, locks, and owned goggle assets retain their existing paths.
- The maintained include checker accepts named Aphelion/Nova addition records and normalizes Windows paths for Nova unit tests. `tools/ci/tests/test_ticked_file_markers.py` covers these forms while retaining missing-file and ordering failures.

### Core and cross-module change inventory

The following inherited files adapt their listed symbols to native gas access, Dogmos scheduling, gameplay callbacks or diagnostics. Inline records retain the upstream source for future merges. Nova-owned files remain in their original modules. This inventory supplements the detailed atmosphere ownership exception above.

| File | Changed symbols |
| --- | --- |
| `__odlint.dm` | `/proc/load_ext`, `file-level definitions` |
| `code/__DEFINES/atmospherics/atmos_core.dm` | `MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER`, `MOLES_CELLSTANDARD` |
| `code/__DEFINES/atmospherics/atmos_helpers.dm` | `CALCULATE_ADJACENT_TURFS`, `LINDA_CYCLE_ARCHIVE`, `PIPING_LAYER_DOUBLE_SHIFT`, `TURFS_CAN_SHARE`, `TURF_SHARES` |
| `code/__DEFINES/atmospherics/atmos_piping.dm` | `TANK_DEFAULT_RELEASE_PRESSURE`, `TANK_MAX_RELEASE_PRESSURE`, `TANK_PLASMAMAN_RELEASE_PRESSURE` |
| `code/__HELPERS/atmospherics.dm` | `/proc/gas_mixture_parser`, `/proc/print_gas_mixture` |
| `code/__HELPERS/logging/atmos.dm` | `/proc/log_atmos` |
| `code/__HELPERS/radiation.dm` | `/proc/get_perceived_radiation_danger` |
| `code/_globalvars/logging.dm` | `/world/proc/_initialize_log_files` |
| `code/controllers/master.dm` | `/datum/controller/master/Initialize`, `/datum/controller/master/proc/RunQueue` |
| `code/controllers/subsystem.dm` | `/datum/controller/subsystem`, `/datum/controller/subsystem/proc/pause`, `/datum/controller/subsystem/proc/pause_until_next_tick` |
| `code/controllers/subsystem/air.dm` | `/datum/controller/subsystem/air/Initialize`, `/datum/controller/subsystem/air/Recover`, `/datum/controller/subsystem/air/StopLoadingMap`, `/datum/controller/subsystem/air/fire`, `/datum/controller/subsystem/air/proc/add_to_active`, `/datum/controller/subsystem/air/proc/expand_pipeline`, `/datum/controller/subsystem/air/proc/parse_gas_string`, `/datum/controller/subsystem/air/proc/preprocess_gas_string`, `/datum/controller/subsystem/air/proc/process_active_turfs`, `/datum/controller/subsystem/air/proc/process_atmos_machinery`, `/datum/controller/subsystem/air/proc/process_atoms`, `/datum/controller/subsystem/air/proc/process_excited_groups`, `/datum/controller/subsystem/air/proc/process_high_pressure_delta`, `/datum/controller/subsystem/air/proc/process_hotspots`, `/datum/controller/subsystem/air/proc/process_pipenets`, `/datum/controller/subsystem/air/proc/process_super_conductivity`, `/datum/controller/subsystem/air/proc/remove_from_active`, `/datum/controller/subsystem/air/proc/setup_allturfs`, `/datum/controller/subsystem/air/proc/sleep_active_turf`, `/datum/controller/subsystem/air/proc/start_processing_machine`, `/datum/controller/subsystem/air/proc/stop_processing_machine`, `/datum/controller/subsystem/air/stat_entry`, `/datum/controller/subsystem/air/ui_act`, `/datum/controller/subsystem/air/ui_data`, `KENNEL_SLOW_MODE_PUSH_INTERVAL`, `SUBSYSTEM_DEF(air)`, `file-level definitions` |
| `code/controllers/subsystem/minor_mapping.dm` | `/datum/controller/subsystem/minor_mapping/proc/valid_mouse_turf` |
| `code/controllers/subsystem/time_track.dm` | `/datum/controller/subsystem/time_track/Initialize`, `/datum/controller/subsystem/time_track/fire` |
| `code/datums/atmosphere/_atmosphere.dm` | `/datum/atmosphere/proc/generate_gas_string` |
| `code/datums/components/grillable.dm` | `/datum/component/grillable/proc/on_location_changed` |
| `code/datums/components/rot.dm` | `/datum/component/rot/proc/rot_react` |
| `code/datums/components/wet_floor.dm` | `/datum/component/wet_floor/process` |
| `code/datums/diseases/advance/symptoms/heal.dm` | `/datum/symptom/heal/plasma/CanHeal` |
| `code/datums/diseases/floor_diseases/gastritium.dm` | `/datum/disease/gastritium/proc/tritium_burp` |
| `code/datums/elements/atmos_requirements.dm` | `/datum/element/atmos_requirements/proc/get_atmos_req_list` |
| `code/datums/elements/atmos_sensitive.dm` | `/atom/proc/process_exposure`, `/turf/open/process_exposure` |
| `code/datums/elements/death_gases.dm` | `/datum/element/death_gases/proc/on_death` |
| `code/datums/elements/frozen.dm` | `/datum/element/frozen/proc/on_moved` |
| `code/datums/helper_datums/teleport.dm` | `/proc/find_safe_turf`, `/proc/is_safe_turf` |
| `code/datums/mutations/olfaction.dm` | `/datum/action/cooldown/spell/olfaction/cast` |
| `code/datums/status_effects/debuffs/fire_stacks.dm` | `/datum/status_effect/fire_handler/fire_stacks/tick` |
| `code/game/machinery/computer/atmos_computers/_atmos_control.dm` | `/obj/machinery/computer/atmos_control/ui_act` |
| `code/game/machinery/dna_infuser/organ_sets/fish_organs.dm` | `/obj/item/organ/lungs/proc/on_low_water` |
| `code/game/machinery/doors/firedoor.dm` | `/obj/machinery/door/firedoor`, `/obj/machinery/door/firedoor/Destroy`, `/obj/machinery/door/firedoor/post_machine_initialize`, `/obj/machinery/door/firedoor/proc/activate`, `/obj/machinery/door/firedoor/proc/check_atmos`, `/obj/machinery/door/firedoor/proc/process_results`, `/obj/machinery/door/firedoor/process`, `/obj/structure/firelock_frame/border_only/CanPass`, `FIRELOCK_ATMOS_RECHECK_INTERVAL`, `FIRELOCK_MIN_ALARM_HOLD`, `REACTIVATION_DELAY` |
| `code/game/machinery/spaceheater.dm` | `/obj/machinery/space_heater/process_atmos`, `/obj/machinery/space_heater/ui_data` |
| `code/game/objects/effects/effect_system/fluid_spread/effects_foam.dm` | `/obj/effect/particle_effect/fluid/foam/firefighting/process`, `/obj/structure/foamedmetal/resin/Initialize` |
| `code/game/objects/effects/effect_system/fluid_spread/effects_smoke.dm` | `/datum/effect_system/fluid_spread/smoke/freezing/proc/chill_turf` |
| `code/game/objects/effects/spawners/bombspawner.dm` | `/obj/effect/spawner/newbomb/isolated_tritium/Initialize`, `/obj/effect/spawner/newbomb/noblium/Initialize`, `/obj/effect/spawner/newbomb/plasma/Initialize`, `/obj/effect/spawner/newbomb/pressure/Initialize`, `/obj/effect/spawner/newbomb/proc/calculate_pressure`, `/obj/effect/spawner/newbomb/tritium/Initialize` |
| `code/game/objects/items/cigarettes.dm` | `/obj/item/match/fire_act` |
| `code/game/objects/items/devices/powersink.dm` | `/obj/item/powersink/proc/release_heat` |
| `code/game/objects/items/devices/scanners/gas_analyzer.dm` | `/obj/item/analyzer/proc/collect_scan_info`, `/proc/atmos_scan` |
| `code/game/objects/items/devices/transfer_valve.dm` | `/obj/item/transfer_valve/proc/merge_gases`, `/obj/item/transfer_valve/proc/split_gases` |
| `code/game/objects/items/tanks/jetpack.dm` | `/obj/item/tank/jetpack/populate_gas` |
| `code/game/objects/items/tanks/tank_types.dm` | `/obj/item/tank/internals/anesthetic/populate_gas`, `/obj/item/tank/internals/emergency_oxygen/engi/clown/bz/populate_gas`, `/obj/item/tank/internals/emergency_oxygen/engi/clown/helium/populate_gas`, `/obj/item/tank/internals/emergency_oxygen/engi/clown/n2o/populate_gas`, `/obj/item/tank/internals/emergency_oxygen/populate_gas`, `/obj/item/tank/internals/oxygen/populate_gas`, `/obj/item/tank/internals/plasma/full/populate_gas`, `/obj/item/tank/internals/plasma/populate_gas`, `/obj/item/tank/internals/plasmaman/belt/full/populate_gas`, `/obj/item/tank/internals/plasmaman/full/populate_gas`, `/obj/item/tank/internals/plasmaman/populate_gas` |
| `code/game/objects/items/tanks/tanks.dm` | `/obj/item/tank/Initialize`, `/obj/item/tank/atom_destruction`, `/obj/item/tank/examine`, `/obj/item/tank/proc/ignite`, `/obj/item/tank/proc/remove_air_volume`, `/obj/item/tank/process`, `/obj/item/tank/welder_act` |
| `code/game/objects/items/weaponry/ranged/flamethrower.dm` | `/obj/item/flamethrower/proc/default_ignite`, `/obj/item/flamethrower/proc/flame_turf`, `/obj/item/flamethrower/proc/instant_refill` |
| `code/game/objects/obj_defense.dm` | `/obj/ex_act`, `/obj/fire_act`, `/obj/hitby`, `file-level definitions` |
| `code/game/objects/structures/bonfire.dm` | `/obj/structure/bonfire/proc/check_oxygen` |
| `code/game/objects/structures/crates_lockers/closets/bodybag.dm` | `/obj/structure/closet/body_bag/environmental/prisoner/pressurized/syndicate/refresh_air`, `/obj/structure/closet/body_bag/environmental/proc/refresh_air`, `/obj/structure/closet/body_bag/environmental/stasis/refresh_air` |
| `code/game/objects/structures/crates_lockers/closets/secure/freezer.dm` | `/obj/structure/closet/secure_closet/freezer/process_internal_air` |
| `code/game/objects/structures/crates_lockers/crates.dm` | `/obj/structure/closet/crate/freezer/process_internal_air` |
| `code/game/objects/structures/morgue.dm` | `/obj/structure/bodycontainer/morgue/process` |
| `code/game/objects/structures/toiletbong.dm` | `/obj/structure/toiletbong/crowbar_act` |
| `code/game/objects/structures/transit_tubes/transit_tube_pod.dm` | `/obj/structure/transit_tube_pod/Initialize`, `/obj/structure/transit_tube_pod/return_temperature` |
| `code/game/turfs/change_turf.dm` | `/turf/open/AfterChange`, `/turf/open/proc/Assimilate_Air`, `/turf/proc/AfterChange`, `/turf/proc/TerraformTurf` |
| `code/game/turfs/open/_open.dm` | `/turf/open`, `/turf/open/GetTemperature`, `/turf/open/TakeTemperature` |
| `code/game/turfs/open/space/space.dm` | `/turf/open/space` |
| `code/game/turfs/open/space/space_EXPENSIVE.dm` | `/turf/open/space/Initialize` |
| `code/game/turfs/turf.dm` | `/turf/proc/GetTemperature`, `/turf/proc/TakeTemperature` |
| `code/modules/admin/admin_verbs.dm` | `/client/proc/disable_stealth_mode` |
| `code/modules/admin/verbs/fix_air.dm` | `file-level definitions` |
| `code/modules/antagonists/heretic/items/corrupted_organs.dm` | `/obj/item/organ/lungs/corrupt/check_breath` |
| `code/modules/antagonists/heretic/knowledge/void_lore.dm` | `/datum/heretic_knowledge/ultimate/void_final/proc/on_life` |
| `code/modules/assembly/igniter.dm` | `/obj/item/assembly/igniter/condenser/activate` |
| `code/modules/atmospherics/machinery/air_alarm/_air_alarm.dm` | `/obj/machinery/airalarm/proc/check_danger`, `/obj/machinery/airalarm/proc/check_enviroment`, `/obj/machinery/airalarm/ui_data` |
| `code/modules/atmospherics/machinery/air_alarm/air_alarm_circuit.dm` | `/obj/item/circuit_component/air_alarm/input_received` |
| `code/modules/atmospherics/machinery/atmosmachinery.dm` | `/atom/movable/atmos_conditions_changed`, `/obj/machinery/atmospherics`, `/obj/machinery/atmospherics/on_set_is_operational`, `/obj/machinery/atmospherics/proc/set_on`, `/turf/open/atmos_conditions_changed` |
| `code/modules/atmospherics/machinery/components/binary_devices/circulator.dm` | `/obj/machinery/atmospherics/components/binary/circulator/proc/return_transfer_air` |
| `code/modules/atmospherics/machinery/components/binary_devices/dp_vent_pump.dm` | `/obj/machinery/atmospherics/components/binary/dp_vent_pump/high_volume/Initialize`, `/obj/machinery/atmospherics/components/binary/dp_vent_pump/process_atmos` |
| `code/modules/atmospherics/machinery/components/binary_devices/pump.dm` | `/obj/machinery/atmospherics/components/binary/pump/process_atmos`, `/obj/machinery/atmospherics/components/binary/pump/update_icon_nopipes` |
| `code/modules/atmospherics/machinery/components/binary_devices/temperature_gate.dm` | `/obj/machinery/atmospherics/components/binary/temperature_gate/process_atmos` |
| `code/modules/atmospherics/machinery/components/binary_devices/temperature_pump.dm` | `/obj/machinery/atmospherics/components/binary/temperature_pump/process_atmos` |
| `code/modules/atmospherics/machinery/components/binary_devices/volume_pump.dm` | `/obj/machinery/atmospherics/components/binary/volume_pump/process_atmos` |
| `code/modules/atmospherics/machinery/components/components_base.dm` | `/obj/machinery/atmospherics/components/Initialize`, `/obj/machinery/atmospherics/components/proc/crowbar_deconstruction_act`, `/obj/machinery/atmospherics/components/proc/relocate_airs` |
| `code/modules/atmospherics/machinery/components/electrolyzer/electrolyzer_reactions.dm` | `/datum/gas_reaction/electrolyzer/h2o_conversion/react`, `/datum/gas_reaction/electrolyzer/halon_generation/react`, `/datum/gas_reaction/electrolyzer/nob_conversion/react`, `/datum/gas_reaction/electrolyzer/proc/reaction_check` |
| `code/modules/atmospherics/machinery/components/fusion/hfr_core.dm` | `/obj/machinery/atmospherics/components/unary/hypertorus/core/Initialize` |
| `code/modules/atmospherics/machinery/components/fusion/hfr_main_processes.dm` | `/obj/machinery/atmospherics/components/unary/hypertorus/core/proc/fusion_process`, `/obj/machinery/atmospherics/components/unary/hypertorus/core/proc/inject_from_side_components`, `/obj/machinery/atmospherics/components/unary/hypertorus/core/proc/moderator_common_process`, `/obj/machinery/atmospherics/components/unary/hypertorus/core/proc/process_internal_cooling`, `/obj/machinery/atmospherics/components/unary/hypertorus/core/proc/remove_waste`, `/obj/machinery/atmospherics/components/unary/hypertorus/core/process_atmos` |
| `code/modules/atmospherics/machinery/components/fusion/hfr_parts.dm` | `/obj/machinery/hypertorus/interface/ui_act`, `/obj/machinery/hypertorus/interface/ui_data` |
| `code/modules/atmospherics/machinery/components/fusion/hfr_procs.dm` | `/obj/machinery/atmospherics/components/unary/hypertorus/core/proc/check_fuel`, `/obj/machinery/atmospherics/components/unary/hypertorus/core/proc/check_gas_requirements`, `/obj/machinery/atmospherics/components/unary/hypertorus/core/proc/deactivate`, `/obj/machinery/atmospherics/components/unary/hypertorus/core/proc/dump_gases`, `/obj/machinery/atmospherics/components/unary/hypertorus/core/proc/update_temperature_status` |
| `code/modules/atmospherics/machinery/components/gas_recipe_machines/crystallizer.dm` | `/obj/machinery/atmospherics/components/binary/crystallizer/proc/check_temp_requirements`, `/obj/machinery/atmospherics/components/binary/crystallizer/proc/dump_gases`, `/obj/machinery/atmospherics/components/binary/crystallizer/proc/heat_calculations`, `/obj/machinery/atmospherics/components/binary/crystallizer/proc/heat_conduction`, `/obj/machinery/atmospherics/components/binary/crystallizer/proc/inject_gases`, `/obj/machinery/atmospherics/components/binary/crystallizer/proc/internal_check`, `/obj/machinery/atmospherics/components/binary/crystallizer/process_atmos`, `/obj/machinery/atmospherics/components/binary/crystallizer/ui_data` |
| `code/modules/atmospherics/machinery/components/tank.dm` | `/obj/machinery/atmospherics/components/tank/Initialize`, `/obj/machinery/atmospherics/components/tank/proc/fill_to_pressure`, `/obj/machinery/atmospherics/components/tank/proc/merger_refresh_complete`, `/obj/machinery/atmospherics/components/tank/process_atmos` |
| `code/modules/atmospherics/machinery/components/trinary_devices/filter.dm` | `/obj/machinery/atmospherics/components/trinary/filter/process_atmos`, `/obj/machinery/atmospherics/components/trinary/filter/update_icon_nopipes` |
| `code/modules/atmospherics/machinery/components/trinary_devices/mixer.dm` | `/obj/machinery/atmospherics/components/trinary/mixer/Initialize`, `/obj/machinery/atmospherics/components/trinary/mixer/process_atmos` |
| `code/modules/atmospherics/machinery/components/unary_devices/airlock_pump.dm` | `/obj/machinery/atmospherics/components/unary/airlock_pump/Initialize`, `/obj/machinery/atmospherics/components/unary/airlock_pump/proc/fill_tile`, `/obj/machinery/atmospherics/components/unary/airlock_pump/proc/siphon_tile` |
| `code/modules/atmospherics/machinery/components/unary_devices/cryo.dm` | `/obj/machinery/cryo_cell/handle_internal_lifeform`, `/obj/machinery/cryo_cell/process_atmos`, `/obj/machinery/cryo_cell/return_temperature`, `/obj/machinery/cryo_cell/ui_data` |
| `code/modules/atmospherics/machinery/components/unary_devices/heat_exchanger.dm` | `/obj/machinery/atmospherics/components/unary/heat_exchanger/process_atmos` |
| `code/modules/atmospherics/machinery/components/unary_devices/machine_connector.dm` | `/datum/gas_machine_connector/New` |
| `code/modules/atmospherics/machinery/components/unary_devices/outlet_injector.dm` | `/obj/machinery/atmospherics/components/unary/outlet_injector/process_atmos` |
| `code/modules/atmospherics/machinery/components/unary_devices/passive_vent.dm` | `/obj/machinery/atmospherics/components/unary/passive_vent/process_atmos` |
| `code/modules/atmospherics/machinery/components/unary_devices/portables_connector.dm` | `/obj/machinery/atmospherics/components/unary/portables_connector/Initialize` |
| `code/modules/atmospherics/machinery/components/unary_devices/thermomachine.dm` | `/obj/machinery/atmospherics/components/unary/thermomachine/process_atmos`, `/obj/machinery/atmospherics/components/unary/thermomachine/ui_data` |
| `code/modules/atmospherics/machinery/components/unary_devices/vent_pump.dm` | `/obj/machinery/atmospherics/components/unary/vent_pump`, `/obj/machinery/atmospherics/components/unary/vent_pump/high_volume/Initialize`, `/obj/machinery/atmospherics/components/unary/vent_pump/proc/toggle_overclock`, `/obj/machinery/atmospherics/components/unary/vent_pump/process_atmos` |
| `code/modules/atmospherics/machinery/components/unary_devices/vent_scrubber.dm` | `/obj/machinery/atmospherics/components/unary/vent_scrubber/proc/scrub`, `/obj/machinery/atmospherics/components/unary/vent_scrubber/should_atmos_process` |
| `code/modules/atmospherics/machinery/datum_pipeline.dm` | `/datum/pipeline/Destroy`, `/datum/pipeline/proc/CalculateGasmixColor`, `/datum/pipeline/proc/add_member`, `/datum/pipeline/proc/build_pipeline`, `/datum/pipeline/proc/build_pipeline_blocking`, `/datum/pipeline/proc/merge`, `/datum/pipeline/proc/reconcile_air`, `/datum/pipeline/proc/temperature_interact`, `/datum/pipeline/proc/temporarily_store_air`, `/datum/pipeline/process` |
| `code/modules/atmospherics/machinery/other/meter.dm` | `/datum/armor/machinery_meter`, `/obj/item/circuit_component/atmos_meter/proc/request_meter_data`, `/obj/machinery/meter/Destroy`, `/obj/machinery/meter/proc/reattach_to_layer`, `/obj/machinery/meter/proc/status`, `/obj/machinery/meter/process_atmos` |
| `code/modules/atmospherics/machinery/other/miner.dm` | `/obj/machinery/atmospherics/miner/proc/mine_gas` |
| `code/modules/atmospherics/machinery/pipes/heat_exchange/he_pipes.dm` | `/obj/machinery/atmospherics/pipe/heat_exchanging`, `/obj/machinery/atmospherics/pipe/heat_exchanging/Initialize`, `/obj/machinery/atmospherics/pipe/heat_exchanging/is_connectable`, `/obj/machinery/atmospherics/pipe/heat_exchanging/post_buckle_mob`, `/obj/machinery/atmospherics/pipe/heat_exchanging/process`, `/obj/machinery/atmospherics/pipe/heat_exchanging/process_atmos` |
| `code/modules/atmospherics/machinery/pipes/pipes.dm` | `/obj/machinery/atmospherics/pipe`, `/obj/machinery/atmospherics/pipe/proc/set_volume` |
| `code/modules/atmospherics/machinery/portable/canister.dm` | `/obj/machinery/portable_atmospherics/canister/air/create_gas`, `/obj/machinery/portable_atmospherics/canister/anesthetic_mix/create_gas`, `/obj/machinery/portable_atmospherics/canister/fusion_test/create_gas`, `/obj/machinery/portable_atmospherics/canister/proc/create_gas`, `/obj/machinery/portable_atmospherics/canister/proc/toggle_valve` |
| `code/modules/atmospherics/machinery/portable/pipe_scrubber.dm` | `/obj/machinery/portable_atmospherics/pipe_scrubber/proc/scrub` |
| `code/modules/atmospherics/machinery/portable/portable_atmospherics.dm` | `/obj/machinery/portable_atmospherics/Initialize`, `/obj/machinery/portable_atmospherics/proc/take_atmos_damage`, `/obj/machinery/portable_atmospherics/process_atmos` |
| `code/modules/atmospherics/machinery/portable/pump.dm` | `/obj/machinery/portable_atmospherics/pump/ui_act` |
| `code/modules/atmospherics/machinery/portable/scrubber.dm` | `/obj/machinery/portable_atmospherics/scrubber/proc/scrub` |
| `code/modules/cargo/bounties/atmos.dm` | `/datum/bounty/item/atmospherics/applies_to`, `/datum/bounty/item/atmospherics/contribution_amount` |
| `code/modules/cargo/exports/large_objects.dm` | `/datum/export/gas_canister/get_base_cost` |
| `code/modules/clothing/masks/gas_filter.dm` | `/obj/item/gas_filter/proc/reduce_filter_status` |
| `code/modules/error_handler/error_handler.dm` | `/world/Error`, `file-level definitions` |
| `code/modules/events/space_vines/vine_mutations.dm` | `/datum/spacevine_mutation/gas_eater/process_mutation`, `/datum/spacevine_mutation/temp_stabilisation/additional_atmos_processes` |
| `code/modules/fishing/fish/_fish.dm` | `/obj/item/fish/proc/proper_environment` |
| `code/modules/fishing/fish/fish_traits.dm` | `/datum/fish_trait/emulsijack/proc/on_non_stasis_life` |
| `code/modules/fishing/fish/types/rift.dm` | `/obj/item/fish/dolphish/do_fish_process`, `/obj/item/fish/gullion/suicide_act` |
| `code/modules/holodeck/holo_effect.dm` | `/obj/effect/holodeck_effect/sparks/activate` |
| `code/modules/hydroponics/unique_plant_genes.dm` | `/datum/plant_gene/trait/gas_production/process` |
| `code/modules/mapfluff/ruins/spaceruin_code/atmos_asteroid.dm` | `CO2_PRESSURIZED_MIX`, `file-level definitions` |
| `code/modules/mapping/map_template.dm` | `/datum/map_template/proc/initTemplateBounds`, `/datum/map_template/proc/preload_size` |
| `code/modules/mob/living/basic/guardian/guardian_types/gaseous.dm` | `/datum/action/cooldown/mob_cooldown/expel_gas/proc/on_life` |
| `code/modules/mob/living/basic/slime/life.dm` | `/mob/living/basic/slime/proc/handle_slime_stasis` |
| `code/modules/mob/living/basic/space_fauna/regal_rat/regal_rat.dm` | `/mob/living/basic/regal_rat/handle_environment` |
| `code/modules/mob/living/basic/tree.dm` | `/mob/living/basic/tree/Life` |
| `code/modules/mob/living/carbon/alien/life.dm` | `/mob/living/carbon/alien/check_breath` |
| `code/modules/mob/living/carbon/human/_species.dm` | `/datum/species/proc/handle_gas_interaction` |
| `code/modules/mob/living/carbon/life.dm` | `/mob/living/carbon/proc/check_breath`, `/mob/living/carbon/proc/handle_breath_temperature` |
| `code/modules/mob/living/living.dm` | `/mob/living/proc/get_temperature` |
| `code/modules/mob/mob.dm` | `/atom/proc/prepare_huds` |
| `code/modules/mod/modules/modules_maint.dm` | `/obj/item/mod/module/springlock/proc/on_wearer_exposed_gas` |
| `code/modules/mod/modules/modules_timeline.dm` | `/obj/structure/chrono_field/return_air` |
| `code/modules/power/supermatter/supermatter.dm` | `/obj/machinery/power/supermatter_crystal/proc/calculate_damage`, `/obj/machinery/power/supermatter_crystal/proc/calculate_gases`, `/obj/machinery/power/supermatter_crystal/proc/calculate_internal_energy`, `/obj/machinery/power/supermatter_crystal/proc/get_status`, `/obj/machinery/power/supermatter_crystal/proc/sm_ui_data`, `/obj/machinery/power/supermatter_crystal/process_atmos` |
| `code/modules/power/supermatter/supermatter_extra_effects.dm` | `/obj/machinery/power/supermatter_crystal/proc/handle_high_power` |
| `code/modules/power/supermatter/supermatter_gas.dm` | `/datum/sm_gas/carbon_dioxide/extra_effects`, `/datum/sm_gas/miasma/extra_effects` |
| `code/modules/power/thermoelectric_generator.dm` | `/obj/machinery/power/thermoelectric_generator/process_atmos`, `/obj/machinery/power/thermoelectric_generator/ui_data` |
| `code/modules/power/turbine/turbine.dm` | `/obj/machinery/power/turbine/Initialize`, `/obj/machinery/power/turbine/core_rotor/process`, `/obj/machinery/power/turbine/inlet_compressor/proc/compress_gases`, `/obj/machinery/power/turbine/proc/transfer_gases` |
| `code/modules/power/turbine/turbine_computer.dm` | `/obj/machinery/computer/turbine_computer/ui_data` |
| `code/modules/reagents/chemistry/reagents/food_reagents.dm` | `/datum/reagent/consumable/frostoil/expose_turf`, `/datum/reagent/consumable/nutriment/fat/expose_turf` |
| `code/modules/reagents/chemistry/reagents/other_reagents.dm` | `/datum/reagent/water/expose_turf` |
| `code/modules/reagents/chemistry/reagents/pyrotechnic_reagents.dm` | `/datum/reagent/firefighting_foam/expose_turf` |
| `code/modules/reagents/chemistry/recipes.dm` | `/datum/chemical_reaction/proc/freeze_radius` |
| `code/modules/reagents/reagent_containers.dm` | `/obj/item/reagent_containers/proc/reagent_container_sound_chain` |
| `code/modules/recycling/disposal/bin.dm` | `/obj/machinery/disposal/bin/process` |
| `code/modules/research/anomaly/anomaly_refinery.dm` | `/obj/machinery/research/anomaly_refinery/proc/simulate_valve` |
| `code/modules/research/experimentor/experiments.dm` | `/datum/experimentor_result_handler/scan/cold/handle_malfunctions`, `/datum/experimentor_result_handler/scan/heat/handle_malfunctions` |
| `code/modules/research/ordnance/tank_compressor.dm` | `/obj/machinery/atmospherics/components/binary/tank_compressor/proc/record_data`, `/obj/machinery/atmospherics/components/binary/tank_compressor/process_atmos` |
| `code/modules/research/techweb/nodes/engi_nodes.dm` | `/datum/techweb_node/energy_manipulation` |
| `code/modules/research/xenobiology/crossbreeding/chilling.dm` | `/obj/item/slimecross/chilling/darkpurple/do_effect` |
| `code/modules/shuttle/mobile_port/shuttle_move.dm` | `/obj/docking_port/mobile/proc/cleanup_runway` |
| `code/modules/shuttle/mobile_port/shuttle_move_callbacks.dm` | `/turf/proc/onShuttleMove` |
| `code/modules/shuttle/mobile_port/variants/supply.dm` | `/obj/docking_port/mobile/supply/proc/refill_air` |
| `code/modules/surgery/bodyparts/bodypart_effects/plasma_based.dm` | `/datum/status_effect/grouped/bodypart_effect/plasma_based/tick` |
| `code/modules/surgery/organs/_organ.dm` | `/obj/item/organ/proc/on_death` |
| `code/modules/surgery/organs/internal/lungs/_lungs.dm` | `/obj/item/organ/lungs`, `/obj/item/organ/lungs/ethereal/proc/consume_water`, `/obj/item/organ/lungs/lavaland/Initialize`, `/obj/item/organ/lungs/on_mob_remove`, `/obj/item/organ/lungs/proc/breathe_gas_volume`, `/obj/item/organ/lungs/proc/breathe_nitro`, `/obj/item/organ/lungs/proc/breathe_oxygen`, `/obj/item/organ/lungs/proc/breathe_plasma`, `/obj/item/organ/lungs/proc/check_breath`, `/obj/item/organ/lungs/proc/handle_breath_temperature`, `/obj/item/organ/lungs/proc/too_much_oxygen`, `/obj/item/organ/lungs/proc/too_much_plasma`, `/obj/item/organ/lungs/slime/check_breath` |
| `code/modules/unit_tests/_unit_tests.dm` | `EASY_ALLOCATE` |
| `code/modules/unit_tests/breath.dm` | `/datum/unit_test/breath/breath_sanity/Run`, `/datum/unit_test/breath/breath_sanity_plasmamen/Run` |
| `code/modules/unit_tests/gas_transfer.dm` | `/datum/unit_test/atmospheric_gas_transfer/proc/nob_to_trit` |
| `code/modules/unit_tests/lungs.dm` | `/datum/unit_test/lungs/proc/create_gas_mix`, `GET_MOLES` |
| `code/modules/unit_tests/unit_test.dm` | `/datum/unit_test/proc/allocate`, `/datum/unit_test/proc/allocate_turf_pair`, `/datum/unit_test/proc/convert_neighbor_to_space`, `/datum/unit_test/proc/restore_atmos`, `/datum/unit_test/proc/restore_neighbor_from_space`, `/datum/unit_test/proc/resync_turf_for_dogmos`, `/proc/RunUnitTest`, `/proc/RunUnitTests` |
| `code/modules/vehicles/mecha/_mecha.dm` | `/obj/vehicle/sealed/mecha/proc/process_cabin_air`, `/obj/vehicle/sealed/mecha/proc/process_internal_damage_effects` |
| `code/modules/vehicles/mecha/equipment/tools/air_tank.dm` | `/obj/item/mecha_parts/mecha_equipment/air_tank/Initialize` |
| `code/modules/vehicles/mecha/mecha_ui.dm` | `/obj/vehicle/sealed/mecha/ui_data` |
| `code/modules/wiremod/components/sensors/tempsensor.dm` | `/obj/item/circuit_component/tempsensor/input_received` |
| `modular_nova/master_files/code/modules/reagents/chemistry/reagents/other_reagents.dm` | `/datum/reagent/space_cleaner/sterilizine/expose_turf` |
| `modular_nova/modules/RBMK2/code/reactor.dm` | `/obj/machinery/power/rbmk2/proc/transfer_rod_temperature`, `/obj/machinery/power/rbmk2/ui_data`, `/obj/machinery/power/rbmk2/update_overlays` |
| `modular_nova/modules/RBMK2/code/reactor_processing.dm` | `/obj/machinery/power/rbmk2/process`, `/obj/machinery/power/rbmk2/process_atmos` |
| `modular_nova/modules/RBMK2/code/reactor_rod.dm` | `/obj/item/tank/rbmk2_rod/preloaded/populate_gas`, `/obj/item/tank/rbmk2_rod/random_tritium/populate_gas` |
| `modular_nova/modules/ashwalkers/code/buildings/planttank.dm` | `/obj/structure/plant_tank/process` |
| `modular_nova/modules/bluespace_miner/code/bluespace_miner.dm` | `/obj/machinery/bluespace_miner/proc/update_mining_stat`, `/obj/machinery/bluespace_miner/process` |
| `modular_nova/modules/colony_fabricator/code/appliances/co2_cracker.dm` | `/datum/cracker_reaction/co2_cracking/react`, `/datum/cracker_reaction/proc/reaction_check`, `/obj/machinery/electrolyzer/co2_cracker/RefreshParts` |
| `modular_nova/modules/colony_fabricator/code/machines/stirling_generator.dm` | `/obj/machinery/power/stirling_generator/process_atmos` |
| `modular_nova/modules/customization/game/objects/items/tanks/n2_tanks.dm` | `/obj/item/tank/internals/nitrogen/belt/emergency/populate_gas`, `/obj/item/tank/internals/nitrogen/belt/full/populate_gas`, `/obj/item/tank/internals/nitrogen/full/populate_gas`, `/obj/item/tank/internals/nitrogen/populate_gas` |
| `modular_nova/modules/delam_emergency_stop/code/scram.dm` | `/obj/machinery/atmospherics/components/unary/delam_scram/Initialize`, `/obj/machinery/atmospherics/components/unary/delam_scram/process_atmos` |
| `modular_nova/modules/primitive_catgirls/code/organs.dm` | `/obj/item/organ/lungs/icebox_adapted/Initialize` |
| `modular_nova/modules/space_vines/vine_mutations.dm` | `/datum/spacevine_mutation/carbon_recycling/process_mutation` |
| `modular_nova/modules/xenoarchartifacts/artifacts/artifact_machine.dm` | `/obj/machinery/artifact/process` |
| `modular_nova/modules/xenoarchartifacts/effects/gas.dm` | `/datum/artifact_effect/gas/proc/assume_gas` |
| `modular_nova/modules/xenoarchartifacts/effects/temperature.dm` | `/datum/artifact_effect/temperature/cold/do_effect_aura`, `/datum/artifact_effect/temperature/cold/do_effect_destroy`, `/datum/artifact_effect/temperature/cold/do_effect_touch`, `/datum/artifact_effect/temperature/heat/do_effect_aura`, `/datum/artifact_effect/temperature/heat/do_effect_destroy`, `/datum/artifact_effect/temperature/heat/do_effect_touch` |

## Diagnostics and cycle ownership

`SSair.diagnostics` owns bounded Kennel histories, weak pin membership, cost/jump
indices and diagnostic policy. Subsystem recovery transfers this single datum.
The stable SSair explosion and reaction-cost callbacks are thin adapters; native
reaction profiling reads policy from the diagnostics owner. This dependency is
part of the source-bound native/game pairing. Diagnostics are not independently scheduled.

Each Kennel UI owns its selected tab and browse request. Overview and hidden
machinery panels do not build browse results. A page inspects at most 250 registry
candidates once, filters within that page, and caches until an explicit page,
search or tab action. Page counts describe candidate ranges; match counts describe
the current page. Process metrics are sampled at most once per second across viewers.
Slow mode changes diagnostic cadence only. Permanent manual pins override automatic
expiry; overlay membership survives co-located pin removal, movement and deletion.

| Active-turf phase | Completion / next phase |
| --- | --- |
| `DOGMOS_ACTIVE_MAINTENANCE` | Walk the active list with its resume cursor and chunk boundary, then select native work. |
| `DOGMOS_ACTIVE_NATIVE` | Complete selected native stages, then settle callbacks and visuals. |
| `DOGMOS_ACTIVE_SETTLEMENT` | Drain bounded callbacks and visual work before the cycle advances. |

Equalization dispatch and asynchronous heat-worker completion are independent
states. Their flags and required cursors remain separate. Chunk boundaries are
iteration bounds, not external-worker prefetch state. `REALTIMEOFDAY` already
accounts for midnight rollover and remains the elapsed-time source.

## Dormant machinery wake ownership

| Device / path | Wake and cleanup coverage |
| --- | --- |
| Atmos components (including pressure pumps) | `set_on` and control changes start processing; pipeline `update_reconcile` wakes components after gas/network changes. Machinery area power handling and node rebuilds remain in the existing owners. |
| Heat-exchange pipes | Opt into both turf-atmos and pipeline wakes; initialization starts processing. Turf registration/adjacency and pipeline rebuilds own relocation/topology effects. |
| Pipe meters | `set_target` registers once on the target pipe's lazy meter list; pipeline reconciliation wakes meters. Target QDELETING drops registration; retargeting unregisters the old pipe. |
| Firelocks | Existing close/hold polling remains. No claim that an equivalent complete signal-only wake path exists. |

This pass changes the phase representation and meter allocation, not dormant-device
behavior. Existing gas, frontier, lifetime, topology and machinery tests remain the
acceptance route. Keep their runtime results distinct from this source-level matrix.

Native teardown occurs immediately before the terminal world deletion/reboot,
after yielding shutdown work. `Master.Shutdown()` alone is not that boundary:
asynchronous map work can still resume, and `FinishTestRun()` yields before deleting
the world. Releasing the native arenas in a subsystem Shutdown hook would reject
those still-valid callers. The terminal helper is idempotent and retains the native
shutdown admission guard.

Fusion tests remain in the existing unit-test-only include route. The experimental
feature stays default-off; its source is retained while a separate feature review
and qualified recipe remain outstanding.
