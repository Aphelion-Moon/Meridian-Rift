"""Recover pinned cutter inputs from Git history and prove their generated output.

The default writes only a new review directory. --apply restores only inputs whose
recut states, directions, frames, timing and pixels match the retained game icons.
Original authorship remains in Git history and the recovery manifest.
"""
import argparse, hashlib, json, pathlib, shutil, subprocess, sys

REPO = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'tools'))
from dmi import Dmi


def digest(data):
    return hashlib.sha256(data).hexdigest()


def icon_signature(filename):
    icon = Dmi.from_file(filename)
    states = []
    for state in icon.states:
        states.append({'name': state.name, 'dirs': state.dirs, 'frames': state.framecount,
                       'delays': state.delays or [1] * state.framecount,
                       'loop': state.loop, 'rewind': state.rewind, 'movement': state.movement,
                       'hotspots': state.hotspots,
                       'pixels': [digest(frame.convert('RGBA').tobytes()) for frame in state.frames]})
    states.sort(key=lambda state: (str(state['name']), state['movement']))
    if len({(state['name'], state['movement']) for state in states}) != len(states):
        raise ValueError('Ambiguous duplicate icon states')
    return digest(json.dumps({'width': icon.width, 'height': icon.height, 'states': states}, sort_keys=True).encode())


def recover(output, cutter, apply=False):
    output = output.resolve()
    if output.exists():
        raise ValueError('Use a new review directory; earlier recovery evidence is immutable')
    output.mkdir(parents=True)
    staged = output / 'sources'
    staged.mkdir()
    rows = []
    git = lambda *args: subprocess.check_output(['git', '-C', str(REPO), *args], stderr=subprocess.PIPE, timeout=30)
    for debt in json.loads((REPO / 'tools/autowiki/cutter-debt.json').read_text(encoding='utf-8')):
        source = debt['config'][:-5]
        if any(not (REPO / name).resolve().is_relative_to(REPO) or pathlib.Path(name).is_absolute() for name in [source, debt['config'], debt['output']]):
            raise ValueError('Cutter inventory path escapes the repository')
        if (REPO / source).exists():
            continue
        row = {**debt, 'source': source}
        rows.append(row)
        try:
            if digest((REPO / debt['config']).read_bytes()) != debt['configSha256'] or digest((REPO / debt['output']).read_bytes()) != debt['sha256']:
                raise ValueError('Pinned cutter configuration or output changed')
            removed = git('log', '-1', '--format=%H', '--diff-filter=D', '--', source).decode().strip()
            if not removed:
                raise ValueError('No source deletion found in local Git history')
            revision = git('rev-parse', removed + '^').decode().strip()
            content = git('show', revision + ':' + source)
            row.update({'recoveredFrom': revision, 'removedBy': removed, 'gitBlob': git('rev-parse', revision + ':' + source).decode().strip(), 'sourceSha256': digest(content), 'lastSourceCommit': git('log', '-1', '--format=%H', revision, '--', source).decode().strip()})
            target = staged / source
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
            shutil.copy2(REPO / debt['config'], staged / debt['config'])
        except (ValueError, OSError, subprocess.SubprocessError) as error:
            row['error'] = type(error).__name__ + ': recovery evidence unavailable or changed'
    with (output / 'cutter.log').open('wb') as log:
        result = subprocess.run([str(cutter.resolve()), '--dont-wait', '--templates', str(REPO / 'cutter_templates'), str(staged)], stdout=log, stderr=subprocess.STDOUT, timeout=120)
    if result.returncode:
        raise RuntimeError('Isolated cutter failed; inspect its review log')
    for row in rows:
        if row.get('error'):
            continue
        try:
            row['expectedSignature'] = icon_signature(REPO / row['output'])
            row['generatedSignature'] = icon_signature(staged / row['output'])
            row['verified'] = row['expectedSignature'] == row['generatedSignature']
        except (ValueError, OSError, AssertionError, NotImplementedError):
            row['verified'] = False
            row['error'] = 'Generated output cannot be compared as a complete DMI'
    restored = 0
    for row in rows:
        if not apply or not row.get('verified'):
            continue
        target = REPO / row['source']
        if target.exists() or digest((REPO / row['output']).read_bytes()) != row['sha256'] or digest((REPO / row['config']).read_bytes()) != row['configSha256']:
            raise RuntimeError('Repository changed during review; no further sources restored')
        with target.open('xb') as stream:
            stream.write((staged / row['source']).read_bytes())
        restored += 1
    report = {'version': 1, 'cutterSha256': digest(cutter.read_bytes()), 'reviewed': len(rows), 'verified': sum(bool(row.get('verified')) for row in rows), 'restored': restored, 'rows': rows}
    (output / 'recovery.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: report[key] for key in ['reviewed', 'verified', 'restored']}))
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=pathlib.Path)
    parser.add_argument('--cutter', type=pathlib.Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    result = recover(args.output, args.cutter, args.apply)
    if result['verified'] != result['reviewed']:
        raise SystemExit(1)
