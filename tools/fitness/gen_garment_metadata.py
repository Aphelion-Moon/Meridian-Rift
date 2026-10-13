"""Writes garment_metadata.json: what garment fitting needs of the static worn and underclothes sheets, read here once
rather than from their pixels each round (garment_sheet_metadata() in code/garment_fitting.dm). For each sheet:
  md5:     the sheet's hash. A sheet that has changed since is read from its pixels again, as generated icons are.
  sleeves: its 4-direction states whose own sleeves pick shaded sleeves (garment_sleeve_mode()); the rest pick solid.
  colours: for each state whose fits read whole views (worn states with shaded sleeves, and every underclothes state),
           each view's colours and how many pixels have each, as "rrggbb:count,...", in the order fit_garment_view()
           fits them: view by view (S, N, E, W), then frame by frame. Underclothes are fitted on their first frame only.
           Null for a view with two colours as bright as each other, which is read from its pixels.
The sheets are 32x32 worn clothing sheets (uniforms, suits, shoes and gloves) and the underclothes sheets.

Run `python tools/fitness/gen_garment_metadata.py` whenever one of those sheets changes, after gen_fit_templates.py when
the arms change too, and commit the JSON it writes to modular_aphelion/modules/fitness/fitting/. Until then a changed
sheet is fitted from its pixels, so the output never goes wrong; only its first fits cost more.
"""
import glob
import hashlib
import json
import os
import sys

# The repository root: this file is tools/fitness/gen_garment_metadata.py.
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")).replace(os.sep, "/") + "/"
FITTING = ROOT + "modular_aphelion/modules/fitness/fitting/"
sys.path.insert(0, ROOT + "tools")
from dmi import Dmi  # noqa: E402

UNDERCLOTHES = ["icons/mob/clothing/underwear.dmi", "modular_nova/master_files/icons/mob/clothing/underwear.dmi"]
VIEWS = range(4)  # S, N, E, W, as a frame's directions are stored

# garment_sleeve_mode()'s rules, which these must give the same answer as.
SLEEVE_MIN_PIXELS = 6
SLEEVE_LIT_MIN = 90
SLEEVE_GREY_PERCENT = 12
SLEEVE_MAX_COLOURS = 5
SLEEVE_MAX_HUE_SPREAD = 20
SLEEVE_MAX_GREYS_WITH_HUE = 1


def worn_sheets():
    """The worn clothing sheets, as paths from the repository root."""
    paths = set(
        glob.glob(ROOT + "icons/mob/clothing/under/*.dmi") + glob.glob(ROOT + "icons/mob/clothing/suits/*.dmi")
        + [ROOT + "icons/mob/clothing/feet.dmi", ROOT + "icons/mob/clothing/hands.dmi"]
        + glob.glob(ROOT + "modular_nova/master_files/icons/mob/clothing/under/*.dmi")
        + glob.glob(ROOT + "modular_nova/master_files/icons/mob/clothing/suits/*.dmi")
        + [ROOT + f"modular_nova/master_files/icons/mob/clothing/{n}.dmi" for n in ("uniform", "uniform_digi", "suit", "suit_digi", "feet", "feet_digi", "hands")]
        + [p for p in glob.glob(ROOT + "modular_aphelion/**/*.dmi", recursive=True) if "/mob/" in p.replace(os.sep, "/") and "clothing" in p.replace(os.sep, "/")]
    )
    return sorted(os.path.relpath(p, ROOT).replace(os.sep, "/") for p in paths)


def arm_core():
    """Both baseline arms' front view pixels, which the sleeves are read over."""
    with open(FITTING + "fit_templates.json") as f:
        limbs = json.load(f)["limbs"]
    return limbs["r_arm"]["1"]["S"]["core"] + limbs["l_arm"]["1"]["S"]["core"]


def sleeve_mode(front, core):
    """garment_sleeve_mode(): "sleeve_c" where the sleeves are one plain colour, "solid" where they're busy, dark or missing."""
    p = front.load()
    covered = 0
    lit = set()
    for x, y in core:
        c = p[x, y]
        if not c[3]:
            continue
        covered += 1
        if max(c[:3]) >= SLEEVE_LIT_MIN:
            lit.add(c[:3])
    if covered < SLEEVE_MIN_PIXELS or not lit:
        return "solid"
    greys = 0
    hues = set()
    for r, g, b in lit:
        high = max(r, g, b)
        spread = high - min(r, g, b)
        if spread * 100 < SLEEVE_GREY_PERCENT * high:
            greys += 1
            continue
        if high == r:
            hue = (60 * (g - b)) // spread % 360
        elif high == g:
            hue = 120 + (60 * (b - r)) // spread
        else:
            hue = 240 + (60 * (r - g)) // spread
        hues.add(hue)
    hued = len(lit) - greys
    if not hued:
        return "sleeve_c" if greys <= SLEEVE_MAX_COLOURS else "solid"
    if hued > SLEEVE_MAX_COLOURS or greys > SLEEVE_MAX_GREYS_WITH_HUE:
        return "solid"
    ordered = sorted(hues)
    widest_gap = max([b - a for a, b in zip(ordered, ordered[1:])] + [ordered[0] + 360 - ordered[-1]])
    return "sleeve_c" if 360 - widest_gap <= SLEEVE_MAX_HUE_SPREAD else "solid"


def colours(frame):
    """A view's colours and their pixel counts, as GetPixel() reads them, packed as "rrggbb:count,...". None for a view with
    two colours as bright as each other: a garment's ramp keeps those in the order a read of its pixels meets them."""
    counts = {}
    data = frame.tobytes()
    for i in range(0, len(data), 4):
        if data[i + 3]:
            key = data[i:i + 3].hex()
            counts[key] = counts.get(key, 0) + 1
    brightness = {299 * int(c[0:2], 16) + 587 * int(c[2:4], 16) + 114 * int(c[4:6], 16) for c in counts}
    if len(brightness) != len(counts):
        return None
    return ",".join(f"{c}:{n}" for c, n in sorted(counts.items()))


def sheet_entry(rel, underclothes, core):
    path = ROOT + rel
    with open(path, "rb") as f:
        digest = hashlib.md5(f.read()).hexdigest()
    dmi = Dmi.from_file(path)
    if (dmi.width, dmi.height) != (32, 32):
        return None
    sleeves = []
    state_colours = {}
    for state in dmi.states:
        if state.dirs != 4:
            continue
        frames = 1 if underclothes else state.framecount
        if not underclothes:
            if sleeve_mode(state.frames[0].convert("RGBA"), core) != "sleeve_c":
                continue
            sleeves.append(state.name)
        # Frames are stored frame by frame, each in S, N, E, W order.
        state_colours[state.name] = [colours(state.frames[frame * 4 + view].convert("RGBA")) for view in VIEWS for frame in range(frames)]
    return {"md5": digest, "sleeves": sleeves, "colours": state_colours}


def main(out_path):
    core = arm_core()
    sheets = {}
    for rel in worn_sheets():
        entry = sheet_entry(rel, False, core)
        if entry:
            sheets[rel] = entry
    for rel in UNDERCLOTHES:
        sheets[rel] = sheet_entry(rel, True, core)
    with open(out_path, "w") as f:
        json.dump({"version": 1, "sheets": sheets}, f, separators=(",", ":"), sort_keys=True)
    return sheets


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else FITTING + "garment_metadata.json"
    sheets = main(out)
    states = sum(len(s["colours"]) for s in sheets.values())
    print(out, os.path.getsize(out), "bytes;", len(sheets), "sheets;", sum(len(s["sleeves"]) for s in sheets.values()), "shaded-sleeve states;", states, "states with colours")
