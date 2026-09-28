import json
from pathlib import Path
import tempfile
import unittest

from modular_aphelion.tools.update_module_includes import update


class ModuleIncludeTests(unittest.TestCase):
    def test_regenerates_only_module_group_with_schema_exclusions_and_stable_order(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            schema = root / 'tools/ticked_file_enforcement/schemas/tgstation_dme.json'
            schema.parent.mkdir(parents=True)
            schema.write_text(json.dumps({'forbidden_includes': ['**/diagnostic.dm'], 'excluded_files': []}))
            for name in ('z/code/run.dm', 'a/code/run.dm', 'a/code/diagnostic.dm', 'a/base.dm'):
                path = root / 'modular_aphelion/modules' / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('// source\n')
            before = b'// header\r\n#include "core.dm"\r\n#include "modular_aphelion\\modules\\stale.dm"\r\n#define AFTER 7\r\n'
            dme = root / 'tgstation.dme'
            dme.write_bytes(before)
            expected = b'// header\r\n#include "core.dm"\r\n#include "modular_aphelion\\modules\\a\\base.dm"\r\n#include "modular_aphelion\\modules\\a\\code\\run.dm"\r\n#include "modular_aphelion\\modules\\z\\code\\run.dm"\r\n#define AFTER 7\r\n'
            self.assertEqual(update(root), expected)
            dme.write_bytes(expected)
            self.assertEqual(update(root), expected)

    def test_refuses_to_move_interleaved_defines(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'tgstation.dme').write_text('#include "modular_aphelion\\modules\\a.dm"\n#define INTERLEAVED 1\n#include "modular_aphelion\\modules\\b.dm"\n')
            with self.assertRaisesRegex(ValueError, 'contiguous'):
                update(root)
