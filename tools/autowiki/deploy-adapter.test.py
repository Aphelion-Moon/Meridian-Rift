import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('deploy_adapter', Path(__file__).with_name('deploy-adapter.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class DeploymentTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root / 'source'
        ext = self.source / 'mediawiki/MeridianAutowiki'
        ext.mkdir(parents=True)
        (ext / 'extension.json').write_text('{}')
        for name in module.RUNTIME:
            (self.source / name).write_text('fixture ' + name)
        self.settings = self.root / 'integration.php'
        self.settings.write_text("<?php\nwfLoadExtension('MeridianAutowiki');\n// Preserve unrelated settings.\n")
        self.receiver = self.root / 'receiver.json'
        self.receiver.write_text(json.dumps({'statusFile': str(self.root / 'status.json'), 'retainedOption': True}))
        self.jobs = self.root / 'jobs.ps1'
        self.jobs.write_text('run old-runtime/receiver.js')
        self.config = {key: str(self.root / key) for key in ('releases', 'journalRoot', 'php', 'maintenanceRunner', 'settings', 'currentExtension')}
        self.config.update(source=str(self.source), extensionSettings=str(self.settings), receiverConfig=str(self.receiver),
                           switches=[{'path': str(self.jobs), 'replacements': [{'from': 'old-runtime/receiver.js', 'to': '{runtime}/receiver.js'}]}])
        self.before = {p: p.read_bytes() for p in (self.settings, self.receiver, self.jobs)}
        self.state = {'active': '', 'epoch': 1, 'editorialPending': False, 'publication': None}
        self.fail_health = False
        self.change_human = False
        self.change_binding = False
        self.deployer = module.Deployment(self.config, self.run_command)

    def run_command(self, args, env, cwd):
        entry = Path(cwd) / args[4]
        if entry.name == 'State.php':
            return json.dumps(self.state)
        if entry.name == 'Schema.php':
            if self.change_binding:
                self.jobs.write_text('A concurrent administrator edit')
            return 'Schema ready.'
        if entry.name == 'Health.php':
            if self.change_human:
                self.state['epoch'] = 2
            return json.dumps({'ready': not self.fail_health, 'codeRoot': str(entry.parent.parent)})
        raise AssertionError('Unexpected maintenance command')

    def test_complete_versions_and_explicit_rollback(self):
        result = self.deployer.deploy()
        cfg = json.loads(self.receiver.read_text())
        self.assertTrue(cfg['retainedOption'])
        self.assertTrue((Path(cfg['extensionDirectory']) / 'extension.json').is_file())
        self.assertIn('// Preserve unrelated settings.', self.settings.read_text())
        self.assertIn(result['release'], self.jobs.read_text())
        self.assertEqual(self.deployer.rollback(result['journal'])['status'], 'rolled-back')
        for p, old in self.before.items():
            self.assertEqual(p.read_bytes(), old)

    def test_failed_health_restores_exact_prior_bindings(self):
        self.fail_health = True
        with self.assertRaises(RuntimeError):
            self.deployer.deploy()
        for p, old in self.before.items():
            self.assertEqual(p.read_bytes(), old)
        journal = json.loads(next((self.root / 'journalRoot').glob('*.json')).read_text())
        self.assertEqual(journal['status'], 'rolled-back')

    def test_web_failure_rolls_back_even_when_cli_health_passes(self):
        self.config['healthUrl'] = 'https://wiki.example/api.php'
        def unavailable(url):
            raise RuntimeError('HTTP 500')
        self.deployer.web = unavailable
        with self.assertRaises(RuntimeError):
            self.deployer.deploy()
        for p, old in self.before.items():
            self.assertEqual(p.read_bytes(), old)

    def test_human_edits_prevent_automatic_rollback(self):
        self.change_human = True
        with self.assertRaises(RuntimeError):
            self.deployer.deploy()
        journal = json.loads(next((self.root / 'journalRoot').glob('*.json')).read_text())
        self.assertEqual(journal['status'], 'recovery-review-required')
        self.assertNotEqual(self.settings.read_bytes(), self.before[self.settings])

    def test_concurrent_binding_edit_is_preserved(self):
        self.change_binding = True
        with self.assertRaises(RuntimeError):
            self.deployer.deploy()
        self.assertEqual(self.settings.read_bytes(), self.before[self.settings])
        self.assertEqual(self.jobs.read_text(), 'A concurrent administrator edit')

    def test_receiver_lock_is_not_broken(self):
        lock = self.root / 'status.json.lock'
        lock.mkdir()
        with self.assertRaises(FileExistsError):
            self.deployer.deploy()
        self.assertTrue(lock.exists())
        self.assertFalse((self.root / 'releases').exists())

    def test_immutable_versions_cannot_be_silently_reused_after_changes(self):
        files, hashes, release = module.inventory(self.source)
        version = module.materialize(self.root / 'releases', files, hashes, release)
        (version / 'runtime/receiver.js').write_text('changed')
        with self.assertRaisesRegex(RuntimeError, 'immutable release changed'):
            self.deployer.deploy()
        self.assertEqual(self.settings.read_bytes(), self.before[self.settings])

    def test_explicit_rollback_rejects_later_edits(self):
        result = self.deployer.deploy()
        self.state['epoch'] = 2
        with self.assertRaisesRegex(RuntimeError, 'Human or publication state changed'):
            self.deployer.rollback(result['journal'])


if __name__ == '__main__':
    unittest.main()
