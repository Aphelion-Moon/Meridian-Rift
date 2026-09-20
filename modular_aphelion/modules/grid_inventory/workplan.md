# Native grid inventory: backpack pilot

## Feasibility and direction

The larger effort is preserving storage behavior and producing convincing item visuals. Performance remains an assessment from source inspection; no prototype or benchmark has been run.

Azure Peak provides a useful reference: it implements item dimensions, rotation, occupied cells, and automatic placement. Its native HUD largely displays existing sprites within larger rectangular backgrounds. Meridian uses a different storage architecture, so adapt the ideas rather than directly porting the implementation. [Azure Peak source](https://github.com/Azure-Peak/Azure-Peak/blob/9141f49dc73c491ab6d04291506cf4d87c9f8ac8/code/game/objects/items/storage/new_storage/tetris.dm#L16-L67), [HUD rendering](https://github.com/Azure-Peak/Azure-Peak/blob/9141f49dc73c491ab6d04291506cf4d87c9f8ac8/code/game/objects/items/storage/new_storage/tetris.dm#L104-L161).

The agreed first version is **one opt-in backpack using the native game HUD**, rectangular items with rotation, and a mixture of existing and dedicated inventory artwork.

## Packing and capacity

- Start with a **7×3 grid of 32-pixel cells**. This is a pilot calibration, not a claim of equivalent capacity to the current backpack.
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
- Ordinary click-to-store uses deterministic first-fit placement, trying both orientations. Manual placement uses the chosen cells. Existing items stay where the player put them; no automatic repacking.

## Native HUD and artwork

- Extend Meridian’s [storage interface](/code/datums/storage/storage_interface.dm:1) with a grid presentation using **separate HUD objects for item displays**. Scaling, rotation, and highlights affect those displays only.
- Show a themed container frame, clear occupied footprints, item tooltips, and valid/invalid placement previews. Preserve pickup, examine, nested-container navigation, and close controls.
- Drag stored items to rearrange them; click an empty cell with a held item to place it. Provide a Rotate button for held-item placement and Ctrl-click rotation for stored items. Invalid moves leave the original placement intact; drops outside the panel cancel rearrangement.
- Add an inventory-appearance hook. Fit existing appearances proportionally with pixel scaling, preserving supported colors and overlays. **Do not stretch artwork or derive physical size from sprite dimensions.**
- Demonstrate dedicated inventory art with a lighter (1×1), bottle (1×2), crowbar (1×3), and first-aid kit (2×2). These establish the visual standard without requiring a complete item resprite.

Different-sized inventory sprites are workable. Matching the screenshot consistently will require some purpose-made art: enlarging a small diagonal sprite cannot supply missing detail or a better silhouette.

## Storage integration and performance

- Keep the implementation in a modular grid-storage feature, with narrow hooks in the existing [storage owner](/code/datums/storage/storage.dm:406). Unconverted containers retain their current behavior.
- Use a small occupancy array and item-to-placement records. Validate placement on the server, including current ownership, access, bounds, and overlap.
- Maintain records through insertion, initialization, removal, deletion, and size changes—not just HUD actions. Unplaceable preloaded or forced-in contents remain accessible in a take-only overflow strip; new insertions are blocked until it is cleared.
- Preserve placement across closing and reopening. Clean up viewer-specific displays and signals when the interface closes; synchronize concurrent viewers.
- Reuse HUD displays and cached appearances. Refresh previews only when the target cell, orientation, item, or contents change. Avoid continuous inventory scans, repeated icon flattening, and exhaustive packing algorithms.

A direct placement checks only the item’s occupied cells. Automatic placement checks a bounded number of candidate positions. **Native drag events still involve server/network latency**, so smoothness needs client testing even if collision checks are cheap.

## Validation and rollout

1. **Packing tests:** bounds, overlap, rotation, fragmented space, automatic placement, invalid moves, and two viewers acting on the same item.
2. **Lifecycle tests:** preloaded contents, direct movement, deletion, stack/size changes, nesting, access loss, overflow recovery, and repeated open/close cleanup.
3. **DreamSeeker trials:** actual dragging, rotation, pickup, tooltips, artwork, HUD themes, different view sizes, and realistic latency.
4. **Performance measurements:** compare ordinary and grid backpacks for insertion time, refresh cost, drag traffic, and retained HUD objects, including synthetic concurrent-viewer load.
5. Keep the pilot explicitly spawnable for testing. Expand to ordinary backpacks only after visual, usability, balance, and performance acceptance.

Initial boundaries: one open container panel, inventory-only sprite changes, rectangular footprints, and existing stack semantics. Irregular shapes, multiple simultaneous container panels, and conversion of specialized storage are later projects.
