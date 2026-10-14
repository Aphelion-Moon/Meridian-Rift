# Bulky augment finishes: art sources and generator

The recolourable augment finishes (`modular_aphelion/modules/bulky_augments`) draw from three generated sheets. Edit the
sources here, never the sheets.

## Sources

`art/<finish id>/` holds one finish:

| File | What it is |
|---|---|
| `arms.png` | 128x32, views S E N W at x 0, 32, 64, 96: both arms in S and N, the near arm in E and W |
| `hands.png` | both hands in every view (the far hand is a 3 px sliver in E and W) |
| `legs.png` | both legs in S and N, the near leg in E and W |
| `leg_far.png` | the far leg in E and W |
| `finish.json` | `id`, `name` and `decode`: every colour the strips use -> what it packs |

The strips are drawn in the finish's default colours over the Muscular outline
(`modular_aphelion/modules/fitness/icons/human_parts_muscular.dmi`). A pixel may leave the outline's skin showing (leave it
transparent, or paint a skin reshade), but never draw outside the outline.

A `decode` entry is one of:

- `{"m": [paint, accent, frame]}`: a machine pixel, its shade in one channel (e.g. `[212, 0, 0]` is paint at 212/255);
- `{"g": [light, shine_w, shine_x]}`: a glow pixel: a light (`[255, 61, 0]` is a light's core with its white lift,
  `[150, 0, 0]` a dimmer light), or untinted shine (`[0, 255, 0]` is `#fafbff`, `[0, 0, 255]` is `#c4c7d0`);
- `{"skin": "E"}`: a skin reshade, a letter of the human skin ramp (`gen_augment_sheets.py`'s `SKIN`).

In the default colours a machine pixel is `colour * shade / 255` of its channel's default, so every colour in the strips
must decode to exactly one entry. The table may hold more colours than the strips use (the whole ramp the palette offers).

Lights are optional: a finish only has them if its design does. The generator writes a zone's `_e` emissive mask only
where that zone has light pixels, plus an empty one for a lit arm's hand (tg draws the hand's mask along with the
arm's). A finish without lights leaves "lights" out of its datum's `channels`, and never glows.

## Editing a finish

1. Work in Aseprite on a 128x32 document with the layers `leg far`, `torso` (locked reference), `legs`, `arms`, `hands`, `hair`
   (locked reference), its palette holding only the finish's decode colours plus the reference body's. Lock the palette
   while drawing so nothing off-table lands in the strips.
2. Export the four limb layers to `art/<id>/` (one PNG per layer, nothing else visible).
3. Add any new colour to `finish.json`.
4. Run `python tools/bulky_augments/gen_augment_sheets.py` from the repository root. It asserts every pixel decodes, nothing
   is semi-transparent and nothing lies outside the outline, then writes all three sheets for every finish.
5. A new finish also needs its `/datum/robotic_style/recolorable` subtype (channels, default colours, presets) in
   `modular_aphelion/modules/bulky_augments/code/finishes.dm`, with `limb_id_override` set to its id. Its `channels` list
   only the channels its art uses.
