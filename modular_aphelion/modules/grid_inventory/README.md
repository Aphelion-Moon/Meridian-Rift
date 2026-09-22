# Native grid inventory pilot

Spawn `/obj/item/storage/backpack/grid_pilot` for an empty 7x3 backpack, or
`/obj/item/storage/backpack/grid_pilot/sample` for the four artwork samples.
Its 21 cells hold 21 default tiny items, matching an ordinary backpack's tiny-item
capacity. Larger items must fit their footprints. Only these pilot subtypes
start a grid session; no loadouts, vendors, or maps select them.
The implementation plan is [workplan.md](workplan.md).

The compact native panel uses 24px cells, a dark flat background, subtle grid
lines, a thin border, and a colored titlebar with an **X**. It starts at the
existing backpack HUD position; drag the titlebar to move it. All nine HUD
styles are supported, including live style changes.
Items draw directly over the grid without individual borders. Panel titles use
plain text without a black outline.

Click an empty cell with your active held item to place it. Drag stored items to
rearrange the grid or transfer between open containers. While dragging, **Q**
rotates left, **E** rotates right, and the mouse wheel also rotates. Invalid
drops and drops outside a panel leave the original placement intact.
Hover fills the item's occupied cells with translucent white. Dragging fills
the proposed placement green when it fits, or red when it does not; grid lines
remain visible through the fill, underneath the item artwork.

Double-click a nested container to open its own movable, closable panel.
Ordinary nested storage keeps its original slot capacity and insertion rules.
Its display uses the same item footprints and 24px cells as the backpack,
expanding into additional rows or pages instead of shrinking item artwork.
Item positions and rotations remain stable when the panel refreshes.
A plain single click takes the item immediately through the normal pickup path.
A native double-click reverses that pickup, restores the original anchor and
rotation, and opens the container. The following click-release is consumed;
a new mouse press starts a fresh action. No pickup timer or server-side
double-click threshold is used. The item can briefly appear in hand between
the two clicks. Rollback respects access, ownership and insertion checks;
it never reclaims an item that the player has dropped or moved elsewhere.
This uses Microsoft's documented
[click rollback pattern](https://learn.microsoft.com/en-us/dotnet/desktop/winforms/input-mouse/how-to-distinguish-between-clicks-and-double-clicks)
for incompatible single/double-click actions. Removing the artificial wait also
follows [NN/g's response-time guidance](https://www.nngroup.com/articles/response-times-3-important-limits/)
for direct manipulation. Network latency and normal gameplay restrictions still
apply; there is no client prediction or bypass of pickup checks.
Closing a child panel leaves its parent open; closing a parent also closes its
descendant panels. Compact hover tooltips show the item name, category, a short
description preview, and relevant controls.
Tooltips use the game's existing HUD tooltip browser, independently of TGUI,
so their text stays sharp at different map zooms. They use the panel's palette,
14px body text, and equal 6px vertical padding, with a 300px maximum width.

Orange overflow cells are take-only. Remove those items to enable insertion
again. The **>** button cycles overflow pages so forced contents cannot become
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
  All HUD mutations check reach, open-session membership, mobility, ownership and fit.
  Drag revision checks reject actions captured before another content change.
- `/datum/grid_inventory_session` coordinates the viewer's open panels and drag
  input. Each `/datum/storage_interface/grid` owns its cells and item displays.
  Refreshes reuse them; closing deletes the relevant displays and signals.
  Appearance changes invalidate affected display caches. World items never
  enter the grid HUD's `client.screen` list.
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

**Historical benchmark: the earlier 32px, single-panel implementation.** These
local BYOND 516.1687 measurements (2026-09-21) used one item per container and do
not establish performance for the current 24px implementation with multiple panels.

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
That earlier run passed all eight focused behavior tests plus the opt-in
benchmark, produced `clean_run.lk`, and had no runtimes. Earlier runs hit
unrelated atmosphere/decorative-burning runtimes during world setup; their
focused assertions also passed. The earlier compile reported two existing
warnings (reference tracking and disabled loop checks).

The current implementation compiles under BYOND 516.1687 with zero errors and
the same two warnings. All 13 focused behavior tests passed, including both
Click/DblClick event orders, immediate single-click pickup, stale rollback rejection,
transfer rollback, storage-first teardown, and highlight cleanup after rotation,
leaving the grid, refreshing the panel, or closing a drop destination, plus
restoring ordinary hover after a drop.
The nested-storage regression checks equal artwork scale across containers,
full-footprint mouse targets and previews, persistent positioning, collisions,
and accessibility of paged contents. A connected-client fixture also
passed nested-panel ownership, original starting position, HUD refresh/theme
preservation, tooltip show/hide, rotation-key release, and screen cleanup checks. That run produced
`clean_run.lk` with no runtimes. The full unit suite and current performance
benchmark were not run.

DreamSeeker captures verified the original starting position, centered sample
art, separate parent/child panels, Midnight and Plasmafire styling, borderless
items, plain panel titles, and translucent hover/valid/invalid placement fills.
A side-by-side native capture also verified equal crowbar size in the backpack
and an ordinary nested medkit.
An isolated DreamSeeker WebView2 capture verified the tooltip renderer's sharp
14px text, 15px heading, and equal 6px vertical padding. Browser checks covered
placement at all four viewport corners and cancellation of a pending show.
The double-click fix is
covered by event-sequence regressions; these screenshots are not proof of
physical mouse/key gestures or behavior under network latency.

Before rollout, use DreamSeeker with two actual viewers to verify dragging,
rotation and key release, immediate pickup and double-click opening, tooltips,
hover previews, panel dragging, nested transfers, close/reopen, and live HUD
style changes. Include small and large views and realistic latency. Measure traffic
and client rendering there. Visual, usability, capacity/balance and performance
acceptance remain required before converting any other storage.
