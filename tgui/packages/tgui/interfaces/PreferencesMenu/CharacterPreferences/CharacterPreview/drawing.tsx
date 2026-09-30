// THIS IS AN APHELION UI FILE
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';

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
 */
export function drawPreviewFacing(
  context: FacingCanvas,
  image: CanvasImageSource,
  preview: CharacterPreviewDrawing,
  dir: SpriteDir,
) {
  const { width, height, x, rows } = preview;
  const left = preview.frames[dir];
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
 * whole-number scale allows, capped at a tile filling the box's shorter side:
 * its tile's centre across the middle, and all it draws in any facing centred
 * up and down. `x` and `y` are the tile's centre and floor in box pixels.
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
      fits(Math.min(width, height), TILE),
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

export type ShownPreview = {
  preview: CharacterPreviewDrawing;
  image?: HTMLImageElement;
  /** Where the drawing has pixels, once its image has loaded. */
  bounds?: DrawnBounds;
};

/**
 * The preview to show, with its image and where it has pixels once that has
 * loaded. A newer preview takes over only when its own image has, so a view
 * goes straight from one drawing to the next, never empty or cutting the old
 * image by the new frames.
 */
export function useShownPreview(
  preview: CharacterPreviewDrawing,
): ShownPreview {
  const [loaded, setLoaded] = useState<{
    preview: CharacterPreviewDrawing;
    image: HTMLImageElement;
  }>();

  useEffect(() => {
    const image = new Image();
    const show = () => setLoaded({ preview, image });
    image.addEventListener('load', show);
    image.src = preview.image;
    return () => image.removeEventListener('load', show);
  }, [preview.id, preview.image]);

  const bounds = useMemo(
    () => (loaded ? drawnBounds(loaded.image, loaded.preview) : undefined),
    [loaded],
  );

  return loaded ? { ...loaded, bounds } : { preview };
}

type PreviewCanvasProps = {
  shown: ShownPreview;
  dir: SpriteDir;
  scale: number;
  /** Where the tile's centre and its floor stand, in pixels of the positioned box it's in. */
  x: number;
  y: number;
  className?: string;
};

/**
 * One facing of a drawn preview mob, its tile stood at x and y. Height and
 * body size are drawn as the game draws them: moved rows first, then the mob's
 * transform about its tile's centre.
 */
export function PreviewCanvas(props: PreviewCanvasProps) {
  const { shown, dir, scale, x, y, className } = props;
  const { preview, image } = shown;
  const { width, height } = preview;
  const [a, b, c, d, e, f] = preview.transform ?? IDENTITY;
  const canvas = useRef<HTMLCanvasElement>(null);

  // Before the browser paints: a new size clears the canvas.
  useLayoutEffect(() => {
    const context = canvas.current?.getContext('2d');
    if (context && image) {
      drawPreviewFacing(context, image, preview, dir);
    }
  }, [preview, image, dir]);

  return (
    <canvas
      ref={canvas}
      className={className}
      width={width}
      height={height}
      style={{
        position: 'absolute',
        imageRendering: 'pixelated',
        left: `${x - (preview.x + TILE / 2) * scale}px`,
        top: `${y - (height - preview.y) * scale}px`,
        width: `${width * scale}px`,
        height: `${height * scale}px`,
        transformOrigin: `${(preview.x + TILE / 2) * scale}px ${(height - preview.y - TILE / 2) * scale}px`,
        // BYOND's y runs up, the page's down.
        transform: preview.transform
          ? `matrix(${a}, ${-d}, ${-b}, ${e}, ${c * scale}, ${-f * scale})`
          : undefined,
      }}
    />
  );
}
