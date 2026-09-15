# Runtime ownership regressions

Module ID: `RUNTIME_OWNERSHIP`

Focused ownership fixtures for failures found by the full game create-and-destroy gate.
They check AI escape-target deletion tracking and inventory transfers using real production APIs.
No creative content is supplied by this module.

## Core changes

The escape decorators' successful target assignment uses the existing blackboard setter so
target deletion removes the stored reference. Conditional selection policy is unchanged.
These small core changes carry `APHELION EDIT CHANGE - RUNTIME_OWNERSHIP` markers.

`/mob/proc/put_in_hand` rechecks item lifetime and location after `forceMove` dispatches
movement signals. A listener may delete the item or move it to another holder before the
original pickup resumes. That pickup now fails before writing a stale hand slot. The check
is a narrow marked addition; normal pickup and transfer behavior stays covered separately.

## Upstream tracking

No upstream issue or PR has been filed from this local task. The escape decorators belong to
this checkout's behavior-tree implementation; remove the local assignment patches when its
upstream supplies equivalent deletion-tracked assignments, retaining regression coverage.

## Inclusion and verification

`modular_aphelion/tools/update_module_includes.py --write` regenerates module includes from
the maintained source files. Run the repository ticked-file gate afterward.
Tests are enabled only for `UNIT_TESTS` or `SPACEMAN_DMM`.
