"""Install immutable wiki/receiver versions and switch checked local bindings.

Configuration and journals belong outside the web root with administrator-only
write access. This tool never publishes a game package or alters game services.
"""
from pathlib import Path
import argparse
import base64
import hashlib
import json
import os
import re
import subprocess
import uuid
import urllib.parse
import urllib.request

RUNTIME = ('receiver.js artifact-source.js extract-artifact.py publish.js release.js '
           'selection-plan.js tgs.js data-contract.js appearances.js png.js fields.js '
           'provenance.js semantic-check.js source-binding.js build-request.js contract.json package.json run-receiver.ps1').split()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def absolute(value):
    p = Path(value)
    if not p.is_absolute():
        raise RuntimeError('Deployment paths must be absolute')
    return p.resolve()


def atomic(path, data):
    temp = path.with_name(path.name + '.' + uuid.uuid4().hex + '.pending')
    try:
        temp.write_bytes(data)
        os.replace(temp, path)
    finally:
        if temp.exists():
            temp.unlink()


def encode(value):
    return (json.dumps(value, indent=2) + '\n').encode('utf-8')


def inventory(source):
    extension = source / 'mediawiki/MeridianAutowiki'
    files = {}
    for p in sorted(extension.rglob('*')):
        if p.is_symlink():
            raise RuntimeError('Linked source files are not release inputs')
        if p.is_file():
            files['extension/' + p.relative_to(extension).as_posix()] = p.read_bytes()
    for name in RUNTIME:
        p = source / name
        if p.is_symlink():
            raise RuntimeError('Linked runtime files are not release inputs')
        files['runtime/' + name] = p.read_bytes()
    hashes = {name: digest(data) for name, data in sorted(files.items())}
    return files, hashes, digest(encode(hashes))


def materialize(root, files, hashes, release):
    destination = root / release
    if destination.exists():
        actual = {p.relative_to(destination).as_posix(): digest(p.read_bytes())
                  for p in destination.rglob('*') if p.is_file()}
        if actual != hashes or any(p.is_symlink() for p in destination.rglob('*')):
            raise RuntimeError('An existing immutable release changed')
        return destination
    root.mkdir(parents=True, exist_ok=True)
    stage = root / (release + '.' + uuid.uuid4().hex + '.pending')
    stage.mkdir()
    for name, data in files.items():
        p = stage / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)
    # A rename exposes the completed directory; old versions stay available.
    stage.rename(destination)
    return destination


class Deployment:
    def __init__(self, config, run=None, web=None):
        self.config = config
        self.paths = {key: absolute(config[key]) for key in
                      ('source', 'releases', 'journalRoot', 'extensionSettings',
                       'receiverConfig', 'php', 'maintenanceRunner', 'settings')}
        self.run = run or self.execute
        self.web = web or self.web_health

    @staticmethod
    def web_health(url):
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme != 'https' or parsed.username or parsed.password:
            raise RuntimeError('The web health endpoint must use HTTPS without credentials')
        query = urllib.parse.parse_qsl(parsed.query) + [('deploycheck', uuid.uuid4().hex), ('maxage', '0')]
        target = urllib.parse.urlunsplit(parsed._replace(query=urllib.parse.urlencode(query)))
        request = urllib.request.Request(target, headers={'Cache-Control': 'no-cache', 'User-Agent': 'MeridianAutowiki-Deployment/1.0'})
        with urllib.request.urlopen(request, timeout=30) as response:
            value = json.loads(response.read(2 * 1024 * 1024))
            if response.status != 200 or not value.get('query', {}).get('general'):
                raise RuntimeError('The web adapter did not return valid MediaWiki site information')

    def execute(self, args, env, cwd):
        result = subprocess.run(args, env=env, cwd=cwd, capture_output=True, timeout=180,
                                encoding='utf-8', errors='replace')
        diagnostics = self.paths['journalRoot'] / 'diagnostics'
        diagnostics.mkdir(parents=True, exist_ok=True)
        (diagnostics / (uuid.uuid4().hex + '.log')).write_text(result.stdout + '\n' + result.stderr, encoding='utf-8')
        if result.returncode:
            raise RuntimeError('Maintenance command failed; inspect protected diagnostics')
        return result.stdout.strip()

    def maintenance(self, entry):
        entry = Path(entry)
        # MediaWiki splits C:/... as extension prefix C before testing whether it
        # is absolute. Pin cwd to the version and use an explicit relative script.
        args = [str(self.paths['php']), '-d', 'memory_limit=1G',
                str(self.paths['maintenanceRunner']), './maintenance/' + entry.name, '--conf',
                str(self.paths['settings'])]
        return self.run(args, {**os.environ, 'MW_WIKI': self.config.get('wiki', 'meridian')}, entry.parent.parent)

    def state(self, extension):
        output = self.maintenance(extension / 'maintenance/State.php')
        try:
            value = json.loads(output)
            return {key: value[key] for key in ('active', 'epoch', 'editorialPending')} | {
                'publication': value.get('publication')}
        except (ValueError, KeyError):
            raise RuntimeError('Maintenance did not return complete wiki state') from None

    def journal(self, path, value):
        atomic(path, encode(value))

    def deploy(self):
        cfg = json.loads(self.paths['receiverConfig'].read_text(encoding='utf-8-sig'))
        lock = Path(str(absolute(cfg['statusFile'])) + '.lock')
        # Never break a lock based on age or a state-file timestamp.
        lock.mkdir()
        try:
            return self.deploy_locked(cfg)
        finally:
            lock.rmdir()

    def deploy_locked(self, cfg):
        files, hashes, release = inventory(self.paths['source'])
        directory = materialize(self.paths['releases'], files, hashes, release)
        extension = directory / 'extension'
        if self.config.get('webPrincipal'):
            if os.name != 'nt':
                raise RuntimeError('Windows web permissions were requested on another platform')
            permissions = subprocess.run(['icacls.exe', str(directory), '/grant:r',
                                          self.config['webPrincipal'] + ':(OI)(CI)(RX)'],
                                         capture_output=True, timeout=30)
            if permissions.returncode:
                raise RuntimeError('Could not grant the web service read access to this version')
        current = absolute(cfg.get('extensionDirectory', self.config['currentExtension']))
        before = self.state(current)
        if before['editorialPending']:
            raise RuntimeError('Reconcile pending human revisions before deployment')
        settings_path = self.paths['extensionSettings']
        old_settings = settings_path.read_bytes()
        settings = old_settings.decode('utf-8-sig')
        pattern = r"wfLoadExtension\(\s*'MeridianAutowiki'\s*(?:,\s*'[^']*')?\s*\);"
        replacement = "wfLoadExtension('MeridianAutowiki','" + extension.as_posix().replace("'", "\\'") + "/extension.json');"
        settings, count = re.subn(pattern, lambda _: replacement, settings)
        if count != 1:
            raise RuntimeError('Expected one explicit Autowiki extension binding')
        bindings = [(settings_path, old_settings, settings.encode('utf-8'))]
        config_before = self.paths['receiverConfig'].read_bytes()
        cfg['extensionDirectory'] = str(extension)
        bindings.append((self.paths['receiverConfig'], config_before, encode(cfg)))
        for switch in self.config.get('switches', []):
            path = absolute(switch['path'])
            original = path.read_bytes()
            text = original.decode('utf-8-sig')
            for change in switch['replacements']:
                old = change['from']
                if text.count(old) != 1:
                    raise RuntimeError('A deployment binding changed; refresh the deployment plan')
                new = change['to'].replace('{extension}', extension.as_posix()).replace('{runtime}', (directory / 'runtime').as_posix())
                text = text.replace(old, new)
            bindings.append((path, original, text.encode('utf-8')))
        if len({str(p).casefold() for p, _, _ in bindings}) != len(bindings):
            raise RuntimeError('A deployment plan names a binding more than once')
        self.paths['journalRoot'].mkdir(parents=True, exist_ok=True)
        journal_path = self.paths['journalRoot'] / (release + '-' + uuid.uuid4().hex + '.json')
        journal = {'version': 1, 'release': release, 'directory': str(directory),
                   'stateBefore': before, 'status': 'prepared', 'files': hashes,
                   'bindings': [{'path': str(p), 'before': base64.b64encode(old).decode(),
                                 'after': digest(new)} for p, old, new in bindings]}
        self.journal(journal_path, journal)
        if self.maintenance(extension / 'maintenance/Schema.php') != 'Schema ready.':
            raise RuntimeError('Schema upgrade did not confirm completion; bindings retained')
        if self.state(current) != before:
            raise RuntimeError('Wiki state changed before deployment; bindings retained')
        # Check every binding before changing any of them.
        if any(p.read_bytes() != old for p, old, _ in bindings):
            raise RuntimeError('A binding changed during preparation; bindings retained')
        applied = []
        try:
            journal['status'] = 'switching'
            self.journal(journal_path, journal)
            for p, old, new in bindings:
                if p.read_bytes() != old:
                    raise RuntimeError('A binding changed before its switch')
                atomic(p, new)
                applied.append((p, old, new))
            health = json.loads(self.maintenance(extension / 'maintenance/Health.php'))
            if absolute(health['codeRoot']) != extension or health['ready'] is not True:
                raise RuntimeError('The new adapter did not pass its installed health check')
            if self.config.get('healthUrl'):
                self.web(self.config['healthUrl'])
            if self.state(extension) != before:
                raise RuntimeError('Wiki state changed during deployment')
            journal['status'] = 'installed'
            self.journal(journal_path, journal)
            return {'release': release, 'journal': str(journal_path), 'status': 'installed'}
        except Exception:
            # If people edited or another writer changed a binding, retain evidence
            # and require an explicit recovery review rather than overwriting it.
            try:
                safe = self.state(extension) == before and all(p.read_bytes() == new for p, _, new in applied)
            except Exception:
                safe = False
            if safe:
                for p, old, _ in reversed(applied):
                    atomic(p, old)
                journal['status'] = 'rolled-back'
            else:
                journal['status'] = 'recovery-review-required'
            self.journal(journal_path, journal)
            raise RuntimeError('Deployment failed; recovery state is recorded in its protected journal') from None

    def rollback(self, journal_path):
        journal_path = absolute(journal_path)
        if journal_path.parent != self.paths['journalRoot']:
            raise RuntimeError('Choose a journal from the configured protected directory')
        journal = json.loads(journal_path.read_text(encoding='utf-8'))
        if journal['status'] != 'installed':
            raise RuntimeError('Only a completed installation can use routine rollback')
        cfg = json.loads(self.paths['receiverConfig'].read_text(encoding='utf-8-sig'))
        lock = Path(str(absolute(cfg['statusFile'])) + '.lock')
        lock.mkdir()
        try:
            extension = absolute(journal['directory']) / 'extension'
            if self.state(extension) != journal['stateBefore']:
                raise RuntimeError('Human or publication state changed; review recovery before rollback')
            allowed = {self.paths['extensionSettings'], self.paths['receiverConfig']}
            allowed.update(absolute(s['path']) for s in self.config.get('switches', []))
            bindings = journal['bindings']
            if any(absolute(b['path']) not in allowed or digest(absolute(b['path']).read_bytes()) != b['after'] for b in bindings):
                raise RuntimeError('A binding changed after installation; rollback refused')
            for b in reversed(bindings):
                atomic(absolute(b['path']), base64.b64decode(b['before'], validate=True))
            journal['status'] = 'rolled-back'
            self.journal(journal_path, journal)
            return {'status': 'rolled-back', 'journal': str(journal_path)}
        finally:
            lock.rmdir()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('config', help='Protected deployment configuration JSON')
    parser.add_argument('--rollback', help='Restore unchanged bindings from this protected journal')
    args = parser.parse_args()
    try:
        config = json.loads(Path(args.config).read_text(encoding='utf-8-sig'))
        deployer = Deployment(config)
        print(json.dumps(deployer.rollback(args.rollback) if args.rollback else deployer.deploy()))
    except Exception as error:
        print(json.dumps({'status': 'failed', 'error': type(error).__name__}))
        raise SystemExit(1)
