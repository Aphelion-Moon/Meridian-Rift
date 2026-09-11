# Dogmos Pipeline Expansion Volume Batching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Do not dispatch subagents without explicit user approval.

**Goal:** Replace per-pipe volume snapshot-and-command pairs during yielded pipeline expansion with one volume read and one volume command per non-empty expansion invocation.

**Architecture:** Keep a lazy local volume accumulator inside `SSair.expand_pipeline()`. Initialize it only when the invocation discovers its first new pipe, add subsequent pipe volumes locally, and flush once before either a tick-budget return or normal completion. Do not retain pending volume across invocations or change pipeline ownership, gas merging, member ordering, or yielding.

**Tech Stack:** BYOND 516.1687 Dream Maker, existing Dogmos service-backed gas-mixture API, DM unit tests, RIFT controller.

**Spec:** `docs/audits/2026-09-02-dogmos-post-fix-playtest-audit.md`

## Constraints

- Preserve the user-owned `code/controllers/subsystem/air.dm` change setting `share_max_steps = 4` and edit only the scoped expansion proc.
- Leave all changes uncommitted and unpushed.
- Do not edit `aphelion-dogmos`, protocol types, generated bindings, manifests, native artifacts, Cargo files, toolchains, workflows, or release tooling.
- Publish accumulated volume before every cooperative yield and before the caller clears `pipeline.building`.
- Keep zero service calls when an invocation discovers no new pipe.
- Preserve member discovery order, parent replacement, temporary-air merge order, and final volume exactly.
- Treat the estimated 85,152 avoided crossings as a mechanism upper bound, not accepted performance evidence.

## Task 1: Add a focused red expansion regression

**Files:**
- Modify: `modular_aphelion/modules/dogmos/code/service_backend_test.dm`

- [ ] Add `/datum/unit_test/dogmos_service_pipeline_expansion_volume_batch` with one pipeline and a short manually connected chain of at least four allocated smart pipes with distinct positive volumes.
- [ ] Set the first pipe as the pipeline's existing member/parent, leave the remaining pipe parents unset, and wire their `nodes` lists into a linear chain so the production `pipeline_expansion()` traversal discovers them.
- [ ] Reset the mixture snapshot cache, record misses, call `SSair.expand_pipeline(test_pipeline, border)`, and assert the border is empty and every pipe belongs to the pipeline.
- [ ] Snapshot the final network mixture once. Assert final volume equals the exact sum and revision advanced only once beyond its pre-expansion revision.
- [ ] Assert cache misses equal the one lazy initial volume read plus the one final verification snapshot, independent of the number of added pipes.
- [ ] Retain the expected red result against current production: it advances revision once per added pipe and incurs a volume miss for every added pipe rather than once for the invocation.
- [ ] Teardown must clear pipe parents/nodes and pipeline members before deletion so it neither schedules unrelated rebuilds nor double-retires the pipeline.

Run:

```powershell
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json --focus /datum/unit_test/dogmos_service_pipeline_expansion_volume_batch --shim dogmos.dll --service dogmosd.exe --network offline --format result
```

## Task 2: Batch volume within one invocation

**Files:**
- Modify: `code/controllers/subsystem/air.dm:763-795`

- [ ] Add a lazy local `expanded_volume` initialized null at the start of `expand_pipeline()`.
- [ ] On the first newly discovered pipe, set it from `net.air.return_volume()`, then add the pipe volume. On subsequent pipes, add locally without another snapshot.
- [ ] Replace the current per-pipe `set_volume(return_volume() + item.volume)` line using the repository's required downstream edit markers.
- [ ] Before the `MC_TICK_CHECK` return, call `set_volume(expanded_volume)` only when the accumulator is non-null.
- [ ] After the loop, perform the same conditional flush for normal completion.
- [ ] Do not extract a helper or store the accumulator on the pipeline datum; keeping it invocation-local makes the yield boundary explicit and prevents stale state during destruction or recovery.

## Task 3: Verify focused and adjacent behavior

- [ ] Re-run the focused expansion regression. Require one recorded/pass, zero failures/skips/runtimes, exact membership and volume, one effective volume revision, and two cache misses including final verification.
- [ ] Run the temporary-store, pipenet reconciliation, snapshot-cache, and mixture-identity tests with the new expansion test.
- [ ] Add or run a no-expansion assertion proving an empty/dead border does not fetch or set volume.
- [ ] Inspect RIFT's collected `unit_tests.json`, compile output, DreamDaemon log, dogmosd log, result JSON, and cleanup record. Do not rely on launcher exit code alone.
- [ ] Run `git diff --check` and inspect the scoped diff, especially the unrelated `share_max_steps = 4` hunk. Confirm the sibling `../aphelion-dogmos` checkout remains clean.
- [ ] Run the bounded full RuntimeStation soak used by the first repair. Keep the known MetaStation `atom_mounted.dm:201` initialization issue classified separately unless it changes.

## Task 4: Performance acceptance

- [ ] Keep `share_max_steps`, map, seed, BYOND build, installed artifacts, scenario, duration, and workload fixed.
- [ ] Run three controls and three candidates around the same fusion/decompression stress window.
- [ ] Compare `expand_pipeline`, `process_rebuilds`, `set_volume`, `return_volume`, mixture snapshot/command crossings, SSair budget behavior, DreamDaemon private/working set, dogmosd private/RSS, and numerical/event outcomes.
- [ ] Accept a performance improvement only when repeated candidate deltas exceed run-to-run noise and every rebuild outcome remains equivalent.
