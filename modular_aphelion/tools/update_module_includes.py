"""Regenerate the DME's Aphelion module includes from maintained module source files."""
from pathlib import Path
import argparse
import fnmatch
import json
import re


def update(root: Path, module: str | None = None) -> bytes:
    dme = (root / 'tgstation.dme').read_bytes()
    newline = b'\r\n' if b'\r\n' in dme else b'\n'
    lines = dme.splitlines()
    prefix = 'modular_aphelion\\modules\\' + (module + '\\' if module else '')
    pattern = re.compile(rb'#include "' + re.escape(prefix.encode('utf-8')) + rb'[^"\r\n]+\.dm"')
    indices = [index for index, line in enumerate(lines) if pattern.fullmatch(line)]
    if not indices or indices != list(range(indices[0], indices[-1] + 1)):
        raise ValueError('Expected one contiguous existing Aphelion module include group')
    schema = json.loads((root / 'tools/ticked_file_enforcement/schemas/tgstation_dme.json').read_text(encoding='utf-8'))
    source = root / 'modular_aphelion/modules'
    if module:
        source /= module
    paths = [path for path in source.rglob('*.dm')
             if not any(fnmatch.fnmatch(path.relative_to(root).as_posix(), pattern)
                        for pattern in schema['forbidden_includes'])
             and str(path.relative_to(root)) not in schema['excluded_files']]
    # DreamMaker sorts files before subdirectories at each level.
    paths.sort(key=lambda path: tuple((0 if part.endswith('.dm') else 1, part.lower()) for part in path.relative_to(root).parts))
    generated = [f'#include "{str(path.relative_to(root)).replace(chr(47), chr(92))}"'.encode('utf-8') for path in paths]
    return newline.join(lines[:indices[0]] + generated + lines[indices[-1] + 1:]) + newline


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    repository = Path(__file__).resolve().parents[2]
    parser.add_argument('--module', choices=sorted(path.name for path in (repository / 'modular_aphelion/modules').iterdir() if path.is_dir()),
                        help='Update one existing module group, preserving conditional includes in other modules')
    args = parser.parse_args()
    output = update(repository, args.module)
    target = repository / 'tgstation.dme'
    if args.write:
        target.write_bytes(output)
    elif output != target.read_bytes():
        raise SystemExit('Aphelion module includes drifted; run with --write')
