# Vector assets

Original artwork for the Vector skin, grouped the way `forge/` and `neon/` are.

| File | Status | Notes |
| --- | --- | --- |
| `vector-rangefinder.svg` | Held, unreferenced | Rangefinder reticle drawn for Vector's measurement motif. No stylesheet loads it yet; kept deliberately for future use rather than deleted. |

An unreferenced asset costs nothing at runtime — Rspack only inlines what a
stylesheet actually requests — so this file adds repository weight only. To put
it to work, reference it from `_vector.scss` or `_vector-display.scss` the way
the other skins reference theirs, and update the Status column above.
