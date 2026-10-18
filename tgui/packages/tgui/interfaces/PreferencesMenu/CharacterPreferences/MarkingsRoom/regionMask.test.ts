// THIS IS AN APHELION UI FILE
import { afterEach, expect, it, spyOn } from 'bun:test';
import { type FrameRegions, regionMask } from './regions';

let uploads: number[][] = [];
const context = {
  createImageData: (width: number, height: number) => ({
    data: new Uint8ClampedArray(width * height * 4),
  }),
  putImageData: (image: { data: Uint8ClampedArray }) =>
    uploads.push([...image.data]),
};
let restore: (() => void)[] = [];
afterEach(() => {
  for (const undo of restore) undo();
  restore = [];
  uploads = [];
});

it('reuses a hovered region and rebuilds it for a replacement portrait map', () => {
  const get = spyOn(HTMLCanvasElement.prototype, 'getContext').mockReturnValue(
    context as unknown as CanvasRenderingContext2D,
  );
  const url = spyOn(
    HTMLCanvasElement.prototype,
    'toDataURL',
  ).mockImplementation(() => `data:mask,${uploads.length}`);
  restore.push(
    () => get.mockRestore(),
    () => url.mockRestore(),
  );
  const first: FrameRegions = {
    width: 2,
    height: 1,
    zones: ['head', 'chest'],
    index: new Uint8Array([1, 2]),
  };
  const head = regionMask(first, 'head');
  regionMask(first, 'chest');
  expect(regionMask(first, 'head')).toBe(head);
  expect(uploads).toEqual([
    [255, 255, 255, 255, 0, 0, 0, 0],
    [0, 0, 0, 0, 255, 255, 255, 255],
  ]);
  const replacement = { ...first, index: new Uint8Array([0, 1]) };
  expect(regionMask(replacement, 'head')).not.toBe(head);
  expect(uploads[2]).toEqual([0, 0, 0, 0, 255, 255, 255, 255]);
});
