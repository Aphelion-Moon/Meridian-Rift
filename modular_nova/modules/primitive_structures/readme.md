## Title: PRIMITIVE

### Description:

Contains various items of primitive style for icecats and sometimes even ashwalkers

### TG Proc/File Changes:

- `code/game/objects/items/wall_mounted.dm`: `requires_floor` defaults to `TRUE`. Torch mounts set it to `FALSE`, preserving their ability to mount while the user stands on non-floor terrain. The shared wallframe checks still require an adjacent, cardinally aligned support and an available wall position; a successful placement consumes the torch mount.

### Defines:

- N/A

### Master file additions

- N/A

### Included files that are not contained in this module:

- N/A

### Credits:
