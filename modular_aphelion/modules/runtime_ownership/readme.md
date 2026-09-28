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

## Queued JPS repath and teardown regression

`code/controllers/subsystem/movement/movement_types.dm`, `/datum/move_loop/has_target/jps/proc/recalculate_path`, retains an early deleted-loop check. The upstream deletion-during-`move()` fix does not guard a repath invocation that reaches this proc after teardown. `code/modules/unit_tests/movement_order_sanity.dm` exercises normal movement, deletion during movement, and a late repath; the late call must not restart its cooldown or enqueue pathfinding. Remove the local guard when upstream provides the same late-call contract. No upstream issue or PR has been filed for this remaining case.

Related existing corrections are marked in `code/datums/components/atom_mounted.dm`, `code/modules/unit_tests/wallmount.dm`, and `code/modules/unit_tests/reagent_container_defaults.dm`. They cover missing neighboring turfs at map edges and fixture behavior; the review correction only records their ownership.
