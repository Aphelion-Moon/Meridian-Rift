https://github.com/Skyrat-SS13/Skyrat-tg/pull/248

## Title: Modular Items

MODULE ID: MODULAR_ITEMS

### Description:

A modular folder for various single-item additions that don't deserve their own folder, be it new ones or old-skyrat ported items.

See [portal devices](lewd_items/readme.md) for their controls, ownership, configuration, and tests.

### TG Proc Changes:

- `code/game/objects/items/wall_mounted.dm`: `requires_floor` and `consume_after_attach` default to `TRUE`, preserving ordinary wallframe placement and consumption. Portal bores set both to `FALSE`: they allow the user to stand on a non-floor turf and remain as controllers after mounting either endpoint. Support selection, cardinal alignment, occupancy checks, and the `atom_mounted` lifecycle use the standard wallframe path.

- `code/__HELPERS/global_lists.dm`: wall portals belong to `WALLITEMS_INTERIOR`, so the shared placement checks reject an occupied wall position.

### Defines:

- N/A

### Master file additions

- N/A

### Included files that are not contained in this module:

- N/A

### Credits:

Ranged66 - Material pouch ported
KathrinBailey - Pretty much a whole bunch of clothes.
mel-byond - Ported Baystation12 Aviators
RimiNosha - Fixing up code no one else would touch.
