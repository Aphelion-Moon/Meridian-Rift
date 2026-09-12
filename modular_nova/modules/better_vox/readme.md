## Credits

Code: [@Gandalf2k15]
Original Sprites: [TauCeti]
Sprite Modifications: [CandleJaxx]

## TODO

Get all clothing sprites to fit.
Get all bodyparts to fit.
Add the bodypart color selection.
Make the tails work.
Fix the legs not being fully there without a tail.

## Pants fallback

Uniforms covering `LEGS` use a generated pants fallback when neither an item-specific
Vox sprite nor the shared Vox uniform sheet contains their worn state. The upper
garment is preserved, including rolled-down states. Skirts and other slots are excluded.

`icons/clothing/pants_template.dmi` contains the four-direction `pants` state,
derived from rows 1 through 11 (BYOND coordinates) of the `jumpsuit` state in
`modular_nova/modules/GAGS/icons/jumpsuit_better_vox.dmi`. Those are exactly the
rows removed by the existing `digi_leg_mask` through `replace_icon_legs()`.
`modular_nova/modules/GAGS/json_configs/vox_primalis_pants.json` colors the template using one color, with the same
single-color preference and multicolor pixel sampling used by digi clothing.
Generated files retain normal and rolled-down states and are cached by source
file, state, and palette; they are not stored as dedicated item sprites.

## Vox clothing templates

Normal Vox now have pants, glove, sneaker, and boot fallbacks. Vox Primalis
(Better Vox) additionally have sneaker and boot fallbacks. Dedicated item sprites
and existing shared species states are selected first. Other footwear uses the
boot template, following the digitigrade generator; gloves are only generated for
normal Vox. Uniforms must cover LEGS, except for the existing explicit
vox_primalis_force_pants override.

The templates are 32x32, with south, north, east, and west directions:

| Species | DMI path | States |
| --- | --- | --- |
| Normal Vox | modular_nova/master_files/icons/mob/clothing/species/vox/pants_template.dmi | pants |
| Normal Vox | modular_nova/master_files/icons/mob/clothing/species/vox/hands_template.dmi | gloves |
| Normal Vox | modular_nova/master_files/icons/mob/clothing/species/vox/feet_template.dmi | shoes_colored, shoes_uncolored, boots |
| Better Vox | modular_nova/modules/better_vox/icons/clothing/feet_template.dmi | shoes_colored, shoes_uncolored, boots |

Normal Vox pants are the lower eleven BYOND rows of GAGS/icons/jumpsuit_vox.dmi
(jumpsuit); gloves come from its gloves state. Normal Vox sneakers reuse the
sneakers_back and sneakers_front layers of GAGS/icons/sneakers_vox.dmi. Boots
for normal Vox reuse the boots state of GAGS/icons/shoes/shoes_oldvox.dmi.
Better Vox sneakers reuse the sneakers_back and sneakers_front layers of their
existing feet.dmi. Better Vox boots use the fully covering combat state from that
feet.dmi, normalized to greyscale for recoloring. Better Vox pants use tailored
crease shading and an extended hip contour, with a small bottom notch at BYOND
x=15..17, y=6 in the south and north views. Shading immediately above the notch
forms a short recessed fold. The notch intentionally exposes the underlying
body, including one green pixel at the back. These templates do not change body sprites.

The normal Vox jumpsuit layer is pixel-identical in GAGS/icons/jumpsuit_vox.dmi
and master_files/icons/mob/clothing/species/vox/uniform.dmi (jumpsuit state).
The runtime first checks item-specific Vox icons, then the shared uniform.dmi,
and only generates template pants when those do not provide the requested state.

The shared vox_feet.json GAGS config produces sneakers_worn and boots_worn;
vox_hands.json produces gloves_worn. Each takes one color, like the digi masks.
Single-color clothing keeps its palette, multicolor pants and footwear use the
existing digitigrade color sampler, and gloves use their most common visible
source color. Sneaker trim retains its original color.

Generated pants retain upper garments and rolled-down states, including aliases
for explicit worn states. Files are cached by species, source file/state, template,
item type/state, and palette; generated fallbacks never become dedicated item
icons. Recoloring therefore selects fresh output. Normal Vox clothing selection
precedes generic digitigrade sprites, and fitted sprites skip a second digi mask.
Vox with plantigrade legs retain their existing human-footwear behavior.

The vox_clothing_templates unit test checks all directions, recoloring, static
colors, dedicated-sprite priority, invalid states, skirts, adjusted uniforms, and
actual equipped overlays, plus Better Vox hip and foot coverage against the body
sprites in every direction, with the intentional bottom notch checked separately.
It exports all-direction worn previews into the test workspace's
data/vox_templates_*.png files.
