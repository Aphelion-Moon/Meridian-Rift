"""Generates the pec fitting data (pec_templates.json) from the pec sprites and the human chest.

Per pec shape (pecs, pecs_big, pecs_biggest) and view (S, N, E, W):
  rows:   {y: [left_x, right_x]} the pec's outermost pixel on each side of the centre column (x 15) - front/back views
  pixels: [[x, y], ...] the pec's pixels - front/back views (a band only crosses pec pixels)
  bands:  [y, s, new_edge, old_edge, d, cap] the pec's own front bulge past the body (side views), as fit_templates
  smile:  {"nipples": [[x, y], ...], "nippleless": [[x, y], ...]} the front view's shading pixels
Plus "chest": {view: {y: [left_x, right_x]}} the body's own chest outline, per row.

It also writes pec_flex_templates.json: for each pec flex sheet (the four breasts_onmob_pecbounce*.dmi), its frame delays
and, for each pec shape, one template per frame by the same rules, read from that frame. A frame's smile is the still
smile, each column x moved down by how far the pecs' top crease row in x moved on that frame (the crease is the
(188,140,138) tone in the front view, the centre column x15 skipped): a flexed pec lifts its crease at the outer ends, and
the shading under it lifts with it. Garments are fitted to a flexing chest frame by frame from these.

The smile sits one row above the pec's crease (the sprite's mid tone (229,198,203)): a shirt bridges the crease,
so its shadow is the pec's lower curve. Its raised outer end is the nippled sprite's nipple pixel; nippleless pecs
raise it one pixel further out, onto the shirt's side shading, so no nipple shows.
Coordinates are PIL-style: x 0-31 from the left, y 0-31 from the top.

Run `python tools/fitness/gen_pec_templates.py` whenever the pec sprites or the human chest change, and commit the
pec_templates.json and pec_flex_templates.json it writes to modular_aphelion/modules/fitness/fitting/.
"""
import json
import os
import sys

# The repository root: this file is tools/fitness/gen_pec_templates.py.
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")).replace(os.sep, "/") + "/"
FITTING = ROOT + "modular_aphelion/modules/fitness/fitting/"
sys.path.insert(0, ROOT + "tools")
from dmi import Dmi, SOUTH, NORTH, EAST, WEST  # noqa: E402

BASE = ROOT + "modular_nova/modules/bodyparts/icons/human_parts_greyscale.dmi"
GENITALS = "modular_nova/master_files/icons/mob/sprite_accessory/genitals/"
PECS = ROOT + GENITALS + "breasts_onmob.dmi"
FLEXES = [GENITALS + f"breasts_onmob_pecbounce{suffix}.dmi" for suffix in ("", "_alternate", "_slow", "_alternate_slow")]
DIRS = {"S": SOUTH, "N": NORTH, "E": EAST, "W": WEST}
SHAPES = ["pecs", "pecs_big", "pecs_biggest"]
CREASE = (188, 140, 138)  # the pec sprites' darkest tone: the crease under each pec
MID = (229, 198, 203)     # their lower-curve tone, one row above the crease
SHADOWS = {(218, 180, 178), (197, 153, 151), (188, 140, 138)}  # their shadow tones
CENTRE = 15

_dmis = {}


def pixels(path, state, d, frame=0):
    if path not in _dmis:
        _dmis[path] = Dmi.from_file(path)
    try:
        st = _dmis[path].get_state(state)
    except KeyError:
        return {}
    im = st.get_frame(frame, DIRS[d]).convert("RGBA")
    p = im.load()
    return {(x, y): p[x, y] for y in range(32) for x in range(32) if p[x, y][3]}


def pec(shape, d, nippled=False, sheet=PECS, frame=0):
    out = {}
    for layer in ("ADJ", "FRONT_UNDER"):
        out.update(pixels(sheet, f"m_breasts_{shape}{'' if nippled else '_nippleless'}_0_s_{layer}", d, frame))
    return out


def side_rows(px):
    rows = {}
    for y in sorted({y for _, y in px}):
        left = [x for x, yy in px if yy == y and x < CENTRE]
        right = [x for x, yy in px if yy == y and x > CENTRE]
        rows[str(y)] = [min(left) if left else None, max(right) if right else None]
    return rows


def front_bulge(shape, d, sheet=PECS, frame=0):
    """Side views: where the pec pushes the body's front out (grows forward: E +x, W -x)."""
    body = set(pixels(BASE, "human_chest_m", d)) | set(pixels(BASE, "human_r_leg", d)) | set(pixels(BASE, "human_l_leg", d))
    feat = pec(shape, d, sheet=sheet, frame=frame)
    grows = +1 if d == "E" else -1
    bands = []
    for y in sorted({y for _, y in feat}):
        nx = [x for x, yy in set(feat) | body if yy == y]
        ox = [x for x, yy in body if yy == y]
        if not nx or not ox:
            continue
        new_edge, old_edge = (max(nx), max(ox)) if grows > 0 else (min(nx), min(ox))
        dd = (new_edge - old_edge) * grows
        if dd > 0:
            bands.append([y, -grows, new_edge, old_edge, dd, False])
    return sorted(bands)


def smile(shape):
    feat = pec(shape, "S")
    nippled = pec(shape, "S", nippled=True)
    nip = {p for p, c in nippled.items() if feat.get(p) != c}
    crease = max(y for (x, y), c in feat.items() if c[:3] == CREASE and x != CENTRE)
    row = crease - 1
    curve = {(x, y) for (x, y), c in feat.items() if y == row and x != CENTRE and (c[:3] == MID or c[:3] in SHADOWS)}
    out = {}
    for key, rise in (("nipples", nip), ("nippleless", {(x - 1 if x < CENTRE else x + 1, y) for x, y in nip})):
        pts = (curve | rise) - {(x, y + 1) for x, y in rise}
        out[key] = sorted([x, y] for x, y in pts if 9 <= x <= 21)
    return out


def crease_tops(shape, sheet=PECS, frame=0):
    """{x: the top crease row in column x} of the pecs' front view, the centre column skipped."""
    tops = {}
    for (x, y), c in pec(shape, "S", sheet=sheet, frame=frame).items():
        if x != CENTRE and c[:3] == CREASE and (x not in tops or y < tops[x]):
            tops[x] = y
    return tops


def flex_template(shape, sheet, frame, still_smile):
    """One frame's template of a pec shape on a flex sheet: the still template's rules read from that frame, and the still
    smile moved column by column with the frame's crease."""
    still_tops = crease_tops(shape)
    tops = crease_tops(shape, sheet, frame)
    out = {}
    for d in DIRS:
        entry = {"rows": side_rows(pec(shape, d, sheet=sheet, frame=frame)) if d in ("S", "N") else {},
                 "pixels": sorted([x, y] for x, y in pec(shape, d, sheet=sheet, frame=frame)) if d in ("S", "N") else [],
                 "bands": front_bulge(shape, d, sheet, frame) if d in ("E", "W") else []}
        if d == "S":
            entry["smile"] = {key: sorted([x, y + (tops[x] - still_tops[x] if x in tops and x in still_tops else 0)] for x, y in points)
                              for key, points in still_smile.items()}
        out[d] = entry
    return out


def flex_main(out_path, still):
    data = {"version": 1, "flexes": {}}
    for rel in FLEXES:
        sheet = ROOT + rel
        if sheet not in _dmis:
            _dmis[sheet] = Dmi.from_file(sheet)
        reference = _dmis[sheet].get_state(f"m_breasts_{SHAPES[0]}_nippleless_0_s_FRONT_UNDER")
        frames = reference.framecount
        entry = {"delays": list(reference.delays[:frames]), "shapes": {}}
        for shape in SHAPES:
            entry["shapes"][shape] = [flex_template(shape, sheet, frame, still["shapes"][shape]["S"]["smile"]) for frame in range(frames)]
        data["flexes"][rel] = entry
    with open(out_path, "w") as f:
        json.dump(data, f, separators=(",", ":"), sort_keys=True)
    return data


def main(out_path):
    data = {"version": 1, "centre": CENTRE, "chest": {}, "shapes": {}}
    for d in DIRS:
        data["chest"][d] = side_rows(pixels(BASE, "human_chest_m", d))
    for shape in SHAPES:
        data["shapes"][shape] = {}
        for d in DIRS:
            entry = {"rows": side_rows(pec(shape, d)) if d in ("S", "N") else {},
                     "pixels": sorted([x, y] for x, y in pec(shape, d)) if d in ("S", "N") else [],
                     "bands": front_bulge(shape, d) if d in ("E", "W") else []}
            if d == "S":
                entry["smile"] = smile(shape)
            data["shapes"][shape][d] = entry
    with open(out_path, "w") as f:
        json.dump(data, f, separators=(",", ":"), sort_keys=True)
    return data


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else FITTING + "pec_templates.json"
    flex_out = sys.argv[2] if len(sys.argv) > 2 else FITTING + "pec_flex_templates.json"
    still = main(out)
    print(out, os.path.getsize(out), "bytes")
    flex_main(flex_out, still)
    print(flex_out, os.path.getsize(flex_out), "bytes")
