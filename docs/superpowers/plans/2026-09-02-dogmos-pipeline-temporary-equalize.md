# Dogmos Pipeline Temporary Equalize Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Do not dispatch subagents without explicit user approval.

**Goal:** Replace each pipeline temporary mixture's `copy_from_ratio()` snapshot and two-command sequence with the existing single `equalize_with()` command while preserving final gas state.

**Architecture:** Keep the implemented source-volume cache and volume-aware temporary constructor. Because each receiver is fresh, mutable, pipeline-private, and already has its final member volume, invoke Dogmos's existing receiver-volume-weighted equalization command directly. Do not change native code, the protocol, generated bindings, artifacts, or lifecycle ownership.

**Tech Stack:** BYOND 516.1687 Dream Maker, existing Dogmos ABI 2/protocol 12 service command, DM unit tests, RIFT controller.

**Spec:** `docs/audits/2026-09-02-dogmos-post-fix-playtest-audit.md`

## Constraints

- Preserve the user-owned `code/controllers/subsystem/air.dm` change setting `share_max_steps = 4`.
- Leave all changes uncommitted and unpushed.
- Do not edit `aphelion-dogmos`, protocol types, generated bindings, manifests, native artifacts, Cargo files, toolchains, workflows, or release tooling.
- Preserve temporary-mixture ownership, slot generations, retirement, member volumes, temperature, gas amounts, and total gas conservation.
- Treat profiler call counts as mechanism evidence only. Require matched repeated playtests for a performance claim.

## Task 1: Strengthen the focused regression and retain the red result

**Files:**
- Modify: `modular_aphelion/modules/dogmos/code/service_backend_test.dm`

- [ ] Change the expected snapshot misses for `temporarily_store_air()` from three to one: the source pipeline volume is the only required snapshot.
- [ ] Add test-local snapshot field constants for revision low/high rather than depending on production defines that are undefined before the test file is included.
- [ ] Snapshot both temporary mixtures after distribution and assert revision 2: revision 1 from constructor volume initialization plus one effective equalize command.
- [ ] Retain the existing member-volume, temperature, oxygen, and nitrogen assertions. Add total oxygen and nitrogen conservation assertions across both temporaries.
- [ ] Run the focused test with the current production implementation and retain the expected failure. It should report three snapshot misses or revision 3, proving the regression distinguishes the old path.

Run:

```powershell
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json --focus /datum/unit_test/dogmos_service_pipeline_temporary_air --shim dogmos.dll --service dogmosd.exe --network offline --format result
```

## Task 2: Replace the hot-path operation

**Files:**
- Modify: `code/modules/atmospherics/machinery/datum_pipeline.dm:213-219`

- [ ] Replace only:

```dm
		member.air_temporary.copy_from_ratio(air, member.volume / pipeline_volume)
```

with:

```dm
		member.air_temporary.equalize_with(air)
```

- [ ] Remove `pipeline_volume` if it has no remaining use. Keep `new(member.volume)`.
- [ ] Do not add another immutability check: the receiver was just constructed mutable, and `equalize_with()` enforces receiver immutability natively.
- [ ] Do not change generic snapshot-cache eviction in this task. It is outside the measured caller-specific repair and does not add a source snapshot inside this loop.

## Task 3: Verify focused and adjacent behavior

- [ ] Re-run the focused test. Require one recorded/pass, zero failures/skips/runtimes, one source snapshot miss, revision 2 for each temporary, and all numerical assertions passing.
- [ ] Run adjacent Dogmos tests:

```powershell
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json --focus /datum/unit_test/dogmos_service_mixture_identity --focus /datum/unit_test/dogmos_service_mixture_snapshot_cache --focus /datum/unit_test/dogmos_service_pipeline_temporary_air --focus /datum/unit_test/dogmos_service_pipeline_batch_reconcile --shim dogmos.dll --service dogmosd.exe --network offline --format result
```

- [ ] Inspect RIFT's collected `unit_tests.json`, compile output, DreamDaemon log, dogmosd log, result JSON, and cleanup record. Do not rely on launcher exit code alone.
- [ ] Run `git diff --check` and inspect the scoped diff. Confirm the sibling `../aphelion-dogmos` checkout remains clean.
- [ ] Run the bounded full RuntimeStation soak used by the first repair. Keep the known MetaStation `atom_mounted.dm:201` initialization issue classified separately unless it changes.

## Task 4: Performance acceptance

- [ ] Keep `share_max_steps`, map, seed, BYOND build, installed artifacts, scenario, duration, and workload fixed.
- [ ] Run three controls and three candidates around the same fusion/decompression stress window.
- [ ] Compare `temporarily_store_air`, `copy_from_ratio`, `dogmos_mixture_snapshot`, `dogmos_mixture_command`, SSair budget behavior, DreamDaemon private/working set, dogmosd private/RSS, and numerical/event outcomes.
- [ ] Accept a performance improvement only if the candidate delta exceeds run-to-run noise and preserves all outcomes. Otherwise report only the verified crossing-count reduction.
