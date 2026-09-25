// THIS IS AN APHELION UI FILE
import type {
  SpriteData,
  SpriteDataLayer,
  StringLayer,
} from '../SpriteEditor/Types/types';

/** The server's CUSTOM_SPRITE_INDEX_ALPHABET: one base-64 digit per character. */
export const CANVAS_ALPHABET =
  '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_';

const DIGIT_VALUES = new Map(
  [...CANVAS_ALPHABET].map((character, value) => [character, value]),
);

/** The canvas as the server sends it: every pixel value once, and each view as index codes. */
export type CompactCanvas = {
  palette: string[];
  digits: number;
  views: Record<string, string>;
};

export type CompactSprite = Omit<SpriteData, 'layers'> & {
  canvas: CompactCanvas;
};

/** Expands the server's compact canvas into the per-pixel layer SpriteEditor draws. */
export const decodeCanvas = (sprite: CompactSprite): SpriteData => {
  const { canvas, ...rest } = sprite;
  const { palette, digits, views } = canvas;
  const data: Record<string, StringLayer> = {};
  for (const [dir, codes] of Object.entries(views)) {
    const frame: StringLayer = [];
    let offset = 0;
    for (let y = 0; y < sprite.height; y++) {
      const row: string[] = new Array(sprite.width);
      for (let x = 0; x < sprite.width; x++) {
        let index = 0;
        for (let digit = 0; digit < digits; digit++) {
          index = index * 64 + (DIGIT_VALUES.get(codes[offset++]) ?? 0);
        }
        row[x] = palette[index];
      }
      frame.push(row);
    }
    data[dir] = frame;
  }
  const layer = {
    name: 'Drawing',
    visible: true,
    data,
  } as unknown as SpriteDataLayer;
  return { ...rest, layers: [layer] };
};
