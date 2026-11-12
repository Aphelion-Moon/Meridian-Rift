from pathlib import Path
import tempfile
import unittest
from test_contract import fixture
from stage_ci_runtime import stage_runtime
from verify_contract import ContractError

class RuntimeStagingTests(unittest.TestCase):
    def test_stages_only_the_verified_linux_library(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);fixture(root,'i686-unknown-linux-gnu')
            destination=root/'runtime';destination.mkdir()
            stage_runtime(root,destination)
            self.assertEqual([p.name for p in destination.iterdir()],['libdogmos_in_process.so'])
            self.assertEqual((destination/'libdogmos_in_process.so').read_bytes(),(root/'libdogmos_in_process.so').read_bytes())

    def test_rejects_missing_linux_artifact(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);fixture(root)
            destination=root/'runtime';destination.mkdir()
            with self.assertRaises(ContractError):stage_runtime(root,destination)
            self.assertEqual(list(destination.iterdir()),[])
