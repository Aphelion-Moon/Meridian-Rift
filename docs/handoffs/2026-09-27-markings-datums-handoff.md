# Markings datumization — handoff (2026-09-27)

| | |
|---|---|
| **Worktree** | `C:\Users\mal\Meridian-Rift\.worktrees\markings-datums`, branch `markings-datums` |
| **Base** | `c85041d7bda` — tip of `scenegirlsimulator` == `origin/scenegirlsimulator` as of 2026-09-27 ~18:50. Rebased from `bfaf20397f36` after the hair-appendage work landed as commits `d289b6f1c40`, `3c919cf9b1c`, `c85041d7bda` (80 files). |
| **Snapshot commit** | **not needed any more** — the hair-appendage work is in the base itself (Deviation 3). Every measurement is taken against `c85041d7bda`; the docs and baseline-test commits on top of it change no production code. **The bfaf2039 baseline numbers in ledger row A are stale and must be re-taken on this base.** |
| **Plan** | [`2026-09-27-markings-datums-plan.md`](2026-09-27-markings-datums-plan.md) — verbatim copy of the approved plan: §0 setup, §1 inventory, §2 design, §3 the 9 steps, §4 scope lock, §5 verification, §6 risks, §7 decisions. **Read it in full before touching code.** This document only adds what the plan could not know about this machine. |
| **Execution** | Fable 5.1 orchestrator driving a fresh Opus implementer. The implementer works only in this worktree, one plan step per commit, and reports to the orchestrator after every step. |

The plan cross-references `docs/handoffs/2026-09-26-scenegirlsimulator-codex-handoff.md` for general branch context. That
file is **not** on this machine (Deviation 4); everything needed to work here is below.

## 1. Where things are on this machine

| thing | path |
|---|---|
| repo, main checkout (`scenegirlsimulator`, clean) — **do not work here** | `C:\Users\mal\Meridian-Rift` |
| this worktree | `C:\Users\mal\Meridian-Rift\.worktrees\markings-datums` |
| BYOND 516.1687: `dm.exe`, `dd.exe`, `dreamdaemon.exe`, `dreamseeker.exe` | `C:\Users\mal\Meridian-Rift-BYOND-Lab\toolchains\byond\516.1687\byond\bin\` |
| bun 1.3.5 | `C:\Users\mal\Meridian-Rift-BYOND-Lab\cache\rift\bun-v1.3.5-x64\bun.exe` |
| DreamChecker (SpacemanDMM) | `C:\Users\mal\Meridian-Rift-BYOND-Lab\mcp\build\target\release\dreamchecker.exe` |
| ripgrep 14.1.1, python 3.14 | on `PATH` as `rg`, `python` |
| `tgui\node_modules` | junction → `C:\Users\mal\Meridian-Rift\tgui\node_modules` |
| `tools\bootstrap\.cache` (vendored bun for `build.bat`) | junction → `C:\Users\mal\Meridian-Rift\tools\bootstrap\.cache` |

Neither BYOND nor bun is installed system-wide; the lab is the only toolchain. Never check out branches in, or otherwise
disturb, `C:\Users\mal\Meridian-Rift-BYOND-Lab\worktree` (the lab's own PR worktree, dirty with unrelated work), the main
checkout, or any other worktree listed by `git worktree list`.

## 2. Build, test, lint — exact commands

Run from the worktree root. PowerShell:

```powershell
$env:DM_EXE = 'C:\Users\mal\Meridian-Rift-BYOND-Lab\toolchains\byond\516.1687\byond\bin\dm.exe'
$env:TG_BOOTSTRAP_CACHE = 'C:\Users\mal\Meridian-Rift\tools\bootstrap\.cache'
$bun = 'C:\Users\mal\Meridian-Rift-BYOND-Lab\cache\rift\bun-v1.3.5-x64\bun.exe'
$dreamchecker = 'C:\Users\mal\Meridian-Rift-BYOND-Lab\mcp\build\target\release\dreamchecker.exe'
```

* **Full build** — first time in this worktree, and whenever icons or maps change: `.\build.bat dm`. Runs the icon
  cutter, painting store and behaviour-tree compiler, then `dm.exe` (`tools/build/build.ts`, `DmTarget`). The
  generated inputs are gitignored, so this must run once before a bare `dm.exe` will succeed.
* **Quick recompile** after that: `& $env:DM_EXE -DCBT tgstation.dme`. Zero errors; the warning count must not grow.
* **Unit tests, full local suite:** `.\build.bat dm-test -DRUNNING_LOCAL_TESTS`. `dm-test` compiles
  `tgstation.test.dme` with `CIBUILDING`; without `-DRUNNING_LOCAL_TESTS` only the map-tied tests run
  (`code/_compile_options.dm:183`). Judge by `data\logs\ci\clean_run.lk` existing and by `data\unit_tests.json`;
  a **non-zero exit code is expected** when anything fails.
* **Focused tests:** temporarily append `TEST_FOCUS(/datum/unit_test/<name>)` lines at the end of
  `code/modules/unit_tests/_unit_tests.dm` (inside the `#if defined(UNIT_TESTS)` block, after the includes), run
  `dm-test`, then revert that file. Never commit a `TEST_FOCUS`.
* Before any DreamDaemon run: `tasklist | findstr /i "dreamdaemon dd.exe"` — concurrent daemons collide (exit 208).
  And **stash or commit `.dmi` edits first** — DreamDaemon rewrites DMI files it loads.
* **DreamChecker:** `& $dreamchecker -e tgstation.dme *> <scratch>\dreamchecker-<label>.log`. Record the diagnostic
  count on the base commit before step 1; every later step must add zero (compare the sorted diagnostic lines, not
  just the count).
* **check_grep:** `bash tools/ci/check_grep.sh` from Git Bash (rg on PATH).
* **tgui**, from `tgui\`: `& $bun test packages/tgui/interfaces/PreferencesMenu` (`LimbsPage.test.tsx` exists and
  must stay green), `& $bun run tgui:tsc`, and `& $bun run tgui:build` before committing tgui changes. Biome:
  `.\build.bat tgui-lint` (or `& $bun x biome check <files>` from `tgui\`).
* `git diff --check` before every commit.

## 3. Scope lock — plan §4, plus what this machine forces

Plan §4 is the list. These adjuncts are allowed because the plan's steps cannot be done without them:

* `tgstation.dme` — the include line for the new `modular_nova/modules/customization/datums/dna/body_markings.dm`
  (mirror how `mutant_bodyparts.dm` is included).
* `code/__DEFINES/~nova_defines/DNA.dm` — the new `MARKING_COLOR_*` defines and the marking-side `DEFAULT_*` cleanup.
* `code/modules/unit_tests/_unit_tests.dm` — include lines only — plus **new** test files under
  `code/modules/unit_tests/~nova/` (markings tests, the benchmark harness test, the step-7 art-integrity test).
* The marking DMI sheets under `modular_nova/` — **step 6 only**, deleting the 53 pixel-identical `_chest_f` states.
* `tgui/.../CharacterPreferences/LimbsPage.test.tsx` and the interface's Aphelion SCSS (step 8; styling never inline).
* This file — the ledger in §7 only.

Anything else: **stop and report to the orchestrator** before editing. Never `git add -A`; stage files by name.

**Unrelated optimisation targets (user rule, 2026-09-27).** While profiling, look at every disproportionate hotspot,
marking-related or not, and record it (proc, self/total, calls, hypothesis) in the step report. A fix for one goes in
its **own `perf:` commit**, touching only what the fix needs, never inside a plan-step commit. Prefer fixing at the
upstream `code/` layer with no Nova/Aphelion dependencies so the user can port it to tgstation; a modular-only fix is
still a separate commit but flagged non-portable. Commit body: what was slow, measured before/after, the tests that
verified behaviour, and "portable to tg: yes/no". Larger targets: propose with numbers first.

## 4. Deviations from the plan on this machine — read before plan §0

1. **Paths.** The plan says `C:\Users\Pol\Documents\Meridian-Rift`; here it is `C:\Users\mal\Meridian-Rift`. The
   plan's memory dir `C:\Users\Pol\.claude\...` maps to `C:\Users\mal\.claude\projects\c--Users-mal-meridian\memory\`.
2. **Start gate (§0.1) — cleared via a commit.** At the time the worktree was made there was no `.worktrees/scenegirlsimulator`
   and no hair-appendage WIP here, so the orchestrator proceeded on the user's instruction with base `bfaf20397f36`. Later
   the same day the hair-appendage work landed on `scenegirlsimulator` as three commits (`d289b6f1c40` "A lot of new stuff",
   `3c919cf9b1c`, `c85041d7bda`), and this branch was rebased onto `c85041d7bda` before any production code was written.
   **The main checkout still carries uncommitted tgui work** (CustomSpriteEditor, SpriteEditor and `LimbsPage.tsx` again) —
   another effort is live there. Never touch it; rebase this branch onto `scenegirlsimulator` again right before step 8.
3. **Snapshot (§0.2) not carried — and no longer needed.** The 77-entry WIP the plan wanted snapshotted is now committed in
   the base. Note what the new base already changed inside this refactor's files: `add_marking()` now filters choices with
   `body_markings_of_zone_for_species(zone, species_id, allow_mismatched)` (plan §2.3 territory — build on it, do not
   duplicate it); `LimbsPage.tsx` +29/−5; `code/modules/unit_tests/~nova/limb_markings.dm` +40 lines; a new
   `~nova/digitigrade_legs.dm` test; and most of `modular_aphelion/modules/custom_sprites/code/*.dm` (appendages). Read the
   base's version of every §4 file — the plan's line numbers are from `bfaf20397f36` and drift by a few lines.
4. **`2026-09-26-scenegirlsimulator-codex-handoff.md` is absent** (uncommitted on the other machine). Refer to it by
   name only.
5. **No player saves.** `data/player_saves/` is empty here; the plan's 374 audited saves are not available. Savefile
   parity (§5.1) uses hand-built fixtures per §5.2, with the three on-disk rules in §2.6 as the spec (integer `0`/`1`
   emissive, `[]` for an empty collection, lowercase `#rrggbb`). Follow the fixture style in
   `code/modules/unit_tests/~nova/custom_sprites/save_compatibility.dm`: literal fixtures built without the code under
   test, asserted byte-for-byte via `json_encode`. Never read or write production saves.
6. **`tools/custom_sprite_harness/` does not exist here** (it was never committed). The benchmark (§5) is a focused
   `~nova` unit test declared `priority = TEST_LONGER`: build a fully-marked human (3 markings on all 8 zones), then
   time N× `update_body_parts()`, a species change, husking, dismemberment, a height change and the middleware marking
   action set under `world.Profile(PROFILE_START)` … `world.Profile(PROFILE_STOP, "json")`; write the JSON under
   `data/` and copy it to the orchestrator's scratch dir named by step. Count what DM lets you count: `length()` of
   the marking lists before/after, `limb_icon_cache` size, appearance counts per limb, `filters` counts per
   appearance. **Record the baseline on the base commit before step 1.**
7. **byond-tracy / meridian-mcp** are reachable only through the lab's Codex-scoped MCP, not from this session. The
   closing Tracy trace is optional here; if it is not done, say so in the ledger. `world.Profile` JSON is the primary
   benchmark evidence.
8. **Appearance parity (§5).** The DreamSeeker/PrintWindow harness is not here. Primary evidence is in-test pixel
   comparison: render via `getFlatIcon()` / `icon.GetPixel()` before and after across the plan's matrix (4 facings,
   husk, dropped limb, dwarf/tall/tallest, taur, digitigrade, both physiques, a `roundstartslime` with 3 overlapping
   markings per zone, and both physiques on each of the 53 `gendered = FALSE` conversions). The custom_sprites tests
   already compare pixels this way — reuse the pattern. Capture the "before" icons as part of the step-0 baseline
   (serialise them to `data/` so later steps can diff against them). A live DreamSeeker pass is a stretch goal.

9. **`build.bat dm-test` always exits non-zero on this machine**, even on a clean run (48, 64 and 208 observed).
   Judge only by `data\logs\ci\clean_run.lk` and `data\unit_tests.json`.
10. **`tools/ci/check_grep.sh` is degraded here:** it picks `/usr/bin/grep` (not rg), two checks fail with
    "Unmatched ( or \(", and it dies at line 320 because `jq` is not installed. Its CRLF check lists many pre-existing
    `code/controllers/*` files. Treat its output as advisory; do not "fix" the pre-existing CRLF files.
11. **A `dd.exe` is always running** (PID 27220 at the time of writing, parent `dotnet.exe`, started before this effort):
    it is the live TGS game server. **Never kill it.** Unit-test daemons run cleanly beside it.

## 4b. Findings from work package A that amend the plan

* **Plan step 6, `gendered = FALSE`, is wrong as written.** The renderer builds the chest state as
  `gendered ? (is_dimorphic ? "_[limb_gender]" : "_m") : ""` (`base_marking_overlays.dm`), so a marking with
  `gendered = FALSE` requests a bare `<state>_chest`. Of the 76 chest markings that ship `_chest_m` + `_chest_f`,
  **none** has a bare `_chest` state (audit: `gendered_audit.py` in the evidence dir). The lossless form of the step is:
  for each pixel-identical pair, set `gendered = FALSE`, **rename `_chest_m` → `_chest`** in the DMI and delete
  `_chest_f`. Icon-state names are not saved anywhere, so this is still migration-free. Re-derive the pixel-identical
  set with the audit script before acting; the plan's count of 53 is to be confirmed, not assumed.
* **Unrelated hotspot (user rule above):** `/datum/preference/choiced/digitigrade_legs/apply_to_human` is ~68 %
  inclusive of every prefs-preview refresh in the bfaf2039 baseline profile (0.297 s of 0.332 s over 35 calls).
  Candidate for a separate `perf:` commit; it is `modular_nova` code, so not tg-portable.

## 5. Decisions already taken (plan §7 — do not re-open)

| Question | Decision |
|---|---|
| Species-restriction contradiction (§1.2a) | Derive each marking's species set as the **union of the sets containing it**, explicit overrides for the ~101 set-less markings, enforce at one choke point (`validate_for_species`). |
| Live mutant-colour tracking? | **No.** Resolve once at add/preset/reset time, keep savefile parity, add a reset-to-default control. |
| `always_color_customizable` | Replaced by three-value `color_mode`: follows a mutant colour / fixed default but recolourable / locked. |
| Extra scope | **All four in:** overlay merging (step 9), tgui UX (step 8), art consolidation (step 6), art-integrity CI check (step 7). |
| Art consolidation | Name-based duplicates were a false lead. Set `gendered = FALSE` on the 53 markings with pixel-identical `_chest_m`/`_chest_f` and delete the `_f` states. Do **not** merge `handsfeet`/`rat` or `vox_digitigrade_1`/`_2` — report them. Do not merge the 3 protogen markings. Leave the 45×34 moth sheet's anchoring alone. |
| Reduced marking alpha | Blocks only the **visible** merge, never the emissive one; exactly one species (`/datum/species/jelly/roundstartslime`, 130, no subtypes). Gate on `limb.markings_alpha == 255`, read off the limb. Overlap-aware slime merging is deferred. |
| Worktree | `.worktrees/markings-datums`, branch `markings-datums` off `scenegirlsimulator`. |
| Base handling | Snapshot the hair work as one labelled commit — **not possible here, see Deviation 3.** |
| Start gate | Cleared — see Deviation 2. |

## 6. Working protocol

* **One plan step, one commit.** Steps 6 and 9 must be their own commits so a parity regression bisects cleanly; treat
  every other step the same way. Commit as the repo's configured identity (`mal`). **No `Co-Authored-By` trailer.**
  Subject: short imperative; body: what changed and why, plus the evidence summary.
* **Before every commit:** full compile clean; DreamChecker adds nothing; focused tests for the touched suites green;
  `git diff --check` clean; tgui tests/tsc green when tgui changed; ledger row added.
* **Savefile parity is the hard gate** for steps 1, 2, 5 and 6: the fixture round-trips must byte-match.
* **Comment style:** terse inline comments; full `/** */` doc blocks on proc definitions (see `mutant_bodyparts.dm`).
  Tests use `TEST_ASSERT*`, live in `code/modules/unit_tests/~nova/`, clean up in `Destroy()`, and test behaviour —
  never wording, tooltips or defaults-only changes. Measured-slow tests declare `priority = TEST_LONGER`.
* **Report to the orchestrator after every step** with: the commit SHA, files touched, compile/DreamChecker/test
  evidence (counts and log paths), benchmark numbers vs the baseline, and any question or scope conflict. Do not start
  the next step until the orchestrator has reviewed the diff and said go.
* Never push. Never touch branches other than `markings-datums`. Never edit files outside §3.

## 7. Ledger — the implementer appends one row per step

| step | commit | scope | evidence | notes |
|---|---|---|---|---|
| 0 | _(this docs commit)_ | worktree, junctions, handoff + plan copy | — | snapshot not carried (Deviation 3); baseline benchmark + DreamChecker count still to be captured before step 1 |
| A | `cf938dc3147` (rebased; was `4bc7113ec50`) | **new** `code/modules/unit_tests/~nova/limb_markings_appearance.dm` + `limb_markings_benchmark.dm`; two `_unit_tests.dm` include lines | `build.bat dm` 0 errors / 0 warnings; `dm-test` 0 errors / 4 pre-existing warnings; DreamChecker 129 diagnostics with the sorted list byte-identical to the base commit; `bun test PreferencesMenu` 4 pass / 0 fail; `tgui:tsc` clean; both new tests PASS (appearance 0.98 s, benchmark 0.69 s) with `clean_run.lk` present; `data/markings_benchmark.json` + `data/markings_appearance_before.json` written, the appearance signatures byte-identical across two separate daemon runs | Baseline: **33** marking lists per character (1 outer + 8 zone maps + 24 tuples) and **32** across the limbs; `update_body_parts` 98–111 µs/call cached, 291–321 µs/call creating; `get_cache_key` **7318** calls = 15–18 % of the `update_body_parts` tree against only **273** `get_limb_icon` calls; fully-marked tall human **52** appearances / **52** height filters / **18** emissive. Call counts are stable run to run; wall-clock varies ±25 %, so compare call counts and profile `self`, not wall clock. **`dm-test` always exits non-zero here, even on a clean run** (48/64/208 observed) — judge only by `clean_run.lk` and `data/unit_tests.json`. Two findings reported to the orchestrator, neither acted on: plan step 6's `gendered = FALSE` mechanism does not match the renderer's state formula, and `digitigrade_legs/apply_to_human` costs 68 % of every prefs-preview refresh. |
| A-review | _(docs commit)_ | orchestrator review of A; rebase onto `c85041d7bda`; no code change | commit re-read line by line; evidence re-checked: DreamChecker sets identical on the old base, both tests PASS twice, tgui green; the two findings above recorded | A was run by Opus 5 at xhigh by mistake (the `opus` alias resolved to `claude-opus-5` before the Claude Code update); kept after review. **Its numbers are for `bfaf20397f36` and are stale**: work package B0 re-takes every baseline on `c85041d7bda`. Steps 1+ run on Opus 5.5 at max effort. |
| B0 | _(this commit)_ | review of A on `c85041d7bda`; fixes to `code/modules/unit_tests/~nova/limb_markings_benchmark.dm` and `limb_markings_appearance.dm` only; re-baseline | `dm.exe -DCBT tgstation.dme` 0 errors / 0 warnings; `dm-test` 0 errors / 4 pre-existing warnings; DreamChecker 129 diagnostics, sorted list identical to the base; 7 focused runs (the unchanged harness once, the fixed one five times, one of them an order diagnostic), both tests PASS and `clean_run.lk` present every time; all 11 appearance signatures byte-identical across every run and identical to A's on `bfaf20397f36`; the two final runs identical in every profiled call count (950 procs, bar `/datum/qdel_item/New`), counter and cache delta | Baseline: marking lists **33** in DNA (1 outer + 8 zone maps + 24 tuples); the limbs **own 8** zone maps and **share** the 24 tuples with DNA (A's "32" counted the aliases). Per drive: **800** `update_body_parts`, **4798** `get_cache_key`, **4780** `generate_icon_key`, **297** `get_limb_icon` / `append_base_marking_overlays` (A: 1255 / 7318 / 7300 / 273; the base's batched preview limb swap accounts for the 455 fewer body updates). `update_body_parts` 95-97 us/call cached, 281-284 us/call creating. Fully-marked tall human: **52** appearances, **52** height filters, **8** marking emissives + **10** emissive blockers (A's "18 emissive" was both). `limb_icon_cache` +62 over the drive (+30 fixture transitions, +32 prefs actions), the same every run. Clean-run wall clock per pass: species change 11.3-11.5 ms, husk cycle 10.9-12.0 ms, dismember 1.0-1.2 ms, height change 3.3 ms, prefs action 6.2-6.5 ms; runs overlapping another session's DreamDaemon read up to 60 % slower, so compare call counts and cache deltas, and wall clock only between clean runs. The benchmark now runs before the appearance baseline: in the old order its transitions came out of that test's cache (diagnostic: +6 instead of +30, no husk or tall render at all). Preview character seeded (260927), species human, mismatched parts off. Digitigrade preview hotspot re-checked: still the largest part of every preview refresh, 3.2 ms = 46 % of `apply_prefs_to` (A: 8.5 ms, 66 %). Step 6 re-derived: 53 pixel-identical `_chest_m`/`_chest_f` pairs, but only **51** markings to convert; the other 2 are orphaned `firewatch` art on the two moth sheets. |
