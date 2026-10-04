"""Read DMI/PNG metadata offline without asking BYOND to materialize icons."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import zlib


def inspect(path):
    if path.stat().st_size > 16 * 1024 * 1024:
        raise ValueError('PNG/DMI exceeds 16 MiB')
    raw = path.read_bytes()
    if len(raw) > 16 * 1024 * 1024 or raw[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('Expected PNG/DMI no larger than 16 MiB')
    offset, description, width, height = 8, '', None, None
    while offset + 12 <= len(raw):
        size = struct.unpack('>I', raw[offset:offset + 4])[0]
        kind = raw[offset + 4:offset + 8]
        if offset + size + 12 > len(raw):
            raise ValueError('Truncated PNG chunk')
        data = raw[offset + 8:offset + 8 + size]
        if kind == b'IHDR':
            width, height = struct.unpack('>II', data[:8])
        if kind in (b'tEXt', b'zTXt') and data.startswith(b'Description\0'):
            content = data.split(b'\0', 1)[1]
            if kind == b'zTXt':
                if not content or content[0] != 0:
                    raise ValueError('Unsupported text compression')
                decoder = zlib.decompressobj()
                content = decoder.decompress(content[1:], 1048577)
                if len(content) > 1048576 or not decoder.eof:
                    raise ValueError('DMI metadata exceeds 1 MiB')
            description = content.decode('latin1')
        offset += size + 12
        if kind == b'IEND':
            break
    if not width or not height:
        raise ValueError('Missing image dimensions')
    tile_width = re.search(r'^\s*width\s*=\s*(\d+)', description, re.M)
    tile_height = re.search(r'^\s*height\s*=\s*(\d+)', description, re.M)
    tile_width = int(tile_width[1]) if tile_width else width
    tile_height = int(tile_height[1]) if tile_height else height
    states = []
    for state in re.split(r'^state\s*=', description, flags=re.M)[1:]:
        directions = re.search(r'^\s*dirs\s*=\s*(\d+)', state, re.M)
        frames = re.search(r'^\s*frames\s*=\s*(\d+)', state, re.M)
        states.append({'directions': int(directions[1]) if directions else 1, 'frames': int(frames[1]) if frames else 1})
    declared_tiles = sum(s['directions'] * s['frames'] for s in states)
    if not tile_width or not tile_height or declared_tiles * tile_width * tile_height > width * height:
        raise ValueError('DMI tile counts exceed source sheet')
    return {'path': path.as_posix(), 'sha256': hashlib.sha256(raw).hexdigest(), 'disk_bytes': len(raw),
            'sheet_width': width, 'sheet_height': height, 'tile_width': tile_width, 'tile_height': tile_height,
            'states': states, 'declared_tiles': declared_tiles, 'rgba_sheet_payload_model_bytes': width * height * 4,
            'runtime_bytes': None, 'reason': 'Offline RGBA payload model and compressed disk size; cache residency, sharing, handles and client GPU memory unavailable.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('assets', nargs='+', type=Path)
    args = parser.parse_args()
    print(json.dumps([inspect(path) for path in args.assets], indent=2))
