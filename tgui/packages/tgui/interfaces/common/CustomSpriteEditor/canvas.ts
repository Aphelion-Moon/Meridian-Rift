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
  /** Graffiti sends a view as null when the window was last sent it as it is (fillSentViews()). */
  views: Record<string, string | null>;
  /** Appendage id -> the view the window shows, in the same codes; graffiti's layers above the bottom one by id. */
  appendages?: Record<string, Record<string, string | null>>;
  /** Graffiti: the id of the layer `views` holds, its bottom one. */
  viewsLayer?: string;
  /** Graffiti: layer id -> the serial of its view's codes, which changes whenever they do. */
  viewSerials?: Record<string, number>;
};

/** A graffiti view as the window keeps it: its codes, and the serial they came with. */
export type SentView = { codes: string; serial?: number };

export type CompactSprite = Omit<SpriteData, 'layers'> & {
  canvas: CompactCanvas;
};

/**
 * Views decoded lately, by everything that decides their pixels. An update usually changes one
 * view, so the others come back as the same rows, and whatever was drawn from them stays cached.
 * Callers treat the rows as read-only.
 */
const decodedViews = new Map<string, StringLayer>();
const DECODED_VIEWS_KEPT = 32;

/** One view's codes as rows of pixel values. */
const decodeView = (
  codes: string,
  canvas: CompactCanvas,
  width: number,
  height: number,
): StringLayer => {
  const key = `${width}x${height}|${canvas.digits}|${canvas.palette.join(',')}|${codes}`;
  const cached = decodedViews.get(key);
  if (cached) return cached;
  const frame = decodeCodes(codes, canvas, width, height);
  decodedViews.set(key, frame);
  if (decodedViews.size > DECODED_VIEWS_KEPT) {
    decodedViews.delete(decodedViews.keys().next().value!);
  }
  return frame;
};

const decodeCodes = (
  codes: string,
  canvas: CompactCanvas,
  width: number,
  height: number,
): StringLayer => {
  const { palette, digits } = canvas;
  const frame: StringLayer = [];
  let offset = 0;
  for (let y = 0; y < height; y++) {
    const row: string[] = new Array(width);
    for (let x = 0; x < width; x++) {
      let index = 0;
      for (let digit = 0; digit < digits; digit++) {
        index = index * 64 + (DIGIT_VALUES.get(codes[offset++]) ?? 0);
      }
      row[x] = palette[index];
    }
    frame.push(row);
  }
  return frame;
};

/**
 * Graffiti's canvas sends a layer's view as null when the window was last sent exactly those codes: fills each null
 * from `sent`, which keeps the codes every update brings and their serial, by layer id and view. A view the window
 * never had, as after a reload, or whose serial isn't the one it kept, as when an update it never drew carried newer
 * codes, is left out, and `missing` says the server should be asked for them all again.
 */
export const fillSentViews = (
  sprite: CompactSprite,
  sent: Record<string, SentView>,
): { sprite: CompactSprite; missing: boolean } => {
  const { canvas } = sprite;
  let missing = false;
  const fill = (id: string, views: Record<string, string | null> = {}) => {
    const filled: Record<string, string> = {};
    const serial = canvas.viewSerials?.[id];
    for (const [dir, codes] of Object.entries(views)) {
      const key = `${id}|${dir}`;
      if (codes) sent[key] = { codes, serial };
      const kept = sent[key];
      if (kept && kept.serial === serial) filled[dir] = kept.codes;
      else missing = true;
    }
    return filled;
  };
  const views = fill(canvas.viewsLayer ?? '', canvas.views);
  const appendages: Record<string, Record<string, string>> = {};
  for (const [id, layerViews] of Object.entries(canvas.appendages ?? {})) {
    appendages[id] = fill(id, layerViews);
  }
  return {
    sprite: { ...sprite, canvas: { ...canvas, views, appendages } },
    missing,
  };
};

/** Expands the server's compact canvas into the per-pixel layer SpriteEditor draws. */
export const decodeCanvas = (sprite: CompactSprite): SpriteData => {
  const { canvas, ...rest } = sprite;
  const data: Record<string, StringLayer> = {};
  for (const [dir, codes] of Object.entries(canvas.views)) {
    if (codes)
      data[dir] = decodeView(codes, canvas, sprite.width, sprite.height);
  }
  const layer = {
    name: 'Drawing',
    visible: true,
    data,
  } as unknown as SpriteDataLayer;
  return { ...rest, layers: [layer] };
};

/** A wide (taur) canvas, and the middle half a body without its taur fills. */
export const WIDE_CANVAS = 64;
const MIDDLE = [WIDE_CANVAS / 4, (WIDE_CANVAS * 3) / 4] as const;

/**
 * Whether a view of a wide canvas has nothing paintable or painted outside its middle half, as a
 * taur's front and back don't, so the window can show just that half at twice the size.
 */
export const fitsMiddleHalf = (
  frame: StringLayer | undefined,
  mask: string[] | undefined,
): boolean => {
  if (!frame || frame[0]?.length !== WIDE_CANVAS) return false;
  for (let y = 0; y < frame.length; y++) {
    const row = frame[y];
    const maskRow = mask?.[y];
    for (let x = 0; x < WIDE_CANVAS; x++) {
      if (x >= MIDDLE[0] && x < MIDDLE[1]) continue;
      if (maskRow?.[x] === '1' || !row[x]?.endsWith('00')) return false;
    }
  }
  return true;
};

/** Whether a picture of a wide body is clear outside its middle half, as a front or back view without a taur is. */
export const pictureFitsMiddleHalf = (image: HTMLImageElement): boolean => {
  if (image.naturalWidth !== WIDE_CANVAS) return false;
  const canvas = document.createElement('canvas');
  canvas.width = image.naturalWidth;
  canvas.height = image.naturalHeight;
  const context = canvas.getContext('2d', { willReadFrequently: true });
  if (!context?.getImageData) return false;
  context.drawImage(image, 0, 0);
  const { data } = context.getImageData(0, 0, canvas.width, canvas.height);
  for (let y = 0; y < canvas.height; y++) {
    for (let x = 0; x < WIDE_CANVAS; x++) {
      if (x >= MIDDLE[0] && x < MIDDLE[1]) continue;
      if (data[(y * WIDE_CANVAS + x) * 4 + 3]) return false;
    }
  }
  return true;
};

/** Appendage id -> direction -> rows, for the views the server sent. */
export const decodeAppendages = (sprite: CompactSprite) => {
  const frames: Record<string, Partial<Record<string, StringLayer>>> = {};
  for (const [id, views] of Object.entries(sprite.canvas.appendages ?? {})) {
    frames[id] = {};
    for (const [dir, codes] of Object.entries(views)) {
      if (codes) {
        frames[id][dir] = decodeView(
          codes,
          sprite.canvas,
          sprite.width,
          sprite.height,
        );
      }
    }
  }
  return frames;
};
