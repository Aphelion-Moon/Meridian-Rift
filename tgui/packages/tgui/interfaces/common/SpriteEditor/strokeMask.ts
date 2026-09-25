// THIS IS AN APHELION UI FILE
import type { SpriteData } from './Types/types';

/** The server's CUSTOM_SPRITE_INDEX_ALPHABET: one base-64 digit per character. */
const MASK_ALPHABET =
  '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_';

/**
 * A stroke's pixels as one bit per canvas pixel, six to a character, row-major from the top left,
 * lowest bit first. A whole view fits in one short string, so even a stroke across the whole canvas
 * travels as a single message instead of a point list that has to be split into many.
 */
export const encodeStrokeMask = (
  points: Iterable<[number, number]>,
  width: number,
  height: number,
): string => {
  const cells = new Uint8Array(Math.ceil((width * height) / 6));
  for (const [x, y] of points) {
    const index = y * width + x;
    cells[Math.floor(index / 6)] |= 1 << (index % 6);
  }
  let mask = '';
  for (const cell of cells) mask += MASK_ALPHABET[cell];
  return mask;
};

/** A stroke's pixels as its transaction carries them: a mask where the server reads one, otherwise a point list. */
export const strokePixels = (
  points: Map<string, [number, number]>,
  data: SpriteData | undefined,
) =>
  data?.compactStrokes
    ? { mask: encodeStrokeMask(points.values(), data.width, data.height) }
    : { points: points.values().toArray() };
