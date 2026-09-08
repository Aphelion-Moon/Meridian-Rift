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
Only deleted subscribers are filtered; live listeners and the existing merge behavior
are preserved. The regression `turf_context_deleted_subscriber` checks deletion during
construction and signal delivery to a surviving listener in the same signal bucket.

Upstream status: prepared locally, not submitted. Remove the local hook when upstream
provides equivalent cleanup that also preserves external subscribers. The context regression is
`/datum/unit_test/turf_context_replacement`; pair it with the existing
`/datum/unit_test/connect_loc_change_turf` when verifying listener preservation.
