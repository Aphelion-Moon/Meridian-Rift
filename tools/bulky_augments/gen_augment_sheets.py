"""Generates the recolourable augment finishes' sheets from their art sources.

Each finish's source is a folder in tools/bulky_augments/art/<finish id>/: four 128x32 strips (S E N W, 32 px each), the
layers of its Aseprite working file, drawn in the finish's default colours,

  arms.png      both arms in S and N, the near (right) arm in E, the near (left) arm in W
  hands.png     both hands in every view
  legs.png      both legs in S and N, the near leg in E and W
  leg_far.png   the far leg in E and W

and finish.json, whose "decode" maps every colour used to what it packs (see below). Every pixel must decode, and must lie
inside the Muscular outline of the limb it belongs to: a finish can leave a pixel of the outline as skin, never add one.

For each finish and zone (r_arm, l_arm, r_hand, l_hand, r_leg, l_leg), four directions each, it writes

  icons/bulky_augments.dmi           <id>_<zone>      skin base in the human skin ramp: the Muscular limb's own pixels, with
                                                      the finish's skin reshades
                                     <id>_<zone>_e    the lights, as an emissive mask; left out where a zone
                                                      has no lights (a finish without lights has none), except
                                                      a lit arm's hand, which gets an empty one: tg draws a lit
                                                      arm's hand mask with it
  icons/bulky_augments_humanoid.dmi  the same names   the skin base through the humanoid ramp (the humanoid Muscular sheet's
                                                      own pixels, its reshades mapped), and the same masks
  icons/bulky_augments_paint.dmi     <id>_<zone>_paint  machine pixels packed: red = paint, green = accent, blue = frame
                                                        shade
                                     <id>_<zone>_glow   glow pixels packed: red = light, green = shine w, blue = shine x
                                     Each is left out where a zone has none of its pixels.

The game tints the packed states with numeric 4x4 colour matrices whose rows are (paint, accent, frame) and (lights,
#fafbff, #c4c7d0), so a pixel drawn as base * v / 255 in the source comes out as the player's colour * v / 255. A light's
core is red plus a little green, the white lift of the art.

A decode entry is one of
  {"m": [r, g, b]}    a machine pixel's packed value
  {"g": [r, g, b]}    a glow pixel's packed value
  {"skin": "E"}       a skin reshade, as a letter of the human skin ramp (SKIN below)

Run `python tools/bulky_augments/gen_augment_sheets.py` whenever an art source changes, and commit the three sheets.
"""
import json
import os
import sys

from PIL import Image

# The repository root: this file is tools/bulky_augments/gen_augment_sheets.py.
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")).replace(os.sep, "/") + "/"
sys.path.insert(0, ROOT + "tools")
from dmi import Dmi, SOUTH, NORTH, EAST, WEST  # noqa: E402

ART = ROOT + "tools/bulky_augments/art/"
ICONS = ROOT + "modular_aphelion/modules/bulky_augments/icons/"
HUMAN = Dmi.from_file(ROOT + "modular_aphelion/modules/fitness/icons/human_parts_muscular.dmi")
HUMANOID = Dmi.from_file(ROOT + "modular_aphelion/modules/fitness/icons/humanoid_parts_muscular.dmi")

# DMI direction order, and each view's column in a strip.
VIEWS = [("S", SOUTH), ("N", NORTH), ("E", EAST), ("W", WEST)]
COLUMN = {"S": 0, "E": 32, "N": 64, "W": 96}
ZONES = ["r_arm", "l_arm", "r_hand", "l_hand", "r_leg", "l_leg"]
# The far leg in the side views is drawn on its own layer, under the torso.
FAR_LEG = {"E": "l_leg", "W": "r_leg"}

# The human skin ramp the Muscular sheet is drawn in, and what each step is in the humanoid ramp.
SKIN = {"B": (255, 255, 255), "K": (255, 244, 244), "D": (249, 238, 242), "E": (234, 217, 220), "J": (229, 198, 203),
        "F": (225, 199, 203), "G": (218, 180, 178), "H": (197, 153, 151), "I": (188, 140, 138)}
HUMANOID_SKIN = {"B": (255, 255, 255), "K": (246, 246, 246), "D": (240, 240, 240), "E": (220, 220, 220),
                 "J": (212, 212, 212), "F": (204, 204, 204), "G": (187, 187, 187), "H": (162, 162, 162),
                 "I": (150, 150, 150)}


def layer_for(zone, view):
    part = zone[2:]
    if part == "leg" and FAR_LEG.get(view) == zone:
        return "leg_far"
    return {"arm": "arms", "hand": "hands", "leg": "legs"}[part]


def limb_frame(sheet, prefix, zone, view_dir):
    return sheet.get_state(f"{prefix}_{zone}").get_frame(0, view_dir).convert("RGBA")


def build_finish(finish_id):
    folder = ART + finish_id + "/"
    meta = json.load(open(folder + "finish.json"))
    decode = {k.lower(): v for k, v in meta["decode"].items()}
    strips = {name: Image.open(folder + name + ".png").convert("RGBA") for name in ("arms", "hands", "legs", "leg_far")}
    claimed = {name: set() for name in strips}
    out = {}
    for zone in ZONES:
        frames = {"base": [], "humanoid": [], "e": [], "paint": [], "glow": []}
        for view, view_dir in VIEWS:
            human = limb_frame(HUMAN, "human", zone, view_dir)
            humanoid = limb_frame(HUMANOID, "humanoid", zone, view_dir)
            layer = layer_for(zone, view)
            strip = strips[layer]
            images = {key: Image.new("RGBA", (32, 32), (0, 0, 0, 0)) for key in frames}
            for y in range(32):
                for x in range(32):
                    organic = human.getpixel((x, y))
                    if not organic[3]:
                        continue
                    images["base"].putpixel((x, y), organic)
                    images["humanoid"].putpixel((x, y), humanoid.getpixel((x, y)))
                    sx = COLUMN[view] + x
                    pixel = strip.getpixel((sx, y))
                    if not pixel[3]:
                        continue
                    claimed[layer].add((sx, y))
                    assert pixel[3] == 255, f"{finish_id}: semi-transparent pixel at {layer} {sx},{y}"
                    colour = "#%02x%02x%02x" % pixel[:3]
                    entry = decode.get(colour)
                    assert entry, f"{finish_id}: {colour} at {layer} {sx},{y} is not in the decode table"
                    if "skin" in entry:
                        images["base"].putpixel((x, y), SKIN[entry["skin"]] + (255,))
                        images["humanoid"].putpixel((x, y), HUMANOID_SKIN[entry["skin"]] + (255,))
                    elif "m" in entry:
                        images["paint"].putpixel((x, y), tuple(entry["m"]) + (255,))
                    else:
                        images["glow"].putpixel((x, y), tuple(entry["g"]) + (255,))
                        if entry["g"][0]:
                            images["e"].putpixel((x, y), (255, 255, 255, 255))
            for key in frames:
                frames[key].append(images[key])
        out[zone] = frames
    for name, strip in strips.items():
        stray = [(x, y) for y in range(32) for x in range(128) if strip.getpixel((x, y))[3] and (x, y) not in claimed[name]]
        assert not stray, f"{finish_id}: {name}.png draws outside the Muscular outline at {stray[:8]}"
    return out


def add_state(dmi, name, frames):
    state = dmi.state(name, dirs=4)
    for image in frames:
        state.frame(image)


def main():
    finishes = sorted(name for name in os.listdir(ART) if os.path.isfile(ART + name + "/finish.json"))
    human = Dmi(32, 32)
    humanoid = Dmi(32, 32)
    paint = Dmi(32, 32)
    for finish_id in finishes:
        built = build_finish(finish_id)
        lit = {zone for zone in ZONES if any(image.getbbox() for image in built[zone]["e"])}
        for zone in ZONES:
            frames = built[zone]
            add_state(human, f"{finish_id}_{zone}", frames["base"])
            add_state(humanoid, f"{finish_id}_{zone}", frames["humanoid"])
            # tg draws a lit arm's hand mask too (get_limb_icon()'s aux emissive), so a hand of a lit arm always gets one,
            # empty where the hand has no lights: a missing state fails the invalid_emissives check.
            if zone in lit or (zone.endswith("_hand") and zone.replace("_hand", "_arm") in lit):
                add_state(human, f"{finish_id}_{zone}_e", frames["e"])
                add_state(humanoid, f"{finish_id}_{zone}_e", frames["e"])
            for layer in ("paint", "glow"):
                if any(image.getbbox() for image in frames[layer]):
                    add_state(paint, f"{finish_id}_{zone}_{layer}", frames[layer])
        print(finish_id)
    os.makedirs(ICONS, exist_ok=True)
    human.to_file(ICONS + "bulky_augments.dmi")
    humanoid.to_file(ICONS + "bulky_augments_humanoid.dmi")
    paint.to_file(ICONS + "bulky_augments_paint.dmi")
    print(f"{len(finishes)} finishes written to {ICONS}")


if __name__ == "__main__":
    main()
