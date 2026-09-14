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

## Shared uniform artwork

`icons/clothing/uniform.dmi` contains the retained worn states, including states
used by reskins and adjusted uniforms. Plain colored jumpsuits use
`GAGS/icons/jumpsuit_better_vox.dmi` through GAGS; their obsolete per-color copies
are not needed in the shared sheet.

The former `NEEDS CONVERTED` entry was an editor reminder, not a runtime flag.
Some artwork after it is still used, including legacy human-shaped sprites and
reskins. The marker and unused states have been removed; retained states keep
their existing pixels. The generic `jumpsuit`/`jumpskirt` states and their `_d`
variants remain available to dynamic clothing changes such as disguises.

The fitted rainbow artwork is stored as `rainbow` in the shared uniform sheet.
The item uses `rainbow` for both species lookup and uniform rendering. It does
not run GAGS at initialization, so it uses this sheet directly and retains its
original colors. The generic shared `jumpsuit` artwork stays unchanged.

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
| Normal Vox | modular_nova/master_files/icons/mob/clothing/species/vox/uniform.dmi | template_pants, template_shorts, template_jumpsuit*, template_jumpskirt*, template_jeans*, template_belt*, template_buckle, template_shortalls, rainbow |
| Normal Vox | modular_nova/master_files/icons/mob/clothing/species/vox/hands.dmi | template_gloves, template_gloves_talon_out |
| Normal Vox | modular_nova/master_files/icons/mob/clothing/species/vox/feet.dmi | template_sneakers_back, template_sneakers_front, template_sneakers_chained, template_boots, template_laceups, template_sandals |
| Better Vox | modular_nova/modules/better_vox/icons/clothing/feet_template.dmi | shoes_colored, shoes_uncolored, boots |

Normal Vox GAGS inputs live beside the finished artwork in each slot's sheet.
The `template_` prefix prevents raw layers from being selected as finished worn
states. Uniform layers include rolled-down jumpsuits, skirts, prison markings,
and jeans. Sneakers share their back/front layers between ordinary two-color
GAGS and the one-color fallback; chained sneakers add `template_sneakers_chained`.
The old Vox rainbow jumpsuit uses the original `rainbow` state directly, without
generated pants. Better Vox has a separate `rainbow` state whose legs fit its
own pants template. Colorable boots share the corrected fallback boot
layer; colorable laceups and sandals keep their dedicated template layers.
Better Vox sneakers reuse the standard sneakers_back and sneakers_front layers
from icons/mob/clothing/feet.dmi, preserving the original shading and solid soles.
Each side view adds one sole pixel to cover the talon. Better Vox boots use the
fully covering combat state from their own feet.dmi, normalized to greyscale
for recoloring. Better Vox pants use tailored
crease shading and an extended hip contour, with a small bottom notch at BYOND
x=15..17, y=6 in the south and north views. Shading immediately above the notch
forms a short recessed fold. The notch intentionally exposes the underlying
body, including one green pixel at the back. These templates do not change body sprites.

The normal Vox jumpsuit source layer is `template_jumpsuit` in `uniform.dmi`.
The runtime first checks item-specific Vox icons, then the shared uniform.dmi,
and only generates template pants when those do not provide the requested state.

The vox_feet.json GAGS config produces sneakers_worn and boots_worn;
vox_hands.json produces gloves_worn. The Vox Primalis counterparts keep their
original source names in vox_primalis_feet.json and vox_primalis_hands.json.
Each takes one color, like the digi masks.
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

## Skirts, dresses, and Vox legs

Normal Vox use the same unmodified outfit sprites and recoloring configs as
Better Vox for the audited skirts, dresses, kilts, maid outfits, and similar
clothing. These explicit overrides take priority over the pants template, even
when an outfit covers `LEGS`. The existing old-Vox bathrobe stays species-specific.

Normal Vox always use their digitigrade Vox legs. The leg-shape preference is
hidden, and a saved normal-leg choice cannot select plantigrade legs on spawn
or body replacement.
