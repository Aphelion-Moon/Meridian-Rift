# Native grid inventory: backpack pilot

## Feasibility and direction

The current implementation provides compact native panels while preserving storage ownership and item appearance. Sixteen focused behavior tests pass; the [README](README.md) records the connected-client validation scope. Its earlier 32px, single-panel benchmark does not establish current performance with multiple panels.

Azure Peak provides a useful reference: it implements item dimensions, rotation, occupied cells, and automatic placement. Its native HUD largely displays existing sprites within larger rectangular backgrounds. Meridian uses a different storage architecture, so adapt the ideas rather than directly porting the implementation. [Azure Peak source](https://github.com/Azure-Peak/Azure-Peak/blob/9141f49dc73c491ab6d04291506cf4d87c9f8ac8/code/game/objects/items/storage/new_storage/tetris.dm#L16-L67), [HUD rendering](https://github.com/Azure-Peak/Azure-Peak/blob/9141f49dc73c491ab6d04291506cf4d87c9f8ac8/code/game/objects/items/storage/new_storage/tetris.dm#L104-L161).

The agreed implementation starts with **one opt-in backpack using the native game HUD**, rectangular items with rotation, and a mixture of existing and dedicated inventory artwork. Nested containers open in separate movable panels within the same session.

## Packing and capacity

- Use a **7×3 grid of 24px cells**. Its 21 cells hold 21 default tiny items, matching an ordinary backpack's tiny-item capacity; larger items must fit their footprints.
- Give items an optional footprint override and a `get_storage_footprint()` hook. Untuned items use these defaults:

  | Weight class | Footprint |
  |---|---|
  | Tiny | 1×1 |
  | Small | 1×2 |
  | Normal | 1×3 |
  | Bulky | 2×2 |
  | Huge | 2×3 |
  | Gigantic | 3×3 |

- Store position and orientation **on the container’s placement records**. Rotating an inventory item must not change its world direction or underlying dimensions.
- For the pilot, geometric fit replaces total-size and item-count capacity. Retain maximum individual size, allowed-item lists, exceptions, nesting restrictions, locks, and access checks.
- Nested containers keep their original storage owner and insertion restrictions, with a fixed grid sized from their capacity for tiny items. Incoming items try both orientations within the existing cells; a failed fit rejects insertion. Opening, refreshing or closing a panel never creates usable rows or pages.
- Ordinary click-to-store uses deterministic first-fit placement, trying both orientations. Manual placement uses the chosen cells. Existing items stay where the player put them; no automatic repacking.

## Native HUD and artwork

Current interaction refinement: measure wrapped titles with the native client
font, grow the header with equal vertical padding, and center its controls.
Keep measurement off the drag path. Translate panels without repeating chrome,
layer, highlight, or tooltip updates. For held and dragged items, mark eligible
visible containers blue; the hovered destination becomes green/red while the
payload remains visible without its own fill. Remove the rejection X. Retain
the existing fixed capacity, automatic rotation, and insertion restrictions.

- Extend Meridian’s [storage interface](/code/datums/storage/storage_interface.dm:1) with a grid presentation using **separate HUD objects for item displays**. Scaling, rotation, and highlights affect those displays only.
- Use a dark flat background, subtle 1px grid lines, a thin outer border, and a flat colored header with an **X**. Match all nine HUD styles and update open panels when the HUD style changes.
- Drag a panel by its titlebar. Double-click a nested container to open a separate movable, closable panel. Single-click pickup is immediate; a native double-click reverses that pickup and opens the container. Preserve normal modified clicks and examination. Closing a parent also closes its descendant panels.
- Drag stored or equipped inventory items with the same placement preview. Empty cells select an exact placement; container artwork, panel headers and an open bag's inventory icon automatically place the item, rotating to fit when needed. During a drag, **Q** rotates left, **E** rotates right, and the mouse wheel rotates. Invalid moves leave the original placement intact; drops outside these targets cancel rearrangement.
- Hover with an active-hand item to preview and rotate it before clicking to place it. Automatic container targets have no grid fill and show an X on rejection. A stored-item drag takes priority over the held-item preview until release.
- Show native hover tooltips with the item's name, category, description, and controls, plus valid/invalid placement previews while dragging.
- Add an inventory-appearance hook. Fit existing appearances proportionally with pixel scaling, preserving supported colors and overlays. **Do not stretch artwork or derive physical size from sprite dimensions.**
- Demonstrate dedicated inventory art with a lighter (1×1), bottle (1×2), crowbar (1×3), and first-aid kit (2×2). These establish the visual standard without requiring a complete item resprite.

Different-sized inventory sprites are workable. Matching the screenshot consistently will require some purpose-made art: enlarging a small diagonal sprite cannot supply missing detail or a better silhouette.

## Storage integration and performance

- Keep the implementation in a modular grid-storage feature, with narrow hooks in the existing [storage owner](/code/datums/storage/storage.dm:406). Ordinary storage retains its existing presentation outside a pilot session.
- Use a small occupancy array and item-to-placement records. Validate placement on the server, including current ownership, access, bounds, and overlap.
- Maintain records through insertion, initialization, removal, deletion, and size changes—not just HUD actions. Unplaceable preloaded or forced-in contents remain accessible in a take-only overflow strip; new insertions are blocked until it is cleared.
- Preserve grid placement across closing and reopening. A per-viewer session coordinates open panels and drag input; clean up displays and signals as panels close and synchronize concurrent viewers.
- Reuse HUD displays and cached appearances. Refresh previews only when the target cell, orientation, item, or contents change. Avoid continuous inventory scans, repeated icon flattening, and exhaustive packing algorithms.

A direct placement checks only the item’s occupied cells. Automatic placement checks a bounded number of candidate positions. **Native drag events still involve server/network latency**, so smoothness needs client testing even if collision checks are cheap.

## Validation and rollout

1. **Packing tests:** bounds, overlap, rotation, fragmented space, automatic placement, invalid moves, and two viewers acting on the same item.
2. **Lifecycle tests:** preloaded contents, direct movement, deletion, stack/size changes, nesting, access loss, overflow recovery, and repeated open/close cleanup.
3. **DreamSeeker trials:** panel and item dragging, Q/E and wheel rotation with key release, immediate pickup and double-click opening, nested transfers, tooltips, artwork, live HUD style changes, different view sizes, and realistic latency.
4. **Performance measurements:** compare ordinary and current grid backpacks for insertion time, refresh cost, drag traffic, and retained HUD objects, including multiple panels and concurrent viewers. Keep the earlier 32px benchmark labeled historical.
5. Keep the pilot explicitly spawnable for testing. Expand to ordinary backpacks only after visual, usability, balance, and performance acceptance.

Current boundaries: one pilot session per viewer with multiple nested panels, inventory-only sprite changes, rectangular footprints, and existing stack semantics. Irregular shapes and conversion of specialized storage owners remain outside this pilot.
