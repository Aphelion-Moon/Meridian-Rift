## Click through yourself at normal size

Module ID: SELF_NORMAL_SIZE

### Description:

A body resized up (Oversized, or the body size slider above 1) covers the tiles round its own, so its owner clicked
their own face instead of what stood north of them. With the "Body Size Click-Through (Self)" preference on (listed after
Body Size, off by default), the owner clicks their body as if it were at normal size: clicks on what the body covers past
its normal-size outline reach what is there, and clicks on that outline still reach the body. Everyone, the owner
included, still sees the body at its true size, drawn in front of and behind everything else as before.

- **Only the owner's client clicks it differently.** BYOND decides a click from the pixels each client draws, and an
  image's own `mouse_opacity` counts for nothing (clicks go by its icons' pixels, whatever its alpha), so the owner gets
  two one-person alternate appearances (tg's `/datum/atom_hud/alternate_appearance/basic/one_person`):
  - a hitbox: an image that overrides their mob with a copy of its look at normal size, turned as the body is (lying
    down), at alpha 1, so it shows next to nothing but still takes the clicks on its pixels;
  - a view: an image with no look of its own holding, in its vis_contents, `/obj/effect/abstract/self_normal_size_view`,
    an object wearing a copy of the body's look at its true size with its `mouse_opacity` off, which an object's honours.
    An override image doesn't draw its vis_contents, so the view has an image of its own.

  Both sit on the body's own plane and layer, so a mob standing on or in front of the owner still covers them. The
  copies' pixel offsets are zeroed, since an image drawn at the body takes on its offsets (lying down, on a table)
  already. The mob itself is never changed, so mirrors, photos, afterimages and everything else that copies its look
  copy it as it is, and everyone else clicks the body anywhere it shows.
- **Kept up to date.** The copies are made again the tick after the body's look changes (an overlay applied or removed,
  an icon update, its transform, offsets or colour, its death), so changes made together are copied once. Turning turns
  them at once. What the game only animates on the body, like a jitter, a flip or a fade, the view doesn't play: the
  owner sees where it ends up.
- **When it runs.** While the owner is logged in to a human resized up and wants it: it starts when they log in, the
  preference changes or the body's size does (`/datum/dna/proc/update_body_size()`), and stops when they log out. A
  body something hides behind a render target, like a dusting body or a hologram synth, gets neither. Stopping removes
  both images and deletes the view object.
- **Cost.** A refresh builds two mutable appearances (two such copies measured about 9 us on a 32-overlay body, one 4.5), at most
  once a tick and only after a look change. Each owner holds two images, two alternate-appearance datums and the view
  object, for as long as they're logged in.

Checked in a probe world in DreamSeeker 516.1687 with real clicks, on a body at Oversized's 2x, upright and lying
(lab `runs/selfclick-20261028/`): a click where the 2x head covers the tile above reached the table there, clicks
through the 2x body past the normal-size outline reached the toolbox and the floor under it, and clicks on the
outline reached the body. The owner's screen matched the screen with no component within one colour level on a few
pixels (the hitbox), including lying under another mob and with another mob standing in front.

### TG Proc/File Changes:

None.

### Modular Overrides:

- `code/self_normal_size.dm`: `/datum/component/self_normal_size`, the owner's hitbox and view;
  `/obj/effect/abstract/self_normal_size_view`, the view's object;
  `/mob/living/carbon/human/proc/update_self_normal_size()`, which starts or stops it; and
  `/mob/living/carbon/human/Login()`, which calls it.
- `code/preference.dm`: `/datum/preference/toggle/see_self_normal_size`, which calls it when changed.

### Defines:

- `code/self_normal_size.dm`: `SELF_NORMAL_SIZE_MIN_SCALE`, `SELF_NORMAL_SIZE_KEY`, `SELF_NORMAL_SIZE_VIEW_KEY`,
  `SELF_NORMAL_SIZE_HITBOX_ALPHA`. File-local.

### Included files that are not contained in this module:

- `modular_nova/modules/customization/datums/dna/dna.dm`: `/datum/dna/proc/update_body_size()` calls
  `update_self_normal_size()` on a human once its size has changed.
- `tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/character_preferences/aphelion/self_normal_size.tsx`:
  the player-wide preference, which sorts right after Body Size in character preferences.
- `tgstation.dme`
