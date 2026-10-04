// THIS IS AN APHELION UI FILE
// The server's canvas encoding, for the canvas decoding tests. It lives here, outside
// interfaces/, so the interface bundle never picks it up.
import {
  CANVAS_ALPHABET,
  type CompactSprite,
} from '../interfaces/common/CustomSpriteEditor/canvas';
import { Dir } from '../interfaces/common/SpriteEditor/Types/types';

/** Four views of `width` by `height` white pixels, as SpriteEditor holds them, for tests that set pixels. */
export const fixtureFrames = (width = 32, height = 32) => {
  const frame = () =>
    Array.from({ length: height }, () => Array(width).fill('#ffffffff'));
  return {
    [Dir.SOUTH]: frame(),
    [Dir.NORTH]: frame(),
    [Dir.EAST]: frame(),
    [Dir.WEST]: frame(),
  };
};

/** Encodes frames the way the server does: every pixel value once, and each view as index codes. */
export const compactSprite = (
  width: number,
  height: number,
  frames: Partial<Record<Dir, string[][]>>,
): CompactSprite => {
  const palette: string[] = [];
  const indexes = new Map<string, number>();
  for (const frame of Object.values(frames)) {
    for (const row of frame ?? []) {
      for (const pixel of row) {
        if (!indexes.has(pixel)) {
          indexes.set(pixel, palette.length);
          palette.push(pixel);
        }
      }
    }
  }
  const digits = palette.length <= 64 ? 1 : palette.length <= 4096 ? 2 : 3;
  const code = (index: number) => {
    let text = '';
    for (let digit = 0; digit < digits; digit++) {
      text = CANVAS_ALPHABET[index % 64] + text;
      index = Math.floor(index / 64);
    }
    return text;
  };
  const views: Record<string, string> = {};
  for (const [dir, frame] of Object.entries(frames)) {
    views[dir] = (frame ?? [])
      .map((row) => row.map((pixel) => code(indexes.get(pixel)!)).join(''))
      .join('');
  }
  return {
    width,
    height,
    dirs: 4,
    backdrop: '',
    canvas: { palette, digits, views },
  };
};
