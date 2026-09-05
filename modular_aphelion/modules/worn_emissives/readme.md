## Worn emissive grouping

Module ID: WORN_EMISSIVES

### Description:

Moves floating emissive/blocker branches of ordinary carbon equipment into a sibling emissive
group after slot offsets, height filters and missing-limb masks have been applied. The offsets
remain inside that group, so resting uses normal inherited mob transforms. Existing visible
appearance trees and internal mask ordering are preserved; the finished groups are stored in
`overlays_standing` for removal and multiz rebuilding.

This covers ordinary worn slots and held overlays, not the separate psionic held-item
`vis_contents`/render-source path. Absolute-layer effects and non-emissive planes are not moved.
It does not create blockers for items that intentionally do not supply one.

### Call frequency and caching:

The finished per-slot appearance is cached in `overlays_standing`, not rebuilt every frame.
Ordinary human resting changes the mob transform and reuses these appearances. Plane-offset
changes rebuild the cached appearances through `update_z_overlays()`, without calling this helper.

The single hook is in `apply_overlay()`, when a slot has a cached appearance. Most equipment updates
remove the old slot, build a new worn appearance, apply wearer-specific offsets/filters, and then
call `apply_overlay()`. That new appearance needs preparation even if the item is unchanged.
Other slot types exit at the layer guard; leaves and already-separated emissive roots skip recursion.

The cache stores the result, but there is no separate "already prepared" marker or memoization table.
Explicitly preparing the same cached tree again returns it unchanged, although nested visible branches
are still traversed. An identity-only memo would usually miss the freshly built equipment appearances;
an item-only key would miss changing worn overlays, offsets, filters and plane offsets. Avoiding
redundant equipment rebuilds at their callers would save both construction and preparation work,
but needs call-frequency evidence rather than another cache in this module.

### TG Proc/File Changes:

- `code/modules/mob/living/carbon/carbon_update_icons.dm`: one call in `apply_overlay()` before `add_overlay()`.

### Modular Overrides:

- None. Both helpers are new procs; no existing proc is overridden.

### Defines:

- `WORN_EMISSIVE_UNDERLAYS` / `WORN_EMISSIVE_OVERLAYS`: the two traversal selectors, in draw order.
- `WORN_EMISSIVE_VISIBLE_RESULT`: the shared out-parameter slot for the visible tree.

These are file-local helpers, undefined at the end of `worn_emissives.dm`.

### Included files that are not contained in this module:

- None.
