// THIS IS AN APHELION UI FILE
import { parseHexColorString } from '../SpriteEditor/colorSpaces';
import type { RGBA, StringLayer } from '../SpriteEditor/Types/types';

/** HAIR_APPENDAGE_* bits, as code/__DEFINES/inventory.dm defines them. */
export const Zone = {
  FRONT: 1 << 0,
  LEFT: 1 << 1,
  RIGHT: 1 << 2,
  REAR: 1 << 3,
  TOP: 1 << 4,
  HANGING_FRONT: 1 << 5,
  HANGING_REAR: 1 << 6,
} as const;

export type ZoneInfo = {
  bit: number;
  /** What the zone list calls it; never one of the view names. */
  name: string;
  /** The badge on the layer tab. */
  short: string;
  /** Examples from the built-in styles. */
  examples: string;
  /** The tgfont glyph lit on the head: `tg-zaphelion-zone-<glyph>`. */
  glyph: string;
  /** The head the glyph sits on: seen from the side, or from behind for the sides of the head. */
  view: 'side' | 'back';
};

/** Where an appendage can attach, in the order the list shows them. */
export const ZONES: readonly ZoneInfo[] = [
  {
    bit: Zone.TOP,
    name: 'Crown',
    short: 'Crown',
    examples: 'ahoge, updo, mohawk',
    glyph: 'crown',
    view: 'side',
  },
  {
    bit: Zone.FRONT,
    name: 'Forehead',
    short: 'Forehead',
    examples: 'bangs',
    glyph: 'forehead',
    view: 'side',
  },
  {
    bit: Zone.LEFT,
    name: 'Left side',
    short: 'Left side',
    examples: 'a pigtail on their left',
    glyph: 'left',
    view: 'back',
  },
  {
    bit: Zone.RIGHT,
    name: 'Right side',
    short: 'Right side',
    examples: 'a pigtail on their right',
    glyph: 'right',
    view: 'back',
  },
  {
    bit: Zone.REAR,
    name: 'Back of the head',
    short: 'Back of head',
    examples: 'buns, braids, ponytails',
    glyph: 'back',
    view: 'side',
  },
  {
    bit: Zone.HANGING_FRONT,
    name: 'Down the front',
    short: 'Down the front',
    examples: 'twintails, drills',
    glyph: 'down-front',
    view: 'side',
  },
  {
    bit: Zone.HANGING_REAR,
    name: 'Down the back',
    short: 'Down the back',
    examples: 'long hair',
    glyph: 'down-back',
    view: 'side',
  },
];

export const zoneInfo = (bit: number) =>
  ZONES.find((zone) => zone.bit === bit) ?? ZONES[4];

/** One of the hair's appendage layers, as the server lists them. */
export type Appendage = {
  id: string;
  name: string;
  zone: number;
  outer: boolean | 0 | 1;
  edited: Partial<Record<string, boolean | 0 | 1>>;
  emissive: Partial<Record<string, boolean | 0 | 1>>;
};

/** A Try on hat: its name, the zones its mask strictly covers and what the window draws of it. */
export type TryOnHat = {
  label: string;
  group: string;
  strict: number;
  /**
   * Direction -> canvas rows, "1" where the mask keeps paint and "0" where it trims. The server
   * sends each row as eight hex digits, four pixels a digit with the leftmost in its high bit,
   * which expandHats() spells out.
   */
  masks: Record<string, string[]>;
  /** Direction -> data URL of the hat placed on the canvas. */
  views: Record<string, string>;
};

/** Each hex digit's four pixels, as mask rows spell them. */
const DIGIT_PIXELS: Record<string, string> = Object.fromEntries(
  [...'0123456789abcdef'].map((digit, value) => [
    digit,
    value.toString(2).padStart(4, '0'),
  ]),
);

/** The hats as the server sends them, with each mask row spelled out a character a pixel. */
export const expandHats = (
  hats: Record<string, TryOnHat>,
): Record<string, TryOnHat> =>
  Object.fromEntries(
    Object.entries(hats).map(([key, hat]) => [
      key,
      {
        ...hat,
        masks: Object.fromEntries(
          Object.entries(hat.masks).map(([dir, rows]) => [
            dir,
            rows.map((row) =>
              [...row].map((digit) => DIGIT_PIXELS[digit] ?? '0000').join(''),
            ),
          ]),
        ),
      },
    ]),
  );

/** What a hat does to a layer: nothing, trims it with its mask, or hides it outright. */
export type Fate = 'shown' | 'trimmed' | 'hidden';

/**
 * As the game treats a hairstyle's own pieces: hair is always trimmed; an under-hat piece only when
 * the hat strictly covers its zone; an over-hat piece is never trimmed but hidden while covered.
 */
export const layerFate = (
  appendage: Appendage | null,
  hat: TryOnHat | null | undefined,
): Fate => {
  if (!hat) return 'shown';
  if (!appendage) return 'trimmed';
  const covered = (hat.strict & appendage.zone) !== 0;
  if (appendage.outer) return covered ? 'hidden' : 'shown';
  return covered ? 'trimmed' : 'shown';
};

/** The one sentence under the kind cards. */
export const verdict = (
  appendage: Appendage,
  hat: TryOnHat | null | undefined,
): { tone: 'ok' | 'warn'; text: string } => {
  if (!hat) return { tone: 'ok', text: 'Shown as drawn, with no hat on.' };
  const name = hat.label.toLowerCase();
  switch (layerFate(appendage, hat)) {
    case 'trimmed':
      return {
        tone: 'warn',
        text: `The ${name} trims this piece, just like your hair.`,
      };
    case 'hidden':
      return { tone: 'warn', text: `The ${name} hides this piece completely.` };
    default:
      return appendage.outer
        ? { tone: 'ok', text: `This piece shows on top of the ${name}.` }
        : { tone: 'ok', text: `The ${name} leaves this piece whole.` };
  }
};

export const KINDS = {
  under: {
    label: 'Under hats',
    blurb: 'Sits under hats. Hats that cover it trim it.',
  },
  over: {
    label: 'Over hats',
    blurb: 'Sits on top of hats. Hats that cover it hide it.',
  },
} as const;

/** tgfont glyph names for the layer kinds, as `tg-zaphelion-<name>`. */
export const kindGlyph = (appendage: Appendage | null) =>
  !appendage ? 'wig' : appendage.outer ? 'over-hats' : 'under-hats';

/** As the server cleans names: tags, stray brackets, backslashes and control characters out, spaces collapsed, capped. */
export const cleanName = (raw: string, max: number) =>
  raw
    .replace(/<[^>]*>/g, '')
    .replace(/[<>\\\p{Cc}]/gu, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, max)
    .trim();

const TRANSPARENT = '#00000000';
/** Whether a "#rrggbb" or "#rrggbbaa" pixel shows at all. */
const painted = (pixel: string | undefined) =>
  !!pixel && !(pixel.length === 9 && pixel.endsWith('00'));

/** Frames trimmed by a hat's mask, by frame and then mask, so an update that keeps both keeps the trim. */
const wornFrames = new WeakMap<StringLayer, WeakMap<string[], StringLayer>>();

/**
 * A layer's view as the game draws it under a hat: trimmed pixels dropped, or nothing at all
 * while the hat hides it. Returns null when nothing shows.
 */
export const asWorn = (
  frame: StringLayer | undefined,
  fate: Fate,
  mask: string[] | undefined,
): StringLayer | null => {
  if (!frame || fate === 'hidden') return null;
  if (fate === 'shown' || !mask) return frame;
  let byMask = wornFrames.get(frame);
  if (!byMask) {
    byMask = new WeakMap();
    wornFrames.set(frame, byMask);
  }
  const cached = byMask.get(mask);
  if (cached) return cached;
  const worn = frame.map((row, y) =>
    row.map((pixel, x) => (mask[y]?.[x] === '1' ? pixel : TRANSPARENT)),
  );
  byMask.set(mask, worn);
  return worn;
};

/** Pixels of the layer being painted that a hat trims or hides, as y * width + x, for the canvas hatching. */
export const hatchedPixels = (
  frame: StringLayer | undefined,
  fate: Fate,
  mask: string[] | undefined,
) => {
  const cells = new Set<number>();
  if (!frame || fate === 'shown') return cells;
  for (const [y, row] of frame.entries()) {
    for (const [x, pixel] of row.entries()) {
      if (painted(pixel) && (fate === 'hidden' || mask?.[y]?.[x] !== '1')) {
        cells.add(y * row.length + x);
      }
    }
  }
  return cells;
};

/** A paint layer as the canvas stacks it: the base hair has no appendage. */
export type StackLayer = {
  id: string;
  appendage: Appendage | null;
  frame: StringLayer | undefined;
};

/** Something the canvas draws around the layer being painted, in the game's order. */
export type StackItem =
  | { type: 'frame'; key: string; frame: StringLayer }
  | { type: 'hat' }
  | { type: 'hatch' };

/** How strongly the canvas shows the layers that aren't being painted, and the tried-on hat. */
export const OTHER_LAYER_ALPHA = 0.38;
export const HAT_ALPHA = 0.5;

/** The hair, then its under-hat pieces, then its over-hat pieces, as the game draws them. */
export const drawOrder = <T extends { appendage: Appendage | null }>(
  layers: T[],
) => [
  ...layers.filter((layer) => !layer.appendage?.outer),
  ...layers.filter((layer) => !!layer.appendage?.outer),
];

/**
 * The other layers, the hat and the hatching, split around the layer being painted: `below` goes
 * under it and `above` over it. Other layers show as worn under the hat, which sits between the
 * under-hat and over-hat layers. The hatching marks the painted layer just above the hat, or on top
 * of everything for an over-hat piece, so the pieces that cover it in game still cover the marks.
 */
export const stackAround = (
  layers: StackLayer[],
  selected: string,
  hat: TryOnHat | null | undefined,
  dir: string,
) => {
  const items: (StackItem | 'chosen')[] = [];
  let hatDrawn = false;
  const addHat = () => {
    if (hat && !hatDrawn) items.push({ type: 'hat' });
    hatDrawn = true;
  };
  for (const layer of drawOrder(layers)) {
    if (layer.appendage?.outer) addHat();
    if (layer.id === selected) {
      items.push('chosen');
      continue;
    }
    const frame = asWorn(
      layer.frame,
      layerFate(layer.appendage, hat),
      hat?.masks[dir],
    );
    if (frame) items.push({ type: 'frame', key: layer.id, frame });
  }
  addHat();
  const chosen = layers.find((layer) => layer.id === selected);
  if (hat) {
    const hatIndex = items.findIndex(
      (item) => item !== 'chosen' && item.type === 'hat',
    );
    items.splice(chosen?.appendage?.outer ? items.length : hatIndex + 1, 0, {
      type: 'hatch',
    });
  }
  const split = items.indexOf('chosen');
  const pick = (part: (StackItem | 'chosen')[]) =>
    part.filter((item): item is StackItem => item !== 'chosen');
  return split < 0
    ? { below: pick(items), above: [] as StackItem[] }
    : {
        below: pick(items.slice(0, split)),
        above: pick(items.slice(split + 1)),
      };
};

const frameCanvases = new WeakMap<StringLayer, HTMLCanvasElement>();

/** A frame drawn once into a canvas of its own size, so the window can scale and fade it cheaply. */
export const frameCanvas = (frame: StringLayer) => {
  const cached = frameCanvases.get(frame);
  if (cached) return cached;
  const height = frame.length;
  const width = frame[0]?.length ?? 0;
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d');
  if (context && width && height) {
    const image = context.createImageData(width, height);
    // A frame repeats a few colours many times over, so each is read once.
    const colors = new Map<string, [number, number, number, number]>();
    for (const [y, row] of frame.entries()) {
      for (const [x, pixel] of row.entries()) {
        if (!pixel) continue;
        let color = colors.get(pixel);
        if (!color) {
          const { r, g, b, a = 1 } = parseHexColorString(pixel) as RGBA;
          color = [r, g, b, Math.round(a * 255)];
          colors.set(pixel, color);
        }
        image.data.set(color, (y * width + x) * 4);
      }
    }
    context.putImageData(image, 0, 0);
  }
  frameCanvases.set(frame, canvas);
  return canvas;
};

/**
 * Draws stack items across `width` by `height`: frames faded as other layers are, the hat at half
 * strength, and the hatching over `hatched` cells, `scale` pixels to a canvas pixel.
 */
export const drawStack = (
  context: CanvasRenderingContext2D,
  items: StackItem[],
  width: number,
  height: number,
  hatImage: CanvasImageSource | undefined,
  hatch?: Hatching,
) => {
  context.imageSmoothingEnabled = false;
  for (const item of items) {
    if (item.type === 'frame') {
      context.globalAlpha = OTHER_LAYER_ALPHA;
      context.drawImage(frameCanvas(item.frame), 0, 0, width, height);
    } else if (item.type === 'hat') {
      if (!hatImage) continue;
      context.globalAlpha = HAT_ALPHA;
      context.drawImage(hatImage, 0, 0, width, height);
    } else if (hatch) {
      context.globalAlpha = 1;
      drawHatch(context, hatch);
    }
  }
  context.globalAlpha = 1;
};

/** The chosen layer's hatched pixels as y * columns + x, and how to draw them. */
export type Hatching = {
  cells: Set<number>;
  fate: Fate;
  columns: number;
  scale: number;
  /** The strike over a hidden piece: the theme's over-hat colour. */
  hiddenColor: string;
};

/**
 * Hatched pixels: a dark wash and a rising strike, white where trimmed and the over-hat colour
 * where hidden. The strikes go down as one path, however many pixels there are.
 */
export const drawHatch = (
  context: CanvasRenderingContext2D,
  { cells, fate, columns, scale, hiddenColor }: Hatching,
) => {
  if (!cells.size) return;
  context.save();
  context.fillStyle = 'rgba(10, 8, 7, 0.55)';
  context.beginPath();
  for (const cell of cells) {
    const x = (cell % columns) * scale;
    const y = Math.floor(cell / columns) * scale;
    context.fillRect(x, y, scale, scale);
    context.moveTo(x + 2, y + scale - 2);
    context.lineTo(x + scale - 2, y + 2);
  }
  context.lineWidth = 1.25;
  context.globalAlpha = fate === 'hidden' ? 0.9 : 0.6;
  context.strokeStyle = fate === 'hidden' ? hiddenColor : '#ffffff';
  context.stroke();
  context.restore();
};
