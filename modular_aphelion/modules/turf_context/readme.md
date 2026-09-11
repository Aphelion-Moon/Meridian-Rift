# Turf context lifecycle

The marked hook in `code/game/turfs/turf.dm` removes a turf's own contextual screentip
handler during destruction. `ChangeTurf()` can then carry external listeners into the
replacement without retaining the old type's handler. Reusing condo reservations exposed
the stale handler when deferred initialization registered context on a new door.

Cleanup must happen before `ChangeTurf()` copies the signal tables, so a narrow hook in
the existing destruction path is required. No contextual text or map content is changed.

The marked restoration hook in `code/game/turfs/change_turf.dm` also filters subscribers
deleted during replacement construction. Their destruction can run before the saved
listener table is restored; blindly restoring it retains a deleted object. This caused
the old-gibs hard delete reported by SerenityStation's `create_and_destroy` CI test.
Deleted subscribers are filtered; live subscriptions and the existing merge behavior
are preserved. The regression `turf_context_deleted_subscriber` checks deletion during
construction and signal delivery to a surviving listener in the same signal bucket.

A second marked hook in `code/datums/signals.dm` handles `UnregisterSignal` while a
replacement turf's lookup is temporarily unavailable. It retires the listener-side
callback metadata, including shared elements that remain alive after their host is
deleted. Restoration then skips subscriptions whose callbacks were withdrawn. The
turf's own outgoing signal table is restored afterward, so its pending entries retain
the previous restoration behavior.

`turf_context_elevation_constructor` reproduced stale table trait and footstep
registrations after constructor-time deletion. `turf_context_elevation_reservation`
checks ordinary empty/reload cycles while retaining ownership of the reserved tile.
Both check that an unrelated external turf-change listener survives. The subsequent
full-suite retry rendered the previously failing Arrivals condo preview and passed
both fixtures, including direct checks of the shared elements' signal metadata.

The full suite then exposed a separate missing cleanup in `code/game/turfs/open/lava.dm`:
lava retained its own lava-stopping trait-removal listener after replacement. Deleting
a catwalk on the new floor could dispatch that obsolete callback. A narrow marked
unregister in lava's destructor retires this type-owned registration. The regression
`turf_context_lava_replacement` checks both its removal and continued delivery to an
external listener. This does not change the general turf signal-persistence contract.

Upstream status: prepared locally, not submitted. Remove the local hook when upstream
provides equivalent cleanup that also preserves external subscribers. The context regression is
`/datum/unit_test/turf_context_replacement`; pair it with the existing
`/datum/unit_test/connect_loc_change_turf` when verifying listener preservation.
