# About Dogmos

Dogmos is Meridian Rift's atmospheric simulation backend. Dream Maker owns subsystem scheduling,
machinery, gameplay effects, and the public gas-mixture API. The Rust engine owns gas-mixture
storage and performs the repeated numerical work for turf flow, reactions, pressure equalization,
and blocked-path heat conduction.

The Dogmos Kennel is an operational dashboard for that integration. It reports current subsystem
state, bounded event histories, process memory snapshots, configuration controls, and optional
reaction profiling. Kennel values are diagnostics; they do not change simulation behavior unless a
configuration control is used.

## Reading the Overview

- **Active Turfs**, pressure populations, graph nodes, and pending callbacks are current queue or
  graph sizes. A value that stays above zero can be healthy while work is converging. A value that
  grows continuously at idle warrants investigation.
- **Group / Equalize Components** are work counts reported by the latest native processing cycle.
  They are not counts of unique station turfs.
- **Atmospherics Costs** include Dream Maker work and native calls. Active Turfs includes maintenance,
  diffusion, reaction callbacks and visuals. Native FDM, post-process and equalizer counters are
  subtotals of their parent stages and must not be added a second time.
- **MC total** uses a faster moving average than the stage counters and includes UI updates and
  scheduling overhead. Rebuild counters show the latest resume slice in milliseconds. Values need
  not sum exactly during a changing workload or between display updates.
- **Atmos Cycles** is the subsystem's cycle count; **Hotspots** counts current fire objects.
- A **negative** or non-finite stage cost is an invalid timing sample. It does not represent saved
  time or negative work. The Kennel displays such a value as an instrumentation error instead of
  drawing it on the cost scale.
- **DreamDaemon** includes the in-process native engine's allocations. Its private, virtual and
  working-set byte counts measure different properties of the same 32-bit process.

Idle performance should be judged with no players and no active atmospheric event on Runtime
Station or MetaStation. The engineering target is an Atmospherics MC tick below 20 ms at idle, or as
close to zero as the station's normal machinery permits. Compare matched maps and workloads; a
single Kennel refresh is not a benchmark.

## Diagnosing a slow cycle

1. Check the MC panel and the Kennel stage table to identify the expensive stage.
2. Compare Active Turfs, pressure populations, pipenet cost, heat-graph activity, and callback
   counts over several cycles. Separate a stable nonzero queue from a queue that is growing.
3. Use High-Cost Zones, Breaches, Explosions, Fire Groups, and Structures/Machines to locate the
   source. Jump targets are validated before use and histories are bounded.
4. Enable reaction profiling only for a short investigation. It adds timing work to every profiled
   reaction call.
5. Confirm a repair with the same map and scenario, including a quiet settling period after the
   event. Logs and performance CSVs are the authoritative record for playtest behavior.

Dogmos atmospheric goggles display selected Kennel markers on the map. These overlays are
diagnostic annotations; ordinary gas overlays remain tile-local visual feedback and do not describe
the complete atmospheric topology.
