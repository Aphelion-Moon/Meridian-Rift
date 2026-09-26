// THIS IS AN APHELION UI FILE
import type { ShadeRenderer } from '../SpriteEditor/drawBounds';

/** A rectangle: x, y, width, height. */
export type PixelRect = [number, number, number, number];

/** Height of the region name tag, in screen pixels. */
export const TAG_HEIGHT = 13;

const TAGS: Record<string, string> = {
  head: 'HEAD',
  chest: 'TORSO',
  l_arm: 'L. ARM',
  r_arm: 'R. ARM',
  l_hand: 'L. HAND',
  r_hand: 'R. HAND',
  l_leg: 'L. LEG',
  r_leg: 'R. LEG',
  taur: 'TAUR',
};

const regionChar = (zones: string[], zone?: string | null) => {
  const index = zone ? zones.indexOf(zone) + 1 : 0;
  return index > 0 ? String(index) : null;
};

/** The region owning a pixel in one view, or null. */
export const regionAt = (
  rows: string[] | undefined,
  zones: string[],
  x: number,
  y: number,
): string | null => {
  const index = Number(rows?.[y]?.[x] ?? 0);
  return index > 0 ? (zones[index - 1] ?? null) : null;
};

/** Inclusive pixel bounds [minX, minY, maxX, maxY] of a region in one view, or null when it isn't there. */
export const regionBounds = (
  rows: string[] | undefined,
  zones: string[],
  zone?: string | null,
): [number, number, number, number] | null => {
  const char = regionChar(zones, zone);
  if (!rows || !char) return null;
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -1;
  let maxY = -1;
  rows.forEach((row, y) => {
    const first = row.indexOf(char);
    if (first < 0) return;
    minX = Math.min(minX, first);
    maxX = Math.max(maxX, row.lastIndexOf(char));
    minY = Math.min(minY, y);
    maxY = y;
  });
  return maxX < 0 ? null : [minX, minY, maxX, maxY];
};

/** One-pixel screen bars tracing just outside a region's pixel edges, so they never cover its paint. */
export const regionOutline = (
  rows: string[] | undefined,
  zones: string[],
  zone: string | null | undefined,
  scale: number,
): PixelRect[] => {
  const char = regionChar(zones, zone);
  if (!rows || !char) return [];
  const inside = (x: number, y: number) => rows[y]?.[x] === char;
  const bars: PixelRect[] = [];
  rows.forEach((row, y) => {
    for (let x = 0; x < row.length; x++) {
      if (row[x] !== char) continue;
      const left = x * scale;
      const top = y * scale;
      if (!inside(x, y - 1)) bars.push([left - 1, top - 1, scale + 2, 1]);
      if (!inside(x, y + 1)) bars.push([left - 1, top + scale, scale + 2, 1]);
      if (!inside(x - 1, y)) bars.push([left - 1, top - 1, 1, scale + 2]);
      if (!inside(x + 1, y)) bars.push([left + scale, top - 1, 1, scale + 2]);
    }
  });
  return bars;
};

/** Target-lock corner brackets round a pixel box, as one-pixel screen bars. */
export const bracketBars = (
  bounds: [number, number, number, number],
  scale: number,
  padding = 5,
  arm = 9,
): PixelRect[] => {
  const left = bounds[0] * scale - padding;
  const top = bounds[1] * scale - padding;
  const right = (bounds[2] + 1) * scale + padding - 1;
  const bottom = (bounds[3] + 1) * scale + padding - 1;
  return [
    [left, top, arm, 1],
    [left, top, 1, arm],
    [right - arm + 1, top, arm, 1],
    [right, top, 1, arm],
    [left, bottom, arm, 1],
    [left, bottom - arm + 1, 1, arm],
    [right - arm + 1, bottom, arm, 1],
    [right, bottom - arm + 1, 1, arm],
  ];
};

/** The name tag's top-left corner: above the top-left bracket, or below the box when there's no room. */
export const tagPosition = (
  bounds: [number, number, number, number],
  scale: number,
  tagHeight = TAG_HEIGHT,
  padding = 5,
): [number, number] => {
  const left = Math.max(0, bounds[0] * scale - padding);
  const top = bounds[1] * scale - padding - tagHeight - 2;
  return top >= 0 ? [left, top] : [left, (bounds[3] + 1) * scale + padding + 2];
};

/** A short uppercase name for the canvas tag. */
export const regionTag = (zone: string, label: string) =>
  TAGS[zone] ?? label.toUpperCase();

/** Unavailable pixels: a dark wash with a faint line on every screen row where row % 3 === 1. */
export const drawScanlines: ShadeRenderer = (context, areas, scale) => {
  for (const [x, y, width, height] of areas) {
    const left = x * scale;
    const top = y * scale;
    const w = width * scale;
    const h = height * scale;
    context.fillStyle = 'rgba(10, 12, 14, 0.62)';
    context.fillRect(left, top, w, h);
    context.fillStyle = 'rgba(255, 255, 255, 0.07)';
    for (let row = top + ((((1 - top) % 3) + 3) % 3); row < top + h; row += 3) {
      context.fillRect(left, row, w, 1);
    }
  }
};

/** Painted pixels that hair or a part covers in game, each as a one-pixel rect. */
export const coveredPaint = (
  cover: string[] | undefined,
  frame: string[][] | undefined,
): PixelRect[] => {
  if (!cover || !frame) return [];
  const cells: PixelRect[] = [];
  frame.forEach((row, y) => {
    row.forEach((pixel, x) => {
      const mark = cover[y]?.[x];
      if (mark && mark !== '0' && pixel && !pixel.endsWith('00')) {
        cells.push([x, y, 1, 1]);
      }
    });
  });
  return cells;
};

/** The part covering a pixel: the row mark (1-9, then a-z) indexes the parts list. */
export const coverPartAt = (
  cover: string[] | undefined,
  parts: string[] | undefined,
  x: number,
  y: number,
): string | null => {
  const mark = cover?.[y]?.[x];
  if (!mark || mark === '0' || !parts) return null;
  const index = parseInt(mark, 36);
  return Number.isNaN(index) ? null : (parts[index - 1] ?? null);
};

/** Covered paint: a dark wash and a rising diagonal, so the paint still reads through. */
export const drawCoveredPaint = (
  context: CanvasRenderingContext2D,
  cells: PixelRect[],
  scale: number,
) => {
  for (const [x, y] of cells) {
    const left = x * scale;
    const top = y * scale;
    context.fillStyle = 'rgba(0, 0, 0, 0.45)';
    context.fillRect(left, top, scale, scale);
    context.fillStyle = 'rgba(255, 255, 255, 0.55)';
    for (let step = 0; step < scale; step++) {
      context.fillRect(left + step, top + scale - 1 - step, 1, 1);
    }
  }
};
