"""Generates the garment fitting templates from the real fitness DMIs.

For every limb (r_arm, l_arm, r_leg, l_leg, and the digitigrade legs r_leg_digi, l_leg_digi), fitness level 1-5 and
view (S, N, E, W):
  bands: [y, s, new_edge, old_edge, d, cap]
      a row where the limb's outer edge moved from old_edge out to new_edge (d pixels);
      s is the step pointing back into the limb (+1 or -1); cap marks a row the limb grew into
      above its old top, where old_edge comes from the baseline body outline instead
  core:  baseline limb pixels [[x, y], ...] (the "does this garment cover the limb" test)
  tones: the fitted limb's pixels as indices into the skin ramp [[x, y, i], ...] (form shading)
Arms use the convex envelope of their new outline (sleeves bridge the elbow pinch); legs are exact.
Coordinates are PIL-style: x 0-31 from the left, y 0-31 from the top.

Run `python tools/fitness/gen_fit_templates.py` whenever the limb art changes, and commit the fit_templates.json it
writes to modular_aphelion/modules/fitness/fitting/.
"""
import json
import os
import sys

# The repository root: this file is tools/fitness/gen_fit_templates.py.
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")).replace(os.sep, "/") + "/"
FITTING = ROOT + "modular_aphelion/modules/fitness/fitting/"
sys.path.insert(0, ROOT + "tools")
from dmi import Dmi, SOUTH, NORTH, EAST, WEST  # noqa: E402

BASE = ROOT + "modular_nova/modules/bodyparts/icons/human_parts_greyscale.dmi"
MAMMAL = ROOT + "modular_nova/modules/bodyparts/icons/mammal_parts_greyscale.dmi"  # a human's digitigrade legs
LEVEL = ROOT + "modular_aphelion/modules/fitness/icons/human_parts_fitness_{}.dmi"
DIRS = {"S": SOUTH, "N": NORTH, "E": EAST, "W": WEST}
LIMBS = ["r_arm", "l_arm", "r_leg", "l_leg", "r_leg_digi", "l_leg_digi"]
SKIN_RAMP = [(255, 255, 255), (249, 238, 242), (234, 217, 220), (225, 199, 203), (218, 180, 178), (197, 153, 151)]
OUTLINE_PARTS = ["chest_m", "head_m", "r_arm", "l_arm", "r_leg", "l_leg", "r_hand", "l_hand"]

_dmis = {}


def pixels(path, state, d):
    if path not in _dmis:
        _dmis[path] = Dmi.from_file(path)
    im = _dmis[path].get_state(state).get_frame(0, DIRS[d]).convert("RGBA")
    p = im.load()
    return {(x, y): p[x, y] for y in range(32) for x in range(32) if p[x, y][3]}


def envelope(edges, grows):
    """Convex envelope of an outer-edge profile {y: x}, rounded outward."""
    ys = sorted(edges)
    sign = -grows
    pts = [(y, sign * edges[y]) for y in ys]
    hull = []
    for p in pts:
        while len(hull) >= 2 and (hull[-1][0] - hull[-2][0]) * (p[1] - hull[-2][1]) - (hull[-1][1] - hull[-2][1]) * (p[0] - hull[-2][0]) <= 0:
            hull.pop()
        hull.append(p)
    out = {}
    for y in ys:
        v = hull[0][1]
        for a, b in zip(hull, hull[1:]):
            if a[0] <= y <= b[0]:
                v = a[1] + (b[1] - a[1]) * (y - a[0]) / (b[0] - a[0]) if b[0] != a[0] else min(a[1], b[1])
                break
        out[y] = sign * int(-(-v // 1)) if sign < 0 else sign * int(v // 1)
    return out


def sheet_state(limb):
    """(baseline sheet, state) of a limb: digitigrade legs are the mammal ones, the rest the human sheet's."""
    return (MAMMAL, "mammal_" + limb) if limb.endswith("_digi") else (BASE, "human_" + limb)


def bands_for(limb, level, d):
    base, name = sheet_state(limb)
    old = set(pixels(base, name, d))
    new_px = pixels(LEVEL.format(level), name, d)
    new = set(new_px)
    outline = set()
    digi = limb.endswith("_digi")
    for part in OUTLINE_PARTS:
        if digi and part in ("r_leg", "l_leg"):
            outline |= set(pixels(*sheet_state(part + "_digi"), d))
        else:
            outline |= set(pixels(BASE, "human_" + part, d))
    bands = []
    rows = sorted({y for _, y in new})
    # outward only: front/back views grow away from the body's centre line, side views towards the back;
    # the inner/front side overlaps the torso, where extending a garment would smear sleeve over chest
    side = limb[0]
    grows = {"S": -1 if side == "r" else +1, "N": +1 if side == "r" else -1, "E": -1, "W": +1}[d]
    leg = "_leg" in limb
    # a leg in a side view grows forward too (the thigh, the far digitigrade thigh), where nothing sits in front of it to
    # smear over; leg bands never take the sleeve test, which keeps straps on shoulders - hips have no straps
    for grows in ((grows, -grows) if leg and d in ("E", "W") else (grows,)):
        new_edges = {}
        for y in rows:
            nx = [x for x, yy in new if yy == y]
            new_edges[y] = min(nx) if grows < 0 else max(nx)
        if limb.endswith("arm") and new_edges:
            new_edges = {y: (min(e, new_edges[y]) if grows < 0 else max(e, new_edges[y])) for y, e in envelope(new_edges, grows).items()}
            if d in ("E", "W"):
                # side views: cloth drapes over the rear deltoid, so its outline moves at most 1 px per row
                # (a 2 px jump reads as a flap on a short sleeve's hem)
                for _ in range(2):
                    for y in rows:
                        for n in (y - 1, y + 1):
                            if n in new_edges:
                                new_edges[y] = min(new_edges[y], new_edges[n] + 1) if grows < 0 else max(new_edges[y], new_edges[n] - 1)
        for y in rows:
            ox = [x for x, yy in old if yy == y]
            cap = not ox
            if d in ("E", "W") and ox:
                # side views: the limb hangs in front of the torso, so the garment's old outline is the body's
                # (limb or torso, whichever is further out), not the limb's own edge
                ox += [x for x, yy in outline if yy == y]
                body_new = [x for x, yy in outline if yy == y]
                if body_new:
                    new_edges[y] = min(new_edges[y], min(body_new)) if grows < 0 else max(new_edges[y], max(body_new))
            if cap:
                # rows above the old limb top: the edge of the baseline body on this side
                cx = [x for x, yy in outline if yy == y]
                if not cx:
                    continue
                ox = cx
            old_edge = min(ox) if grows < 0 else max(ox)
            d_ = (old_edge - new_edges[y]) * -grows
            if d_ > 0:
                bands.append([y, -grows, new_edges[y], old_edge, d_, bool(cap) and not leg])
    tones = [[x, y, SKIN_RAMP.index(c[:3])] for (x, y), c in sorted(new_px.items()) if c[:3] in SKIN_RAMP]
    return {"bands": sorted(bands), "core": sorted([list(p) for p in old]), "tones": tones}


def main(out_path):
    data = {"version": 1, "skin_ramp": ["#%02x%02x%02x" % c for c in SKIN_RAMP], "limbs": {}}
    for limb in LIMBS:
        data["limbs"][limb] = {}
        for level in range(1, 6):
            data["limbs"][limb][str(level)] = {d: bands_for(limb, level, d) for d in DIRS}
    with open(out_path, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    return data


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else FITTING + "fit_templates.json"
    d = main(out)
    print(out, os.path.getsize(out), "bytes")
