// THIS IS AN APHELION UI FILE
import {
  type CSSProperties,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import {
  bloomReach,
  DEFAULT_BLOOM,
  drawLightsOff,
  pixelsOf,
  tiledFloor,
} from '../../../common/LightsOff';
import type { CharacterPreviewDrawing } from '../../types';
import { SPRITE_DIRS, type SpriteDir } from '../SpeciesRegistry/constants';

/** A mob's own tile, in pixels. */
export const TILE = 32;

const IDENTITY: NonNullable<CharacterPreviewDrawing['transform']> = [
  1, 0, 0, 0, 1, 0,
];

/** What drawing a facing needs of a canvas. */
type FacingCanvas = Pick<
  CanvasRenderingContext2D,
  'clearRect' | 'drawImage'
> & {
  imageSmoothingEnabled: boolean;
};

/**
 * Draws one facing of a preview mob at its own size: the frame from the image,
 * then each run of rows a height filter moves, taken again from the rows it
 * shows. The drawing leaves height out; the game shows it as these rows.
 * `left` takes another frame of the facing's size instead, such as its glow,
 * whose rows move with the facing's.
 */
export function drawPreviewFacing(
  context: FacingCanvas,
  image: CanvasImageSource,
  preview: CharacterPreviewDrawing,
  dir: SpriteDir,
  left = preview.frames[dir],
) {
  const { width, height, x, rows } = preview;
  context.imageSmoothingEnabled = false;
  context.clearRect(0, 0, width, height);
  context.drawImage(image, left, 0, width, height, 0, 0, width, height);
  for (const [first, count, source] of rows ?? []) {
    context.clearRect(x, first, TILE, count);
    if (source >= 0) {
      context.drawImage(
        image,
        left + x,
        source,
        TILE,
        count,
        x,
        first,
        TILE,
        count,
      );
    }
  }
}

/** How far past an edge between two pixels a sample sitting on it is taken to be. */
const EDGE = 1e-6;

/**
 * How many of its own pixels body size carries a facing past its frame, on its
 * farthest side: the room a canvas needs round the frame to hold the facing
 * sized. None for a body that isn't sized, or only shrinks.
 */
export function previewGrowth(preview: CharacterPreviewDrawing) {
  if (!preview.transform) {
    return 0;
  }
  const { width, height, x, y } = preview;
  const [a, b, c, d, e, f] = preview.transform;
  // The frame's edges about the tile's centre, y upwards.
  const left = -x - TILE / 2;
  const right = width - x - TILE / 2;
  const bottom = -y - TILE / 2;
  const top = height - y - TILE / 2;
  let past = 0;
  for (const cornerX of [left, right]) {
    for (const cornerY of [bottom, top]) {
      const turnedX = a * cornerX + b * cornerY + c;
      const turnedY = d * cornerX + e * cornerY + f;
      past = Math.max(
        past,
        left - turnedX,
        turnedX - right,
        bottom - turnedY,
        turnedY - top,
      );
    }
  }
  return Math.max(0, Math.ceil(past - EDGE));
}

/**
 * A facing's pixels, the frame's size as drawPreviewFacing() draws it, sized as
 * the game sizes the mob: transformed about its tile's centre into a frame
 * `grow` pixels larger on every side, each pixel taking the one under its
 * centre, as PIXEL_SCALE has it. The game draws its map at the sprites' own
 * pixel size and only then zooms it, so a fractional size doubles and drops
 * whole pixels; the page zooms this the same way.
 */
export function sizedFacingPixels(
  pixels: Uint8ClampedArray,
  preview: CharacterPreviewDrawing,
  grow: number,
) {
  const { width, height, x, y } = preview;
  const [a, b, c, d, e, f] = preview.transform ?? IDENTITY;
  const sizedWidth = width + 2 * grow;
  const sizedHeight = height + 2 * grow;
  const sized = new Uint8ClampedArray(sizedWidth * sizedHeight * 4);
  const determinant = a * e - b * d;
  if (!determinant) {
    return sized;
  }
  // The tile's centre in frame pixels, rows from the top.
  const centreX = x + TILE / 2;
  const centreY = height - y - TILE / 2;
  for (let row = 0; row < sizedHeight; row++) {
    // This row's centre about the tile's centre, y upwards, less the transform's offset.
    const upward = centreY - (row - grow + 0.5) - f;
    for (let column = 0; column < sizedWidth; column++) {
      const across = column - grow + 0.5 - centreX - c;
      // Back through the transform to the drawing. A centre on the edge
      // between two pixels takes the one left of it, and the one above: the
      // game breaks such ties on rounding noise, and these match it most.
      const fromColumn = Math.floor(
        centreX + (e * across - b * upward) / determinant - EDGE,
      );
      const fromRow = Math.floor(
        centreY - (a * upward - d * across) / determinant - EDGE,
      );
      if (
        fromColumn >= 0 &&
        fromColumn < width &&
        fromRow >= 0 &&
        fromRow < height
      ) {
        const from = (fromRow * width + fromColumn) * 4;
        sized.set(
          pixels.subarray(from, from + 4),
          (row * sizedWidth + column) * 4,
        );
      }
    }
  }
  return sized;
}

/**
 * Where a row of the drawing shows once height has moved its rows, as
 * drawPreviewFacing() moves them: `frameY` (from the frame's top, its fraction
 * kept) moved with the run that shows its row, or where it was if none does.
 */
export function previewMovedY(
  preview: CharacterPreviewDrawing,
  frameY: number,
) {
  const row = Math.floor(frameY);
  for (const [first, count, source] of preview.rows ?? []) {
    if (source >= 0 && row >= source && row < source + count) {
      return frameY + first - source;
    }
  }
  return frameY;
}

/** Where a drawing has pixels: [left, top, right, bottom) in frame pixels, rows from the top. */
export type DrawnBounds = [number, number, number, number];

/**
 * Where a drawing has pixels in any facing, with height's rows moved. A frame
 * can carry empty rows, like the headroom a tall character's keeps for rows
 * lifted above its tile, which a fit shouldn't make room for.
 */
function drawnBounds(
  image: HTMLImageElement,
  preview: CharacterPreviewDrawing,
): DrawnBounds | undefined {
  const { width, height } = preview;
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d', { willReadFrequently: true });
  if (!context) {
    return undefined;
  }
  let [left, top, right, bottom] = [width, height, 0, 0];
  for (const dir of SPRITE_DIRS) {
    drawPreviewFacing(context, image, preview, dir);
    const { data } = context.getImageData(0, 0, width, height);
    for (let row = 0; row < height; row++) {
      for (let column = 0; column < width; column++) {
        if (data[(row * width + column) * 4 + 3]) {
          left = Math.min(left, column);
          right = Math.max(right, column + 1);
          top = Math.min(top, row);
          bottom = Math.max(bottom, row + 1);
        }
      }
    }
  }
  return right > left ? [left, top, right, bottom] : undefined;
}

/**
 * How far what a preview draws reaches once transformed, in its own pixels
 * about its tile: across from the tile's centre, and up from its floor.
 * Goes by the frame until the drawing's own bounds are known.
 */
export function previewExtent(
  preview: CharacterPreviewDrawing,
  bounds?: DrawnBounds,
) {
  const { width, height, x, y } = preview;
  const [a, b, c, d, e, f] = preview.transform ?? IDENTITY;
  const [boundLeft, boundTop, boundRight, boundBottom] = bounds ?? [
    0,
    0,
    width,
    height,
  ];
  let left = Number.POSITIVE_INFINITY;
  let right = Number.NEGATIVE_INFINITY;
  let top = Number.NEGATIVE_INFINITY;
  let bottom = Number.POSITIVE_INFINITY;
  // The drawn corners about the tile's centre, y upwards, as transformed.
  for (const cornerX of [boundLeft - x - TILE / 2, boundRight - x - TILE / 2]) {
    for (const cornerY of [
      height - boundBottom - y - TILE / 2,
      height - boundTop - y - TILE / 2,
    ]) {
      const turnedX = a * cornerX + b * cornerY + c;
      const turnedY = d * cornerX + e * cornerY + f + TILE / 2;
      left = Math.min(left, turnedX);
      right = Math.max(right, turnedX);
      top = Math.max(top, turnedY);
      bottom = Math.min(bottom, turnedY);
    }
  }
  return { left, right, top, bottom };
}

/** How many times a length fits another; a hair over, from float error in a transform, still fits. */
const fits = (space: number, length: number) =>
  Math.floor(space / length + 1e-6);

/**
 * The largest whole-number scale, up to a species sprite's, at which what a
 * preview draws fits a square box once transformed, stood on the box's floor
 * with its tile's centre on the box's centre. Only what hangs below its feet
 * may run over the floor.
 */
export function previewScale(
  preview: CharacterPreviewDrawing,
  box: number,
  bounds?: DrawnBounds,
): number {
  const extent = previewExtent(preview, bounds);
  // From the tile's centre to the farther side, and from its floor to the top.
  const reach = Math.max(0, -extent.left, extent.right);
  const rise = Math.max(TILE / 2, extent.top);
  return Math.max(
    1,
    Math.min(fits(box, TILE), fits(box, 2 * reach), fits(box, rise)),
  );
}

/**
 * How far a pan may move a drawing, in its own pixels: rightwards from minX to
 * maxX, and downwards from minY to maxY.
 */
export type PanBounds = {
  minX: number;
  maxX: number;
  minY: number;
  maxY: number;
};

/**
 * Where a preview stands in a box that everything it draws fills as far as a
 * whole-number scale allows, capped at a tile filling the box's shorter side,
 * or at `maxScale` when given: its tile's centre across the middle, and all it
 * draws in any facing centred up and down. `x` and `y` are the tile's centre
 * and floor in box pixels.
 *
 * `zoom` adds whole steps to that fitted scale, from 1x up to twice the fit,
 * still centred on what the preview draws; `fitScale` is the scale before it.
 *
 * `panBounds` is how far a pan may move it: as far as brings any part of what
 * it draws to the box's middle, at any zoom.
 */
export function previewFit(
  preview: CharacterPreviewDrawing | undefined,
  width: number,
  height: number,
  bounds?: DrawnBounds,
  zoom = 0,
  maxScale?: number,
) {
  const extent = preview
    ? previewExtent(preview, bounds)
    : { left: -TILE / 2, right: TILE / 2, top: TILE, bottom: 0 };
  const reach = Math.max(0, -extent.left, extent.right);
  const top = Math.max(0, extent.top);
  const bottom = Math.min(0, extent.bottom);
  const fitScale = Math.max(
    1,
    Math.min(
      maxScale ?? fits(Math.min(width, height), TILE),
      fits(width, 2 * reach),
      fits(height, top - bottom),
    ),
  );
  const scale = zoomedScale(fitScale, zoom);
  const y = Math.round(height / 2 + ((top + bottom) * scale) / 2);
  // How high above its floor the drawing is at the box's middle, unpanned.
  const middle = (y - height / 2) / scale;
  const panBounds: PanBounds = {
    minX: -extent.right,
    maxX: -extent.left,
    minY: extent.bottom - middle,
    maxY: extent.top - middle,
  };
  return { scale, fitScale, x: width / 2, y, panBounds };
}

/** A fitted scale with zoom steps added, from 1x up to twice the fit. */
export const zoomedScale = (fitScale: number, zoom: number) =>
  Math.min(2 * fitScale, Math.max(1, fitScale + zoom));

/**
 * Where a preview stands as `previewFit` stands it, except a drawing larger than
 * its tile (a taur's lower body, a large icon): that one fits by its tile alone,
 * at `maxScale` (or a tile filling the box's shorter side), the tile's centre
 * across the middle and what it draws inside the tile centred up and down. Its
 * body then stands the size and in the place any other body does, and what it
 * draws past the tile runs out of the box. A drawing no larger than its tile
 * fits exactly as `previewFit` fits it.
 */
export function previewBodyFit(
  preview: CharacterPreviewDrawing | undefined,
  width: number,
  height: number,
  bounds?: DrawnBounds,
  zoom = 0,
  maxScale?: number,
) {
  if (!preview || (preview.width <= TILE && preview.height <= TILE)) {
    return previewFit(preview, width, height, bounds, zoom, maxScale);
  }
  // The tile's box in the frame's pixels, and what is drawn inside it.
  const tileLeft = preview.x;
  const tileTop = preview.height - preview.y - TILE;
  const inside: DrawnBounds = [
    Math.max(bounds?.[0] ?? tileLeft, tileLeft),
    Math.max(bounds?.[1] ?? tileTop, tileTop),
    Math.min(bounds?.[2] ?? tileLeft + TILE, tileLeft + TILE),
    Math.min(bounds?.[3] ?? tileTop + TILE, tileTop + TILE),
  ];
  const extent = previewExtent(
    preview,
    inside[2] > inside[0] && inside[3] > inside[1]
      ? inside
      : [tileLeft, tileTop, tileLeft + TILE, tileTop + TILE],
  );
  const top = Math.max(0, extent.top);
  const bottom = Math.min(0, extent.bottom);
  const fitScale = Math.max(
    1,
    Math.min(
      maxScale ?? fits(Math.min(width, height), TILE),
      fits(height, top - bottom),
    ),
  );
  const scale = zoomedScale(fitScale, zoom);
  const y = Math.round(height / 2 + ((top + bottom) * scale) / 2);
  const middle = (y - height / 2) / scale;
  const panBounds: PanBounds = {
    minX: -extent.right,
    maxX: -extent.left,
    minY: extent.bottom - middle,
    maxY: extent.top - middle,
  };
  return { scale, fitScale, x: width / 2, y, panBounds };
}

export type ShownPreview = {
  preview: CharacterPreviewDrawing;
  image?: HTMLImageElement;
  /** Its animation's patches, once loaded: their own image, or the drawing's. */
  moving?: HTMLImageElement;
  /** Where the drawing has pixels, once its image has loaded. */
  bounds?: DrawnBounds;
};

/** An image once it has loaded, or undefined if it couldn't. */
function loadImage(source: string) {
  return new Promise<HTMLImageElement | undefined>((resolve) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => resolve(undefined);
    image.src = source;
  });
}

/**
 * The preview to show, with its image and where it has pixels once that has
 * loaded. A newer preview takes over only when its own image has, so a view
 * goes straight from one drawing to the next, never empty or cutting the old
 * image by the new frames. Its animation's patches load with it; a drawing
 * whose patches don't load shows still.
 */
export function useShownPreview(
  preview: CharacterPreviewDrawing,
): ShownPreview {
  const [loaded, setLoaded] = useState<{
    preview: CharacterPreviewDrawing;
    image: HTMLImageElement;
    moving?: HTMLImageElement;
  }>();

  useEffect(() => {
    let current = true;
    const patches = preview.animation?.image;
    Promise.all([
      loadImage(preview.image),
      patches ? loadImage(patches) : undefined,
    ]).then(([image, moving]) => {
      if (current && image) {
        setLoaded({
          preview,
          image,
          moving: preview.animation ? (patches ? moving : image) : undefined,
        });
      }
    });
    return () => {
      current = false;
    };
  }, [preview.id, preview.image]);

  const bounds = useMemo(
    () => (loaded ? drawnBounds(loaded.image, loaded.preview) : undefined),
    [loaded],
  );

  return loaded ? { ...loaded, bounds } : { preview };
}

/**
 * One facing as a view shows it: the drawing, which way it faces, its scale,
 * and where its tile's centre and floor stand in the view's box. Whatever is
 * drawn over the character lines up with it from this.
 */
export type PreviewView = {
  shown: ShownPreview;
  dir: SpriteDir;
  scale: number;
  x: number;
  y: number;
  /** Whether the lights are off. */
  dark: boolean;
};

/**
 * Where one facing's frame stands in a view, as PreviewCanvas places it, with
 * `reach` of its own pixels to spare on every side: height's rows are the
 * frame's own, and body size transforms it about its tile's centre.
 */
export function previewFrameStyle(
  preview: CharacterPreviewDrawing,
  scale: number,
  x: number,
  y: number,
  reach = 0,
): CSSProperties {
  const { width, height } = preview;
  const [a, b, c, d, e, f] = preview.transform ?? IDENTITY;
  return {
    position: 'absolute',
    left: `${x - (preview.x + TILE / 2 + reach) * scale}px`,
    top: `${y - (height - preview.y + reach) * scale}px`,
    width: `${(width + 2 * reach) * scale}px`,
    height: `${(height + 2 * reach) * scale}px`,
    transformOrigin: `${(preview.x + TILE / 2 + reach) * scale}px ${(height - preview.y - TILE / 2 + reach) * scale}px`,
    // BYOND's y runs up, the page's down.
    transform: preview.transform
      ? `matrix(${a}, ${-d}, ${-b}, ${e}, ${c * scale}, ${-f * scale})`
      : undefined,
  };
}

/**
 * Where a point of a facing's frame, in its pixels from the top left, stands
 * in the view's box, with body size's transform applied.
 */
export function previewFramePoint(
  preview: CharacterPreviewDrawing,
  scale: number,
  x: number,
  y: number,
  frameX: number,
  frameY: number,
): [number, number] {
  const [a, b, c, d, e, f] = preview.transform ?? IDENTITY;
  // From the tile's centre, in box pixels before the transform.
  const dx = (frameX - preview.x - TILE / 2) * scale;
  const dy = (frameY - (preview.height - preview.y - TILE / 2)) * scale;
  return [
    x + a * dx - b * dy + c * scale,
    y - (TILE / 2) * scale - d * dx + e * dy - f * scale,
  ];
}

type PreviewCanvasProps = {
  shown: ShownPreview;
  dir: SpriteDir;
  scale: number;
  /** Where the tile's centre and its floor stand, in pixels of the positioned box it's in. */
  x: number;
  y: number;
  className?: string;
  /** Whether its lights are off, so it shows what glows. */
  dark?: boolean;
  /** How far what glows blooms with the lights off: the player's bloom setting. */
  bloom?: number;
  /** The background's tile, which the bloom lights round what glows, as it does the floor in game. */
  floor?: HTMLImageElement;
};

/**
 * A canvas the size of one facing, holding that facing or another frame of it.
 * Lights off reads it back, so it is kept on the CPU: a GPU canvas would stall
 * the page reading it.
 */
function facingCanvas(
  image: CanvasImageSource,
  preview: CharacterPreviewDrawing,
  dir: SpriteDir,
  left?: number,
) {
  const canvas = document.createElement('canvas');
  canvas.width = preview.width;
  canvas.height = preview.height;
  const context = canvas.getContext('2d', { willReadFrequently: true });
  if (context) {
    drawPreviewFacing(context, image, preview, dir, left);
  }
  return canvas;
}

/**
 * A preview's frame as PreviewCanvas holds it once body size is drawn into it:
 * `grow` pixels larger on every side, with no transform left to apply.
 */
function sizedFrame(
  preview: CharacterPreviewDrawing,
  grow: number,
): CharacterPreviewDrawing {
  if (!preview.transform) {
    return preview;
  }
  return {
    ...preview,
    width: preview.width + 2 * grow,
    height: preview.height + 2 * grow,
    x: preview.x + grow,
    y: preview.y + grow,
    transform: undefined,
  };
}

/** Puts a facing drawn at its own size into `context`, sized as the game sizes the mob. */
function drawSizedFacing(
  context: CanvasRenderingContext2D,
  facing: CanvasImageSource,
  preview: CharacterPreviewDrawing,
  grow: number,
) {
  const pixels = pixelsOf(facing, preview.width, preview.height);
  if (!pixels) {
    return;
  }
  context.putImageData(
    new ImageData(
      sizedFacingPixels(pixels, preview, grow),
      preview.width + 2 * grow,
      preview.height + 2 * grow,
    ),
    0,
    0,
  );
}

/** Draws a facing, or another frame of it, as drawPreviewFacing() does, then sized. */
function drawShownFacing(
  context: CanvasRenderingContext2D,
  image: CanvasImageSource,
  preview: CharacterPreviewDrawing,
  dir: SpriteDir,
  grow: number,
  left?: number,
) {
  if (!preview.transform) {
    drawPreviewFacing(context, image, preview, dir, left);
    return;
  }
  drawSizedFacing(
    context,
    facingCanvas(image, preview, dir, left),
    preview,
    grow,
  );
}

/** A facing, or another frame of it, on a canvas of its own as drawShownFacing() draws it. */
function shownFacingCanvas(
  image: CanvasImageSource,
  preview: CharacterPreviewDrawing,
  dir: SpriteDir,
  grow: number,
  left?: number,
) {
  const facing = facingCanvas(image, preview, dir, left);
  if (!preview.transform) {
    return facing;
  }
  const canvas = document.createElement('canvas');
  canvas.width = preview.width + 2 * grow;
  canvas.height = preview.height + 2 * grow;
  const context = canvas.getContext('2d', { willReadFrequently: true });
  if (context) {
    drawSizedFacing(context, facing, preview, grow);
  }
  return canvas;
}

/**
 * Which of an animation's steps shows `elapsed` ms in, as they loop, and how
 * many ms are left of it.
 */
export function animationStep(steps: [number, number][], elapsed: number) {
  const period = steps.reduce((total, [, ms]) => total + ms, 0);
  let into = period > 0 ? elapsed % period : 0;
  for (let index = 0; index < steps.length; index++) {
    const ms = steps[index][1];
    if (into < ms) {
      return { index, wait: ms - into };
    }
    into -= ms;
  }
  return { index: 0, wait: steps[0]?.[1] ?? 0 };
}

/**
 * Lays a facing as drawn, with each of its moving regions' patches for the
 * steps they are on, over a canvas the size of the facing, for
 * drawPreviewFacing() to take as it takes the drawing.
 */
export function layAnimationFrame(
  context: CanvasRenderingContext2D,
  image: CanvasImageSource,
  moving: CanvasImageSource,
  preview: CharacterPreviewDrawing,
  dir: SpriteDir,
  regionSteps: number[],
) {
  const { width, height, animation } = preview;
  const regions = animation?.facings[dir] ?? [];
  context.clearRect(0, 0, width, height);
  context.drawImage(
    image,
    preview.frames[dir],
    0,
    width,
    height,
    0,
    0,
    width,
    height,
  );
  regions.forEach(({ box, steps }, index) => {
    const left = steps[regionSteps[index]]?.[0] ?? -1;
    if (left < 0) {
      return;
    }
    const [boxX, boxY, boxWidth, boxHeight] = box;
    context.clearRect(boxX, boxY, boxWidth, boxHeight);
    context.drawImage(
      moving,
      (animation?.left ?? 0) + left,
      0,
      boxWidth,
      boxHeight,
      boxX,
      boxY,
      boxWidth,
      boxHeight,
    );
  });
}

/** How often a hidden page's animation looks again whether it is shown, in ms. */
const HIDDEN_RECHECK = 1000;

/**
 * One facing of a drawn preview mob, its tile stood at x and y. Height and
 * body size are drawn as the game draws them: moved rows first, then the mob's
 * transform about its tile's centre, at the sprites' own pixel size, before
 * the page zooms it (sizedFacingPixels()).
 *
 * With the lights off it is lit as the game lights it in the dark, from its
 * glow, with room round it for the bloom; see LightsOff.tsx.
 *
 * What animates plays, a step at a time, while the page is shown and the
 * lights are on, as the game plays it whatever the player's system says of
 * motion: each step lays its patches over the facing and redraws the canvas.
 * Lights off, it holds still.
 */
export function PreviewCanvas(props: PreviewCanvasProps) {
  const {
    shown,
    dir,
    scale,
    x,
    y,
    className,
    dark = false,
    bloom = DEFAULT_BLOOM,
    floor,
  } = props;
  const { preview, image, moving } = shown;
  const canvas = useRef<HTMLCanvasElement>(null);
  // The room body size needs round the frame, and the frame the canvas holds once it's drawn in.
  const grow = useMemo(() => previewGrowth(preview), [preview]);
  const sized = useMemo(() => sizedFrame(preview, grow), [preview, grow]);
  const { width, height } = sized;
  // Room past the drawing on every side for its bloom, in its own pixels.
  const reach = dark ? bloomReach(bloom) : 0;
  const regions = preview.animation?.facings[dir];

  // Before the browser paints: a new size clears the canvas.
  useLayoutEffect(() => {
    const context = canvas.current?.getContext('2d');
    if (!context || !image) {
      return;
    }
    if (!dark) {
      drawShownFacing(context, image, preview, dir, grow);
      return;
    }
    const glowLeft = preview.glow_frames?.[dir];
    // The floor's tile repeats from the character's own tile, as the background lays it.
    const tile = floor && pixelsOf(floor, TILE, TILE);
    // Lit once sized, as the game lights the sized mob, so the floor keeps its own size.
    drawLightsOff(
      context,
      shownFacingCanvas(image, preview, dir, grow),
      glowLeft === undefined
        ? undefined
        : shownFacingCanvas(image, preview, dir, grow, glowLeft),
      width,
      height,
      bloom,
      reach,
      tile &&
        tiledFloor(
          tile,
          TILE,
          TILE,
          width + 2 * reach,
          height + 2 * reach,
          -reach - sized.x,
          -reach - height + sized.y + TILE,
        ),
    );
  }, [preview, image, dir, dark, bloom, reach, grow, sized, floor]);

  // From the facing as drawn above, which is every region's first step, each
  // region's next step when its time comes, laid over the facing with the
  // others' and drawn as the facing is. A hidden page looks again every
  // HIDDEN_RECHECK ms, as well as when it is told it is shown, and skips ahead.
  useEffect(() => {
    const context = canvas.current?.getContext('2d');
    if (!context || !image || !moving || !regions || dark) {
      return;
    }
    const frame = document.createElement('canvas');
    frame.width = preview.width;
    frame.height = preview.height;
    const frameContext = frame.getContext('2d');
    if (!frameContext) {
      return;
    }
    const start = performance.now();
    const regionSteps = regions.map(() => 0);
    let timer: ReturnType<typeof setTimeout> | undefined;
    const next = () => {
      if (document.hidden) {
        timer = setTimeout(next, HIDDEN_RECHECK);
        return;
      }
      const elapsed = performance.now() - start;
      let wait = Number.POSITIVE_INFINITY;
      let moved = false;
      regions.forEach(({ steps }, index) => {
        const step = animationStep(steps, elapsed);
        wait = Math.min(wait, step.wait);
        if (step.index !== regionSteps[index]) {
          regionSteps[index] = step.index;
          moved = true;
        }
      });
      if (moved) {
        layAnimationFrame(
          frameContext,
          image,
          moving,
          preview,
          dir,
          regionSteps,
        );
        drawShownFacing(context, frame, preview, dir, grow, 0);
      }
      timer = setTimeout(next, wait);
    };
    const resume = () => {
      if (!document.hidden) {
        clearTimeout(timer);
        next();
      }
    };
    document.addEventListener('visibilitychange', resume);
    next();
    return () => {
      clearTimeout(timer);
      document.removeEventListener('visibilitychange', resume);
    };
  }, [image, moving, regions, preview, dir, dark, grow]);

  return (
    <canvas
      ref={canvas}
      className={className}
      width={width + 2 * reach}
      height={height + 2 * reach}
      style={{
        imageRendering: 'pixelated',
        ...previewFrameStyle(sized, scale, x, y, reach),
      }}
    />
  );
}
