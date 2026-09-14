"""Extract only a bounded data package into a new private directory; never execute it."""
import json
from pathlib import Path
import re
import stat
import sys
import zipfile

MAX_ARCHIVE = 512 * 1024 * 1024
MAX_TOTAL = 1024 * 1024 * 1024


def extract(archive, destination):
    archive, destination = Path(archive), Path(destination)
    if archive.stat().st_size > MAX_ARCHIVE:
        raise ValueError('Archive exceeds size limit')
    if destination.exists():
        raise ValueError('Extraction destination must be new')
    with zipfile.ZipFile(archive) as z:
        entries = z.infolist()
        if not 1 <= len(entries) <= 150020:
            raise ValueError('Archive entry limit exceeded')
        seen, total, files = set(), 0, []
        for entry in entries:
            name = entry.filename
            if name != entry.orig_filename:
                raise ValueError('Archive path contains a null character')
            mode = entry.external_attr >> 16
            if entry.flag_bits & 1 or stat.S_ISLNK(mode) or stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR):
                raise ValueError('Archive contains a special or encrypted entry')
            if name in seen:
                raise ValueError('Duplicate archive entry')
            seen.add(name)
            if entry.is_dir():
                if name != 'icons/' or entry.file_size != 0:
                    raise ValueError('Unexpected archive directory')
                continue
            if name == 'manifest.json':
                limit = 64 * 1024 * 1024
            elif name == 'source-binding.json':
                limit = 65536
            elif re.fullmatch(r'[a-z][a-z_]*\.jsonl', name):
                limit = 256 * 1024 * 1024
            elif re.fullmatch(r'icons/(entity|appearance)-[a-f0-9]{32}\.png', name):
                limit = 4 * 1024 * 1024
            else:
                raise ValueError('Unexpected archive path')
            total += entry.file_size
            if entry.file_size > limit or total > MAX_TOTAL:
                raise ValueError('Uncompressed archive exceeds size limit')
            files.append(entry)
        if 'manifest.json' not in seen:
            raise ValueError('Archive manifest missing')
        destination.mkdir()
        (destination / 'icons').mkdir()
        for entry in files:
            # The strict flat filename grammar above excludes traversal, Windows
            # devices, alternate streams, links and case-folding collisions.
            with z.open(entry) as src, (destination / entry.filename).open('xb') as dst:
                written = 0
                while chunk := src.read(1024 * 1024):
                    written += len(chunk)
                    if written > entry.file_size:
                        raise ValueError('Archive entry exceeds declared length')
                    dst.write(chunk)
                if written != entry.file_size:
                    raise ValueError('Truncated archive entry')
        return {'files': len(files), 'bytes': total}


if __name__ == '__main__':
    try:
        print(json.dumps(extract(*sys.argv[1:])))
    except Exception:
        print('Package archive extraction failed.', file=sys.stderr)
        sys.exit(1)
