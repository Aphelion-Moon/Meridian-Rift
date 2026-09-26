import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image, PngImagePlugin

from build_assets import compatible, format_animation_manifest, frame, marker_anchor, read_dmi


class AssetContracts(unittest.TestCase):
    def test_frame_index_respects_direction_order_and_sheet_wrapping(self):
        with tempfile.TemporaryDirectory() as directory:
            image = Image.new("RGBA", (8, 8))
            # Four 4x4 cells: first frame S/N, second frame S/N.
            for box, color in [((0, 0, 4, 4), "red"), ((4, 0, 8, 4), "green"), ((0, 4, 4, 8), "blue"), ((4, 4, 8, 8), "white")]:
                image.paste(color, box)
            metadata = PngImagePlugin.PngInfo()
            metadata.add_text("Description", '# BEGIN DMI\nversion = 4.0\n width = 4\n height = 4\nstate = "body"\n dirs = 2\n frames = 2\n delay = 2,3\n# END DMI\n')
            path = Path(directory) / "fixture.dmi"
            image.save(path, format="PNG", pnginfo=metadata)
            sheet = read_dmi(path)
            cell, origin = frame(sheet, sheet["states"][0], 1, 0)
            self.assertEqual(origin, (0, 4))
            self.assertEqual(cell.getpixel((0, 0)), (0, 0, 255, 255))
            self.assertEqual(sheet["states"][0]["delays"], [2, 3])

    def test_anchor_converts_to_byond_coordinates_and_rejects_ambiguity(self):
        cell = Image.new("RGBA", (4, 8))
        cell.putpixel((2, 1), (51, 255, 255, 255))
        self.assertEqual(marker_anchor(cell), (3, 7))
        cell.putpixel((0, 0), (51, 255, 255, 255))
        self.assertIsNone(marker_anchor(cell))

    def test_manifest_formatter_keeps_data_and_compacts_frames(self):
        manifest = {
            "source_sha": "fixture",
            "models": {
                "fixture.dmi#borgi": {
                    "idle:0": {
                        "south": [
                            {"x": 0.0, "y": -22, "delay": 1.0},
                            {"x": 1.0, "y": -21, "delay": 1.0},
                        ],
                    },
                },
            },
            "fallbacks": ["fixture.dmi#sit:0: incompatible authored timing"],
        }

        formatted = format_animation_manifest(manifest)

        self.assertEqual(json.loads(formatted), manifest)
        self.assertIn(
            '"south": [{"x": 0.0, "y": -22, "delay": 1.0}, {"x": 1.0, "y": -21, "delay": 1.0}]',
            formatted,
        )

    def test_matching_frame_count_does_not_hide_different_timing(self):
        sheet = {"width": 64, "height": 32}
        source = {"dirs": 4, "frames": 2, "delays": [10, 1]}
        marker = {"dirs": 4, "frames": 2, "delays": [1, 1]}
        self.assertFalse(compatible(sheet, source, sheet, marker))


if __name__ == "__main__":
    unittest.main()
