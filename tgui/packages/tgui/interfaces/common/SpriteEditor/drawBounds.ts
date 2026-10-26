// THIS IS AN APHELION UI FILE
import { clamp } from 'tgui-core/math';

export const getShadedAreas = (
  imageWidth: number,
  imageHeight: number,
  drawBounds?: [number, number, number, number],
  drawMask?: string[],
): [number, number, number, number][] => {
  const areas: [number, number, number, number][] = [];
  if (!drawBounds && !drawMask) return areas;
  const left = clamp(drawBounds?.[0] ?? 0, 0, imageWidth);
  const top = clamp(drawBounds?.[1] ?? 0, 0, imageHeight);
  const right = clamp((drawBounds?.[2] ?? imageWidth - 1) + 1, 0, imageWidth);
  const bottom = clamp(
    (drawBounds?.[3] ?? imageHeight - 1) + 1,
    0,
    imageHeight,
  );
  const shade = (x: number, y: number, width: number, height: number) => {
    if (width > 0 && height > 0) areas.push([x, y, width, height]);
  };
  if (drawMask) {
    // Cache horizontal runs, including holes, until the limb geometry changes.
    for (let y = 0; y < imageHeight; y++) {
      let start = -1;
      for (let x = 0; x <= imageWidth; x++) {
        const shaded =
          x < imageWidth &&
          (x < left ||
            x >= right ||
            y < top ||
            y >= bottom ||
            drawMask[y]?.[x] !== '1');
        if (shaded && start < 0) start = x;
        if (!shaded && start >= 0) {
          shade(start, y, x - start, 1);
          start = -1;
        }
      }
    }
  } else if (left >= right || top >= bottom) {
    shade(0, 0, imageWidth, imageHeight);
  } else {
    shade(0, 0, imageWidth, top);
    shade(0, bottom, imageWidth, imageHeight - bottom);
    shade(0, top, left, bottom - top);
    shade(right, top, imageWidth - right, bottom - top);
  }
  return areas;
};

/** Paints shaded (unavailable) areas; `areas` are pixel rects, `scale` screen pixels per pixel. */
export type ShadeRenderer = (
  context: CanvasRenderingContext2D,
  areas: [number, number, number, number][],
  scale: number,
) => void;
