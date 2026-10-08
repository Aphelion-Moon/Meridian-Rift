"""Extract local sprite frames for the browser editor fixture; never touch saves."""
import base64
import io
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_assets import ROOT, read_dmi, frame


def encode(image):
    output = io.BytesIO()
    image.save(output, format="PNG")
    return base64.b64encode(output.getvalue()).decode("ascii")


def build():
    output = ROOT / "data/cyborg-editor-preview"
    output.mkdir(parents=True, exist_ok=True)
    models = []
    for path, name in [
        ("modular_nova/modules/borgs/icons/widerobot_serv.dmi", "borgi-serv"),
        ("modular_nova/modules/borgs/icons/widerobot_serv.dmi", "drakeserv"),
        ("modular_nova/modules/borgs/icons/robots_serv.dmi", "heavyserv"),
    ]:
        sheet = read_dmi(ROOT / path)
        state = next((state for state in sheet["states"] if state["name"] == name), None)
        if state is None:
            raise ValueError(f"Missing chassis fixture: {name}")
        models.append(dict(id=str(len(models)), department="Service", skin=state["name"],
                           width=sheet["width"], height=sheet["height"],
                           images=[encode(frame(sheet, state, 0, direction)[0]) for direction in range(4)]))
    sheet = read_dmi(ROOT / "modular_aphelion/modules/cyborg_customization/icons/accessories/penis_dogborg_onmob.dmi")
    state = next(state for state in sheet["states"] if state["name"] == "m_penis_knotted_3_2_FRONT_primary")
    accessory = [encode(frame(sheet, state, 0, direction)[0]) for direction in range(4)]
    human = read_dmi(ROOT / "icons/mob/human/mannequin.dmi")
    human_state = next(state for state in human["states"] if state["name"] == "mannequin_plastic_male")
    (output / "fixtures.json").write_text(json.dumps(dict(
        models=models, accessory=accessory[0], accessory_directions=accessory,
        reference=encode(frame(human, human_state, 0, 0)[0]))))
    print(f"Extracted {len(models)} chassis fixtures and one accessory.")


if __name__ == "__main__":
    build()
