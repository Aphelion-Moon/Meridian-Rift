# Dogmos integration and ownership

Dogmos replaces the inherited gas-mixture representation and environmental atmosphere processing while preserving the public DM API and SS13 gameplay boundary.

## Ownership

DM owns datum/turf identity, gas-mixture compatibility procs, SSair scheduling, machinery/pipenets, gameplay, logging and UI. The native in-process engine owns gas arrays, numerical kernels, graphs and workers within DreamDaemon. Do not duplicate authoritative gas state. Only main-thread callbacks may resolve game objects and perform gameplay effects; preserve order and deleted-target checks.

See [the build contract](dogmos-in-process.md) and [gameplay callbacks](dogmos-gameplay-events.md).

## Narrow fork-owned exception

The forced gas-mixture implementation under `code/modules/atmospherics/gasmixtures/**` and environmental simulation under `code/modules/atmospherics/environmental/**` are Dogmos-owned because the representation change cannot be expressed as isolated overrides without copying large inherited procs. The only additional generated-file exceptions are `code/__DEFINES/dogmos_bindings.dm` and `code/__DEFINES/dogmos_contract.dm`.

This exception does not cover `code/controllers/subsystem/air.dm`, `code/modules/atmospherics/machinery/**`, unrelated gameplay, turfs, UI, or deployment/build files. Existing inherited files outside the exception use `APHELION EDIT` for new Meridian work. Preserve inherited `NOVA EDIT`; do not convert it. Generated files remain generator-owned even when their path is exempt from inline markers.

The module entry point and turf hooks live under [the Dogmos module](../../modular_aphelion/modules/dogmos/readme.md). The current processing overview is [Atmospherics](../../code/modules/atmospherics/Atmospherics.md).

## Change rules

Preserve public proc behavior and test it at the first DM-visible consumer. Route pure math/invariants to Rust tests, lifecycle and gameplay consequences to focused DM tests, and generated proc changes to binding/contract drift checks. Validate handles, references, callback targets, numeric inputs, and authority after any input or asynchronous boundary.

Do not alter diffusion/equalization/heat gameplay coefficients as a performance optimization. Establish invariants, operation transcripts, and repeated measurements first.
