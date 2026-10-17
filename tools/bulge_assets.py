"""Read, check and preview the bulge template sheets (modular_aphelion/modules/bulge/icons/templates), and name the
templates the server derives at run time.

Every template is named for what it is; the names follow from the family data (families.dm), the penis shapes and the
rules in templates.dm, which this tool reads and mirrors. There is no index to keep in step and no list kept by hand:
the sheets, the DM data and the rules are the whole truth.

The sheets hold the shapes up to each family's small_cap, the skirts' anatomy clearance and flaps, and the large heart
boxers' precoloured patches. Past small_cap the shapes, the anatomy they leave bare, the loincloths' drapes and their
cuts have no sheet: the server derives them at run time from the game's penis, testicle and loincloth sprites
(templates.dm), and the bulge_derivation unit test holds them to its frozen record. This tool names them; it does not
draw them.

  python tools/bulge_assets.py verify                     check every sheet, name and identity
  python tools/bulge_assets.py fix [SHEET...]             re-encode every sheet named (all by default) that is not an
                                                          8-bit palette PNG as one, with the same pixels and DMI
                                                          metadata, and print the proof
  python tools/bulge_assets.py find TEXT                  sheet states, derived templates, families and garments
                                                          matching TEXT
  python tools/bulge_assets.py preview STATE --output DIR [--garment FILE:STATE]
      a sheet state's four directions as PNGs, scaled up; a kind map also as its kinds in colour, and with --garment
      composited over that worn sprite with the approved print rule, as the server derives a printed patch; for a
      revealing skirt's hard shape also the garment cut by its flap, and the clearance where the shaft shows over it.
      A derived template has no sheet state to preview: the tool says so.

Run from any directory; Pillow is the only requirement (tools/bulge_assets_requirements.txt). Edit the sheets in
Dream Maker, then run verify, and fix where it says so: Dream Maker re-saves a sheet of few colours as a 1-bit or 4-bit
palette PNG, which rust-g's DMI reader, behind tg's icon_exists(), cannot read. Do not run ZopfliPNG or other PNG
optimisers over them: rust-g's DMI reader failed on some of their output.
"""
from __future__ import annotations
import argparse, colorsys, hashlib, io, os, re, struct, sys, zlib
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / 'modular_aphelion/modules/bulge'
SHEETS = MODULE / 'icons/templates'
FAMILIES_DM = MODULE / 'code/families.dm'
TEMPLATES_DM = MODULE / 'code/templates.dm'
GARMENTS_DM = MODULE / 'code/garment_families.dm'
GENITALS_DM = ROOT / 'modular_nova/modules/customization/modules/mob/dead/new_player/sprite_accessories/genitals.dm'
DIRS = ('south', 'north', 'east', 'west')
FAMILY_ROOT = '/datum/bulge_family'
PENIS_ROOT = '/datum/sprite_accessory/genital/penis'
# Kinds as the DM numbers them (BULGE_KIND_*), their fixed greys in a kind map, and colours to tell them apart.
KINDS = {1: 'cloth', 2: 'light', 3: 'highlight', 4: 'shade', 5: 'deep shade'}
GREYS = {0x80: 1, 0xa3: 2, 0xb7: 3, 0x64: 4, 0x4b: 5}
SHOW = {1: (90, 140, 220, 255), 2: (120, 220, 120, 255), 3: (250, 250, 120, 255), 4: (230, 120, 60, 255), 5: (170, 50, 170, 255)}
# What each sheet holds: kind maps decode by grey, masks are opaque white, patches keep their colours.
KIND_SHEETS = ('cloth_small', 'skirt_shapes')
MASK_SHEETS = ('skirt_clearance', 'skirt_flaps')
PATCH_SHEETS = ('printed_patches',)
NAME_PATTERNS = {
    'cloth_small': r'[a-z_]+_(half|hard)_[1-8]_(plain|digi)',
    'skirt_shapes': r'[a-z0-9_]+_(half|hard)_[1-8]_(plain|digi)',
    'skirt_clearance': r'[a-z0-9_]+_(half|hard)_[1-8]',
    'skirt_flaps': r'[a-z0-9_]+_hard_[1-8]_(plain|digi)',
    'printed_patches': r'[a-z_]+_(half|hard)_[5-8]_(plain|digi)(_[a-z_]+)?',
}
# The templates the server derives at run time (templates.dm), by kind, and the names they are derived under: a shape
# past small_cap (whose bare anatomy, if it leaves any, is derived under the same name), a loincloth's drape, and the cut
# under it, "[drapes]_cut_[row]", the row following from the derived drape. A derived identity's `where` here is
# (None, name, 0, 0): no sheet; a cut's name is None, as only the server can say its row.
DERIVED = 'derived at run time'
DERIVED_PATTERNS = {
    'shape': r'[a-z_]+_(half|hard)_[5-8]_(plain|digi)_[a-z_]+',
    'drape': r'[a-z_]+_[1-7](_untoned)?(_flat)?',
}
DERIVED_KINDS = {'shape': 'a shape past small_cap and the anatomy it leaves bare', 'drape': "a loincloth's drape",
                 'cut': "a loincloth's cut"}


# ---------------------------------------------------------------- sheets
def read_dmi(path: Path):
    """-> ({state: (dirs, frames, [tile RGBA bytes])}, (width, height)); frames S, N, E, W per direction."""
    with Image.open(path) as source:
        description = source.info['Description']
        atlas = source.convert('RGBA')
    width = int(re.search(r'width\s*=\s*(\d+)', description)[1])
    height = int(re.search(r'height\s*=\s*(\d+)', description)[1])
    if width <= 0 or height <= 0 or atlas.width % width or atlas.height % height:
        raise ValueError(f"{path.name}: invalid frame dimensions {width}x{height} for atlas {atlas.size}")
    columns = atlas.width // width
    capacity = columns * (atlas.height // height)
    states, offset = {}, 0
    for match in re.finditer(r'state = "([^"]*)"(.*?)(?=state =|# END|\Z)', description, re.S):
        name, metadata = match.groups()
        directions = int(re.search(r'dirs\s*=\s*(\d+)', metadata)[1])
        frames = int(re.search(r'frames\s*=\s*(\d+)', metadata)[1])
        if directions <= 0 or frames <= 0:
            raise ValueError(f"{path.name}: {name} needs positive direction and frame counts")
        if offset + directions * frames > capacity:
            raise ValueError(f"{path.name}: {name} declares frames beyond the atlas capacity ({capacity})")
        tiles = []
        for _ in range(directions * frames):
            x, y = (offset % columns) * width, (offset // columns) * height
            tiles.append(atlas.crop((x, y, x + width, y + height)).tobytes())
            offset += 1
        assert name not in states, ('duplicate state', path.name, name)
        states[name] = (directions, frames, tiles)
    return states, (width, height)


class Sheets:
    def __init__(self, folder=SHEETS):
        self.folder = folder
        self.files = {p.stem: read_dmi(p) for p in sorted(folder.glob('*.dmi'))}

    def has(self, sheet, state):
        return sheet in self.files and state in self.files[sheet][0]

    def frame_size(self, sheet):
        return self.files[sheet][1]

    def tiles(self, sheet, state):
        return self.files[sheet][0][state][2]


# ---------------------------------------------------------------- PNG encoding
# Every sheet is an 8-bit palette PNG. Dream Maker re-saves a sheet of few colours as a 1-bit or 4-bit palette PNG,
# which rust-g's DMI reader (behind tg's icon_exists()) cannot read; fix re-encodes such a sheet at eight bits.
PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'
COLOUR_TYPES = {0: 'greyscale', 2: 'RGB', 3: 'palette', 4: 'greyscale and alpha', 6: 'RGBA'}


def png_header(data: bytes):
    """-> (width, height, bit depth, colour type, interlace method) from a PNG's IHDR, or None if `data` is no PNG."""
    if len(data) < 29 or data[:8] != PNG_SIGNATURE or data[12:16] != b'IHDR':
        return None
    width, height, depth, colour, _, _, interlace = struct.unpack('>IIBBBBB', data[16:29])
    return width, height, depth, colour, interlace


def describe_header(header):
    """'324x324, 4-bit palette' for a png_header()."""
    width, height, depth, colour, interlace = header
    kind = COLOUR_TYPES.get(colour, 'colour type %d' % colour)
    return '%dx%d, %d-bit %s%s' % (width, height, depth, kind, ', interlaced' if interlace else '')


def encoding_problem(header):
    """Why a sheet with this IHDR (png_header()) is not the 8-bit palette PNG every sheet is, or None."""
    if header is None:
        return 'not a PNG'
    if header[2:4] == (8, 3):
        return None
    if header[3] == 3:
        return 'a %s PNG, which rust-g cannot read: run fix' % describe_header(header)
    return 'a %s PNG, not an 8-bit palette PNG; fix re-encodes palette PNGs only' % describe_header(header)


def png_chunks(data: bytes):
    """-> [(type, body)] of a PNG's chunks in order, IHDR first and IEND last; ValueError if it is damaged."""
    if data[:8] != PNG_SIGNATURE:
        raise ValueError('not a PNG')
    chunks, pos = [], 8
    while not chunks or chunks[-1][0] != b'IEND':
        if pos + 12 > len(data):
            raise ValueError('cut short')
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if data[pos + 8 + length:pos + 12 + length] != struct.pack('>I', zlib.crc32(kind + body)):
            raise ValueError('a damaged %s chunk' % kind.decode('latin-1'))
        chunks.append((kind, body))
        pos += 12 + length
    if chunks[0][0] != b'IHDR' or pos != len(data):
        raise ValueError('no IHDR first, or bytes after IEND')
    return chunks


def unfilter(line: bytearray, kind, previous):
    """Undoes a scanline's PNG filter `kind` in place and returns it; `previous` is the scanline above, unfiltered.
    One byte stands for a pixel here, as at every bit depth under eight."""
    if kind > 4:
        raise ValueError('filter type %d' % kind)
    for i in range(len(line) if kind else 0):
        left, up, up_left = (line[i - 1], previous[i], previous[i - 1]) if i else (0, previous[i], 0)
        if kind == 1:
            line[i] = (line[i] + left) & 0xff
        elif kind == 2:
            line[i] = (line[i] + up) & 0xff
        elif kind == 3:
            line[i] = (line[i] + (left + up) // 2) & 0xff
        else:
            p = left + up - up_left
            near_left, near_up, near_up_left = abs(p - left), abs(p - up), abs(p - up_left)
            if near_left <= near_up and near_left <= near_up_left:
                line[i] = (line[i] + left) & 0xff
            else:
                line[i] = (line[i] + (up if near_up <= near_up_left else up_left)) & 0xff
    return line


def repack_palette(data: bytes) -> bytes:
    """A palette PNG of 1, 2 or 4 bits per pixel -> the same image as an 8-bit palette PNG: IHDR at bit depth 8; the
    pixels one byte each, filter type 0 on every row, in one IDAT where the first one was; a tRNS table widened to one
    alpha per palette entry, the entries a short table leaves out opaque as before; every other chunk (PLTE, the DMI
    metadata's zTXt, any other) byte for byte and in its place. ValueError for anything else."""
    chunks = png_chunks(data)
    width, height, depth, colour, compression, filtering, interlace = struct.unpack('>IIBBBBB', chunks[0][1])
    if colour != 3 or depth not in (1, 2, 4) or (compression, filtering, interlace) != (0, 0, 0):
        raise ValueError('a %s PNG; fix re-encodes palette PNGs of bit depth 1, 2 or 4, not interlaced' % describe_header(
            (width, height, depth, colour, interlace)))
    palettes = [body for kind, body in chunks if kind == b'PLTE']
    alphas = [body for kind, body in chunks if kind == b'tRNS']
    entries = len(palettes[0]) // 3 if len(palettes) == 1 and len(palettes[0]) % 3 == 0 else 0
    if not entries or len(alphas) > 1 or alphas and len(alphas[0]) > entries:
        raise ValueError('its PLTE or tRNS chunk is not valid')
    stride = (width * depth + 7) // 8
    raw = zlib.decompress(b''.join(body for kind, body in chunks if kind == b'IDAT'))
    if len(raw) != height * (stride + 1):
        raise ValueError('%d bytes of image data, where %d are wanted' % (len(raw), height * (stride + 1)))
    mask, shifts = (1 << depth) - 1, range(8 - depth, -1, -depth)
    spread = [bytes((byte >> shift) & mask for shift in shifts) for byte in range(256)]
    rows, previous = [], bytearray(stride)
    for y in range(height):
        start = y * (stride + 1) + 1
        previous = unfilter(bytearray(raw[start:start + stride]), raw[start - 1], previous)
        indices = b''.join(spread[byte] for byte in previous)[:width]
        if max(indices) >= entries:
            raise ValueError('a pixel past the palette, in row %d' % y)
        rows.append(b'\0' + indices)
    pixels = zlib.compress(b''.join(rows), 9)
    out = [PNG_SIGNATURE]
    for kind, body in chunks:
        if kind == b'IHDR':
            body = struct.pack('>IIBBBBB', width, height, 8, 3, 0, 0, 0)
        elif kind == b'tRNS':
            body += b'\xff' * (entries - len(body))
        elif kind == b'IDAT':
            if pixels is None:
                continue
            body, pixels = pixels, None
        out.append(struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body)))
    return b''.join(out)


# ---------------------------------------------------------------- DM data
def dm_blocks(path: Path, root: str):
    """Type blocks at or under `root`: {type: {var: value text}} from one level of tab-indented assignments."""
    blocks, current = {}, None
    for line in path.read_text(encoding='utf-8').split('\n'):
        if line.startswith('/') and not line.startswith('//'):
            head = line.strip()
            current = head if (head == root or head.startswith(root + '/')) and '(' not in head else None
            if current is not None:
                blocks.setdefault(current, {})
        elif current is not None and line.startswith('\t') and not line.startswith('\t\t'):
            m = re.match(r'^\t(?:var/)?(\w+) = (.+?)\s*(//.*)?$', line)
            if m:
                blocks[current][m[1]] = m[2]
        elif line.strip() and not line.startswith('\t'):
            current = None
    return blocks


def literal(text):
    text = text.strip()
    if text in ('TRUE', 'FALSE'):
        return text == 'TRUE'
    if text == 'null':
        return None
    if re.fullmatch(r'-?\d+', text):
        return int(text)
    if len(text) > 1 and text[0] == text[-1] and text[0] in '"\'':
        return text[1:-1]
    return text


class Types:
    """Types under one root, each inheriting from the path above it (no parent_type here)."""

    def __init__(self, blocks, defaults, evaluate):
        self.blocks, self.defaults, self.evaluate = blocks, defaults, evaluate

    @staticmethod
    def parent(path):
        return path.rsplit('/', 1)[0] if path.count('/') > 1 else None

    def get(self, path, var):
        p = path
        while p:
            if p in self.blocks and var in self.blocks[p]:
                return self.evaluate(self.blocks[p][var], p, var, self)
            p = self.parent(p)
        return self.defaults.get(var)


class Data:
    """What the rules read: the families, the penis shapes, the sheets' windows, and each garment's family."""

    def __init__(self):
        text = TEMPLATES_DM.read_text(encoding='utf-8')
        defines = {m[1]: m[2].strip() for m in re.finditer(r'^#define (\w+) (.+)$', text, re.M)}
        self.windows = {}
        for name, value in defines.items():
            m = re.fullmatch(r"'modular_aphelion/modules/bulge/icons/templates/(\w+)\.dmi'", value)
            if m and name.startswith('BULGE_SHEET_'):
                stem = name[len('BULGE_SHEET_'):]
                self.windows[m[1]] = (int(defines['BULGE_%s_X' % stem]), int(defines['BULGE_%s_Y' % stem]))
        greys = {int(defines[n].strip('"#')[:2], 16) for n in defines if n.startswith('BULGE_GREY_')}
        assert greys == set(GREYS), ('templates.dm greys differ from the tool', greys)
        family_blocks = dm_blocks(FAMILIES_DM, FAMILY_ROOT)
        declared = family_blocks.pop(FAMILY_ROOT)
        self.families = Types(family_blocks, {k: self.family_value(v, FAMILY_ROOT, k, None) for k, v in declared.items()}, self.family_value)
        self.family_types = sorted(family_blocks)
        penis_blocks = dm_blocks(GENITALS_DM, PENIS_ROOT)
        for t, values in dm_blocks(TEMPLATES_DM, PENIS_ROOT).items():
            penis_blocks.setdefault(t, {}).update(values)
        genital = dm_blocks(GENITALS_DM, '/datum/sprite_accessory/genital').get('/datum/sprite_accessory/genital', {})
        defaults = {'max_sprite_size_affix': None, 'skintone_max_sprite_size_affix': None, 'has_skintone_shading': False}
        defaults.update({k: literal(v) for k, v in genital.items() if k in defaults})
        defaults.update({k: literal(v) for k, v in penis_blocks.pop(PENIS_ROOT).items()})
        self.penis = Types(penis_blocks, defaults, self.penis_value)
        self.penis_types = sorted(t for t in penis_blocks if self.penis.get(t, 'icon_state') not in (None, 'none'))
        garment_blocks = dm_blocks(GARMENTS_DM, '/obj/item/clothing')
        garment_blocks.update(dm_blocks(GARMENTS_DM, '/datum/sprite_accessory/clothing'))
        self.garments = Types(garment_blocks, {'bulge_family': FAMILY_ROOT + '/none'}, lambda v, p, var, t: v.strip())

    @staticmethod
    def family_value(text, path, var, types):
        text = text.strip()
        if var in ('own_shape_sizes', 'own_clearance_sizes', 'own_flap_sizes'):
            if text in ('ALL', 'NONE'):
                return 0xff if text == 'ALL' else 0
            return sum(1 << (int(n) - 1) for n in re.findall(r'BULGE_SIZE_BIT\((\d)\)', text))
        if var == 'large_digi_forms':
            return (1 if 'BULGE_FORM_HALF' in text else 0) | (2 if 'BULGE_FORM_HARD' in text else 0)
        if text.startswith('BULGE_FINISH_'):
            return text[len('BULGE_FINISH_'):].lower()
        return literal(text)

    @staticmethod
    def penis_value(text, path, var, types):
        m = re.fullmatch(r'parent_type::(\w+)(?:\s*\+\s*"([^"]*)")?', text.strip())
        if m:
            return types.get(types.parent(path), m[1]) + (m[2] or '')
        return literal(text)

    def fam(self, family, var):
        return self.families.get(family, var)

    def shape_by_name(self, icon_state):
        for t in self.penis_types:
            if self.penis.get(t, 'icon_state') == icon_state:
                return t
        raise KeyError(icon_state)


# ---------------------------------------------------------------- the rules (as templates.dm)
def bit(size):
    return 1 << (size - 1)


class Rules:
    """Identity -> (sheet, state, pixel_x, pixel_y), or (None, name, 0, 0) for a template derived at run time, or None:
    the same names templates.dm computes."""

    def __init__(self, data: Data, sheets: Sheets):
        self.d, self.s = data, sheets

    def where(self, sheet, state):
        if not self.s.has(sheet, state):
            return None
        return (sheet, state) + self.d.windows[sheet]

    def window(self, sheet):
        """The sheet's window offsets (BULGE_<sheet>_X/Y in templates.dm), or None for a sheet no rule reads."""
        return self.d.windows.get(sheet)

    def shape_owner(self, family, hard, size, own='own_shape_sizes'):
        """The family whose shape (or clearance, or flap: `own` names the family's own sizes of it) is drawn."""
        if hard:
            owner = self.d.fam(family, 'hard_shapes_of')
            if owner and not (self.d.fam(family, own) & bit(size)):
                return owner
            return family
        return self.d.fam(family, 'half_shapes_of') or family

    def cap(self, family, hard):
        return self.d.fam(family, 'hard_cap' if hard else 'half_cap')

    def large_size(self, size, shape, toned):
        if size <= 6:
            return size
        cap = self.d.penis.get(shape, 'max_sprite_size_affix')
        skin = self.d.penis.get(shape, 'skintone_max_sprite_size_affix')
        if toned and skin:
            cap = skin
        return max(6, min(size, cap + 1))

    def large_name(self, owner, hard, size, digi, shape, toned):
        stem = self.d.fam(owner, 'shapes')
        if stem is None or not shape or not self.d.penis.get(shape, 'bulge_hyper'):
            return None
        size = self.large_size(size, shape, toned)
        legs = 'digi' if digi and (self.d.fam(owner, 'large_digi_forms') & (2 if hard else 1)) else 'plain'
        untoned = not toned and self.d.penis.get(shape, 'bulge_untoned')
        return '%s_%s_%d_%s_%s%s' % (stem, 'hard' if hard else 'half', size, legs, self.d.penis.get(shape, 'icon_state'), '_untoned' if untoned else '')

    def family_size(self, family, hard, size):
        """The size a family draws a bulge of `size` at: its own up to its cap, the cap past it; 0 for none."""
        if family not in self.d.families.blocks or size < 1:
            return 0
        return min(size, self.cap(family, hard) or 0)

    def shape_size(self, family, hard, size, shape=None):
        """The size whose shape a family draws for a bulge of `size` on a penis shape (bulge_shape_size()): its own up to
        its cap, except that past small_cap a shape with no shapes of its own (bulge_hyper FALSE, the tentacles), and one
        past its print_cap (Nondescript (Alt), Tapered (Alt) and Hemi (Alt)), draw small_cap's shape; 0 for none."""
        size = self.family_size(family, hard, size)
        small_cap = self.d.fam(family, 'small_cap')
        if size > small_cap and shape and (not self.d.penis.get(shape, 'bulge_hyper') or size > self.d.penis.get(shape, 'print_cap')):
            return small_cap
        return size

    def shape_where(self, family, hard, size, digi, shape=None, toned=True):
        size = self.shape_size(family, hard, size, shape)
        if not size or (hard and self.d.fam(family, 'loincloth')):
            return None
        if size > self.d.fam(family, 'small_cap') and self.d.fam(family, 'printed_patches') and size <= self.d.fam(family, 'print_cap'):
            return None  # A precoloured patch is drawn alone there (printed_patch_where).
        form, legs = ('hard' if hard else 'half'), ('digi' if digi else 'plain')
        if size <= self.d.fam(family, 'small_cap'):
            stem = self.d.fam(self.shape_owner(family, hard, size), 'shapes')
            if stem is None:
                return None
            sheet = 'skirt_shapes' if family.startswith(FAMILY_ROOT + '/skirt/') else 'cloth_small'
            return self.where(sheet, '%s_%s_%d_%s' % (stem, form, size, legs))
        name = self.large_name(self.d.fam(family, 'large_shapes_of') or family, hard, size, digi, shape, toned)
        return (None, name, 0, 0) if name else None  # Derived at run time (bulge_derive_large()).

    def clearance_where(self, family, hard, size):
        size = self.family_size(family, hard, size)
        if not size or not self.d.fam(family, 'clearance'):
            return None
        stem = self.d.fam(self.shape_owner(family, hard, size, 'own_clearance_sizes'), 'shapes')
        return self.where('skirt_clearance', '%s_%s_%d' % (stem, 'hard' if hard else 'half', size))

    def flap_where(self, family, size, digi):
        size = self.family_size(family, True, size)
        if not size or not self.d.fam(family, 'flaps'):
            return None
        stem = self.d.fam(self.shape_owner(family, True, size, 'own_flap_sizes'), 'shapes')
        return self.where('skirt_flaps', '%s_hard_%d_%s' % (stem, size, 'digi' if digi else 'plain'))

    def drape_where(self, family, size, sprite_size, shape, toned):
        stem = self.d.fam(family, 'drapes') if family in self.d.families.blocks else None
        if stem is None or not shape:
            return None
        untoned = not toned and self.d.penis.get(shape, 'bulge_untoned')
        flat_from = self.d.fam(family, 'flat_tip_from')
        flat = flat_from and size >= flat_from and self.d.penis.get(shape, 'bulge_hyper')
        name = '%s_%s_%d%s%s' % (stem, self.d.penis.get(shape, 'icon_state'), sprite_size, '_untoned' if untoned else '', '_flat' if flat else '')
        return (None, name, 0, 0)  # Derived at run time (bulge_derive_drape()).

    def printed_patch_where(self, family, hard, size, digi, shape=None, toned=True):
        """A printed family's patch (bulge_printed_patch()): the one drawn for the penis shape's profile where the sheet
        has one, named with the shape's icon state appended (and "_untoned" after it first, for a shape drawn without
        skin tones whose untoned sprites draw differently), else the human penis's; none for a shape that draws
        small_cap's shape there (shape_size(): the tentacles, a shape past its print_cap)."""
        stem = self.d.fam(family, 'printed_patches') if family in self.d.families.blocks else None
        if not stem or self.shape_size(family, hard, size, shape) <= self.d.fam(family, 'small_cap') or size > self.d.fam(family, 'print_cap'):
            return None
        name = '%s_%s_%d_%s' % (stem, 'hard' if hard else 'half', size, 'digi' if digi else 'plain')
        own = None
        if shape:
            if not toned and self.d.penis.get(shape, 'bulge_untoned'):
                own = self.where('printed_patches', '%s_%s_untoned' % (name, self.d.penis.get(shape, 'icon_state')))
            own = own or self.where('printed_patches', '%s_%s' % (name, self.d.penis.get(shape, 'icon_state')))
        return own or self.where('printed_patches', name)


def skirt_clearance_name(shape_name):
    """The clearance state a skirt shape's identity reads (bulge_clearance() in templates.dm): named as the shape without
    its legs, as a clearance is the same on plain and digitigrade legs."""
    return shape_name.rsplit('_', 1)[0]


# ---------------------------------------------------------------- placing onto the 32x32 tile (top left origin)
def placed(sheets: Sheets, where):
    """The state's four directions on the tile, S N E W, as 4096 RGBA bytes each."""
    sheet, state, px, py = where
    w, h = sheets.frame_size(sheet)
    top = 32 - py - h
    out = []
    for tile in sheets.tiles(sheet, state):
        b = bytearray(4096)
        for y in range(h):
            for x in range(w):
                o = (y * w + x) * 4
                if tile[o + 3]:
                    p = ((top + y) * 32 + px + x) * 4
                    b[p:p + 4] = tile[o:o + 4]
        out.append(bytes(b))
    return out


def decode(sheets: Sheets, where, direction):
    """Kind per pixel (0 where none) facing one way (0 S, 1 N, 2 E, 3 W), from a kind map's greys."""
    tile = placed(sheets, where)[direction]
    return bytes(GREYS[tile[p * 4]] if tile[p * 4 + 3] else 0 for p in range(1024))


# ---------------------------------------------------------------- the identities the families declare
def bulge_size(length):
    """The bulge size of a penis `length` inches long, as bulge_size() in bulge.dm gives it."""
    for limit, size in ((65, 8), (57, 7), (49, 6), (37, 5), (11, 4), (8, 3), (5, 2)):
        if length >= limit:
            return size
    return 1


def sprite_affix(length, cap):
    """The penis sprite size the game draws for `length` inches (penis.dm get_sprite_size_string()), capped."""
    for limit, affix in ((6, 1), (11, 2), (36, 3), (48, 4), (56, 5), (64, 6)):
        if length <= limit:
            return min(affix, cap)
    return min(7, cap)


def toned_options(data, shape):
    return (True, False) if data.penis.get(shape, 'has_skintone_shading') else (False,)


def draws(data, family):
    """Whether a family draws anything: shapes of its own or another's, or drapes. The others are abstract parents."""
    return any(data.fam(family, var) for var in ('shapes', 'half_shapes_of', 'hard_shapes_of', 'large_shapes_of', 'drapes'))


def declared(rules: Rules):
    """(kind, identity, where) for every identity the families declare, as the bulge_template_identities unit test
    resolves them. A shape past small_cap, a drape and a cut are derived at run time: `where` (None, name, 0, 0), and
    whether a shape leaves anatomy bare is the derivation's to say (none where it covers the whole penis)."""
    d = rules.d
    for family in d.family_types:
        if not draws(d, family):
            continue
        for hard in (False, True):
            for size in range(1, (rules.cap(family, hard) or 0) + 1):
                if d.fam(family, 'clearance'):
                    yield 'clearance', (family, hard, size), rules.clearance_where(family, hard, size)
                for digi in (False, True):
                    if not (hard and d.fam(family, 'loincloth')):
                        if size <= d.fam(family, 'small_cap'):
                            yield 'shape', (family, hard, size, digi), rules.shape_where(family, hard, size, digi)
                        elif d.fam(family, 'printed_patches') and size <= d.fam(family, 'print_cap'):
                            where = rules.printed_patch_where(family, hard, size, digi)
                            yield 'patch', (family, hard, size, digi), where
                            for shape in d.penis_types:
                                if rules.shape_size(family, hard, size, shape) <= d.fam(family, 'small_cap'):
                                    continue  # small_cap's shape and its print, no patch: the tentacles, a shape past its print_cap
                                known = where
                                for toned in ((True, False) if d.penis.get(shape, 'bulge_untoned') else (True,)):
                                    own = rules.printed_patch_where(family, hard, size, digi, shape, toned)
                                    if own != known:  # The penis shape's own patch (untoned: its own untoned one).
                                        yield 'patch', (family, hard, size, digi, shape, toned), own
                                    known = own
                        else:
                            for shape in d.penis_types:
                                # Not the tentacles, nor a shape past its print_cap: small_cap's shape, no anatomy.
                                if rules.shape_size(family, hard, size, shape) > d.fam(family, 'small_cap'):
                                    for toned in toned_options(d, shape):
                                        ident = (family, hard, size, digi, shape, toned)
                                        yield 'shape', ident, rules.shape_where(*ident)
                    if hard and d.fam(family, 'flaps'):
                        yield 'flap', (family, size, digi), rules.flap_where(family, size, digi)
        if d.fam(family, 'drapes'):
            for shape in d.penis_types:
                for toned in toned_options(d, shape):
                    cap = d.penis.get(shape, 'max_sprite_size_affix')
                    skin = d.penis.get(shape, 'skintone_max_sprite_size_affix')
                    cap = skin if toned and skin else cap
                    for ident in sorted({(family, bulge_size(n), sprite_affix(n, cap), shape, toned) for n in range(1, 101)}):
                        drape = rules.drape_where(*ident)
                        yield 'drape', ident, drape
                        yield 'cut', ident, (None, None, 0, 0) if drape else None


# ---------------------------------------------------------------- commands
def sheet_kind(sheet):
    if sheet in KIND_SHEETS:
        return 'kinds'
    if sheet in MASK_SHEETS:
        return 'mask'
    if sheet in PATCH_SHEETS:
        return 'patch'
    return None


def verify(args):
    sheets, data = Sheets(), Data()
    rules = Rules(data, sheets)
    problems = []
    totals = {'sheets': 0, 'states': 0, 'bytes': 0, 'decoded_bytes': 0}
    per_sheet = {}
    kind_names = {}
    for sheet, (states, (w, h)) in sheets.files.items():
        per_sheet[sheet] = len(states)
        path = sheets.folder / (sheet + '.dmi')
        totals['sheets'] += 1
        # Every sheet is an 8-bit palette PNG: rust-g cannot read the 1-bit and 4-bit ones Dream Maker saves; fix.
        problem = encoding_problem(png_header(path.read_bytes()))
        if problem:
            problems.append('%s: %s' % (sheet, problem))
        totals['states'] += len(states)
        totals['bytes'] += path.stat().st_size
        with Image.open(path) as image:
            totals['decoded_bytes'] += image.size[0] * image.size[1] * 4
        kind = sheet_kind(sheet)
        window = rules.window(sheet) if kind else None
        if kind is None or window is None:
            problems.append('%s: a sheet no rule reads (no window in templates.dm; past small_cap nothing is read from a sheet)' % sheet)
            continue
        if window[0] < 0 or window[1] < 0 or window[0] + w > 32 or window[1] + h > 32:
            problems.append('%s: its %dx%d window at %s leaves the 32x32 tile' % (sheet, w, h, window))
        pattern = NAME_PATTERNS[sheet]
        for name, (dirs, frames, tiles) in states.items():
            if (dirs, frames) != (4, 1):
                problems.append('%s %s: %d directions and %d frames, where four and one are wanted' % (sheet, name, dirs, frames))
                continue
            if not re.fullmatch(pattern, name):
                problems.append('%s %s: the name does not follow the convention' % (sheet, name))
            if kind == 'kinds':
                if name in kind_names:
                    problems.append('%s %s: also a kind map in %s; kind map names must be unique' % (sheet, name, kind_names[name]))
                kind_names[name] = sheet
            bad = None
            for d, tile in enumerate(tiles):
                for p in range(0, len(tile), 4):
                    if not tile[p + 3]:
                        continue
                    if d == 1 and kind != 'patch':
                        bad = 'draws facing north'
                    elif kind == 'kinds' and (tile[p + 3] != 255 or not tile[p] == tile[p + 1] == tile[p + 2] or tile[p] not in GREYS):
                        bad = 'has a pixel in no kind\'s grey (#%02x%02x%02x%02x)' % tuple(tile[p:p + 4])
                    elif kind == 'mask' and tile[p:p + 4] != b'\xff\xff\xff\xff':
                        bad = 'has a mask pixel that is not opaque white'
                    if bad:
                        break
                if bad:
                    break
            if bad:
                problems.append('%s %s: %s' % (sheet, name, bad))
    reached, counts, derived = set(), {}, {}
    for kind, ident, where in declared(rules):
        if where is None:
            counts[kind] = counts.get(kind, 0) + 1
            problems.append('the %s of %s does not resolve' % (kind, ident))
        elif where[0] is None:
            counts[kind + ' (derived)'] = counts.get(kind + ' (derived)', 0) + 1
            if where[1] is not None:
                derived.setdefault(kind, set()).add(where[1])
                if not re.fullmatch(DERIVED_PATTERNS[kind], where[1]):
                    problems.append('%s %s: the derived name does not follow the convention' % (kind, where[1]))
        else:
            counts[kind] = counts.get(kind, 0) + 1
            reached.add(where[:2])
    for sheet, (states, _) in sheets.files.items():
        for name in states:
            if (sheet, name) not in reached:
                problems.append('%s %s: no identity reaches it' % (sheet, name))
    for garment in data.garments.blocks:
        family = data.garments.get(garment, 'bulge_family')
        if family == FAMILY_ROOT + '/none':
            continue
        if family not in data.families.blocks:
            problems.append('%s names %s, which families.dm does not declare' % (garment, family))
        elif not draws(data, family):
            problems.append('%s names %s, an abstract family that draws nothing' % (garment, family))
    for p in problems[:200]:
        print('PROBLEM', p)
    print({**totals, 'states_per_sheet': per_sheet, 'identities': counts, 'states_reached': len(reached),
           'derived_templates': {k: len(v) for k, v in sorted(derived.items())}, 'problems': len(problems)})
    return 1 if problems else 0


def decoded(data: bytes):
    """-> (size, DMI metadata text, RGBA bytes) of a PNG's bytes as Pillow decodes it, for fix's proof."""
    with Image.open(io.BytesIO(data)) as image:
        return image.size, image.info.get('Description'), image.convert('RGBA').tobytes()


def fix(args):
    """Re-encodes every sheet named (all by default) that is a palette PNG under eight bits as an 8-bit palette PNG
    (repack_palette()), and writes it only once Pillow decodes both files to the same size, the same RGBA pixels and
    the same DMI metadata, and every chunk but IHDR, tRNS and IDAT is the same bytes; prints both IHDRs and the proof.
    An 8-bit palette sheet is left as it is."""
    names = [name.removesuffix('.dmi') for name in args.query] or [path.stem for path in sorted(SHEETS.glob('*.dmi'))]
    failed = 0
    for name in names:
        path = SHEETS / (name + '.dmi')
        data = path.read_bytes() if path.is_file() else b''
        header = png_header(data)
        if not encoding_problem(header):
            print('%s: %s; left as it is' % (name, describe_header(header)))
            continue
        try:
            fixed = repack_palette(data)
        except ValueError as error:
            print('PROBLEM %s: %s' % (name, error if data else 'no sheet at %s' % path))
            failed += 1
            continue
        before, after = decoded(data), decoded(fixed)
        others = [[chunk for chunk in png_chunks(png) if chunk[0] not in (b'IHDR', b'tRNS', b'IDAT')] for png in (data, fixed)]
        alphas = [[len(body) for kind, body in png_chunks(png) if kind == b'tRNS'] or ['none'] for png in (data, fixed)]
        proof = {'size': before[0] == after[0], 'RGBA': before[2] == after[2],
                 'Description': before[1] is not None and before[1] == after[1],
                 'every chunk but IHDR, tRNS and IDAT': others[0] == others[1]}
        print('%s: IHDR %s -> %s; %d -> %d bytes; tRNS entries %s -> %s' % (
            name, describe_header(header), describe_header(png_header(fixed)), len(data), len(fixed), alphas[0][0], alphas[1][0]))
        print('  proof, as Pillow decodes both: %s; RGBA %d bytes, MD5 %s; Description %d characters' % (
            ', '.join('%s %s' % (k, 'equal' if v else 'DIFFERS') for k, v in proof.items()), len(after[2]),
            hashlib.md5(after[2]).hexdigest(), len(after[1] or '')))
        if not all(proof.values()) or encoding_problem(png_header(fixed)):
            print('PROBLEM %s: not written, as the re-encoded sheet differs' % name)
            failed += 1
            continue
        temporary = path.with_name(path.name + '.tmp')
        temporary.write_bytes(fixed)
        os.replace(temporary, path)
        written = path.read_bytes() == fixed
        print('  written' if written else '  PROBLEM: the file on disk is not the one proved')
        failed += not written
    return 1 if failed else 0


def derived_names(rules: Rules):
    """{name: kind} of every template the server derives at run time under a name this tool can give (shapes past
    small_cap, drapes), and {cut stem: family} of the loincloths' cuts, "[stem][row]"."""
    names, cuts = {}, {}
    for kind, ident, where in declared(rules):
        if where and where[0] is None:
            if where[1] is not None:
                names.setdefault(where[1], kind)
            elif kind == 'cut':
                cuts.setdefault('%s_cut_' % rules.d.fam(ident[0], 'drapes'), ident[0])
    return names, cuts


def find(args):
    sheets, data = Sheets(), Data()
    rules = Rules(data, sheets)
    q = args.query.casefold()
    for sheet, (states, _) in sheets.files.items():
        for name in states:
            if q in name.casefold() or q in sheet.casefold():
                print('state   %s %s' % (sheet, name))
    names, cuts = derived_names(rules)
    for name, kind in sorted(names.items()):
        if q in name.casefold():
            print('derived %s %s: %s, %s (templates.dm)' % (kind, name, DERIVED_KINDS[kind], DERIVED))
    for stem, family in sorted(cuts.items()):
        if q in stem.casefold() or q.startswith(stem):
            print('derived cut %s<row> of %s: %s, %s (templates.dm), the row following from its drape' % (stem, family, DERIVED_KINDS['cut'], DERIVED))
    for family in data.family_types:
        if q in family.casefold() or q in str(data.fam(family, 'shapes')).casefold():
            print('family  %s shapes=%s' % (family, data.fam(family, 'shapes')))
    for garment in data.garments.blocks:
        family = data.garments.get(garment, 'bulge_family')
        if q in garment.casefold() or q in family.casefold():
            print('garment %s %s' % (garment, family))


# The approved print rule (preview_v5.print_interior and print_at, bulge_v4.over): what the server derives.
OVER = {2: (255, 70), 3: (255, 110), 4: (0, 55), 5: (0, 105)}


def _runs(values):
    runs = []
    for v in sorted(values):
        if runs and v == runs[-1][1] + 1:
            runs[-1] = (runs[-1][0], v)
        else:
            runs.append((v, v))
    return runs


def _mirror(q, run):
    lo, hi = run
    if lo == hi:
        return lo
    period = 2 * (hi - lo)
    m = (q - lo) % period
    return lo + (m if m <= hi - lo else period - m)


def _nearest(runs, q):
    return min(runs, key=lambda r: 0 if r[0] <= q <= r[1] else min(abs(q - r[0]), abs(q - r[1])))


def _two_prints(a, b):
    def hue_chroma(p):
        h, _l, _s = colorsys.rgb_to_hls(*(c / 255 for c in p[:3]))
        return h * 360, max(p[:3]) - min(p[:3])
    (ha, ca), (hb, cb) = hue_chroma(a), hue_chroma(b)
    if (ca >= 30) != (cb >= 30):
        return True
    return ca >= 30 and min(abs(ha - hb), 360 - abs(ha - hb)) >= 25


def print_patch(garment, kinds, facing):
    """The printed patch: garment, 4096 RGBA bytes facing `facing` ('S', 'E' or 'W'); kinds, 1024 bytes."""
    px = lambda x, y: tuple(garment[(y * 32 + x) * 4:(y * 32 + x) * 4 + 4])
    interior = set()
    for y in range(32):
        for lo, hi in _runs(x for x in range(32) if px(x, y)[3]):
            interior.update((x, y) for x in (range(lo, hi + 1) if hi - lo < 2 else range(lo + 1, hi)))
    out = bytearray(4096)
    for p in range(1024):
        k = kinds[p]
        if not k or not interior:
            continue
        x, y = p % 32, p // 32
        if (x, y) not in interior and not any(yy == y for _, yy in interior):
            column = [yy for xx, yy in interior if xx == x]
            lo, hi = _nearest(_runs(column or {yy for _, yy in interior}), y)
            y = _mirror(y, (lo, hi)) if hi - lo >= 3 else min(max(y, lo), hi)
        if (x, y) in interior:
            base = px(x, y)[:3]
        else:
            runs = _runs(xx for xx, yy in interior if yy == y)
            if facing == 'E':
                runs = [r for r in runs if r[1] < x] or runs
            elif facing == 'W':
                runs = [r for r in runs if r[0] > x] or runs
            run = _nearest(runs, x)
            if facing in 'EW' and run[1] - run[0] == 1 and not _two_prints(px(run[0], y), px(run[1], y)):
                base = px(run[0] if facing == 'E' else run[1], y)[:3]
            else:
                base = px(_mirror(x, run), y)[:3]
        if k == 1:
            rgb = tuple(base)
        else:
            target, alpha = OVER[k]
            rgb = tuple(round(c + (target - c) * alpha / 255) for c in base)
        out[p * 4:p * 4 + 4] = bytes(rgb) + b'\xff'
    return bytes(out)


def preview(args):
    sheets, data = Sheets(), Data()
    rules = Rules(data, sheets)
    # A shape, its clearance and its flap share a name; "sheet:state" picks one, else the kind map comes first.
    wanted_sheet, _, wanted = args.query.rpartition(':')
    matches = [(s, n) for s, (states, _) in sheets.files.items() for n in states if n == wanted and wanted_sheet in ('', s)]
    if not matches:
        names, cuts = derived_names(rules)
        kind = names.get(wanted) or ('cut' if any(re.fullmatch(re.escape(stem) + r'[0-9]+', wanted) for stem in cuts) else None)
        if kind:
            sys.exit('%s is %s, %s (templates.dm): it has no sheet state to preview.' % (wanted, DERIVED_KINDS[kind], DERIVED))
    assert matches, 'No state is named %s; use find.' % args.query
    sheet, state = min(matches, key=lambda m: sheet_kind(m[0]) != 'kinds')
    where = (sheet, state) + rules.window(sheet)
    tiles = placed(sheets, where)
    args.output.mkdir(parents=True, exist_ok=True)
    garment = None
    if args.garment:
        file, garment_state = args.garment.rsplit(':', 1)
        worn = read_dmi(ROOT / file)[0]
        assert garment_state in worn, 'No state %s in %s; a GAGS garment has no worn file to read.' % (garment_state, file)
        garment = worn[garment_state][2]
    # A revealing skirt's hard shape names its flap and its clearance (skirt_clearance_name()).
    flap = placed(sheets, rules.where('skirt_flaps', state)) if sheet == 'skirt_shapes' and sheets.has('skirt_flaps', state) else None
    clearance_state = skirt_clearance_name(state)
    clearance = placed(sheets, rules.where('skirt_clearance', clearance_state)) if flap and sheets.has('skirt_clearance', clearance_state) else None
    for d, name in enumerate(DIRS):
        scale = lambda image: image.resize((256, 256), Image.NEAREST)
        scale(Image.frombytes('RGBA', (32, 32), tiles[d])).save(args.output / ('%s.%s_%s.png' % (sheet, state, name)))
        if sheet_kind(sheet) != 'kinds':
            continue
        kinds = decode(sheets, where, d)
        shown = bytearray(4096)
        for p in range(1024):
            if kinds[p]:
                shown[p * 4:p * 4 + 4] = bytes(SHOW[kinds[p]])
        scale(Image.frombytes('RGBA', (32, 32), bytes(shown))).save(args.output / ('%s.%s_%s_kinds.png' % (sheet, state, name)))
        if garment and name != 'north':
            base = Image.frombytes('RGBA', (32, 32), garment[d])
            base.alpha_composite(Image.frombytes('RGBA', (32, 32), print_patch(garment[d], kinds, name[0].upper())))
            scale(base).save(args.output / ('%s.%s_%s_printed.png' % (sheet, state, name)))
        if garment and flap and name != 'north':
            # As the game draws a hard revealing skirt: the garment with its flap cut away, its patch over the cut.
            cut = bytearray(garment[d])
            for p in range(1024):
                if flap[d][p * 4 + 3]:
                    cut[p * 4:p * 4 + 4] = b'\0\0\0\0'
            base = Image.frombytes('RGBA', (32, 32), bytes(cut))
            base.alpha_composite(Image.frombytes('RGBA', (32, 32), print_patch(garment[d], kinds, name[0].upper())))
            scale(base).save(args.output / ('%s.%s_%s_cut.png' % (sheet, state, name)))
            if clearance:
                # Where the shaft shows over the cloth, in translucent magenta.
                mark = bytearray(4096)
                for p in range(1024):
                    if clearance[d][p * 4 + 3]:
                        mark[p * 4:p * 4 + 4] = b'\xff\x00\xff\x96'
                base.alpha_composite(Image.frombytes('RGBA', (32, 32), bytes(mark)))
                scale(base).save(args.output / ('%s.%s_%s_clearance.png' % (sheet, state, name)))
    print('Wrote %s to %s. Kind colours: %s.' % (state, args.output, ', '.join('%s %s' % (KINDS[k], c[:3]) for k, c in SHOW.items())))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('command', choices=('verify', 'fix', 'find', 'preview'))
    parser.add_argument('query', nargs='*', help='find: the text; preview: the state; fix: the sheets, all by default')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--garment', help='FILE:STATE of a worn sprite (32x32, four directions), FILE from the repository root')
    args = parser.parse_args()
    if args.command == 'verify':
        sys.exit(verify(args))
    if args.command == 'fix':
        sys.exit(fix(args))
    assert len(args.query) == 1, 'Supply one state name or search text.'
    args.query = args.query[0]
    if args.command == 'find':
        find(args)
        return
    assert args.output, 'preview needs --output DIR'
    preview(args)


if __name__ == '__main__':
    main()
