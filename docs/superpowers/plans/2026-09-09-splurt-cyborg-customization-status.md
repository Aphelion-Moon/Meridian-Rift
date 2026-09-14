# Cyborg customization implementation status

User authorized implementation on branch `cyborg-customizer`. Changes remain uncommitted. Baselines: Meridian `aed808fbe309de11a14d574586745f6dad79a983`; SPLURT PR 960 `090a9cb13722af449567867c720826eb6af215a5`, still open at recheck.

The six-stage [workplan](2026-09-09-splurt-cyborg-customization.md) is the acceptance checklist. The [module README](../../../modular_aphelion/modules/cyborg_customization/README.md) records implemented boundaries, migration rules, asset provenance and supported mapping policy.

The next client session is described in the [two-client playtest checklist](2026-09-10-cyborg-customizer-playtest.md), including a short smoke pass and the broader creation, visibility and performance matrix.

## Playtest regression: numeric size dropdown

Opening the cyborg tab produced `TypeError: e.replace is not a function`. The reported bundle offsets resolved to `capitalizeFirst` called by `generateOptions`: the native cyborg-size preference publishes numeric choices, while the ordinary feature dropdown requires strings. A test rendering the registered size component with the native five-number payload reproduced the exact exception.

The size feature now uses a reusable, typed numeric dropdown adapter. It converts labels/selection to text at the dropdown boundary and converts the selected value back to a number for preference updates. Existing string dropdowns keep their contract. The regression verifies all size labels render and selecting 1.6 submits numeric 1.6. Maintained TGUI lint/typecheck and all **29 tests (57 expectations)** pass. The final maintained production build passed in 140.074 seconds, including the rebuilt TGUI bundle and a DM compile with zero errors/warnings (1:56). DM source is unchanged; the earlier 18-test native result is retained rather than claimed rerun. The test lives outside the auto-loaded feature registry to avoid bundling test dependencies. Restart the local test server and reopen Setup Character to load the rebuilt asset bundle; live-client confirmation of this fix remains pending.

## Continuation audit: creator and export boundaries

The source audit found and corrected five issues before the playtest:

- Immediate preference export now enters `preferences.export_to_client()`, serializing the current character and player preferences before handing the JSON tree to the existing download transport. This includes a pending layout edit before its debounce timer fires.
- Cyborg page activation has one frontend owner (the page mount/unmount effect). The backend ignores duplicate transitions, so unrelated navigation and repeated close messages do not flush another interface's pending draft.
- The override editor inherits the cardinal direction when the selected pose has no explicit entry, matching the live renderer. Editing one field preserves the other inherited values; explicit pose entries still take precedence.
- Creator preview and override editor share direction/pose state. Editing the visible north/rest pose no longer writes a hidden south/idle entry. The linked editor offers only poses supported by the selected model; runtime controls retain the full manual set.
- Name and hex-color inputs submit on blur instead of sending a complete backend update for each keystroke.

Three real-component TGUI regressions cover preview targeting and explicit/inherited pose edits. New native tests exercise repeated creator open/edit/close, stale actions, future-schema preservation, export preparation and authored preview PNGs/static fallbacks. The export and duplicate-close regressions were observed failing against the earlier implementation before their fixes. The initial animation test incorrectly required animation for a documented Alina fallback; it was corrected to validate the static path too. The follow-up source review found no remaining defect in these five fixes.

Final continuation checks:

- **18 focused DM tests passed, zero failures and zero runtime-error entries.** The world shut down naturally at 12:02:35 UTC with `clean_run.lk = Success!`. Run-specific JSON and logs are at `data/logs/cyborg-focused-20260910-7/`. The focused compile had zero errors and two existing test-configuration warnings (2:09). Its temporary DME/DMB/RSC files were removed after process exit.
- **28 TGUI tests passed, zero failures, 52 expectations**, including three real-component customizer regressions. Maintained lint/typecheck passed; warnings are the two existing Nova imports and generated tgfont CSS. Formatting passed for the changed UI files. The last supported-pose adjustment was rerun through the maintained lint/test targets and the pinned Bun suite.
- **Production DM build passed with zero errors and zero warnings** (2:22; maintained build 168.188 seconds). After the last UI-only adjustment, the maintained build refreshed the TGUI bundles successfully (49.051 seconds) and correctly reused the unchanged DM binary. This checkout loads TGUI bundles through runtime file paths.
- **DreamChecker 1.11.0 reported zero diagnostics** against the final DM source. The targeted review confirmed the fixes; the supported-pose follow-up also has a failing-before/passing-after component regression.
- No clean full-suite rerun, hosted CI, real-client playtest or paired performance qualification is claimed. The earlier full-run failures below remain recorded separately.

Version clarification: the Windows bootstrap reports Bun 1.3.5. Nested commands in the sandboxed lint/test invocations resolved ambient Bun 1.4.1, while the approved production build used 1.3.5. The final TGUI suite and TypeScript check were also invoked directly with the bootstrap's cached Bun 1.3.5 executable; these results are not inferred from the wrapper's version banner.

| Stage | Source delivered | Qualification |
| --- | --- | --- |
| 1 | Bounded versioned schema, slot/revision drafts, native saves, explicit preset operations, import aliases and future-version preservation | Final focused DM regressions pass; real-client reconnect acceptance pending |
| 2 | Cached descriptor catalog, canonical live IDs, dedicated creator, Visuals/Lore, thumbnails, pose/direction/zoom/pan/background | Final TGUI lint/typecheck and 29 tests passed, including four customizer component regressions |
| 3 | Live state, profile binding, size composition, identity/examine/directory integration | DM model/default/size/exposure tests pass; real creation/transfer/resize matrix pending |
| 4 | Six slots, shared geometry, direct accessory registry, offline anchors/masks, private viewer holders, animated preview | Asset builder, three Python tests, native preview/fallback PNGs and DM direct-art cardinal tests pass; visual/two-client evidence pending |
| 5 | Mounted RoboTact/self controls, shared operations, owner/slot guards, safe message interaction adapter | DM action/ownership/capability and authored interaction payload tests pass; two-client execution pending |
| 6 | Regression sources, asset tooling and documentation | Production build and DreamChecker pass; final 18-test focused run passes with clean natural shutdown; clean full-suite qualification outstanding |

## Earlier qualification evidence

- Asset generation: 36 compatible local icon/state mappings, 27 pose/movement fallbacks, seven generated occlusion sheets.
- Python asset-builder tests: three passed (frame atlas addressing, marker coordinate validation, mismatched timing rejection).
- TGUI maintained `tgui-lint`: passed TypeScript and lint; two existing Nova warnings.
- TGUI maintained `tgui-test`: 25 passed, zero failures, 41 expectations.
- Final formatting/Biome checks passed for all 14 changed/new TGUI files.
- Repository DMI parser: all 23 new module DMI sheets parsed successfully.
- Define sanity: passed, 4,048 defines. Trait validity: passed, 884 traits.
- Ticked-file enforcement: tgstation, Aphelion and Nova schemas passed. The unit-test checker has a pre-existing Windows separator bug (`~nova/` versus glob's `~nova\\`); with only in-memory path normalization to match POSIX CI, all four schemas pass, including 291 unit-test files. No checker source was changed.
- Maintained production build: succeeded, including CBT generation (20,813 defines and 392 sources), TGUI bundle and DM compilation. The rebuild after the last production-code correction completed with zero errors and zero warnings (DM 3:14; build 229.413 seconds); subsequent edits were confined to unit-test fixtures. The earlier icon-cutter pass separately reported 40 missing pre-existing source PNGs while returning success; this is not a clean asset-pipeline qualification.
- Final focused CIBUILDING compile: zero errors, two existing test-configuration warnings (reference tracking and disabled loop checks), 2:14 elapsed.
- Focused runtime attempts: 8/14 then 11/14 passed; both worlds shut down naturally and their JSON/log evidence was retained. Failures exposed list-initializer catalog extraction, numeric fallback versus clamping, membership precedence, an empty-sound loader sentinel and test-fixture lifecycle issues. All were corrected: all 14 cyborg tests now pass inside the full local suite.
- The maintained `dm-test -DRUNNING_LOCAL_TESTS` target compiled with zero errors and four existing test-configuration warnings. Before termination, its logs recorded 516 passes (including all 14 cyborg regressions) and four failed tests. The create/destroy sweep reached a retained mock-client reference from our fixture; the failing run was stopped after preserving the logs. These are partial counts: there was no natural shutdown or new full-suite JSON result.
- The fixture leak was traced to `robot.mock_client` surviving mob teardown and the mock/preference backreferences. The tests now use a shared teardown harness, isolated registries and the existing memory-only preference fixture. A fifteenth test checks actual native garbage collection using the collector's deletion generation, avoiding BYOND reference-ID reuse and early weakref invalidation.
- **Final focused runtime: 15 passed, zero failures and zero runtime-error entries.** DreamDaemon shut down naturally at 11:27:19 UTC and produced `clean_run.lk`. Run-specific JSON is retained at `data/logs/cyborg-focused-20260910-4/unit_tests.json`, alongside the runtime/test logs. Temporary `tgstation.test.dme`, `.dmb` and `.rsc` files were removed; no test-focus directives remain in deliverable source.
- DreamChecker 1.11.0, repository-pinned official release with verified SHA-256: zero diagnostics against `tgstation.dme` after correcting membership grouping and one list type annotation.
- BYOND installed compiler: 516.1687. Repository-pinned Bun 1.3.5 and Python 3.11.0 caches prepared by the maintained bootstrap.
- Parser attempt returned an error without diagnostics; no parser success is claimed.
- The shell grep checker was attempted through Git Bash. Map globs exceeded Windows' process argument limit and `jq` was unavailable; the whole check is incomplete. Its actionable port finding (`lowertext` instead of `LOWER_TEXT`) was fixed. Two unchanged TGS uses were also reported.

## Compiler investigation

The maintained build helper calls `dm.exe` without arguments to detect the version. Under sandbox restrictions this installation opens a hidden Browse for Folder dialog for that probe; a direct five-minute attempt also produced no diagnostics. Approved builds outside the sandbox progress normally. Initial typing errors were corrected with typed human aliases and a shared real/mock-client preference resolver. Temporary probe/workaround edits were removed from build helpers.

Two small isolated BYOND experiments established runtime causes: `initial()` returns null for list-valued instance initializers; ungrouped membership expressions rejected a valid layout root. The catalog now copies declarations from the audited null-location model path, and schema membership checks use explicit grouping.

## Remaining acceptance gates

1. Obtain a clean full-suite run after the separately recorded failures are addressed. The attempted full run was stopped during reference tracing and must not be reported as completed; the expanded 18-test cyborg run, including fixture collection, completed cleanly.
2. Run hosted equivalents of the completed local static/TGUI checks; retain the Windows checker caveat separately.
3. Exercise actual creator open/edit/close/import/reconnect, model reset/disguise, normal/latejoin/converted/constructed/cafe creation, resize hardware and mounted runtime tabs with two clients.
4. Capture the model/pose/direction matrix, observer arrival/exit and independent viewer toggles. Include tipped/dead/disguised transitions and compare hats, lights, tools and body occlusion.
5. Measure three paired baseline/feature scenes for cold/warm creator open, slider dragging, model cycling, idle and walking cyborgs. Record server CPU/memory/ticks, cache estimates and object/file counts; repeat 100 open/edit/close cycles. No performance improvement is claimed yet.
6. Hosted CI and human acceptance remain unrun. No deployment, commit or push was performed.

Commands for resuming qualification from the repository root:

```text
tools/build/build.bat tgui-lint
tools/build/build.bat tgui-test
BUILD.cmd
tools/build/build.bat dm-test -DRUNNING_LOCAL_TESTS
python tools/cyborg_customization/build_assets.py
python -m unittest discover -s tools/cyborg_customization -p "test_*.py"
```

The DM test target clears its CI log directory; preserve useful earlier evidence before running it. This checkout does not contain the later RIFT controller; use its checked-in build/test targets. Avoid treating launcher exit status or static analysis as proof of an error-free session.

## Full-run failures retained for follow-up

| Test or phase | Observed evidence | Scope assessment |
| --- | --- | --- |
| `door_click` | Concurrent Mountainside Apartment preview loading duplicated elevation turf-reset/turf-change registrations; `elements/elevation.dm:56`, `signals.dm:39`, `tables_racks.dm:107` | Stack follows unchanged template/elevation code; no clean baseline execution was performed. |
| `job_display_order` | AI and human-AI both declare `JOB_DISPLAY_ORDER_AI` (8001), rejected by `job_display_order.dm:12` | Deterministic duplicate in unchanged job declarations. |
| `monkey_business` | Missing existing emissive states, invalid pathfinding start, and burning components on decorative objects during lava/template cleanup | Reported stacks are outside the port; retained for separate diagnosis rather than claimed fixed. |
| `plane_layer_sanity` | Existing `flick_visual` objects had top-down layers on plane -32767 | Reported types are outside the new image-holder subtype; baseline reproduction remains unrun. |
| `create_and_destroy` (interrupted) | Reference scan retained a mock client through a test cyborg's `mock_client` field | Port test-fixture defect; teardown repaired and a dedicated GC regression added. |

Local evidence is retained under `data/logs/ci/`, `data/logs/cyborg-focused-20260910*/` and ignored task scratch. The root `data/unit_tests.json` is replaced by each completed test run; consult its timestamp and run-specific copies before attributing it to a run.
