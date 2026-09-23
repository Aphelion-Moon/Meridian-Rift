"""The native contract rejects mismatched bytes, architecture and source identities."""
import copy
import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import verify_contract as contract
import sync_in_process as sync


def fixture(root: Path, target='i686-pc-windows-msvc'):
    windows = target == 'i686-pc-windows-msvc'
    binary = bytearray(128)
    if windows:
        binary[:2] = b'MZ'
        struct.pack_into('<I', binary, 0x3c, 64)
        binary[64:68] = b'PE\0\0'
        struct.pack_into('<H', binary, 68, 0x14c)
    else:
        binary[:6] = b'\x7fELF\x01\x01'
        struct.pack_into('<H', binary, 18, 3)
    source = 'b' * 64
    bindings = ('#define DOGMOS_IN_PROCESS\n#define DOGMOS_IN_PROCESS_IDENTITY "in-process:'+source+'"\n#define DOGMOS "libdogmos_in_process"\n').encode()
    features = ['aphelion_reactions', 'katmos', 'katmos_slow_decompression', 'superconductivity', 'turf_processing']
    manifest = dict(schema_version=1, kind='unqualified-in-process-playtest', backend='in-process', target=target, toolchain='1.98.0', source_revision='a'*40, source_sha256=source, features=features, tests_run=False, runtime_qualified=False)
    native,symbols=contract.native_files(manifest)
    manifest['cargo_arguments']=['+1.98.0','build','-p','dogmos','--lib','--example','generate_bindings','--release','--locked','--target',target,'--no-default-features','--features',','.join(features)]
    manifest['artifacts']={native:hashlib.sha256(binary).hexdigest(),symbols:'c'*64,'dogmos_bindings.dm':hashlib.sha256(bindings).hexdigest(),'dogmos-source-snapshot.json':source}
    (root/'code/__DEFINES').mkdir(parents=True,exist_ok=True)
    (root/native).write_bytes(binary)
    (root/'code/__DEFINES/dogmos_bindings.dm').write_bytes(bindings)
    (root/'code/__DEFINES/dogmos_contract.dm').write_bytes(contract.render_contract_defines(manifest))
    lock='dogmos.lock.json' if windows else 'dogmos-linux.lock.json'
    (root/lock).write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n',encoding='utf-8',newline='\n')
    return manifest


class NativeContractTests(unittest.TestCase):
    def test_accepts_matching_native_artifacts_on_both_platforms(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            for target in ('i686-pc-windows-msvc','i686-unknown-linux-gnu'):
                expected=fixture(root,target)
                self.assertEqual(contract.verify_installed(root,target=target),expected)

    def test_rejects_changed_library_bindings_and_defines(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            for path in ('dogmos.dll','code/__DEFINES/dogmos_bindings.dm','code/__DEFINES/dogmos_contract.dm'):
                fixture(root)
                with (root/path).open('ab') as f:f.write(b'changed')
                with self.assertRaises(contract.ContractError):contract.verify_installed(root,target='i686-pc-windows-msvc')

    def test_rejects_wrong_architecture_even_with_matching_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);manifest=fixture(root)
            binary=bytearray((root/'dogmos.dll').read_bytes());struct.pack_into('<H',binary,68,0x8664)
            manifest['artifacts']['dogmos.dll']=hashlib.sha256(binary).hexdigest()
            with self.assertRaisesRegex(contract.ContractError,'architecture'):
                contract.verify_in_process_bytes(manifest,binary,(root/'code/__DEFINES/dogmos_bindings.dm').read_bytes())

    def test_rejects_changed_source_features_and_build_arguments(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);valid=fixture(root)
            for key,value in [('source_sha256','d'*64),('features',[]),('cargo_arguments',[]),('target','x86_64-pc-windows-msvc')]:
                changed=copy.deepcopy(valid);changed[key]=value
                with self.assertRaises(contract.ContractError):contract.validate_in_process_manifest(changed)

    def test_rejects_missing_and_noncanonical_locks(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            with self.assertRaises(contract.ContractError):contract.verify_installed(root,target='i686-pc-windows-msvc')
            valid=fixture(root)
            (root/'dogmos.lock.json').write_text(json.dumps(valid),encoding='utf-8',newline='\n')
            with self.assertRaises(contract.ContractError):contract.verify_installed(root,target='i686-pc-windows-msvc')


class PairedInstallTests(unittest.TestCase):
    def bundles(self, root):
        result = []
        for target in ('i686-pc-windows-msvc', 'i686-unknown-linux-gnu'):
            directory = root / target
            directory.mkdir()
            manifest = fixture(directory, target)
            native = contract.native_files(manifest)[0]
            result.append((manifest, {native: (directory / native).read_bytes(),
                                     'dogmos_bindings.dm': (directory / 'code/__DEFINES/dogmos_bindings.dm').read_bytes()}))
        return result

    def invoke(self, root, bundles):
        with patch.object(sys, 'argv', ['sync', '--bundle', 'windows', '--companion-bundle', 'linux',
                                       '--native-root', str(root), '--root', str(root)]), \
                patch.object(sync, 'read_bundle', side_effect=bundles):
            sync.main()

    def test_paired_install_validates_both_platforms(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bundles = self.bundles(root)
            (root / 'tgstation.dme').touch()
            (root / 'code/__DEFINES').mkdir(parents=True)
            self.invoke(root, bundles)
            for manifest, _ in bundles:
                self.assertEqual(contract.verify_installed(root, target=manifest['target']), manifest)

    def test_companion_mismatch_is_rejected_before_any_write(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bundles = self.bundles(root)
            (root / 'tgstation.dme').touch()
            bundles[1][0]['source_sha256'] = 'd' * 64
            with patch.object(sync, 'atomic_write') as write:
                with self.assertRaisesRegex(contract.ContractError, 'identical source'):
                    self.invoke(root, bundles)
                write.assert_not_called()

    def test_failed_post_install_verification_restores_all_previous_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bundles = self.bundles(root)
            (root / 'tgstation.dme').touch()
            fixture(root)
            # Preserve unrelated/preexisting bytes even when the second platform was absent.
            (root / 'dogmos.dll').write_bytes(b'previous installed library')
            paths = ['dogmos.dll', 'dogmos.lock.json', 'libdogmos_in_process.so',
                     'dogmos-linux.lock.json', 'code/__DEFINES/dogmos_bindings.dm',
                     'code/__DEFINES/dogmos_contract.dm']
            before = {name: (root / name).read_bytes() if (root / name).exists() else None for name in paths}
            with patch.object(sync, 'verify_installed', side_effect=contract.ContractError('injected verification failure')):
                with self.assertRaisesRegex(contract.ContractError, 'injected'):
                    self.invoke(root, bundles)
            after = {name: (root / name).read_bytes() if (root / name).exists() else None for name in paths}
            self.assertEqual(after, before)

if __name__ == '__main__':
    unittest.main()
