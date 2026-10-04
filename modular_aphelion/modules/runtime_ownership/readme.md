# Runtime ownership regressions

Module ID: `RUNTIME_OWNERSHIP`

Ownership guards and focused fixtures for failures found by game verification.
They cover AI escape-target deletion tracking, inventory transfers, progress-bar cleanup and condo preview shutdown using production APIs.
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

Condo preview shutdown closes admission and waits for suspended photographs before Master
stops scheduling: reservation expansion can itself await Mapping's turf reclamation. Atoms,
Mapping and Dogmos remain available until that work finishes. Startup and admin-upload previews use the same
ownership wrapper. The preview loop stops between interiors; an already running map load finishes
through reservation release. Mapping's queued turf reclamation is not awaited after its scheduler
has stopped. Inert subsystem copies cover concurrent photographs, late calls and exception cleanup.

## Upstream tracking

No upstream issue or PR has been filed from this local task. The escape decorators belong to
this checkout's behavior-tree implementation; remove the local assignment patches when its
upstream supplies equivalent deletion-tracked assignments, retaining regression coverage.
The progress-bar guard fixes an inherited tgstation lifecycle bug exposed during the local full
suite. No upstream issue or PR has been filed for it; remove the local guard when upstream handles
queued user-deletion callbacks after bar destruction, retaining the regression fixture.
The condo preview barrier fixes inherited Nova initialization work surviving subsystem shutdown.
No upstream issue or PR has been filed; remove the wrapper and marked hooks when upstream joins
in-flight photographs before dependent subsystems shut down, retaining regression coverage.

## Inclusion and verification

`modular_aphelion/tools/update_module_includes.py --module runtime_ownership --write` regenerates this module's includes from
the maintained source files. Run the repository ticked-file gate afterward.
Tests are enabled only for `UNIT_TESTS` or `SPACEMAN_DMM`.
