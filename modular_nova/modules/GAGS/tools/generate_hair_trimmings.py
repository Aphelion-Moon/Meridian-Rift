"""Regenerates modular_nova/modules/GAGS/icons/hair_trimmings.dmi.

The hair trimmings are procedurally drawn rather than hand-placed, so this
script is the source of truth for them - edit the style functions here and
re-run, don't paint over the .dmi.

    python generate_hair_trimmings.py                 # rewrite the .dmi in place
    python generate_hair_trimmings.py --preview p.png # also render a colour sheet

The preview replicates what SSgreyscale does with these configs (multiply the
mask by the colour, then overlay), so it shows what the decal will actually
look like in game without needing to boot the server.

Requires Pillow.
"""
import argparse, math, os, random, re
from PIL import Image, ImageDraw, ImageFont
from PIL.PngImagePlugin import PngInfo

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_DMI = os.path.join(HERE, os.pardir, 'icons', 'hair_trimmings.dmi')

# -- dmi io ---------------------------------------------------------------

def parse_desc(desc):
    """Return (width, height, [state dicts]) from a DMI Description block."""
    w = h = 32
    states = []
    cur = None
    for raw in desc.splitlines():
        line = raw.strip()
        if line.startswith('width'):
            if cur is None:
                w = int(line.split('=')[1])
        elif line.startswith('height'):
            if cur is None:
                h = int(line.split('=')[1])
        elif line.startswith('state ='):
            cur = {'name': re.match(r'state = "(.*)"', line).group(1), 'dirs': 1, 'frames': 1, 'meta': []}
            states.append(cur)
        elif cur is not None and '=' in line:
            k, v = [x.strip() for x in line.split('=', 1)]
            if k in ('dirs', 'frames'):
                cur[k] = int(v)
            else:
                cur['meta'].append((k, v))
    return w, h, states


def read_dmi(path):
    """-> (sheet Image RGBA, width, height, states)"""
    im = Image.open(path).convert('RGBA')
    desc = Image.open(path).info.get('Description', '')
    w, h, states = parse_desc(desc)
    return im, w, h, states


def cells(sheet, w, h):
    """Yield every icon cell in sheet order."""
    cols = sheet.width // w
    i = 0
    while True:
        x, y = (i % cols) * w, (i // cols) * h
        if y + h > sheet.height:
            return
        yield sheet.crop((x, y, x + w, y + h))
        i += 1


def write_dmi(path, frames, w=32, h=32):
    """frames: list of (name, Image). Single dir, single frame each."""
    n = len(frames)
    cols = max(1, math.ceil(math.sqrt(n)))
    rows = math.ceil(n / cols)
    sheet = Image.new('RGBA', (cols * w, rows * h), (0, 0, 0, 0))
    lines = ['# BEGIN DMI', 'version = 4.0', '\twidth = %d' % w, '\theight = %d' % h]
    for i, (name, img) in enumerate(frames):
        sheet.paste(img, ((i % cols) * w, (i // cols) * h))
        lines += ['state = "%s"' % name, '\tdirs = 1', '\tframes = 1']
    lines.append('# END DMI')
    info = PngInfo()
    info.add_text('Description', '\n'.join(lines) + '\n', zip=True)
    sheet.save(path, 'PNG', pnginfo=info, optimize=True)

# -- drawing --------------------------------------------------------------

SIZE = 32
MARGIN = 2


class Buf:
    """32x32 paint buffer in painter's order: later strokes occlude earlier."""

    def __init__(self):
        self.px = {}

    def put(self, x, y, val, alpha):
        x, y = int(round(x)), int(round(y))
        if not (0 <= x < SIZE and 0 <= y < SIZE):
            return
        self.px[(x, y)] = (val, alpha)

    def put_under(self, x, y, val, alpha):
        """Paint only where nothing has been drawn, so dust never eats a strand."""
        x, y = int(round(x)), int(round(y))
        if not (0 <= x < SIZE and 0 <= y < SIZE) or (x, y) in self.px:
            return
        self.px[(x, y)] = (val, alpha)

    def image(self):
        im = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
        p = im.load()
        for (x, y), (v, a) in self.px.items():
            v = max(0, min(255, int(round(v))))
            a = max(0, min(255, int(round(a))))
            p[x, y] = (v, v, v, a)
        return im


def strand_points(x0, y0, heading, length, turn, wobble, freq, phase):
    """Walk a heading that curves, sampling ~3x per pixel of arc length."""
    n = max(6, int(length * 3))
    pts, x, y, h = [], x0, y0, heading
    for i in range(n + 1):
        t = i / n
        pts.append([x, y, t])
        hh = h + wobble * math.sin(freq * t * math.tau + phase)
        x += (length / n) * math.cos(hh)
        y += (length / n) * math.sin(hh)
        h += turn / n
    return pts


def fit(groups, anchor):
    """Pull a hank back inside the tile, keeping it near its intended anchor."""
    flat = [p for g in groups for p in g]
    xs = [p[0] for p in flat]
    ys = [p[1] for p in flat]
    # Recentre on the anchor first, so a curled strand does not drift off-tile.
    dx = anchor[0] - (min(xs) + max(xs)) / 2
    dy = anchor[1] - (min(ys) + max(ys)) / 2
    lo, hi = MARGIN, SIZE - 1 - MARGIN
    dx += max(0.0, lo - (min(xs) + dx)) - max(0.0, (max(xs) + dx) - hi)
    dy += max(0.0, lo - (min(ys) + dy)) - max(0.0, (max(ys) + dy) - hi)
    for p in flat:
        p[0] += dx
        p[1] += dy
    return groups


def taper(t, head=0.16, tail=0.3, floor=0.3):
    """Coverage profile: thin at the root, thinner still at the tip."""
    if t < head:
        return floor + (1 - floor) * (t / head)
    if t > 1 - tail:
        return floor * 0.6 + (1 - floor * 0.6) * ((1 - t) / tail)
    return 1.0


def line(x0, y0, x1, y1):
    """Integer Bresenham, inclusive of both ends."""
    pts = []
    dx, dy = abs(x1 - x0), abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx - dy
    while True:
        pts.append((x0, y0))
        if x0 == x1 and y0 == y1:
            return pts
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x0 += sx
        if e2 < dx:
            err += dx
            y0 += sy


def draw_strand(body, sheen, pts, val, rng, glint=False):
    """Bresenham between samples so diagonals stay 1px with no anti-aliasing."""
    prev = None
    trail = []
    for (x, y, t) in pts:
        cx, cy = int(round(x)), int(round(y))
        # Slight along-length lighting variation keeps strands from reading
        # flat without digging a dark hole in the hair colour.
        v = val * (0.95 + 0.05 * math.sin(t * 6.5))
        a = 255 * taper(t)
        if prev is None:
            body.put(cx, cy, v, a)
            trail.append((cx, cy, t))
        else:
            for (lx, ly) in line(prev[0], prev[1], cx, cy):
                body.put(lx, ly, v, a)
                trail.append((lx, ly, t))
        prev = (cx, cy)

    if not glint or len(trail) < 7:
        return
    # One short specular run per lit strand, kept off the very tip.
    start = rng.uniform(0.18, 0.42)
    span = rng.uniform(0.24, 0.38)
    for (lx, ly, t) in trail:
        if start <= t <= start + span:
            edge = abs(t - (start + span / 2)) / (span / 2)
            sheen.put(lx, ly, 255 - 75 * edge, 255 - 70 * edge)


def hank(body, sheen, rng, x0, y0, heading, length, count, val, glint,
         turn=0.0, wobble=0.0, freq=1.0, spacing=2.0, fan=0.04, anchor=None):
    """A clump of near-parallel strands sharing one base curve."""
    phase = rng.uniform(0, math.tau)
    perp = heading + math.pi / 2
    groups = []
    for k in range(count):
        off = (k - (count - 1) / 2) * spacing
        groups.append(strand_points(
            x0 + math.cos(perp) * off, y0 + math.sin(perp) * off,
            heading + off * fan, length * rng.uniform(0.85, 1.12),
            turn * rng.uniform(0.8, 1.2), wobble, freq,
            phase + rng.uniform(-0.5, 0.5)))
    for k, pts in enumerate(fit(groups, anchor or (x0, y0))):
        # Strands nearer the top of the clump catch a little more light. Kept
        # shallow on purpose: depth here reads as grime, not shading.
        shade = val * (0.85 + 0.15 * (k + 1) / count)
        draw_strand(body, sheen, pts, shade, rng, glint and k >= count - 2)


def flecks(body, rng, count, spread, cx=16, cy=16):
    """Loose single-pixel trimmings scattered around the pile."""
    for _ in range(count):
        a = rng.uniform(0, math.tau)
        r = spread * math.sqrt(rng.random())
        body.put(min(SIZE - 1 - MARGIN, max(MARGIN, cx + math.cos(a) * r)),
                 min(SIZE - 1 - MARGIN, max(MARGIN, cy + math.sin(a) * r)),
                 rng.uniform(190, 235), rng.uniform(150, 225))


def fuzz(body, rng, count, spread, cx=16, cy=16, elong=1.0, tilt=0.0):
    """The fine hair dust that settles between clippings on a salon floor."""
    for _ in range(count):
        a = rng.uniform(0, math.tau)
        r = math.sqrt(rng.random())
        ex, ey = spread * elong * r * math.cos(a), spread * r * math.sin(a)
        body.put_under(
            min(SIZE - 1, max(0, cx + ex * math.cos(tilt) - ey * math.sin(tilt))),
            min(SIZE - 1, max(0, cy + ex * math.sin(tilt) + ey * math.cos(tilt))),
            rng.uniform(165, 215), rng.uniform(34, 82))


# -- styles -----------------------------------------------------------------
# Each returns (body, sheen). `n` is the size step: 1 trim, 2 restyle, 3 chop.

def depth(i, total):
    """0 for the hank furthest back, 1 for the one on top of the pile."""
    return 1.0 if total < 2 else i / (total - 1)


def scatter(rng, spread, cx=16, cy=16):
    """A point drawn evenly from a disc around the pile's centre."""
    a = rng.uniform(0, math.tau)
    r = spread * math.sqrt(rng.random())
    return cx + math.cos(a) * r, cy + math.sin(a) * r


def style_lock(n, rng):
    """Long straight hair: heavy hanks of combed strands lying across
    each other."""
    body, sheen = Buf(), Buf()
    hanks = (1, 2, 3)[n - 1]
    length = (13, 16, 19)[n - 1]
    width = (3, 4, 4)[n - 1]
    for i in range(hanks):
        top = depth(i, hanks)
        cx, cy = scatter(rng, (0, 3.5, 5.0)[n - 1])
        hank(body, sheen, rng, cx, cy,
             rng.uniform(-0.55, 0.55) + (math.pi if rng.random() < 0.4 else 0),
             length, width, 200 + 55 * top, top > 0.4,
             turn=rng.choice([-1, 1]) * rng.uniform(0.5, 1.0),
             wobble=rng.uniform(0.05, 0.11), freq=rng.uniform(0.9, 1.4),
             spacing=rng.uniform(1.9, 2.3), fan=rng.uniform(0.02, 0.05),
             anchor=(cx, cy))
    flecks(body, rng, (3, 5, 7)[n - 1], (9, 11, 12)[n - 1])
    return body, sheen


def style_snip(n, rng):
    """A plain trim: short clippings dropped at every angle."""
    body, sheen = Buf(), Buf()
    hanks = (3, 5, 7)[n - 1]
    spread = (4.5, 6.5, 8.0)[n - 1]
    for i in range(hanks):
        top = depth(i, hanks)
        cx, cy = scatter(rng, spread)
        hank(body, sheen, rng, cx, cy, rng.uniform(0, math.tau),
             rng.uniform(4.5, 7.5) + n, rng.choice([2, 2, 3]),
             200 + 55 * top, top > 0.5,
             turn=rng.choice([-1, 1]) * rng.uniform(0.2, 0.7),
             wobble=rng.uniform(0.05, 0.12), freq=rng.uniform(0.8, 1.4),
             spacing=rng.uniform(1.9, 2.4), fan=rng.uniform(0.03, 0.09),
             anchor=(cx, cy))
    flecks(body, rng, (4, 6, 9)[n - 1], (9, 11, 12)[n - 1])
    return body, sheen


def style_curl(n, rng):
    """Curly hair: corkscrew hanks that wave back on themselves."""
    body, sheen = Buf(), Buf()
    hanks = (1, 2, 3)[n - 1]
    length = (13, 16, 18)[n - 1]
    for i in range(hanks):
        top = depth(i, hanks)
        cx, cy = scatter(rng, (0, 4.5, 6.0)[n - 1])
        # Low frequency: at 32px a tight corkscrew just resolves into noise.
        hank(body, sheen, rng, cx, cy,
             rng.uniform(-0.6, 0.6) + (math.pi if rng.random() < 0.4 else 0),
             length, (2, 2, 3)[n - 1], 200 + 55 * top, top > 0.35,
             turn=rng.choice([-1, 1]) * rng.uniform(0.15, 0.4),
             wobble=rng.uniform(0.55, 0.8), freq=rng.uniform(1.2, 1.6),
             spacing=rng.uniform(2.4, 3.0), fan=0.0,
             anchor=(cx, cy))
    flecks(body, rng, (3, 5, 7)[n - 1], (9, 11, 12)[n - 1])
    return body, sheen


def style_splay(n, rng):
    """A swept-up heap: hanks radiating from a common root, tips fanned out."""
    body, sheen = Buf(), Buf()
    hanks = (3, 4, 5)[n - 1]
    length = (8, 10, 12)[n - 1]
    base = rng.uniform(0, math.tau)
    cx, cy = 16 + rng.uniform(-1.0, 1.0), 16 + rng.uniform(-1.0, 1.0)
    for i in range(hanks):
        top = depth(i, hanks)
        a = base + math.tau * i / hanks + rng.uniform(-0.3, 0.3)
        # Roots sit on a ring, not at the centre, or the middle knots up.
        root = rng.uniform(2.5, 4.5)
        span = length * rng.uniform(0.7, 1.2)
        hank(body, sheen, rng,
             cx + math.cos(a) * root, cy + math.sin(a) * root, a,
             span, (2, 2, 3)[n - 1], 200 + 55 * top, top > 0.45,
             turn=rng.choice([-1, 1]) * rng.uniform(0.3, 0.8),
             wobble=rng.uniform(0.05, 0.12), freq=rng.uniform(0.9, 1.5),
             spacing=rng.uniform(1.9, 2.4), fan=rng.uniform(0.02, 0.07),
             anchor=(cx + math.cos(a) * (root + span * 0.45),
                     cy + math.sin(a) * (root + span * 0.45)))
    flecks(body, rng, (3, 5, 7)[n - 1], (9, 11, 12)[n - 1], cx, cy)
    return body, sheen


def style_arc(n, rng):
    """Crescents and flared tufts - how a cut lock actually lands.

    Straight from the reference photos: each clipping bows into an open C as
    it falls, or lands as a tuft that is tight at the root and fans at the
    tip. They scatter with plenty of bare floor between them.
    """
    body, sheen = Buf(), Buf()
    pieces = (2, 4, 6)[n - 1]
    spread = (5.0, 7.5, 9.5)[n - 1]
    for i in range(pieces):
        top = depth(i, pieces)
        cx, cy = scatter(rng, spread)
        val = 200 + 55 * top
        if rng.random() < 0.6:
            # A crescent. Turning through `span` over an arc `span * radius`
            # long draws a circle of that radius. Keep the span well under a
            # half turn or the ends meet and it reads as a ring, not a hair.
            radius = rng.uniform(3.6, 6.0)
            span = rng.uniform(1.3, 2.5)
            hank(body, sheen, rng, cx, cy, rng.uniform(0, math.tau),
                 radius * span, rng.choice([1, 1, 2]), val, top > 0.4,
                 turn=rng.choice([-1, 1]) * span,
                 wobble=rng.uniform(0.0, 0.05), freq=1.0,
                 spacing=1.5, fan=0.0, anchor=(cx, cy))
        else:
            # A tuft: strands pinched at the root, splaying towards the tip.
            hank(body, sheen, rng, cx, cy, rng.uniform(0, math.tau),
                 rng.uniform(5.0, 8.0) + n, (3, 4, 4)[n - 1], val, top > 0.4,
                 turn=rng.choice([-1, 1]) * rng.uniform(0.3, 0.9),
                 wobble=rng.uniform(0.04, 0.1), freq=rng.uniform(0.8, 1.3),
                 spacing=rng.uniform(0.7, 1.0), fan=rng.uniform(0.22, 0.42),
                 anchor=(cx, cy))
    fuzz(body, rng, (5, 9, 13)[n - 1], (9, 11, 13)[n - 1])
    return body, sheen


def style_tangle(n, rng):
    """The big chop: a matted heap with strands escaping the edges.

    The reference for this is a whole head of hair on the floor. What makes
    it read is long strands sweeping the full length of an elongated mass and
    crossing each other - short clumps packed together just look like bars.
    """
    body, sheen = Buf(), Buf()
    sweeps = (3, 6, 9)[n - 1]
    major = (4.5, 6.0, 7.0)[n - 1]
    minor = major * rng.uniform(0.35, 0.5)
    tilt = rng.uniform(0, math.pi)

    def in_mass(reach=1.0):
        """A point inside the tilted ellipse the mass occupies."""
        a = rng.uniform(0, math.tau)
        r = reach * math.sqrt(rng.random())
        ex, ey = major * r * math.cos(a), minor * r * math.sin(a)
        return (16 + ex * math.cos(tilt) - ey * math.sin(tilt),
                16 + ex * math.sin(tilt) + ey * math.cos(tilt), a)

    for i in range(sweeps):
        top = depth(i, sweeps)
        cx, cy, _ = in_mass()
        # Long, heavily curved, running the length of the mass. Half get
        # flipped end for end so they cross rather than comb together.
        hank(body, sheen, rng, cx, cy,
             tilt + rng.uniform(-0.55, 0.55) + (math.pi if rng.random() < 0.5 else 0),
             rng.uniform(13.0, 19.0) + n, rng.choice([2, 2, 3]),
             200 + 55 * top, top > 0.55,
             turn=rng.choice([-1, 1]) * rng.uniform(0.7, 1.6),
             wobble=rng.uniform(0.12, 0.3), freq=rng.uniform(1.1, 2.0),
             spacing=rng.uniform(1.6, 2.2), fan=rng.uniform(0.02, 0.07),
             anchor=(cx, cy))

    for _ in range((2, 3, 5)[n - 1]):
        # Wisps: single dim strands trailing off the edge of the mass.
        sx, sy, a = in_mass(reach=1.6)
        pts = strand_points(sx, sy, a + rng.uniform(-0.7, 0.7),
                            rng.uniform(8.0, 13.0) + n,
                            rng.choice([-1, 1]) * rng.uniform(0.4, 1.4),
                            rng.uniform(0.12, 0.32), rng.uniform(1.0, 2.0),
                            rng.uniform(0, math.tau))
        fit([pts], (sx, sy))
        draw_strand(body, sheen, pts, rng.uniform(185, 225), rng)

    fuzz(body, rng, (6, 11, 17)[n - 1], major * 1.6, 16, 16,
         elong=1.3, tilt=tilt)
    return body, sheen


def style_wisp(n, rng):
    """Barely anything: a few fine loose strands well clear of each other.

    The sparse end of the reference photos - a couple of hairs that missed
    the pile. Reads as a light trim without needing any mass at all.
    """
    body, sheen = Buf(), Buf()
    strands = (3, 6, 9)[n - 1]
    spread = (5.0, 7.0, 9.0)[n - 1]
    # One loose drift direction for the lot. Strands crossing at wide angles
    # read as glyphs rather than hair, so keep them roughly parallel.
    drift = rng.uniform(0, math.tau)
    for i in range(strands):
        top = depth(i, strands)
        cx, cy = scatter(rng, spread)
        pts = strand_points(cx, cy,
                            drift + rng.uniform(-0.6, 0.6)
                            + (math.pi if rng.random() < 0.45 else 0),
                            rng.uniform(5.5, 10.0) + n,
                            rng.choice([-1, 1]) * rng.uniform(0.4, 1.1),
                            rng.uniform(0.08, 0.2), rng.uniform(1.0, 1.8),
                            rng.uniform(0, math.tau))
        fit([pts], (cx, cy))
        draw_strand(body, sheen, pts, 200 + 55 * top, rng, top > 0.5)
    fuzz(body, rng, (4, 7, 10)[n - 1], (9, 11, 13)[n - 1])
    return body, sheen


def style_clump(n, rng):
    """A wad of hair balled up rather than lain flat.

    Built like a bird's nest: strands laid tangent to a ring so they wrap
    around a common centre and weave over each other. Winding them tightly
    instead just fills solid and loses every strand in the silhouette.
    """
    body, sheen = Buf(), Buf()
    # Scales by how many wads there are, not how big each one is: a bigger
    # wad just fills in and loses its weave.
    wads = (1, 2, 2)[n - 1]
    spread = (0.0, 7.0, 8.5)[n - 1]
    for i in range(wads):
        top = depth(i, wads)
        wx, wy = scatter(rng, spread)
        val = 200 + 55 * top
        for k in range(5):
            a = rng.uniform(0, math.tau)
            r = rng.uniform(1.5, 2.8)
            # Tangent to the ring, so the strand wraps the wad instead of
            # spiking out of it.
            hank(body, sheen, rng,
                 wx + math.cos(a) * r, wy + math.sin(a) * r,
                 a + math.pi / 2 + rng.uniform(-0.35, 0.35),
                 rng.uniform(6.0, 10.0), rng.choice([1, 2]),
                 val * rng.uniform(0.9, 1.0), top > 0.4 and k % 3 == 0,
                 turn=rng.choice([-1, 1]) * rng.uniform(1.4, 2.6),
                 wobble=rng.uniform(0.06, 0.18), freq=rng.uniform(1.0, 1.9),
                 spacing=1.5, fan=0.0,
                 anchor=(wx + math.cos(a) * r * 0.5,
                         wy + math.sin(a) * r * 0.5))
        for _ in range((2, 3, 5)[n - 1]):
            # Ends working loose, so it isn't a closed disc. At the biggest
            # size these carry the extra bulk, since the wads can't grow.
            a = rng.uniform(0, math.tau)
            pts = strand_points(wx, wy, a, rng.uniform(5.0, 9.0),
                                rng.choice([-1, 1]) * rng.uniform(0.3, 1.0),
                                rng.uniform(0.05, 0.15), 1.2,
                                rng.uniform(0, math.tau))
            fit([pts], (wx + math.cos(a) * 3.5, wy + math.sin(a) * 3.5))
            draw_strand(body, sheen, pts, val * 0.93, rng)
    fuzz(body, rng, (5, 9, 13)[n - 1], (8, 10, 12)[n - 1])
    return body, sheen


def style_sweep(n, rng):
    """A drift, as though someone has already run a broom through it.

    Everything points one way, piling up along a leading edge and thinning
    out behind it.
    """
    body, sheen = Buf(), Buf()
    runs = (3, 6, 9)[n - 1]
    heading = rng.uniform(0, math.tau)
    perp = heading + math.pi / 2
    reach = (6.5, 8.0, 9.5)[n - 1]
    for i in range(runs):
        top = depth(i, runs)
        # Bunched towards the leading edge, trailing off behind it.
        along = reach * (rng.random() ** 1.25) - reach * 0.4
        across = rng.uniform(-1, 1) * reach * 1.0
        cx = 16 + math.cos(heading) * along + math.cos(perp) * across
        cy = 16 + math.sin(heading) * along + math.sin(perp) * across
        hank(body, sheen, rng, cx, cy, heading + rng.uniform(-0.3, 0.3),
             rng.uniform(7.0, 12.0) + n, rng.choice([2, 3, 3]),
             200 + 55 * top, top > 0.45,
             turn=rng.choice([-1, 1]) * rng.uniform(0.2, 0.7),
             wobble=rng.uniform(0.05, 0.14), freq=rng.uniform(0.9, 1.6),
             spacing=rng.uniform(1.7, 2.2), fan=rng.uniform(0.02, 0.06),
             anchor=(cx, cy))
    fuzz(body, rng, (5, 9, 14)[n - 1], reach * 1.4, 16, 16,
         elong=1.35, tilt=heading)
    return body, sheen


# Seeds are fixed so the sheet regenerates identically. Don't renumber an
# existing style's seed unless you mean to redraw it.
STYLES = [('curl', style_curl, 42), ('arc', style_arc, 44),
          ('tangle', style_tangle, 45), ('wisp', style_wisp, 46)]

# Defined but not shipped. Move an entry into STYLES and re-run to bring one
# back, then add its name to trimming_shapes in the salon's misc_items.dm.
#   lock   read as evenly-combed lines rather than fallen hair
#   splay  read as a starburst; nothing in a real pile radiates from a point
#   snip   fine, but cut from the random pool
#   clump  weakest of the set - wads merge into a blob at the larger sizes
#   sweep  fine, but cut from the random pool
RETIRED = [('lock', style_lock, 40), ('splay', style_splay, 43),
           ('snip', style_snip, 41), ('clump', style_clump, 58),
           ('sweep', style_sweep, 48)]


def build(bump=0):
    frames = []
    for name, fn, seed in STYLES:
        for n in (1, 2, 3):
            body, sheen = fn(n, random.Random(seed * 100 + n + bump * 7919))
            frames.append(('%s_%d' % (name, n), body.image()))
            frames.append(('%s_%d_sheen' % (name, n), sheen.image()))
    return frames

# -- preview --------------------------------------------------------------

SCALE = 4
CELL = 32 * SCALE

# Sample hair colours: the default black, plus the usual suspects.
SAMPLES = [
    ('black', '#1b1b1b'),
    ('brown', '#7c4a24'),
    ('blonde', '#e0c268'),
    ('ginger', '#b5431a'),
    ('mint', '#6fd7b0'),
]

STATES = [(s, n) for s, _, _ in STYLES for n in (1, 2, 3)]


def hexcol(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def multiply(mask, colour):
    """BYOND ICON_MULTIPLY against an opaque colour."""
    out = Image.new('RGBA', mask.size)
    mp, op = mask.load(), out.load()
    r, g, b = colour
    for y in range(mask.height):
        for x in range(mask.width):
            mr, mg, mb, ma = mp[x, y]
            op[x, y] = (mr * r // 255, mg * g // 255, mb * b // 255, ma)
    return out


def lighten(colour, amount=0.65):
    """Matches BlendRGB(hair_colour, COLOR_WHITE, amount) in DM."""
    return tuple(int(round(c + (255 - c) * amount)) for c in colour)


def render(states, colour, sheen_colour):
    """-> (palette A image, palette B image) for one state."""
    body = multiply(states['body'], colour)
    matte = body
    glossy = body.copy()
    glossy.alpha_composite(multiply(states['sheen'], sheen_colour))
    return matte, glossy


def font(size):
    for path in ('C:/Windows/Fonts/segoeui.ttf', 'C:/Windows/Fonts/arial.ttf'):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()

# -- entry point --------------------------------------------------------------

def render_sheet(dmi_path, out_path):
    sheet, w, h, meta = read_dmi(dmi_path)
    by_name, i = {}, 0
    for st in meta:
        by_name[st['name']] = list(cells(sheet, w, h))[i]
        i += st['dirs'] * st['frames']

    label_w, head_h, pad = 110, 64, 6
    cols = len(SAMPLES) * 2
    img = Image.new('RGBA',
                    (label_w + cols * (CELL + pad) + pad,
                     head_h + len(STATES) * (CELL + pad) + pad), (38, 40, 44, 255))
    d = ImageDraw.Draw(img)
    f_small, f_head = font(15), font(17)

    for c, (cname, chex) in enumerate(SAMPLES):
        x = label_w + c * 2 * (CELL + pad) + pad
        d.text((x, 10), cname, font=f_head, fill=hexcol(chex) + (255,))
        d.text((x, 34), 'A matte', font=f_small, fill=(150, 152, 158, 255))
        d.text((x + CELL + pad, 34), 'B sheen', font=f_small, fill=(150, 152, 158, 255))

    for r, (style, n) in enumerate(STATES):
        y = head_h + r * (CELL + pad) + pad
        d.text((10, y + CELL // 2 - 9), '%s_%d' % (style, n), font=f_head,
               fill=(214, 216, 222, 255))
        masks = {'body': by_name['%s_%d' % (style, n)],
                 'sheen': by_name['%s_%d_sheen' % (style, n)]}
        for c, (_, chex) in enumerate(SAMPLES):
            col = hexcol(chex)
            for k, cell in enumerate(render(masks, col, lighten(col))):
                x = label_w + (c * 2 + k) * (CELL + pad) + pad
                # Floor-ish backdrop so light and dark hair both stay readable.
                d.rectangle([x, y, x + CELL - 1, y + CELL - 1], fill=(88, 90, 96, 255))
                img.alpha_composite(cell.resize((CELL, CELL), Image.NEAREST), (x, y))

    img.save(out_path)
    return img.size


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', default=DEFAULT_DMI, help='.dmi to write')
    ap.add_argument('--preview', help='also render a colour sheet to this .png')
    ap.add_argument('--bump', type=int, default=0,
                    help='reroll every shape with a different seed')
    args = ap.parse_args()

    write_dmi(args.out, build(args.bump))
    print('wrote', os.path.normpath(args.out))
    if args.preview:
        print('wrote', args.preview, render_sheet(args.out, args.preview))
