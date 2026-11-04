// THIS IS AN APHELION UI FILE
import type { StringLayer } from '../SpriteEditor/Types/types';
import { CANVAS_ALPHABET } from './canvas';
import type { GraffitiArt } from './types';

// The server's graffiti limits (code/__DEFINES/~aphelion_defines/graffiti.dm).
export const GRAFFITI_WIDTH = 32;
export const GRAFFITI_WIDE_WIDTH = 64;
export const GRAFFITI_HEIGHT = 32;
export const GRAFFITI_MAX_LAYERS = 4;
export const GRAFFITI_MAX_LAYER_NAME = 20;
export const GRAFFITI_MAX_NAME = 32;
export const GRAFFITI_MAX_DESCRIPTION = 200;
/** The alpha placed graffiti draws opaque paint at, 80%: a colour this opaque or more is stored opaque. */
export const GRAFFITI_ALPHA_CEILING = 204;
/** The least alpha paint keeps, 20%. */
export const GRAFFITI_ALPHA_FLOOR = 51;
/** A piece's own palette; past it an index takes two characters, which only merged art reaches. */
export const GRAFFITI_MAX_COLORS = 63;
const GRAFFITI_FLAT_MAX_COLORS = 4095;

const RUN_LENGTHS = '123456789abcdef';
const DIGIT_VALUES = new Map(
  [...CANVAS_ALPHABET].map((character, value) => [character, value]),
);
const PACKED_COLOR = /^#[0-9a-f]{8}$/;

/**
 * Decodes a flat art grid as graffiti_decode_flat() does: `g1` or `g2`, the characters each index
 * takes, then runs of a hex length (1-f) and an index, most significant character first. It refuses
 * what that refuses, before expanding anything.
 *
 * Returns `pixelCount` palette indices, 0 where transparent, or null when the prefix doesn't fit the
 * palette size, a run is malformed, an index is past the palette, or the runs cover another number
 * of pixels.
 */
export const decodeFlat = (
  encoded: string,
  paletteSize: number,
  pixelCount: number,
): number[] | null => {
  if (
    typeof encoded !== 'string' ||
    !Number.isInteger(paletteSize) ||
    paletteSize < 0 ||
    paletteSize > GRAFFITI_FLAT_MAX_COLORS ||
    !Number.isInteger(pixelCount) ||
    pixelCount < 1 ||
    pixelCount > GRAFFITI_WIDE_WIDTH * GRAFFITI_HEIGHT
  ) {
    return null;
  }
  const digits = paletteSize > GRAFFITI_MAX_COLORS ? 2 : 1;
  const step = digits + 1;
  if (
    encoded.slice(0, 2) !== `g${digits}` ||
    (encoded.length - 2) % step ||
    encoded.length > 2 + pixelCount * step
  ) {
    return null;
  }
  const indices: number[] = new Array(pixelCount);
  let decoded = 0;
  for (let at = 2; at < encoded.length; at += step) {
    const run = RUN_LENGTHS.indexOf(encoded[at]) + 1;
    let index = DIGIT_VALUES.get(encoded[at + 1]);
    if (digits === 2 && index !== undefined) {
      const low = DIGIT_VALUES.get(encoded[at + 2]);
      index = low === undefined ? undefined : index * 64 + low;
    }
    if (
      !run ||
      index === undefined ||
      index > paletteSize ||
      decoded + run > pixelCount
    ) {
      return null;
    }
    indices.fill(index, decoded, decoded + run);
    decoded += run;
  }
  return decoded === pixelCount ? indices : null;
};

/** An art's packed palette as `#rrggbbaa` colours, or none when it isn't one graffiti_palette_pack() wrote. */
export const unpackPalette = (packed: string): string[] => {
  if (typeof packed !== 'string' || packed.length % 9) return [];
  const colors: string[] = [];
  for (let at = 0; at < packed.length; at += 9) {
    const color = packed.slice(at, at + 9);
    if (!PACKED_COLOR.test(color)) return [];
    colors.push(color);
  }
  return colors;
};

/** An art's pixels, row by row from the top left: `#rrggbbaa`, '' where transparent. None when it doesn't decode. */
export const artToPixels = (art: GraffitiArt): string[] => {
  const palette = unpackPalette(art.pal);
  const indices = decodeFlat(art.grid, palette.length, art.w * GRAFFITI_HEIGHT);
  if (!indices) return [];
  return indices.map((index) => (index ? palette[index - 1] : ''));
};

/**
 * A stored alpha byte as the window draws it: its share of the ceiling, so paint at the ceiling, which is stored opaque,
 * draws fully opaque and 99% of it draws at 99%. Placed graffiti shows its real alpha, never above the ceiling.
 */
export const shownAlpha = (alpha: number) =>
  Math.min(255, Math.round((alpha * 255) / GRAFFITI_ALPHA_CEILING));

/** Stored colour -> as shownColor() draws it. Pieces repeat a few dozen colours, so this stays small. */
const shownColors = new Map<string, string>();
const SHOWN_COLORS_KEPT = 256;

/** A stored `#rrggbb` or `#rrggbbaa` colour with its alpha drawn as its share of the ceiling (shownAlpha()). */
export const shownColor = (color: string) => {
  if (color.length < 9) return color;
  let shown = shownColors.get(color);
  if (!shown) {
    const alpha = shownAlpha(Number.parseInt(color.slice(7, 9), 16));
    shown = `${color.slice(0, 7)}${alpha.toString(16).padStart(2, '0')}`;
    if (shownColors.size >= SHOWN_COLORS_KEPT) shownColors.clear();
    shownColors.set(color, shown);
  }
  return shown;
};

const shownFrames = new WeakMap<StringLayer, StringLayer>();

/** A layer's pixels as the window draws them (shownColor()), made once a frame. Callers treat it as read-only. */
export const shownFrame = (frame: StringLayer): StringLayer => {
  let shown = shownFrames.get(frame);
  if (!shown) {
    shown = frame.map((row) => row.map(shownColor));
    shownFrames.set(frame, shown);
  }
  return shown;
};
