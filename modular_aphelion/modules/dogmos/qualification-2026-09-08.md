# Dogmos repair qualification, 2026-09-09

Local qualification passed: 623/623 full DM tests, a full production build and
300-second soak, and all six final performance observations. No runtime signatures
or leftover owned processes were recorded in those eight runs. No production
deployment or new hosted CI pass is claimed.

On this machine, median MetaStation initialization was **204.535 seconds**
with the final candidate versus **248.175 seconds** with the preserved
Dogmos control, an observed **17.58% reduction**.
This compares the final startup optimizations against an already corrected Dogmos
frontier walk; the control is not stock/no-Dogmos Meridian.

## Matched performance observations

Windows 10 Home 10.0.19045; Intel Core i7-9750H, 6 cores/12 logical processors;
31.9 GiB reported physical memory. All runs used BYOND 516.1687, Bun 1.3.5,
MetaStation, seed `29051994`, shared pinned caches, the same complete native pair,
and 180 seconds from the first observed playing state. There were no players.
The observer test creates its fixture room during gameplay. Controls and candidates
ran alternately and serially. Source hashes, map, seed, tool versions, cache mode,
actual procedure-profiling state and diagnostic mode matched their declared variants.

| Variant/run | Initialization | First queues clear | First air-cycle progress | Final-minute active turfs, median (range) | Air cycles |
| --- | ---: | ---: | ---: | ---: | ---: |
| final-control-1, `20260908T231011Z-d1e2fc35` | 232.250 s | 117.456 s | 127.456 s | 155 (44–10521) | 97 |
| final-candidate-1, `20260908T232023Z-2dcce3cc` | 204.600 s | 55.712 s | 76.031 s | 48 (43–328) | 149 |
| final-control-2, `20260908T233010Z-1346147e` | 263.106 s | 86.569 s | 114.256 s | 44.5 (0–271) | 105 |
| final-candidate-2, `20260908T234104Z-932c1d59` | 200.594 s | 70.062 s | 79.875 s | 45 (0–321) | 129 |
| final-control-3, `20260908T235102Z-3683315c` | 248.175 s | 118.594 s | 130.475 s | 118.5 (44–9774) | 95 |
| final-candidate-3, `20260909T000135Z-1e9169d5` | 204.535 s | 71.564 s | 99.176 s | 73.5 (43–297) | 124 |

Control initialization range: 232.250–263.106 seconds.
Candidate range: 200.594–204.600 seconds.
All six observations completed with natural DreamDaemon shutdown and clean cleanup.
Automatic BYOND procedure profiling was present in every observation; these are
not unprofiled runs or Tracy captures. Three repeats show observed variability,
not a main-server performance guarantee.

The candidate final-minute medians were 45–73.5 active turfs, with maxima
of 297–328. Median first-queue clearance was 70.062 seconds versus 117.456
for controls. These observations support faster local shift-start progress;
they do not establish populated main-server settlement.

## Separate process resources

Nominal 250 ms sampling records private bytes, virtual size, working set and
cumulative CPU time. The table shows median (minimum–maximum) per-run peaks in
MiB and sampled CPU seconds. DreamDaemon includes its loaded 32-bit shim;
`dogmosd` is a separate 64-bit process. Never add them into a DreamDaemon footprint.

| Process/phase | Variant | Peak private MiB | Peak virtual MiB | Sampled CPU seconds |
| --- | --- | ---: | ---: | ---: |
| dreamdaemon/initialization | control | 2574.0 (2570.9–2582.6) | 2760.3 (2759.2–2774.8) | 239.3 (225.7–250.4) |
| dreamdaemon/initialization | candidate | 2562.8 (2555.4–2563.4) | 2742.9 (2742.4–2744.8) | 200.0 (195.4–200.3) |
| dreamdaemon/gameplay | control | 2721.9 (2720.8–2737.2) | 2918.1 (2905.7–2925.9) | 137.0 (136.5–137.9) |
| dreamdaemon/gameplay | candidate | 2724.1 (2723.4–2743.8) | 2909.7 (2909.4–2938.3) | 134.7 (134.0–136.0) |
| dogmosd/initialization | control | 342.7 (319.4–344.6) | 4495.9 (4473.2–4498.2) | 9.5 (9.3–9.8) |
| dogmosd/initialization | candidate | 328.1 (325.4–447.2) | 4481.4 (4478.7–4600.3) | 6.0 (5.8–6.3) |
| dogmosd/gameplay | control | 421.4 (419.2–453.3) | 4587.6 (4585.6–4620.1) | 8.2 (7.7–8.7) |
| dogmosd/gameplay | candidate | 401.0 (399.0–421.5) | 4567.3 (4565.6–4587.4) | 8.5 (7.4–8.9) |

DreamDaemon gameplay private-memory peaks overlap: the median was 2,724.1 MiB
for candidates versus 2,721.9 MiB for controls. A sustained DreamDaemon footprint
reduction is not established by this comparison.

The largest recorded sampling gap was 481 ms. Every sampler finished
without errors. Attachment follows process discovery, so the first allocation can
precede sampling. These measurements are not address-space region maps or native
allocation attribution. A DreamDaemon footprint reduction is not established by
changes to service RSS or allocation probes.

## Qualified changes

- Complete the active-turf snapshot across scheduler pauses, retaining prefetch
  progress and completing FDM/reaction work before retirement. Keep the native
  frontier frozen until the dependent stages finish.
- Retry native reaction publication after accepted gameplay writes while
  preserving callback target and mixture identity checks.
- Prefetch startup mixture snapshots in bounded batches and validate mixture
  ownership with opaque tokens plus slot/generation checks. Tokens do not hold
  their gas-mixture datum alive.
- Coalesce repeated runtime adjacency construction, template-border publication,
  and the two synchronous blocked-turf updates during shuttle movement. Preserve
  signal order, gas copying, outer batch ownership, and exception propagation.
- Retire withdrawn turf subscriptions during replacement construction, including
  shared elements whose host is deleted while the target lookup is unavailable.
- Unregister lava's own trait-removal callback before its turf is replaced.
- Correct the space-boundary test to wait for actual diffusion or completed
  atmosphere fires within a bounded interval, and override an invalid inherited
  emissive mask with null on one mapped condo vending machine.
- Scope the map-space test exception to intentional bluespace boundaries in condo
  areas on reserved z-levels, including asynchronous previews.

The native revision is `14f0a4c2cb1a6db9a7e1685e385e0fb3d3fd7ced`.
The complete installed release is identified by `dogmos.lock.json` SHA-256
`19e3b533286741e3e2c195cd1712ce4f4366a75d2b2776143530c5b978d65b1f`.
Install all seven game-side release members through the maintained synchronizer;
do not mix a shim, service, generated contract, or lock from different releases.

## Functional gates

| Gate | Result | Evidence |
| --- | --- | --- |
| Full DM suite | 623/623 passed, zero skipped, zero runtime signatures; natural exit 144, clean cleanup | `20260908T222913Z-c3e6d573`; zero compiler errors, two test-build warnings |
| All-type construction/deletion | All 30,717 types passed in 97.9375 seconds | Same full suite |
| Production RuntimeStation build/soak | Zero compiler errors/warnings; 300 seconds after readiness, zero runtime signatures; requested stop, clean cleanup | `20260908T225913Z-57c98a18`; initialization 132.762 seconds |
| Startup prefetch regression | Collision-aware oracle, ordered reads and callback/visual/state parity passed | Focused `20260908T214909Z-e1b6470c` 2/2; both cases also passed the final full suite |
| Turf listener lifecycle | Constructor cleanup and lava self-listener regressions observed red then green | `20260908T195100Z-b85e9fc6` / `20260908T200011Z-d71a974e`; `20260908T204308Z-9dc34035` / `20260908T204938Z-66c4606b` |
| Exception ownership/batching | 11/11 focused, zero runtimes, natural shutdown, clean cleanup | `20260908T174735Z-38092a56` red; `20260908T175430Z-ff52e380` green; final full suite passed |
| i686 Windows Rust workspace | 461 passed, two ignored | Native revision `14f0a4c`, Rust/Cargo 1.98.0, locked/offline |
| x64 Windows Rust core/server/protocol | 318 passed | Same revision/toolchain |
| x64 Linux Rust core/server/protocol/performance | 331 passed | Same revision/toolchain |
| i686 Linux Rust shim | 44 passed | Same revision/toolchain |
| Packaged Windows/Linux IPC | 1,030 continuation cycles and five stale rejections on each platform | Complete current release probes |

Native logs are under `target/committed-14f0a4c-*` in the native repository.
The four i686 Windows control-plane cases also passed. They launch the Cargo-built
service and do not establish actual DreamDaemon/service-death injection behavior.
The production soak establishes bounded availability, not populated gameplay or
natural server shutdown. The full unit suite forces additional ruins and runs
construction/deletion stress; its initialization and memory are not timing samples.

Four Python analysis regression tests and the checked-in deployment-assets test
also passed after the timing sequence. The installed native contract and all six
restored candidate/control source pairs verified without changes.

## Baseline and remaining boundaries

The untouched no-Dogmos mirror at `6786e9279186b18125176eb0f4f139aed36fc12a`
initialized MetaStation on this machine in 131.994 seconds in
`20260908T122715Z-9707b700`. Its gameplay observation failed after 8.01875 seconds
on `null.moles_archive` in `gas_mixture.compare`. It is a single initialization
reference, not a passing three-minute baseline. The remaining initialization gap
is not dismissed as an Ice Box map effect or claimed eliminated.

Round 118 logged 59.45 seconds on MetaStation; round 120 logged 348.367 seconds
on Ice Box. Those maps differ, while the local runs independently reproduced slow
Dogmos initialization. Main-server settlement and timing still require a matched
playtest/capture. New hosted CI, Linux DreamDaemon and actual service-death injection
from a live DreamDaemon remain unrun.

The next architectural candidate is bulk creation of initial mixture state.
An earlier cumulative profile recorded roughly 78,000 lifecycle calls and 78,000
command calls, with about 6.6 and 6.5 seconds of self time. That profile includes
gameplay, so these are not initialization-only costs or predicted savings.
A bulk path must preserve generations, immediate initialization reads and
intervening writes. It requires a separate protocol design and qualification.

## Reviewer maintenance and server capture

Game `dogmos` commit `a7406c6962330f8ebcd7269ec37b60adcea4a6bc` adds the approved
job-scoped `contents: read` / `pull-requests: write` permissions and removes
Zergspower ownership. Follow-up `ea89176c9a4b451d7a2425b6e5bac478278be5a9` removes
all four `sqnztb` rules. The five `vinylspiders` rules are preserved, without
ownerless overrides. YAML, trigger, permissions, copied hashes and whitespace
checks passed. Neither maintenance commit has been pushed.

The reviewer workflow uses `pull_request_target`; its permission correction
requires the updated workflow on the default/base branch before hosted verification.
See [GitHub token permissions](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token)
and [event context](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request_target).

The portable `dogmos-windows-capture-v2.zip` is 1,692,996 bytes, SHA-256
`1a08b037bfbc5bbf97d32bfd97037f7e9e1d54444b53f704afaaeb2f7345de7a`.
Use the administrator PowerShell procedure in
[`dogmos_tracy/README.md`](../../tools/dogmos_tracy/README.md) alongside TGS.
The bundle includes the required source and license notices; Microsoft runtime
DLLs and BYOND are excluded. Install the required x64 Microsoft Visual C++ v14
Redistributable through the linked Microsoft instructions. Local fixture checks
passed; a real Windows Server 2022 capture remains unrun. A hard restart is
required when deploying the native pair and to unload the Tracy hook after profiling.

Detailed earlier experiments and failures remain in
[`round120-repair-handoff.md`](round120-repair-handoff.md). Local raw evidence uses
`data/rift-runs/<run-id>` and `data/performance-qualification/final-*.json`.
