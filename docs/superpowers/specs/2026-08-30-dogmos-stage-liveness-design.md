# Dogmos Stage Liveness Repair

## Problem

An idle Runtime Station round can enter a permanent Atmospherics failure loop. A multi-tick equalization or excited-group stage retains one Rust transaction across ticks. Any legitimate atmosphere mutation between chunks changes a mixture revision, so the eventual commit returns `StageConflict`. The rejected transaction remains resident, making every retry fail against the same stale revision. Dream Maker then treats the missing response as malformed but continues into later stage and lifecycle requests, producing a cascading conflict loop.

Round initialization also repeatedly registers already-registered neighboring turfs while building adjacency. That recreates lifecycle and heat records and discards queued adjacency work, accounting for most of the measured Atmospherics initialization time.

## Required invariants

- A connected gas component is the smallest atomic publication unit. Its mixture reads and writes either all publish or none publish.
- Disconnected components may publish independently. A later cancellation or conflict does not roll back components that already published because they share no simulation edges.
- A component is validated immediately before publication. External writes detected during that component's computation reject only that component.
- A rejected or malformed stage operation leaves no service-side cursor, transaction, diffusion, heat, reaction, or transient frontier state that can poison the next request.
- Dream Maker never advances to another simulation stage or lifecycle flush after a native stage request returns an invalid response.
- Startup adjacency construction does not re-register a turf whose Dogmos generation and linked-mixture identity are already current. A turf registered before its gas mixture becomes available is refreshed once that mixture exists. Runtime adjacency changes retain the existing explicit refresh behavior.
- Gas and heat numerical results remain equivalent for the same ordered inputs; this repair changes commit granularity, not simulation formulas.

## Rust stage transaction design

Equalization and excited-group processing will build and validate an indexed transaction for one disconnected component at a time. Once a component finishes successfully, its transaction is published and its arena is cleared for reuse without releasing capacity. The stage cursor then advances to the next component.

Cancellation is observed before starting a component and while computing it. Cancellation during computation discards the current component transaction. Components published by earlier chunks or earlier in the same request remain committed. This deliberately replaces whole-stage atomicity with per-component atomicity; disconnected components cannot exchange gas or heat within that stage, so retaining earlier publications is safe and prevents an unrelated component from holding stale mixture revisions across Master Controller ticks.

If validation detects a revision conflict, the current component is discarded and the entire resumable stage scratch state is aborted. The server reports the failure to Dream Maker. A subsequent request begins a clean stage from current world state rather than resuming stale expectations.

The abort operation must clear:

- the stage cursor and component transaction;
- diffusion, heat, and reaction staging buffers;
- transient frontier indexes, flags, and cached component position;
- any request-local bookkeeping that assumes the rejected stage is resumable.

## Dream Maker failure control flow

`dogmos_run_stage()` will treat a missing or malformed native response as a hard stop for the current `SSair.fire()` invocation. It preserves enough DM-side stage identity to retry the stage on a later fire, but it returns before any next-stage call or lifecycle flush.

The Rust service aborts its rejected stage state before returning the error, so that retry starts cleanly. Ordinary revision conflicts should become exceptional after per-component publication; repeated malformed responses remain visible through existing runtime logging rather than being silently accepted.

## Startup registration design

During initial adjacency construction, a neighboring turf is registered only when it has initialized air and its queued Dogmos registration does not match both the current turf generation and linked-mixture identity. The self-registration path follows the same rule while startup batching is active. This distinction preserves the required heat-only-to-gas transition when turf initialization precedes gas-mixture creation. Outside startup batching, existing runtime refresh calls continue to re-register changed turfs so topology and mixture updates are not suppressed.

## Verification

Implementation begins with failing tests for:

1. An external mixture mutation between stage chunks no longer invalidates already completed disconnected components.
2. A conflict or cancellation clears all resumable stage scratch state and a clean retry can complete.
3. An invalid native stage response stops `SSair.fire()` before the next stage or lifecycle flush.
4. Startup adjacency construction does not re-register an already-current neighboring turf.

Local gates include the pinned Rust toolchain tests and lint, Dream Maker compile, focused Dogmos tests, and Meridian-MCP diagnostics after reparsing.

The live acceptance gate is a no-player Runtime Station soak. It must show zero new runtimes, continuous completion of Atmospherics cycles, no StageConflict cascade, no monotonic active-turf growth, and materially improved Atmospherics initialization time. MetaStation is an acceptable secondary validation map, but no other map is used for this repair's game testing.

## Out of scope

- Protocol or generated-binding version convergence.
- Release artifact publication or deployment changes.
- Queueing every atmosphere mutation behind the simulation stage.
- Changes to atmosphere formulas or gameplay behavior unrelated to liveness.
