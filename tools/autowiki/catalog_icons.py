"""Inventory source sprites and compare wiki originals without changing either.

Pixel equality is evidence that artwork exists in the checkout, not proof that
the current game type uses it. Runtime appearance and object identity belong in
the structured game export. Requires Pillow and the repository's tools/dmi.
"""
import argparse, collections, hashlib, json, pathlib, sqlite3, subprocess, sys
from PIL import Image

REPO = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'tools'))
from dmi import Dmi, DIR_ORDER


def pixel_hash(image):
    rgba = image.convert('RGBA')
    rgba.paste((0, 0, 0, 0), mask=rgba.getchannel('A').point(lambda x: 255 if x == 0 else 0))
    return hashlib.sha256(f'{rgba.width}x{rgba.height}:'.encode() + rgba.tobytes()).hexdigest()


def catalogue(repo, output):
    output.mkdir(parents=True, exist_ok=True)
    database = output / 'sprites.sqlite'
    if database.exists():
        raise ValueError('Use a new output directory; an existing catalogue is immutable')
    sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
    filenames = subprocess.check_output(['git', 'ls-files', '-z', '*.dmi'], cwd=repo).decode().split('\0')
    db = sqlite3.connect(database)
    db.executescript('CREATE TABLE sprites(source TEXT, source_sha256 TEXT, state TEXT, direction INTEGER, frames INTEGER, movement INTEGER, width INTEGER, height INTEGER, pixel_sha256 TEXT); CREATE TABLE failures(source TEXT, error TEXT);')
    count = states = 0
    for filename in filter(None, filenames):
        try:
            file = repo / filename
            source_hash = hashlib.sha256(file.read_bytes()).hexdigest()
            dmi = Dmi.from_file(file)
            for state in dmi.states:
                states += 1
                for direction_index in range(state.dirs):
                    image = state.frames[direction_index]
                    db.execute('INSERT INTO sprites VALUES(?,?,?,?,?,?,?,?,?)', (filename, source_hash, state.name, DIR_ORDER[direction_index], state.framecount, int(state.movement), image.width, image.height, pixel_hash(image)))
            count += 1
            if count % 250 == 0:
                db.commit()
                print(f'Catalogued {count} DMI files', flush=True)
        except Exception as error:
            db.execute('INSERT INTO failures VALUES(?,?)', (filename, f'{type(error).__name__}: {error}'))
    db.executescript('CREATE INDEX pixel ON sprites(pixel_sha256); CREATE INDEX state_name ON sprites(state COLLATE NOCASE);')
    db.commit()
    summary = {'sourceSha': sha, 'sourceFiles': count, 'states': states, 'directionalFirstFrames': db.execute('SELECT COUNT(*) FROM sprites').fetchone()[0], 'failures': db.execute('SELECT COUNT(*) FROM failures').fetchone()[0], 'scope': 'First frame of every direction, including movement states; no runtime overlays, coloring or inherited game-type resolution.'}
    (output / 'catalogue.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    db.close()
    return summary


def compare(inventory, output):
    wiki = json.loads(inventory.read_text(encoding='utf-8-sig'))
    db = sqlite3.connect(f'file:{(output / "sprites.sqlite").as_posix()}?mode=ro', uri=True)
    db.row_factory = sqlite3.Row
    uses = collections.Counter(row['lt_title'] for row in wiki['uses'])
    results = []
    for file in wiki['files']:
        item = {'file': file['img_name'], 'width': int(file['img_width']), 'height': int(file['img_height']), 'uses': uses[file['img_name']], 'revision': file['revision'], 'generated': file['img_name'].startswith('Autowiki-')}
        if file['img_media_type'] not in ('BITMAP', 'DRAWING') or max(item['width'], item['height']) > 128:
            item['status'] = 'outside-small-raster-scope'
        else:
            try:
                with Image.open(file['path']) as image:
                    item['animated'] = bool(getattr(image, 'n_frames', 1) > 1)
                    digest = pixel_hash(image)
                matches = db.execute('SELECT source,state,direction,frames,movement FROM sprites WHERE pixel_sha256=?', (digest,)).fetchall()
                item['status'] = 'source-pixel-match' if matches else 'needs-identity-or-render-review'
                item['pixelSha256'] = digest
                item['matches'] = [dict(row) for row in matches]
            except Exception as error:
                item['status'] = 'read-failure'
                item['error'] = type(error).__name__
        results.append(item)
    (output / 'wiki-comparison.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
    summary = {'files': len(results), 'status': dict(collections.Counter(x['status'] for x in results)), 'usedStatus': dict(collections.Counter(x['status'] for x in results if x['uses'])), 'generatedFiles': sum(x['generated'] for x in results), 'missingUsedFilenames': len(set(uses) - {x['file'] for x in results}), 'limitation': 'A source pixel match does not establish the current object appearance; absence of a match does not alone establish that an image is outdated.'}
    (output / 'comparison.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    return summary


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=pathlib.Path)
    parser.add_argument('--repo', type=pathlib.Path, default=REPO)
    parser.add_argument('--wiki-inventory', type=pathlib.Path)
    parser.add_argument('--compare-only', action='store_true')
    args = parser.parse_args()
    if not args.compare_only:
        print(json.dumps(catalogue(args.repo.resolve(), args.output.resolve())))
    if args.wiki_inventory:
        print(json.dumps(compare(args.wiki_inventory, args.output.resolve())))
