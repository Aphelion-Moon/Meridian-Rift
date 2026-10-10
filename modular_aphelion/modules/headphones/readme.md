## Headphones

Module ID: HEADPHONES

### Description:

tg's headphones also go on the neck, with a neck sprite of their own, and six recolourable (GAGS) sets join them:
studio headphones, Streetjack Cans, Raid Headset, Raid Headphones, Halo Phones and Sakura Halo Phones.

- **Neck.** Every pair with a neck sprite (`neck_icon_state`) takes the neck slot. There the band sits under hair
  (`HEADPHONES_NECK_UNDER_HAIR_LAYER`, between hair and the backpack, so backpack straps don't cover the cups) or,
  after an **alt-click**, over it (`HEADPHONES_NECK_OVER_HAIR_LAYER`, between hair and masks). The
  switch only moves the neck: `build_worn_icon()` picks the neck's state and layer when it is asked for the neck
  layer, so the head and ears keep theirs. Examine shows the band's position.
- **Notes.** An item action, **Toggle Music Notes**, hides the floating notes while a song plays; the song and any
  light animation go on. The notes are one overlay, tg's own (`notes`, and `notes_neck` 5 px lower round the cups),
  drawn behind the headphones, whose sprites leave room for them. Lit neon sets colour them in their light, and they
  glow under the sprite's emissive blocker. tg's head and ears sprites keep their notes drawn in.
- **Lights.** **Alt-right-click** switches the lights. The neon sets start lit: a steady glow worn, held or on the
  floor, with their light animation and notes in the light colour while a song plays. Switched off they show dark
  glass, no animation and tg's own notes: Streetjack Cans and the Raid sets redraw their sprites with the light
  colours darkened (the chosen colours stay), Halo and Sakura Halo Phones have dark copies (`_unlit`). The studio
  headphones' badge glow starts off.
- **Raid.** Raid Headphones are the Raid Headset without its boom mic. The headset draws the mic over its worn sprites
  and the item from a GAGS config of its own (`headphones_raid_mic`, in the pads colour), with an emissive blocker,
  so both share every other config and glow mask. Its map icon is `raid_headset`, the item with the mic.
- **Space pods and Nova's cat-ear headphones** have no neck sprite (`neck_icon_state = null`) and keep tg's behaviour.
- **Loadout.** Every new set is under Ears, next to tg's headphones. Being wearable on the neck doesn't earn them a
  Neck entry. The Raid is one entry, Raid Headphones, with the Raid Headset as its reskin
  (`/datum/atom_skin/raid_headphones`), which puts the boom mic on.
- **Icons.** `headphones_gags.dmi` holds every GAGS template, `headphones_emissive.dmi` every glow mask and
  `headphones.dmi` the static sprites (tg's neck sprite and the notes). The lab's export script writes them and the
  json from the approved art.

### Modular Overrides:

- `/obj/item/instrument/piano_synth/headphones`: `slot_flags` adds the neck; `Initialize()`, `examine()`,
  `add_context()`, `click_alt()`, `ui_action_click()`, `build_worn_icon()` and `worn_overlays()`.
- `/obj/item/instrument/piano_synth/headphones/spacepods` and `/catear_headphone`: `neck_icon_state = null`.

### Defines:

- `code/__DEFINES/mobs.dm` (APHELION EDIT ADDITION blocks in the mob layer list): `HEADPHONES_NECK_OVER_HAIR_LAYER` under `FACEMASK_LAYER`, `HEADPHONES_NECK_UNDER_HAIR_LAYER` under `BENEATH_HAIR_LAYER`.

### Included files that are not contained in this module:

- `modular_nova/modules/GAGS/json_configs/head/headphones/`: the GAGS json.
