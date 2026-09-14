import importlib.util
from pathlib import Path
import stat
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('extract_artifact', Path(__file__).with_name('extract-artifact.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ExtractionTests(unittest.TestCase):
    def attempt(self, entries, accepted=False):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            with zipfile.ZipFile(root / 'fixture.zip', 'w') as z:
                for name, data in entries:
                    z.writestr(name, data)
            if accepted:
                self.assertEqual(module.extract(root / 'fixture.zip', root / 'out')['files'], len(entries))
                self.assertEqual((root / 'out' / 'manifest.json').read_bytes(), b'{}')
            else:
                with self.assertRaises(ValueError):
                    module.extract(root / 'fixture.zip', root / 'out')
                self.assertFalse((root / 'out').exists())

    def test_flat_data_and_icons(self):
        self.attempt([('manifest.json', b'{}'), ('entity.jsonl', b'{}'), ('research_node.jsonl', b'{}'), ('icons/entity-' + 'a' * 32 + '.png', b'png')], True)

    def test_bounded_source_binding(self):
        self.attempt([('manifest.json', b'{}'), ('source-binding.json', b'{}')], True)
        self.attempt([('manifest.json', b'{}'), ('source-binding.json', b'x' * 65537)])
        self.attempt([('manifest.json', b'{}'), ('SOURCE-BINDING.json', b'{}')])

    def test_paths_and_special_files(self):
        for name in ['../escape', '/absolute', 'C:/absolute', 'icons/../manifest.json', 'icons\\x.png', 'manifest.json:stream', 'MANIFEST.json', 'CON', 'package/manifest.json', 'script.exe']:
            with self.subTest(name=name):
                self.attempt([('manifest.json', b'{}'), (name, b'x')])
        link = zipfile.ZipInfo('entity.jsonl')
        link.create_system = 3
        link.external_attr = (stat.S_IFLNK | 0o777) << 16
        self.attempt([('manifest.json', b'{}'), (link, b'../outside')])

    def test_duplicates_and_size_bound(self):
        self.attempt([('manifest.json', b'{}'), ('manifest.json', b'{}')])
        prior = module.MAX_TOTAL
        try:
            module.MAX_TOTAL = 2
            self.attempt([('manifest.json', b'{}'), ('entity.jsonl', b'{}')])
        finally:
            module.MAX_TOTAL = prior


if __name__ == '__main__':
    unittest.main()
