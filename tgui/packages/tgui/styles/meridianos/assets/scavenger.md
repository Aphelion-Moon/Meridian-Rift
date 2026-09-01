# Scavenger casing assets

These assets implement the approved second Scavenger (`meridian_bastion`)
mockup, with rusted olive metal surrounding cream-on-dark reading surfaces.

| Asset                | Origin                                                                                                     | Use                                                               |
| -------------------- | ---------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `scavenger-rust.jpg`   | Generated with OpenAI image generation on 2026-09-06; encoded as JPEG at quality 82 from the generated PNG | Repeated casing material, displayed at 384 CSS pixels per tile    |
| `scavenger-plates.svg` | Original SVG authored for this implementation                                                              | Edge-anchored patched plates and recessed fasteners on title bars |

The generation prompt requested a flat, evenly lit dark olive steel material
with irregular muted iron-rust patches, pitting, granular paint wear, and fine
scratches. It excluded text, logos, UI, objects, borders, panel divisions, bolts,
perspective, and directional lighting. Opposing edges were requested to match
for repeated use; the delivered image is 1254 by 1254 pixels. The separate SVG
supplies the plate geometry and fasteners without baking interface details into
the raster material. Neither file contains extracted franchise artwork.

`scavenger-rust.jpg` is 334,019 bytes. Its SHA-256 is
`a90d436919b9198561bbe16f2ba33aa63c7f2c8ef14d8dcc7c0e16316fb8ec86`.
Rspack inlines the JPEG and SVG into both the TGUI and lobby stylesheets, so
BYOND's cached CSS contains the material without separate texture requests.
