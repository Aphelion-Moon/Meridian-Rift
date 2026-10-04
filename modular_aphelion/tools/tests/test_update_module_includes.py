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

    def test_scoped_update_preserves_other_modules_conditional_backends(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            schema = root / 'tools/ticked_file_enforcement/schemas/tgstation_dme.json'
            schema.parent.mkdir(parents=True)
            schema.write_text(json.dumps({'forbidden_includes': [], 'excluded_files': []}))
            source = root / 'modular_aphelion/modules/runtime_ownership/code/guards.dm'
            source.parent.mkdir(parents=True)
            source.write_text('// source\n')
            conditional = ('#ifdef DOGMOS_IN_PROCESS\n'
                           '#include "modular_aphelion\\modules\\dogmos\\native.dm"\n'
                           '#else\n'
                           '#include "modular_aphelion\\modules\\dogmos\\service.dm"\n'
                           '#endif\n')
            old = '#include "modular_aphelion\\modules\\runtime_ownership\\old.dm"\n'
            new = '#include "modular_aphelion\\modules\\runtime_ownership\\code\\guards.dm"\n'
            dme = root / 'tgstation.dme'
            dme.write_bytes((conditional + old).encode())
            expected = (conditional + new).encode()
            self.assertEqual(update(root, 'runtime_ownership'), expected)
            dme.write_bytes(expected)
            self.assertEqual(update(root, 'runtime_ownership'), expected)
            with self.assertRaisesRegex(ValueError, 'contiguous'):
                update(root, 'dogmos')
