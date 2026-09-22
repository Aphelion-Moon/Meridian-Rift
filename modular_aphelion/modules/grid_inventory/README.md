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
plain text without a black outline. Wrapped titles grow the header while keeping
equal vertical padding and a centered close button. Text measurement runs
asynchronously only when the title or available width changes.
Window dragging translates existing HUD objects without rebuilding the chrome,
reapplying layers, or clearing highlights on every mouse event. Repeated clamped
positions are skipped. Movement still travels through the server; this change
does not add client prediction.

Click an empty cell with your active held item to place it. Drag stored items to
rearrange the grid or transfer between open containers. Items dragged from either
hand or an equipped inventory slot use the same preview and rotation controls.
Drop onto a nested container, a panel header, or an open bag's inventory icon to
place the item automatically, rotating it if needed. Drop onto an empty cell to
choose the position and orientation yourself. While dragging, **Q**
rotates left, **E** rotates right, and the mouse wheel also rotates. Invalid
placements and drops outside these targets leave the item in its original inventory.
Hover fills the item's occupied cells with translucent white. Dragging fills
the proposed placement green when it fits, or red when it does not; grid lines
remain visible through the fill, underneath the item artwork.

Double-click a nested container to open its own movable, closable panel.
Nested storage keeps its original owner and insertion restrictions. Its grid
has a fixed number of usable cells based on its capacity for tiny items (seven
cells for a medkit). Incoming items try both orientations in that existing
space; insertion fails if neither fits. Panels never grow usable rows or pages.
Nested panels retain their compact limit of 7×3 cells; unused cells in a partial
last row cannot accept items.
Item footprints and 24px cells stay consistent across containers. Positions
and rotations belong to the storage owner and survive closing its panel.
An active-hand item previews placement when hovering over the grid. Q/E and
the mouse wheel rotate that preview; clicking places it at the shown position.
Eligible containers in every open panel have blue backgrounds while holding or
dragging an item, including the container a dragged item is already in.
Hovering one turns its whole footprint green if the item can fit, or red if it
cannot. Dropping an item onto its current container leaves it in place. The
payload stays visible without its own placement fill over a container; no
rejection X is shown. A panel header uses the same automatic insertion check
and colors its grid. Dragging a stored item takes precedence over the
held-item preview until the drag ends.
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
- Placements and occupancy belong to the storage owner. Grid packing activates
  for the pilot and its nested containers, including closed containers. Insertion
  tries each cell in row order in both orientations, starting with the drag's
  rotation when supplied. Resizes retain the anchor
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
the same two warnings. All 16 focused behavior tests passed, including both
Click/DblClick event orders, immediate single-click pickup, stale rollback rejection,
transfer rollback, storage-first teardown, and highlight cleanup after rotation,
leaving the grid, refreshing the panel, or closing a drop destination, plus
restoring ordinary hover after a drop. Inventory-drag coverage includes hand-slot
backgrounds, worn-item cleanup, no-drop restrictions, precise rotated placement,
open bag icons, closed nested containers, automatic rotation, locks, and full grids.
The nested-storage regressions check fixed capacity while closed, automatic
rotation, full-container rejection, partial final rows, equal artwork scale,
full-footprint mouse targets, persistent positioning, collisions, and access to
take-only forced contents. Held-item tests cover green/red previews, rotation,
click insertion, blue eligibility limited to storage items, full-footprint green/red
container hover with a visible payload, stored-item drag priority, hand swaps,
and rotation after a container pickup. Eligibility refreshes after outside
clicks, locks, and closed-container content changes. A connected-client fixture also
passed nested-panel ownership, original starting position, HUD refresh/theme
preservation, tooltip show/hide, rotation-key release, and screen cleanup checks. That run produced
`clean_run.lk` with no runtimes. The full unit suite and current performance
benchmark were not run. The later cross-panel eligibility test
(`grid_inventory_cross_panel_highlights`) has not been run yet.

DreamSeeker captures verified the original starting position, centered sample
art, separate parent/child panels, Midnight and Plasmafire styling, borderless
items, plain panel titles, and translucent hover/valid/invalid placement fills.
A side-by-side native capture also verified equal crowbar size in the backpack
and an ordinary nested medkit.
Current DreamSeeker captures verify the fixed medkit row, red/green active-hand
previews, blue behind eligible container items only, green/red container hover
with the payload still visible, and stored-item drag priority. A wrapped wallet
title measured 32px high inside a 43px header, with 5px of padding on both sides.
These are controlled rendering checks, rather than full mouse-gesture playtests.
Title-drag regressions check grab offsets, aligned item artwork, and unchanged
HUD object counts. The reduction in drag work has not been measured as client
latency or smoothness.
An isolated DreamSeeker WebView2 capture verified the tooltip renderer's sharp
14px text, 15px heading, and equal 6px vertical padding. Browser checks covered
placement at all four viewport corners and cancellation of a pending show.
Earlier native DreamSeeker mouse events verified immediate pickup, double-click
opening with placement restoration, and a subsequent single click. The local
fixture observed pickup on the next 50 ms server tick after release; that is
not a measurement of network latency. External inventory dragging and automatic
container drops pass the focused regressions. Their full native drag trial
remains unverified because Windows denied foreground access to the test client.

Before rollout, use DreamSeeker with two actual viewers to verify dragging,
rotation and key release, immediate pickup and double-click opening, tooltips,
hover previews, panel dragging, nested transfers, close/reopen, and live HUD
style changes. Include small and large views and realistic latency. Measure traffic
and client rendering there. Visual, usability, capacity/balance and performance
acceptance remain required before converting any other storage.
