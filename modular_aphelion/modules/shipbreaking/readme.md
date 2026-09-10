https://github.com/NovaSector/NovaSector/pull/7638

## Shipbreaking

MODULE ID: SHIPBREAKING

### Description:

Ports the shipbreaking system from Doppler (via NovaSector). Salvage companies can call in derelict
vessels to a salvage dock, break them down with demolition charges, and sell or recycle the remains.
Includes the docking clamp, salvage bay controller, prior-owner ship generation, loot spawners,
epic loot containers, and the Tarkon shipbreaking port ruin.

### TG Proc/File Changes:

- `code/game/machinery/recycler.dm`: recycler accepts structures with `TRAIT_RECYCLE_LIKE_ITEM` as items.
- `code/modules/asset_cache/assets/sheetmaterials.dm`: adds the shipbreaking stacks spritesheet.
- `code/_globalvars/traits/_traits.dm` and `code/_globalvars/traits/admin_tooling.dm`: three new traits.
- `tgui/packages/tgui/interfaces/Fabrication/MaterialIcon.tsx` and `MaterialAccessBar.tsx`: aluminum/nanocarbon display.
- `code/datums/components/anomalock_module.dm`: `coreless` flag that skips the anomaly core requirement.
- `code/modules/mod/modules/_module.dm`: `coreless` var on anomalock modules, passed to the component.
- `code/datums/storage/subtypes/bags.dm`: construction bags hold epic loot, nanocarbon shards, demo charges.

### Modular Overrides:

- N/A

### Defines:

- `code/__DEFINES/~aphelion_defines/shipbreaking.dm`
- `code/__DEFINES/~aphelion_defines/shuttle_defines.dm`
- `code/__DEFINES/~aphelion_defines/traits/declarations.dm`

### Included files that are not contained in this module:

- `strings/aphelion/salvage_shuttle.json`
- `_maps/RandomRuins/SpaceRuins/nova/port_tarkon.dmm`
- `_maps/shuttles/nova/salvage/*.dmm`

### Credits:

Paxilmaniac, Doppler Shift Development Team, intense-skies (NovaSector PR #7638)
