## See yourself at normal size

Module ID: SELF_NORMAL_SIZE

### Description:

A body resized up (Oversized, or the body size slider above 1) covers the tiles round its own, so its owner clicked
their own face instead of what stood north of them. The "See yourself at normal size" preference below Body Size is off by
default. When enabled, the owner alone sees their body at normal size; everyone else sees its true size, as before.

- **Only the owner's client sees it.** The owner's view is a one-person alternate appearance (tg's
  `/datum/atom_hud/alternate_appearance/basic/one_person`): an image that overrides their mob with a copy of the mob's
  own appearance, turned as the body is (lying down) but without its size. Their clicks then reach what the body covers
  on the tiles round it, and still reach their own body on their own tile; everyone else can still click the body
  anywhere it shows. The mob itself is never changed, so mirrors, photos, afterimages and everything else that copies
  its look copy its true size. (tg's seethrough_mob instead hides the mob behind a `*` render target, which every copy
  of its appearance would carry, hiding the copy.) The alternate appearance holds the image and keeps it on the body's
  z-level's planes, so the component keeps no state of its own.
- **Kept up to date.** The copy is made again the tick after the body's look changes (an overlay applied or removed,
  an icon update, its transform, its death), so changes made together are copied once, and on every Life() tick for
  what changes without a signal. Turning turns it at once. What the game only animates on the body, like a jitter, a
  flip or a fade, the copy doesn't play: the owner sees where it ends up.
- **When it shows.** While the owner is logged in to a human resized up and wants it: it starts when they log in, the
  preference changes or the body's size does (`/datum/dna/proc/update_body_size()`), and stops when they log out. A
  body something hides behind a render target, like a dusting body or a hologram synth, shows its owner what everyone
  sees instead.

Checked in a probe world in DreamSeeker 516.1687, on a body at Oversized's 2x: the owner's view is the body exactly as
at normal size (every pixel, glow included), standing on its own tile, and turned at normal size when lying down. A
click where the 2x head covers the tile above reached the object on that tile, where without the view it reached the
body, and a click on the body's own tile still reached the body. A copied appearance carries the body's render target
(`*` and all), which is why this doesn't use tg's seethrough_mob technique.

### TG Proc/File Changes:

None.

### Modular Overrides:

- `code/self_normal_size.dm`: `/datum/component/self_normal_size`, the owner's view;
  `/mob/living/carbon/human/proc/update_self_normal_size()`, which starts or stops it; and
  `/mob/living/carbon/human/Login()`, which calls it.
- `code/preference.dm`: `/datum/preference/toggle/see_self_normal_size`, which calls it when changed.

### Defines:

- `code/self_normal_size.dm`: `SELF_NORMAL_SIZE_MIN_SCALE`. File-local.

### Included files that are not contained in this module:

- `modular_nova/modules/customization/datums/dna/dna.dm`: `/datum/dna/proc/update_body_size()` calls
  `update_self_normal_size()` on a human once its size has changed.
- `tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/character_preferences/aphelion/self_normal_size.tsx`:
  the player-wide preference shown directly below Body Size in character preferences.
- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/BodySize.tsx`: groups the size input and self-view toggle.
- `tgstation.dme`
