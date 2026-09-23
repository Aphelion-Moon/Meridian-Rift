# Saved hair screenshot fixture

`leia_buns.json` is a normal `custom_sprites.json` sidecar containing one character's
hair drawing. Its hand-authored, three-shade brown side buns are designed for the
existing **Short Hair** hairstyle (`/datum/sprite_accessory/hair/short`), colored
`#583820`. The short cap supplies the hair between the buns; the saved drawing
contains only the buns. Front and Back show two buns; Right and Left show the
near-side bun in profile.

The drawing uses the production version-1 palette/RLE format, literal white tint,
and disabled emission in every view. Grid coordinates start at the upper left of
the 32 by 32 canvas. The screenshot shows Front, Back, Right, Left in that order.

`custom_sprite_saved_hair_screenshot` loads this file through the normal sidecar
reader, hydrates and serializes the editor workspace, writes/reopens that result,
and checks exact rendered-pixel parity. It also calls the repository's
`test_screenshot` helper. Its committed reference belongs at
`code/modules/unit_tests/screenshots/custom_sprite_saved_hair_screenshot_leia_buns.png`.
Regenerate that reference only after visually reviewing the native output, like
other screenshot baselines.
