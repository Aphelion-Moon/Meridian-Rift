"""Exercise the maintained include checker with modular edit records."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


CHECKER = Path(__file__).resolve().parents[2] / "ticked_file_enforcement" / "ticked_file_enforcement.py"


class TickedFileMarkerTests(unittest.TestCase):
    def check_fixture(self, includes, files):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in files:
                target = root / "units" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("// fixture\n", encoding="utf-8")
            (root / "includes.dm").write_text("// BEGIN_INCLUDE\n" + includes + "\n// END_INCLUDE\n", encoding="utf-8")
            schema = {"file": "includes.dm", "scannable_directory": "units/", "subdirectories": False, "excluded_files": [], "forbidden_includes": []}
            return subprocess.run([sys.executable, str(CHECKER)], cwd=root, input=json.dumps(schema), text=True, capture_output=True, timeout=15)

    def test_named_markers_preserve_include_order_validation(self):
        result = self.check_fixture('// APHELION EDIT ADDITION START - DOGMOS\n#include "a.dm"\n// APHELION EDIT ADDITION END\n#include "b.dm"', ["a.dm", "b.dm"])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_inline_addition_markers_preserve_include_records(self):
        result = self.check_fixture('#include "a.dm" // APHELION EDIT ADDITION - DOGMOS\n#include "b.dm"', ["a.dm", "b.dm"])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_inline_markers_cannot_hide_missing_or_misordered_includes(self):
        for includes in ('#include "a.dm" // APHELION EDIT ADDITION - DOGMOS', '#include "b.dm" // APHELION EDIT ADDITION - DOGMOS\n#include "a.dm"'):
            with self.subTest(includes=includes):
                result = self.check_fixture(includes, ["a.dm", "b.dm"])
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertRegex(result.stdout, "Missing include|out of order")

    def test_inline_markers_reject_unknown_or_noncanonical_comments(self):
        for comment in ("unrecognized comment", "APHELION EDIT ADDITION - dogmos", "APHELION EDIT ADDITION - DOGMOS__TEST", "APHELION EDIT ADDITION - DOGMOS_", "APHELION EDIT ADDITION START - DOGMOS", "APHELION EDIT ADDITION - DOGMOS trailing text", "NOVA EDIT ADDITION - DOGMOS"):
            with self.subTest(comment=comment):
                result = self.check_fixture('#include "a.dm" // ' + comment, ["a.dm"])
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn("unsupported include-block line", result.stdout)

    def test_nova_subdirectory_uses_portable_path_separator(self):
        result = self.check_fixture('#include "a.dm"\n// NOVA EDIT ADDITION START\n#include "~nova\\b.dm"\n// NOVA EDIT ADDITION END', ["a.dm", "~nova/b.dm"])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_markers_cannot_hide_missing_or_misordered_includes(self):
        for includes in ('#include "a.dm"', '#include "b.dm"\n#include "a.dm"'):
            with self.subTest(includes=includes):
                result = self.check_fixture('// APHELION EDIT ADDITION START - DOGMOS\n' + includes + '\n// APHELION EDIT ADDITION END', ["a.dm", "b.dm"])
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertRegex(result.stdout, "Missing include|out of order")


if __name__ == "__main__":
    unittest.main()
