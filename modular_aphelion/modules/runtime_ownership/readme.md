# Runtime ownership regressions

Module ID: `RUNTIME_OWNERSHIP`

Focused ownership fixtures for failures found by the full game suite.
They check AI escape-target deletion tracking, inventory transfers and progress-bar cleanup using real production APIs.
No creative content is supplied by this module.

## Core changes

The escape decorators' successful target assignment uses the existing blackboard setter so
target deletion removes the stored reference. Conditional selection policy is unchanged.
These small core changes carry `APHELION EDIT CHANGE - RUNTIME_OWNERSHIP` markers.

`/mob/proc/put_in_hand` rechecks item lifetime and location after `forceMove` dispatches
movement signals. A listener may delete the item or move it to another holder before the
original pickup resumes. That pickup now fails before writing a stale hand slot. The check
is a narrow marked addition; normal pickup and transfer behavior stays covered separately.

A progress bar ignores a queued user-deletion callback when another listener has already
destroyed the bar and cleared its user. Signal dispatch intentionally finishes its queued calls;
unregistering during destruction cannot cancel that delivery. The regression uses a wall healer,
a second ordinary bar and a replacement user to cover both cleanup orders and later reuse.

## Upstream tracking

No upstream issue or PR has been filed from this local task. The escape decorators belong to
this checkout's behavior-tree implementation; remove the local assignment patches when its
upstream supplies equivalent deletion-tracked assignments, retaining regression coverage.
The progress-bar guard fixes an inherited tgstation lifecycle bug exposed during the local full
suite. No upstream issue or PR has been filed for it; remove the local guard when upstream handles
queued user-deletion callbacks after bar destruction, retaining the regression fixture.

## Inclusion and verification

`modular_aphelion/tools/update_module_includes.py --write` regenerates module includes from
the maintained source files. Run the repository ticked-file gate afterward.
Tests are enabled only for `UNIT_TESTS` or `SPACEMAN_DMM`.
