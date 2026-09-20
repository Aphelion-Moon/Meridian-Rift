# Native grid inventory pilot

Spawn `/obj/item/storage/backpack/grid_pilot` for an empty 7x3 backpack, or
`/obj/item/storage/backpack/grid_pilot/sample` for the four artwork samples.
No ordinary backpacks, loadouts, vendors, or maps opt into this feature.
The ingested specification is [workplan.md](workplan.md).

Click an empty cell with your active held item to place it. Click the panel's
**R** button to toggle its orientation. Ctrl-click a stored item to rotate in
place; drag from any of its cells to place its lower-left corner at the target
cell. Invalid drops and drops outside this panel leave its placement unchanged.
Normal item clicks, Shift-click examination, Alt-click nested storage navigation,
the back arrow and close button retain their existing behavior.

Orange overflow cells are take-only. Remove those items to enable insertion
again. The **+** button cycles overflow pages so forced contents cannot become
inaccessible because the panel runs out of screen space. Overflow does not
automatically repack when space opens up.

## Implementation contracts

- `get_storage_footprint()` returns two positive integer cell dimensions. The
  optional `storage_footprint` override is independent of artwork and world
  direction. Dynamic overrides call `storage_footprint_changed()` after changes;
  normal `update_weight_class()` changes already notify the container.
- Placements and occupancy belong to `/datum/storage/backpack/grid`. Insertion
  tries each cell in row order, unrotated then rotated. Resizes retain the anchor
  and orientation when possible, otherwise become overflow. Existing neighbors
  never move. Deletion and direct movement release occupied cells immediately.
- The owner retains normal size limits, exceptions, allow/deny lists, locks,
  nesting and item transfer checks. Only the capacity predicate changes.
  All HUD mutations check reach, active storage, mobility, ownership and fit.
  Drag revision checks reject actions captured before another content change.
- `/datum/storage_interface/grid` owns each viewer's cells and item displays.
  Refreshes reuse them; closing deletes them and unregisters signals. Appearance
  changes invalidate affected display caches. The world items never enter the
  grid HUD's `client.screen` list.
- `get_storage_inventory_appearance()` returns a mutable copy for proportional
  pixel scaling and rotation. Ordinary appearances retain colors and overlays;
  the four sample subtypes demonstrate dedicated art. Changed icon states or
  visible overlays fall back to their live appearance until dedicated variants
  exist. World emissive masks are excluded. The sample lighter replaces its
  stock engraving with the dedicated case art, and uses live artwork when lit.
  See [art prompts and files](icons/README.md).

## Validation and acceptance

Focused tests are in `code/modules/unit_tests/grid_inventory.dm`, alongside the
existing storage regression test. They cover packing, bounds, overlap, rotation,
first-fit fragments, preloading, direct moves, deletion, size/stack changes,
overflow recovery, restrictions, access loss, held-item insertion, stale viewer
actions, display reuse, cleanup and separation from world appearance.

`GRID_INVENTORY_BENCHMARK` additionally enables the opt-in benchmark test. It
reports 1,000 insert/remove pairs, 100 layout updates for 20 synthetic interfaces,
and HUD object counts/cleanup. This measures server work without connected
clients and does not measure dragging traffic or perceived responsiveness.

Local measurements on BYOND 516.1687 (2026-09-21), one item per container:

| Operation | Ordinary backpack | Grid pilot |
| --- | ---: | ---: |
| 1,000 insert/remove pairs | 62.5 ms | 100 ms |
| 100 layout updates across 20 interfaces | 18.75 ms | 143.75 ms |
| HUD objects across those interfaces | 180 | 800 |
| Undestroyed HUD objects after interface deletion | 0 | 0 |

These are single-run server measurements with coarse wall-clock timing. The
layout comparison excludes ordinary storage's close/reopen refresh path and
both variants' client screen traffic. The object comparison excludes ordinary
storage's world items. It is not a client performance or memory-retention claim.
The measured run passed all eight focused behavior tests plus the opt-in
benchmark, produced `clean_run.lk`, and had no runtimes. Earlier runs hit
unrelated atmosphere/decorative-burning runtimes during world setup; their
focused assertions also passed. Compilation reports two existing warnings
(reference tracking and disabled loop checks).
The final appearance/interface recheck also completed cleanly, including all
four dedicated sprites, the lighter's lit-state fallback and lighting-mask
exclusion.

Before rollout, use DreamSeeker with two actual viewers to verify dragging,
rotation, pickup, hover previews, nested navigation, close/reopen, artwork in
every HUD theme, small and large views, and realistic latency. Measure traffic
and client rendering there. Visual, usability, capacity/balance and performance
acceptance remain required before converting any other storage.
