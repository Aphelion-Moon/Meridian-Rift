import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image, PngImagePlugin

from build_assets import (
    compatible,
    deduplicate_profiles,
    format_animation_manifest,
    frame,
    load_cached_dmi,
    marker_anchor,
    read_dmi,
)


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

    def test_cached_dmi_loader_reads_only_on_cache_miss(self):
        cache = {}
        path = Path("fixture.dmi")

        with patch("build_assets.read_dmi", return_value=object()) as read_dmi:
            first = load_cached_dmi(cache, "fixture", path)
            second = load_cached_dmi(cache, "fixture", path)

        self.assertIs(first, second)
        read_dmi.assert_called_once_with(path)

    def test_profile_dedup_uses_the_full_table_and_resolves_digest_collisions(self):
        base_frames = [
            {"x": 0.0, "y": -22, "delay": 1.0},
            {"x": 1.0, "y": -21, "delay": 2.0},
        ]
        base = {"idle:0": {"south": base_frames}}

        def changed_frames(**changes):
            frames = [dict(frame) for frame in base_frames]
            frames[0].update(changes)
            return frames

        alternatives = {
            "pose": {"sit:0": {"south": [dict(frame) for frame in base_frames]}},
            "movement": {"idle:1": {"south": [dict(frame) for frame in base_frames]}},
            "direction": {"idle:0": {"north": [dict(frame) for frame in base_frames]}},
            "frame_order": {"idle:0": {"south": list(reversed(base_frames))}},
            "x": {"idle:0": {"south": changed_frames(x=2.0)}},
            "y": {"idle:0": {"south": changed_frames(y=-20)}},
            "delay": {"idle:0": {"south": changed_frames(delay=3.0)}},
        }
        model_profiles = {
            "base": base,
            "same": {"idle:0": {"south": [dict(frame) for frame in base_frames]}},
            **alternatives,
        }

        with patch("build_assets.profile_digest", return_value="a" * 64):
            references, profiles = deduplicate_profiles(model_profiles)
            reordered_references, reordered_profiles = deduplicate_profiles(
                dict(reversed(list(model_profiles.items()))),
            )

        self.assertEqual(references, reordered_references)
        self.assertEqual(profiles, reordered_profiles)
        self.assertEqual(references["base"], references["same"])
        self.assertEqual(len(profiles), len(alternatives) + 1)
        for model_key in alternatives:
            self.assertNotEqual(references["base"], references[model_key])

    def test_manifest_formatter_keeps_data_and_compacts_frames(self):
        profile_id = "profile-0123456789abcdef"
        manifest = {
            "format_version": 1,
            "source_sha": "fixture",
            "models": {"fixture.dmi#borgi": profile_id},
            "profiles": {
                profile_id: {
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
