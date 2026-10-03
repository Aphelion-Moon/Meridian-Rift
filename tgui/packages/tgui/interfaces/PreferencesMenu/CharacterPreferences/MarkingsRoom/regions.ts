// THIS IS AN APHELION UI FILE
import type { CharacterPreviewDrawing } from '../../types';
import { TILE } from '../CharacterPreview/drawing';
import type { SpriteDir } from '../SpeciesRegistry/constants';

/**
 * Which body region owns each pixel of the preview body, facing each way, as
 * the custom markings editor maps it: the server sends it for one drawing
 * (`id`) when the room asks. Each view is 32 rows of `width` characters, "0"
 * for no region and "N" for zones[N - 1]; a taur's wider canvas reaches half
 * its extra width past each side of the tile.
 */
export type MarkingRegions = {
  /** The drawing it was sent for; markings_room_regions_for says which it fits now. */
  id: number;
  /** What the server knows the map by: the page sends it back with the next drawing, and gets no map if it's the same. */
  key?: string;
  zones: string[];
  width: number;
  rows: Partial<Record<SpriteDir, string[] | null>>;
  /**
   * The visible augments it wears (a pair of eyes, an implant's overlay),
   * mapped the same way: "N" for the augment in zones[N - 1]'s slot. Null when
   * none draws on the body.
   */
  augments?: {
    zones: string[];
    rows: Partial<Record<SpriteDir, string[] | null>>;
  } | null;
};

/**
 * One facing's regions laid on its frame, pixel for pixel: each pixel's
 * region number, 0 for none, with height's rows moved as the drawing moves
 * them, so they line up with what the view shows.
 */
export type FrameRegions = {
  width: number;
  height: number;
  zones: string[];
  index: Uint8Array;
};

/** One facing's regions on its frame, or undefined when the map has no such view. */
export function frameRegions(
  preview: CharacterPreviewDrawing,
  regions: MarkingRegions,
  dir: SpriteDir,
): FrameRegions | undefined {
  const rows = regions.rows[dir];
  if (!rows) {
    return undefined;
  }
  const { width, height } = preview;
  // The canvas's top left, in frame pixels.
  const left = preview.x - (regions.width - TILE) / 2;
  const top = height - preview.y - TILE;
  const laid = new Uint8Array(width * height);
  rows.forEach((row, line) => {
    const frameY = top + line;
    if (frameY < 0 || frameY >= height) {
      return;
    }
    for (let column = 0; column < row.length; column++) {
      const region = row.charCodeAt(column) - 48;
      const frameX = left + column;
      if (region > 0 && region < 10 && frameX >= 0 && frameX < width) {
        laid[frameY * width + frameX] = region;
      }
    }
  });
  // Height's rows, as drawPreviewFacing moves them: each run across the tile
  // takes the rows it shows from the frame as it was, or is cleared.
  const index = laid.slice();
  for (const [first, count, source] of preview.rows ?? []) {
    for (let line = 0; line < count; line++) {
      const to = first + line;
      const from = source + line;
      if (to < 0 || to >= height) {
        continue;
      }
      for (let column = 0; column < TILE; column++) {
        const frameX = preview.x + column;
        if (frameX < 0 || frameX >= width) {
          continue;
        }
        index[to * width + frameX] =
          source >= 0 && from >= 0 && from < height
            ? laid[from * width + frameX]
            : 0;
      }
    }
  }
  return { width, height, zones: regions.zones, index };
}

// Each map's facings as laid on frames, by the frame's geometry. Most drawings
// leave the frame as the last one had it (a marking painted or swapped), and
// the server keeps the map the page holds; so the laid map, and every mask
// drawn for it, stays the same object between them.
const laid = new WeakMap<
  MarkingRegions,
  Map<string, FrameRegions | undefined>
>();

/**
 * One facing's regions on its frame, as frameRegions() lays them, the same
 * object for as long as the map and the frame's geometry are the same.
 */
export function frameRegionsOf(
  preview: CharacterPreviewDrawing,
  regions: MarkingRegions,
  dir: SpriteDir,
) {
  const geometry = `${dir} ${preview.width} ${preview.height} ${preview.x} ${preview.y} ${JSON.stringify(preview.rows ?? null)}`;
  let byGeometry = laid.get(regions);
  if (!byGeometry) {
    byGeometry = new Map();
    laid.set(regions, byGeometry);
  }
  if (byGeometry.has(geometry)) {
    return byGeometry.get(geometry);
  }
  const map = frameRegions(preview, regions, dir);
  byGeometry.set(geometry, map);
  return map;
}

const augmentMaps = new WeakMap<MarkingRegions, MarkingRegions | null>();

/** The visible augments' map as a map of its own, kept with the map it came in; null when no augment draws. */
export function augmentRegions(regions: MarkingRegions) {
  let known = augmentMaps.get(regions);
  if (known === undefined) {
    known = regions.augments
      ? {
          ...regions,
          zones: regions.augments.zones,
          rows: regions.augments.rows,
        }
      : null;
    augmentMaps.set(regions, known);
  }
  return known;
}

/** The region a frame pixel belongs to, or undefined. */
export function regionAt(map: FrameRegions, x: number, y: number) {
  if (x < 0 || y < 0 || x >= map.width || y >= map.height) {
    return undefined;
  }
  const region = map.index[Math.floor(y) * map.width + Math.floor(x)];
  return region ? map.zones[region - 1] : undefined;
}

/** A region's bounds on the frame, [left, top, right, bottom), or undefined when it has no pixels. */
export function regionBounds(map: FrameRegions, zone: string) {
  const region = map.zones.indexOf(zone) + 1;
  if (!region) {
    return undefined;
  }
  let [left, top, right, bottom] = [map.width, map.height, 0, 0];
  for (let y = 0; y < map.height; y++) {
    for (let x = 0; x < map.width; x++) {
      if (map.index[y * map.width + x] === region) {
        left = Math.min(left, x);
        right = Math.max(right, x + 1);
        top = Math.min(top, y);
        bottom = Math.max(bottom, y + 1);
      }
    }
  }
  return right > left ? ([left, top, right, bottom] as const) : undefined;
}

// Region maps are immutable snapshots. Reuse their masks between hovers, and let
// a replaced portrait's map and images be collected together.
const masks = new WeakMap<FrameRegions, Map<string, string>>();
// Every mask is drawn on this one canvas and read back as an image. It is kept
// on the CPU (willReadFrequently): a GPU canvas stalls the page on each read.
let maskCanvas: HTMLCanvasElement | undefined;
let maskContext: CanvasRenderingContext2D | null = null;

/** A region's pixels as a frame-sized mask image: white where it is, clear elsewhere. */
export function regionMask(map: FrameRegions, zone: string) {
  return regionsMask(map, [zone]);
}

/**
 * Several regions' pixels as one frame-sized mask image, as an arm augment's
 * lights its hand too; undefined when none of them has any.
 */
export function regionsMask(map: FrameRegions, zones: readonly string[]) {
  return drawMask(map, zones.join(' '), zones, (wanted, words) => {
    let any = false;
    for (let at = 0; at < map.index.length; at++) {
      if (wanted.has(map.index[at])) {
        words[at] = 0xffffffff;
        any = true;
      }
    }
    return any;
  });
}

/**
 * The pixels just outside several regions, each touching one of theirs, even
 * at a corner, as a frame-sized mask image: a line a pixel wide round their
 * shape, a small square round a lone pixel; undefined when they have none.
 */
export function regionsOutline(map: FrameRegions, zones: readonly string[]) {
  const { width, height, index } = map;
  return drawMask(map, `outline ${zones.join(' ')}`, zones, (wanted, words) => {
    const inside = (x: number, y: number) =>
      x >= 0 &&
      y >= 0 &&
      x < width &&
      y < height &&
      wanted.has(index[y * width + x]);
    let any = false;
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        if (inside(x, y)) {
          continue;
        }
        let touches = false;
        for (let dy = -1; dy <= 1 && !touches; dy++) {
          for (let dx = -1; dx <= 1 && !touches; dx++) {
            touches = inside(x + dx, y + dy);
          }
        }
        if (touches) {
          words[y * width + x] = 0xffffffff;
          any = true;
        }
      }
    }
    return any;
  });
}

/**
 * A frame-sized mask image of the pixels `paint` sets, white and opaque, one
 * write a pixel; kept by the map under `key`. Undefined when it sets none.
 */
function drawMask(
  map: FrameRegions,
  key: string,
  zones: readonly string[],
  paint: (wanted: Set<number>, words: Uint32Array) => boolean,
) {
  const known = masks.get(map)?.get(key);
  if (known) {
    return known;
  }
  const wanted = new Set(
    zones.map((zone) => map.zones.indexOf(zone) + 1).filter((region) => region),
  );
  if (!maskCanvas) {
    maskCanvas = document.createElement('canvas');
    maskContext = maskCanvas.getContext('2d', { willReadFrequently: true });
  }
  const context = maskContext;
  if (!wanted.size || !context) {
    return undefined;
  }
  maskCanvas.width = map.width;
  maskCanvas.height = map.height;
  const pixels = context.createImageData(map.width, map.height);
  if (!paint(wanted, new Uint32Array(pixels.data.buffer))) {
    return undefined;
  }
  context.putImageData(pixels, 0, 0);
  const url = maskCanvas.toDataURL();
  let saved = masks.get(map);
  if (!saved) {
    saved = new Map();
    masks.set(map, saved);
  }
  saved.set(key, url);
  return url;
}
