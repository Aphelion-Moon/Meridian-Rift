# Turf context lifecycle

This module retains regression coverage for turf replacement. The lifecycle itself is
now handled by the core implementation merged from `master`:

- `code/game/turfs/turf.dm` clears the outgoing turf's self-subscriptions in
  `_clear_signal_refs()`, while preserving external listeners.
- `code/game/turfs/change_turf.dm` passes surviving signal tables into the replacement
  constructor. `/turf/New()` installs them before initialization can move or delete
  existing occupants.
- Normal `UnregisterSignal()` therefore updates both sides of each subscription
  during construction. Saved tables must not be restored again after initialization.

The former restoration/filter helpers, missing-table unregister fallback, and
context- and lava-specific unregister hooks are superseded by this core lifecycle.
No contextual text or map content is changed.

The retained regressions cover:

- `turf_context_replacement`: retiring an old door's contextual handler while
  preserving an external context listener.
- `turf_context_deleted_subscriber`: removing a subscriber deleted during
  construction while delivering signals to its surviving peer.
- `turf_context_elevation_constructor`: retiring table trait and footstep
  subscriptions during constructor-time deletion.
- `turf_context_elevation_reservation`: ordinary reservation empty/reload cycles.
- `turf_context_lava_replacement`: retiring lava's trait-removal handler while
  retaining an external listener.

Pair these tests with `/datum/unit_test/connect_loc_change_turf` when verifying
listener preservation. Focused regression results do not replace full-suite or
populated-map verification.
