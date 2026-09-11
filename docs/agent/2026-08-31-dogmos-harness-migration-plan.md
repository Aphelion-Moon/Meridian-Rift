# Dogmos harness migration plan

## Preconditions

- Port the accepted general RIFT controller without replacing inherited human build entry points.
- Record the Dogmos artifact, binding, map, child-process, fatal-log, and compile contracts.
- Use MetaStation or full RuntimeStation for runtime evidence, never RuntimeStation Minimal.
- Keep DreamDaemon 32-bit and `dogmosd` 64-bit memory as separate series.

## Implementation

1. Add strict `dogmos` and `dogmos-ci` profiles.
2. Require paired native overlay inputs and copy them only into the isolated workspace.
3. Verify the installed native contract and require overlays to match it.
4. Monitor runtime errors, panic output, stage conflicts, malformed responses, pending stages, and lifecycle rejection.
5. Require exactly one continuous `dogmosd.exe` descendant.
6. Produce Dogmos-specific result data without duplicating process, timeout, cleanup, locking, or report infrastructure.
7. Document each old PowerShell command's RIFT replacement and retain old scripts until matched parity is recorded.
8. Run pinned Rust format, clippy, tests, and target builds, recording exact toolchain and targets.
9. Run focused MetaStation tests and a bounded full RuntimeStation soak with identical verified native artifacts.

## Acceptance

- Runtime overlays never replace or restore files in the repository root.
- Missing, extra, early-exiting, or continuously absent `dogmosd` fails with structured evidence.
- DreamDaemon and service memory maxima remain separate.
- Runtime and Dogmos fatal conditions stop the owned process tree and retain evidence.
- Focused tests and short soaks are reported as scoped evidence, not live-round or production qualification.
- Existing scripts are not removed before durable matched parity evidence exists.
