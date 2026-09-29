## Greyscale eyes

Module ID: GREYSCALE_EYES

### Description:

Some eyes are drawn in a colour of their own that the eye colour can only tint: moth eyes and akula eyes are
near-black, and fly eyes are a fixed red on heads that don't colour eyes at all. Characters with them get an
"Eye Greyscale" checkbox under Eye Emissives. Ticked, the eyes draw a greyscale version of the same shape and
Eye color unlocks, showing at full strength (flies' heads start colouring eyes). Unticked, Eye color is hidden
and the eyes look exactly as they always have.

Each eyes type says whether it has a greyscale version with `greyscale_icon_state` (and `greyscale_icon` when it
lives in another file), so the checkbox covers any eyes that set it, including an Augments+ pick:

- Moth and fly eyes: tg's `motheyes_white`, the robotic moth eyes' sprite. Fly eyes have the same shape.
- Akula eyes: `icons/greyscale_eyes.dmi`, the same pixels as Nova's akula eyes on the `motheyes_white` greys.
  Akula heads swap their own eye sheet into any eyes put in them, so akula eyes put it back when greyscale.

The eye colour stays hidden for these eyes until the box is ticked, but it still applies, as hidden preferences do,
so existing characters keep the faint tint they had.

The preference code runs whenever the preferences menu updates: the eyes lookup is a macro, so the two checks add
no proc calls, and applying it returns at once for eyes without a greyscale version or when nothing changed.

### TG Proc/File Changes:

- None.

### Modular Overrides:

- `/obj/item/organ/eyes`: new `greyscale_icon_state`, `greyscale_icon` and `greyscale_sprite`, set on the moth, fly
  and akula eyes.
- `/obj/item/organ/eyes/akula/on_bodypart_insert()`: keeps the greyscale sheet over the akula head's own.
- `/datum/preference/color/eye_color/has_relevant_feature()`: hidden for these eyes until Eye Greyscale is ticked.

### Defines:

- `PREFERENCES_EYES_TYPE`: local to `preferences.dm`.

### Included files that are not contained in this module:

- `tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/character_preferences/aphelion/eye_greyscale.tsx`
