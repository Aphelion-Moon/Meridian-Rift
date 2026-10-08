import { expect, it } from 'bun:test';
import {
  dragPlacement,
  fitPreview,
  opaqueBounds,
  previewBounds,
} from './previewGeometry';

it('uses visible sprite pixels for grabbing instead of transparent canvas padding', () => {
  const pixels = new Uint8ClampedArray(4 * 4 * 4);
  expect(opaqueBounds(pixels, 4, 4)).toBeUndefined();
  pixels[(1 * 4 + 2) * 4 + 3] = 255;
  pixels[(2 * 4 + 3) * 4 + 3] = 128;
  expect(opaqueBounds(pixels, 4, 4)).toEqual({
    left: 2,
    top: 1,
    width: 2,
    height: 2,
  });
});

it('converts zoomed pointer motion to bounded whole pixel offsets', () => {
  expect(dragPlacement(0, 0, 15, -30, 2)).toEqual({ x: 8, y: 15 });
  expect(dragPlacement(0, 0, -15.2, 15.2, 2)).toEqual({ x: -8, y: -8 });
  expect(dragPlacement(120, -120, 80, 80, 2)).toEqual({ x: 128, y: -128 });
});

it('converts west-facing drag motion back to the mirrored base position', () => {
  expect(dragPlacement(10, 0, 8, -4, 2, -1)).toEqual({ x: 6, y: 2 });
});

it('fits a large body and distant rotated accessories across every animation frame', () => {
  const bounds = previewBounds(
    64,
    64,
    [{ icon: '', x: 128, y: 128, rotation: 45, scale: 16 }],
    [
      { x: 10, y: -8 },
      { x: -5, y: 15 },
    ],
  );
  const camera = fitPreview(bounds, 240, 240, 1.6);
  for (const x of [bounds.left, bounds.right])
    expect(Math.abs((x + camera.x) * camera.scale)).toBeLessThanOrEqual(
      104.00001,
    );
  for (const y of [bounds.top, bounds.bottom])
    expect(Math.abs((y + camera.y) * camera.scale)).toBeLessThanOrEqual(
      104.00001,
    );
});

it('centers the body origin without clipping a tall chassis', () => {
  const bounds = previewBounds(64, 64, []);
  const camera = fitPreview(bounds, 280, 240, 1.6);
  expect(camera.y).toBe(16);
  expect(camera.scale * 64).toBeLessThanOrEqual(208);
});
