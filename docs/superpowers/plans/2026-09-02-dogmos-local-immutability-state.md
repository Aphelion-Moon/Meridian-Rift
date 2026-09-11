# Dogmos Local Immutability State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Do not dispatch subagents without explicit user approval.

**Goal:** Eliminate service snapshots used only to answer whether a gas mixture is immutable while preserving the inherited immutable-mixture API and native mutation enforcement.

**Architecture:** Store the monotonic immutable property on its owning DM datum. Registration starts both representations mutable. `mark_immutable()` sends the existing native command and sets the local flag only after a structurally valid response returns. `is_immutable()` reads the local flag. Native Dogmos continues to reject all writes to immutable mixtures, so the local value controls only legacy DM branching and return behavior.

**Tech Stack:** BYOND 516.1687 Dream Maker, existing Dogmos ABI 2/protocol 12 service command, DM unit tests, RIFT controller.

**Spec:** `docs/audits/2026-09-02-dogmos-post-fix-playtest-audit.md`

## Constraints

- Preserve the user-owned `code/controllers/subsystem/air.dm` change setting `share_max_steps = 4`.
- Leave all changes uncommitted and unpushed.
- Do not edit `aphelion-dogmos`, protocol types, generated bindings, manifests, native artifacts, Cargo files, toolchains, workflows, or release tooling.
- Do not infer immutability from datum type. `/datum/gas_mixture/immutable/planetary` deliberately remains mutable while its initial gas string is parsed.
- Do not remove native immutable guards or change `merge()`, removal, reaction, or frontier branch semantics.
- Treat 13.43 seconds and 116,289 calls as one unmatched playtest interval, not accepted performance evidence.

## Task 1: Add a red local-state regression

**Files:**
- Modify: `modular_aphelion/modules/dogmos/code/service_backend_test.dm`
- Verify: `code/modules/unit_tests/dogmos_immutable_mixture_contract.dm`

- [ ] In `/datum/unit_test/dogmos_service_mixture_snapshot_cache`, mark `first` immutable, then explicitly evict its cached snapshot.
- [ ] Record `dogmos_mixture_cache_misses`, call `first.is_immutable()`, and assert the miss count does not change.
- [ ] Retain a subsequent state read and attempted mutation so the test proves native Dogmos was also marked immutable rather than only the DM datum.
- [ ] Run the focused cache test against current production and retain the expected failure: current `is_immutable()` fetches a service snapshot after explicit eviction.

Run:

```powershell
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json --focus /datum/unit_test/dogmos_service_mixture_snapshot_cache --shim dogmos.dll --service dogmosd.exe --network offline --format result
```

## Task 2: Store the monotonic property locally

**Files:**
- Modify: `code/modules/atmospherics/gasmixtures/gas_mixture.dm`
- Modify: `modular_aphelion/modules/dogmos/code/service_backend.dm`

- [ ] Add an AUTODOC class variable to `/datum/gas_mixture`, initialized false, that records whether the datum has successfully finalized native immutability.
- [ ] Change `is_immutable()` to return only that variable.
- [ ] Change `mark_immutable()` to issue `DOGMOS_COMMAND_MARK_IMMUTABLE`, set the local variable true only after `dogmos_command()` returns a structurally valid response, and return the native updated count unchanged.
- [ ] Do not condition the local assignment on `updated == 1`: an accepted idempotent native mark returning zero still proves the native record immutable.
- [ ] Do not clear the flag during ordinary cache invalidation. The property belongs to the datum lifetime, not the snapshot epoch.

## Task 3: Verify immutable and deferred-finalization contracts

- [ ] Re-run `/datum/unit_test/dogmos_service_mixture_snapshot_cache`; require one pass, zero runtimes, and no cache miss from `is_immutable()` after explicit eviction.
- [ ] Run the immutable contract plus planetary parsing coverage:

```powershell
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json --focus /datum/unit_test/dogmos_immutable_mixture_contract --focus /datum/unit_test/lungs/lungs_sanity_ashwalker --focus /datum/unit_test/dogmos_service_mixture_snapshot_cache --shim dogmos.dll --service dogmosd.exe --network offline --format result
```

- [ ] Confirm `/datum/unit_test/lungs/lungs_sanity_ashwalker` still constructs its test gas through `create_lavaland_mix()` and `/datum/gas_mixture/immutable/planetary`; do not silently omit deferred-finalization coverage if that helper changes.
- [ ] Assert an immutable mixture still rejects merge, copy, mole, temperature, heat-capacity, and reaction changes through native state reads.
- [ ] Inspect RIFT's collected `unit_tests.json`, compile output, DreamDaemon log, dogmosd log, result JSON, and cleanup record.

## Task 4: Adjacent and bounded verification

- [ ] Run adjacent pipeline, frontier, reaction, and snapshot-cache tests, including the existing focused pipeline temporary regression.
- [ ] Run `git diff --check` and inspect the scoped diff. Confirm the sibling `../aphelion-dogmos` checkout remains clean.
- [ ] Run the bounded full RuntimeStation soak used by the first repair. Keep the known MetaStation `atom_mounted.dm:201` initialization issue classified separately unless it changes.
- [ ] Compare exact behavior for ordinary mutable mixtures, direct immutable mixtures, deferred planetary immutable mixtures, and an idempotent second `mark_immutable()` call.

## Task 5: Performance acceptance

- [ ] Keep `share_max_steps`, map, seed, BYOND build, installed artifacts, scenario, duration, and workload fixed.
- [ ] Run three controls and three candidates around the same fusion/decompression stress window.
- [ ] Compare `is_immutable`, `dogmos_mixture_snapshot`, cache hits/misses, `merge`, `copy_from_ratio`, SSair budget behavior, DreamDaemon private/working set, dogmosd private/RSS, and numerical/event outcomes.
- [ ] Accept a performance improvement only when repeated candidate deltas exceed run-to-run noise and every immutable behavior remains equivalent.
