# Atomic mixture creation and initialization qualification

The installed Dogmos pair comes from native master
`6b6321b2c4a0658933b7529e1d732acfac9cc5a4`, with ABI 2 and protocol 14.
Ordinary exact-type gas copies create the destination from its source in one
service request. Custom constructors and copy hooks retain dynamic dispatch.
The earlier protocol-13 pair and frontier integration remain separately recorded
in the September 9 qualification report.

The game changes also reuse pending topology records, share gas/heat edge keys,
and compare payloads in the queue operation. Registration batching and ordered
flush boundaries remain intact. Vertical gas edges now follow the same linked
level and reservation routing as DM adjacency; heat edges remain horizontal.
Closing a vertical gas connection publishes the disconnected edge while retaining
the turf and mixture identities.

The direct-mapped mixture snapshot cache is already bounded to 2,048 entries.
Slot, generation and epoch keys prevent stale reuse, mutations and retirement
evict affected entries, and epoch changes invalidate the cache without traversing
all registered mixtures. This audit found no basis for replacing that bounded
cache with another full-world mirror.

## Native evidence

The native repository's committed atomic-creation audit contains the exact pinned
Rust, Windows/Linux, i686, feature, strict Clippy, contract, generated-binding and
real cross-bitness IPC results. The packaged service also passed the maintained
32-bit client probe: eight copy workloads and 1,030 continuation cycles.

Successful construction requests change from two to one for default copies and
three to one for custom volumes. Complete snapshots agree. In the matched core
probe, 100,000 recycled warm-gas copies reduced allocation requests from 200,000
to zero. These are service-core allocation observations, not DreamDaemon retained
memory or production timing claims.

## DM qualification

| Gate | Evidence | Result |
| --- | --- | --- |
| Initial protocol-14 focus | `20260910T011218Z-3d3a4e06` | 20/20, zero runtimes |
| Vertical gas regression before production correction | `20260910T100459Z-4501009d` | Expected missing-edge failure only; fixture cleanup passed; zero raw runtimes |
| Expanded focus after vertical gas and shared-key changes | `20260910T101337Z-37b06029` | 21/21, zero failed/skipped tests and raw runtimes |
| Heat-read admission regression before guard | `20260910T103808Z-4b5ea2da` | Expected raw-snapshot-path failure only; zero raw runtimes |
| Heat admission, shutdown and healthy temperature authority | `20260910T104711Z-6676083b` | 3/3, zero runtimes |
| Full suite on final source | `20260910T105444Z-70bcb13c` | 653/653, zero failed/skipped tests and raw runtimes |
| Production 300-second soak on final source | `20260910T112018Z-ff6cb9e4` | Passed; zero raw runtimes and structured failure signatures |
| Exact comparison control semantic focus | `20260910T113213Z-dbb1964c` | 7/7, zero runtimes; candidate restored after clean cleanup |

The expanded focus compiled with zero errors and two CI warnings, recorded
explicit shutdown, natural DreamDaemon termination with code 224, successful
RIFT cleanup and no retained processes. The disposable database shut down with
code zero. Installed paired-artifact verification passed.

The vertical fixture was corrected before its accepted failing run. Its openspace
transparency component had to detach while the temporary linked-level route was
still valid, and its bounded activation frontier had to return to its original
state. Earlier setup/cleanup failures are retained as diagnostic evidence; they
are not clean failing-test or performance results.

Those failed fixtures also exposed a late heat-read path that still reached the
service after admission closed. The getter now returns null before consulting
pending heat or native state when service readiness is false; both public
temperature callers use their existing DM-local fallback. The regression failed
on the unguarded getter and passed with the guard. It isolates the target's
pending heat entry, checks the real registered-turf read and both fallback
callers, then restores the exact original queue and fixture state before
assertions. The healthy temperature-authority test also passed.

The final full suite compiled with zero errors and two CI warnings. All 653
recorded tests passed without skips or raw runtimes. DreamDaemon recorded
explicit shutdown and exited naturally with code 96; RIFT cleanup passed without
leftovers or retained resources. The disposable database shut down with code
zero, all recorded owned processes were absent, and the installed pair verified
again. Final source hashes matched the launch record. Its 138.797-second
initialization is a qualification observation, not matched timing evidence.

The production soak built with zero errors and zero warnings, reached readiness,
and completed its requested 300-second observation. DreamDaemon termination was
requested (code 143), as expected for this gate. Cleanup passed with no process
leftovers; only the explicitly requested workspace was retained. All recorded
owned processes were absent, source hashes matched launch, and installed-pair
verification passed. Initialization was 117.25 seconds on Runtime Station.
Observed soak maxima were 1,885,093,888 private bytes for DreamDaemon and
136,425,472 for the service, recorded separately. This single small-map soak
does not establish a memory or startup improvement.

## Completed local control/candidate measurements

All six observations passed on the final restored source. Each completed its single
180-second shared-observer test with zero raw runtimes, successful RIFT cleanup,
stopped disposable database, bounded process sampling and no observed competing
game/compiler workload. Other activity on the host was not controlled; the user
reported substantial concurrent PC activity. The exact ruin placement/order witness matched across
conditions. The first two observations retain their original resumption provenance.

| Order | Condition | RIFT run | Initialization (s) |
| --- | --- | --- | ---: |
| 1 | control | `20260910T120559Z-c05203fb` | 209.181 |
| 2 | candidate | `20260910T121608Z-5fe0aa10` | 238.363 |
| 3 | candidate | `20260910T130641Z-f6829e35` | 202.369 |
| 4 | control | `20260910T131651Z-04ec0e08` | 221.222 |
| 5 | control | `20260910T132751Z-fe9dbc90` | 215.078 |
| 6 | candidate | `20260910T133837Z-fade0d05` | 234.212 |

| Paired block | Candidate minus control (s) | Difference |
| --- | ---: | ---: |
| 1 | +29.182 | +13.95% |
| 2 | -18.853 | -8.52% |
| 3 | +19.134 | +8.90% |

The candidate median is 234.212 seconds versus 215.078 seconds for control
(+8.90%). Two candidate observations are slower and one faster. This series
does not establish a startup improvement; the slower observations remain a
regression concern. Three observations per condition cannot resolve population
tails or attribute the difference to one of the coupled source changes. In all
three pairs the second run was slower, so order and host effects remain
confounded with the variant. Main-server testing is the next performance gate.

| Resource metric, median of three per-run observations | Control | Candidate |
| --- | ---: | ---: |
| dreamdaemon, pre gameplay, peak private bytes (MiB) | 2566.203 | 2566.266 |
| dreamdaemon, pre gameplay, peak working set bytes (MiB) | 2446.926 | 2447.875 |
| dreamdaemon, pre gameplay, peak virtual bytes (MiB) | 2737.770 | 2736.684 |
| dreamdaemon, pre gameplay, sampled cpu seconds (s) | 212.391 | 228.984 |
| dreamdaemon, gameplay, peak private bytes (MiB) | 2714.766 | 2750.184 |
| dreamdaemon, gameplay, peak working set bytes (MiB) | 2593.574 | 2611.406 |
| dreamdaemon, gameplay, peak virtual bytes (MiB) | 2892.117 | 2928.941 |
| dreamdaemon, gameplay, sampled cpu seconds (s) | 134.438 | 132.219 |
| dogmosd, pre gameplay, peak private bytes (MiB) | 274.066 | 342.836 |
| dogmosd, pre gameplay, peak working set bytes (MiB) | 216.410 | 216.203 |
| dogmosd, pre gameplay, peak virtual bytes (MiB) | 4427.301 | 4495.938 |
| dogmosd, pre gameplay, sampled cpu seconds (s) | 6.125 | 5.609 |
| dogmosd, gameplay, peak private bytes (MiB) | 417.562 | 420.785 |
| dogmosd, gameplay, peak working set bytes (MiB) | 290.379 | 289.465 |
| dogmosd, gameplay, peak virtual bytes (MiB) | 4583.262 | 4586.660 |
| dogmosd, gameplay, sampled cpu seconds (s) | 8.766 | 7.719 |

DreamDaemon pre-gameplay median peak private bytes differ by only 65,536 bytes;
there is no demonstrated footprint reduction. Its gameplay median peak private
bytes are 37,138,432 higher in the candidate. These are sampled per-run peaks,
not retained-allocation attribution. Service resources remain separate from
DreamDaemon. Pre-gameplay includes the complete process interval before the
first observed playing state; sampled CPU omits the interval before attachment.

All observations produced three or four default profiler dumps. Profiling can
restart after a drift-triggered dump, so the timing windows are not wholly
unprofiled and those dumps are not a complete matched call-count interval.

The clean no-Dogmos reference remains unqualified after its planetary-mixture
runtime failure. This phase provides no accepted non-Dogmos proximity result.

Evidence identities:

- Summary SHA-256: `8a46a7d5dc6e7a9ee835a940414184843fb03455f0daa16999c63434d60548f8`.
- Summarizer SHA-256: `da6d7fbdf9975b0a43f222179f2a24122a96807294460ab8d7eee9e60834297d`.
- Actual running orchestration: `6f8a5bf3184dd88faa16bc8629d2ce1d0fabba9217b6f6c7851ff0679b932726`.
- Workload monitor: `ab550d3c533dbf59a270979c710b3b1d185b86de2a0fab0ad18dbb0468a389d3`.
- Future helper edits are not attributed to these measurements.

## Server capture and stopping point

The user requested an end to local benchmarking because the PC has substantial
other activity. The native `dogmos` branch is merged into `master`, which remains
at `6b6321b2c4a0658933b7529e1d732acfac9cc5a4`. The installed candidate is retained
on its numerical, lifecycle, subtype and topology qualification. Startup and
DreamDaemon footprint improvement remain unproven; the gameplay peak increase
remains an unresolved observation.

The game-side capture entry point is
`modular_aphelion/tools/dogmos_tracy/START_CAPTURE.cmd`. The portable package
contains the same source, the existing verified x86 hook and x64 collector,
their licenses/provenance, and a regenerated complete hash manifest. See the
[server instructions](../../modular_aphelion/tools/dogmos_tracy/README.md).

The launcher saves deployment paths after first setup, verifies the deployed
Windows native pair, arms the existing one-shot marker and waits for the
operator's normal TGS hard restart. It captures five 120-second windows by
default. New-round process identity, selected engine, loaded hook, separate
DreamDaemon/service samples and before/after build/native hashes are recorded.
It never deploys a release or stops TGS, DreamDaemon or Dogmos. It cleans up its
own unconsumed marker and collector while preserving partial failure evidence.

Local capture-tool checks are separate from game qualification:

- Fifteen launcher scenarios pass in Windows PowerShell 5.1 and PowerShell 7
  using OS/collector fixture doubles, including timeout, foreign marker,
  incomplete trace, native mismatch, changed deployment and cleanup failure.
- Five actual cleanup/error-propagation scenarios pass using process/writer
  doubles. Primary failure text and best-effort capture evidence survive
  independent cleanup failures.
- The real packaged collector starts and the complete bundle/native checks
  pass in both PowerShell versions. The disposable check fixture's DMB is never
  executed; this check does not establish game attachment or trace coverage.
- Real main-server attachment, trace quality, sampling coverage and repeated
  production workload comparison remain unrun. Test those using the packaged
  instructions, without concurrent deployment changes.

The reference-only planetary-template repair and the proposed StopLoadingMap
registration batching remain staged, uninstalled and unqualified. The original
no-Dogmos checkout remains unchanged. Resume that work only after reviewing the
main-server evidence. No additional production behavior was changed after the
completed full suite and soak; subsequent changes are capture tools and reports.

## Reproduction entry points

Use the repository-pinned tools and a prepared disposable CI database for DM
test gates. The exact selected profiles and maps are part of each workload:

```powershell
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json `
    --minimum-tests 500 --wait-for-lock-seconds 0 --shim dogmos.dll `
    --service dogmosd.exe --network offline --format result `
    --wall-timeout-seconds 2400 --idle-timeout-seconds 600
.\RIFT.cmd soak --profile dogmos --map _maps/runtimestation.json `
    --run-seconds 300 --shim dogmos.dll --service dogmosd.exe `
    --network offline --format result --wall-timeout-seconds 1800 `
    --idle-timeout-seconds 600 --keep-workspace
.\modular_aphelion\tools\dogmos_tracy\Test-OneClickCapture.ps1 `
    -EvidenceRoot <new-disposable-fixture-directory>
.\modular_aphelion\tools\dogmos_tracy\Test-CaptureCleanup.ps1 `
    -EvidenceRoot <new-disposable-fixture-directory>
```

The last full-suite and soak records identify dirty game HEAD `12166270...`
with these exact tested files:

| File | SHA-256 |
| --- | --- |
| `gas_mixture.dm` | `52ee55ba7c77dcf2badcc62d5095581c48ff4b51f6ba69a43c39d909a1818d3b` |
| `service_backend.dm` | `636ddd828b74165a930a2c12e93a5c5ff9e5e035a51e53582f9319f20711bb78` |
| `service_backend_test.dm` | `b380ab3e48a45ec7e4270788c24b4536d20b39dabca228a4e37178d90227651b` |
| `dogmos.lock.json` | `e0140cb7e695dc4e3e73490c749eb9eb68d891d65fdf625d4f4c555baab35210` |

The six per-run timing/resource rows are retained in
[the CSV](data/2026-09-10-dogmos-startup.csv). Raw test logs, profiles, database
clones and process observations remain in ignored local evidence. Earlier
overlapped/grouped runs and failed orchestration/reference attempts are retained
there and excluded from performance acceptance.

Hosted CI, Linux BYOND loading, populated playtesting and production Tracy
acceptance remain separate unrun gates. No push was performed.
