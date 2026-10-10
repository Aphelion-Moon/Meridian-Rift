// THIS IS AN APHELION UI FILE
import type { SpriteDir } from '../SpeciesRegistry/constants';

/**
 * One custom marking drawing as it is saved (see the custom_sprites module's
 * codec.dm): a palette, and each view as palette indices from the top left,
 * row by row, run-length coded.
 */
export type CustomMarkingView = {
  /** 32, or 64 for the taur's canvas, which reaches 16px past each side of the tile. */
  width: number;
  palette: string[];
  dirs: Partial<Record<SpriteDir, string | null>>;
};

/** The characters a saved view writes its palette indices in; "0" is unpainted. */
const INDEX_ALPHABET =
  '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_';

/**
 * A view's palette indices, one character a pixel, from its saved code:
 * "f" then every pixel, or "r" then runs of a hex length (1-f) and an index.
 * Undefined for a code that doesn't make `count` pixels.
 */
export function decodeView(encoded: string, count: number): string | undefined {
  if (encoded[0] === 'f') {
    return encoded.length === count + 1 ? encoded.slice(1) : undefined;
  }
  if (encoded[0] !== 'r' || encoded.length % 2 !== 1) {
    return undefined;
  }
  const runs: string[] = [];
  let length = 0;
  for (let at = 1; at < encoded.length; at += 2) {
    const run = Number.parseInt(encoded[at], 16);
    if (!run || length + run > count) {
      return undefined;
    }
    runs.push(encoded[at + 1].repeat(run));
    length += run;
  }
  return length === count ? runs.join('') : undefined;
}

/** A painted pixel of a drawing, on its own canvas. */
export type PaintedPixel = { x: number; y: number; color: string };

const painted = new Map<string, PaintedPixel[]>();

/** The pixels a drawing paints facing one way, or none. Kept for the next look. */
export function paintedPixels(
  view: CustomMarkingView,
  dir: SpriteDir,
): PaintedPixel[] {
  const encoded = view.dirs[dir];
  if (!encoded) {
    return [];
  }
  const key = `${view.width} ${view.palette.join()} ${encoded}`;
  const known = painted.get(key);
  if (known) {
    return known;
  }
  const grid = decodeView(encoded, view.width * 32);
  const pixels: PaintedPixel[] = [];
  if (grid) {
    for (let at = 0; at < grid.length; at++) {
      const index = INDEX_ALPHABET.indexOf(grid[at]);
      const color = index > 0 ? view.palette[index - 1] : undefined;
      if (color) {
        pixels.push({
          x: at % view.width,
          y: Math.floor(at / view.width),
          color,
        });
      }
    }
  }
  if (painted.size > 64) {
    painted.clear();
  }
  painted.set(key, pixels);
  return pixels;
}

/**
 * Paints a drawing's pixels at a whole-number zoom, its canvas's top left at
 * x and y. The taur's wider canvas reaches past the tile's sides, so its top
 * left is half the extra width left of the tile's.
 */
export function drawPainted(
  context: CanvasRenderingContext2D,
  pixels: PaintedPixel[],
  x: number,
  y: number,
  zoom: number,
) {
  for (const pixel of pixels) {
    context.fillStyle = pixel.color;
    context.fillRect(x + pixel.x * zoom, y + pixel.y * zoom, zoom, zoom);
  }
}
