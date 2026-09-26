"""Build audited cyborg anchor metadata and colored occlusion sheets, offline.

Requires Pillow. Donor inputs are pinned in the module; no network or game runtime
work is done here. Only explicit local skin families with matching frame layouts
and timing use authored data. All others retain manual placement.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

from PIL import Image, ImageChops, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / "modular_aphelion/modules/cyborg_customization"
FAMILIES = {"Drake": "drake", "Borgi": "borgi", "Otie": "otie", "Vale": "vale", "ValeDark": "vale", "Hound": "hound", "Darkhound": "hound", "Alina": "alina"}
DIRECTIONS = ["south", "north", "east", "west", "southeast", "southwest", "northeast", "northwest"]
SHA = "090a9cb13722af449567867c720826eb6af215a5"


def read_dmi(path: Path):
    image = Image.open(path)
    description = image.info["Description"]
    width = int(re.search(r"\bwidth = (\d+)", description)[1])
    height = int(re.search(r"\bheight = (\d+)", description)[1])
    states = []
    offset = 0
    for block in re.split(r'^state = ', description, flags=re.M)[1:]:
        name = json.loads(block.splitlines()[0])
        fields = dict(re.findall(r'^\s*(\w+) = ([^\n]+)', block, re.M))
        dirs, frames = int(fields.get("dirs", 1)), int(fields.get("frames", 1))
        delays = [float(value) for value in fields.get("delay", "1").split(",")]
        if len(delays) == 1:
            delays *= frames
        states.append(dict(name=name, dirs=dirs, frames=frames, delays=delays, movement=int(fields.get("movement", 0)), offset=offset))
        offset += dirs * frames
    return dict(image=image.convert("RGBA"), description=description, width=width, height=height, states=states)


def frame(sheet, state, frame_index, direction):
    index = state["offset"] + frame_index * state["dirs"] + direction
    columns = sheet["image"].width // sheet["width"]
    x, y = index % columns * sheet["width"], index // columns * sheet["height"]
    return sheet["image"].crop((x, y, x + sheet["width"], y + sheet["height"])), (x, y)


def compatible(source, state, markers, marker):
    return (source["width"], source["height"], state["dirs"], state["frames"], state["delays"]) == (markers["width"], markers["height"], marker["dirs"], marker["frames"], marker["delays"])


def marker_anchor(cell):
    pixels = [(x + 1, cell.height - y) for y in range(cell.height) for x in range(cell.width) if cell.getpixel((x, y)) == (51, 255, 255, 255)]
    return pixels[0] if len(pixels) == 1 else None


def format_frame_sequence(frames):
    return "[" + ", ".join(json.dumps(frame, separators=(", ", ": ")) for frame in frames) + "]"


def format_animation_profile(profile):
    lines = ["{"]
    for state_index, (state_key, directions) in enumerate(profile.items()):
        state_comma = "," if state_index + 1 < len(profile) else ""
        lines.append(f'  {json.dumps(state_key)}: {{')
        for direction_index, (direction, frames) in enumerate(directions.items()):
            direction_comma = "," if direction_index + 1 < len(directions) else ""
            lines.append(f'    {json.dumps(direction)}: {format_frame_sequence(frames)}{direction_comma}')
        lines.append(f'  }}{state_comma}')
    lines.append("}")
    return lines


def format_animation_manifest(manifest):
    lines = [
        "{",
        f'  "source_sha": {json.dumps(manifest["source_sha"])},',
        '  "models": {',
    ]
    for model_index, (model_key, profile) in enumerate(manifest["models"].items()):
        model_comma = "," if model_index + 1 < len(manifest["models"]) else ""
        profile_lines = format_animation_profile(profile)
        lines.append(f'    {json.dumps(model_key)}: {profile_lines[0]}')
        lines.extend(f'    {line}' for line in profile_lines[1:-1])
        lines.append(f'    {profile_lines[-1]}{model_comma}')
    lines.append("  },")
    fallbacks = json.dumps(manifest["fallbacks"], indent=2).replace("\n", "\n  ")
    lines.append(f'  "fallbacks": {fallbacks}')
    lines.append("}")
    return "\n".join(lines) + "\n"


def build():
    defines = (ROOT / "code/__DEFINES/~nova_defines/robot_defines.dm").read_text()
    icons = dict(re.findall(r"#define (CYBORG_ICON_\w+) '([^']+)'", defines))
    declarations = (ROOT / "modular_nova/modules/borgs/code/robot_model.dm").read_text()
    entries = re.findall(r'^\s*"([^"\n]+)" = list\(SKIN_ICON_STATE\s*=\s*"([^"\n]+)"[^\n]*?SKIN_ICON = (CYBORG_ICON_\w+)', declarations, re.M)
    inputs = {}
    outputs = {}
    manifest = {"source_sha": SHA, "models": {}, "fallbacks": []}
    for skin, base_state, macro in entries:
        family = FAMILIES.get(skin)
        if not family:
            continue
        source_path = icons[macro]
        source = inputs.setdefault(source_path, read_dmi(ROOT / source_path))
        markers = inputs.setdefault(f"marker:{family}", read_dmi(MODULE / f"icons/animation_markers/{family}.dmi"))
        masks = inputs.setdefault(f"mask:{family}", read_dmi(MODULE / f"icons/occlusion_masks/{family}mask.dmi"))
        marker_base = markers["states"][0]["name"]
        mask_base = masks["states"][0]["name"]
        model = {}
        for state in source["states"]:
            if state["name"] != base_state and not state["name"].startswith(base_state + "-"):
                continue
            suffix = state["name"][len(base_state):]
            pose = suffix.lstrip("-") or "idle"
            if pose not in ["idle", "rest", "sit", "bellyup", "rest_deep", "rest_alt", "sit_alt"]:
                continue
            marker = next((s for s in markers["states"] if s["name"] == marker_base + suffix and s["movement"] == state["movement"]), None)
            mask = next((s for s in masks["states"] if s["name"] == mask_base + suffix and s["movement"] == state["movement"]), None)
            key = f'{pose}:{state["movement"]}'
            if not marker or not mask or not compatible(source, state, markers, marker) or not compatible(source, state, masks, mask):
                manifest["fallbacks"].append(f"{source_path}#{state['name']}:{state['movement']}: incompatible authored timing")
                continue
            directions = {}
            valid = True
            for d in range(state["dirs"]):
                anchors = []
                for f in range(state["frames"]):
                    marker_cell, _ = frame(markers, marker, f, d)
                    anchor = marker_anchor(marker_cell)
                    if not anchor:
                        valid = False
                        break
                    anchors.append({"x": anchor[0] - source["width"] / 2, "y": anchor[1] - 24, "delay": state["delays"][f]})
                directions[DIRECTIONS[d]] = anchors
            if not valid:
                manifest["fallbacks"].append(f"{source_path}#{state['name']}:{state['movement']}: no unique cyan anchor")
                continue
            model[key] = directions
            output = outputs.setdefault(source_path, Image.new("RGBA", source["image"].size))
            for d in range(state["dirs"]):
                for f in range(state["frames"]):
                    body, xy = frame(source, state, f, d)
                    mask_cell, _ = frame(masks, mask, f, d)
                    body.putalpha(ImageChops.multiply(body.getchannel("A"), mask_cell.getchannel("A")))
                    output.paste(body, xy)
        if model:
            manifest["models"][source_path + "#" + base_state] = model
    target = MODULE / "icons/occlusion_generated"
    target.mkdir(parents=True, exist_ok=True)
    resource_lines = ["// Generated by tools/cyborg_customization/build_assets.py; do not edit.", "/proc/cyborg_occlusion_resources()", "\tvar/static/list/resources = list("]
    for path, output in sorted(outputs.items()):
        filename = Path(path).name
        info = PngImagePlugin.PngInfo()
        info.add_text("Description", inputs[path]["description"], zip=True)
        output.save(target / filename, format="PNG", pnginfo=info)
        resource_lines.append(f'\t\t"{path}" = \'modular_aphelion/modules/cyborg_customization/icons/occlusion_generated/{filename}\',')
    resource_lines.extend(["\t)", "\treturn resources", ""])
    (MODULE / "code/asset_resources.dm").write_text("\n".join(resource_lines), encoding="utf-8")
    (MODULE / "animation_manifest.json").write_text(format_animation_manifest(manifest), encoding="utf-8")
    print(f"{len(manifest['models'])} models with authored data; {len(manifest['fallbacks'])} pose/movement fallbacks; {len(outputs)} generated sheets")


if __name__ == "__main__":
    build()
