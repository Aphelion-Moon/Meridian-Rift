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
