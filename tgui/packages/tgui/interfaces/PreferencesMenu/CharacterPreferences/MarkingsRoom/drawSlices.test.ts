// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it, spyOn } from 'bun:test';

import { DRAW_SLICE_MS, drawInSlices } from './drawSlices';

let clock = 0;
let frames: FrameRequestCallback[] = [];
let restore: (() => void)[] = [];
beforeEach(() => {
  clock = 1000;
  frames = [];
  const now = spyOn(performance, 'now').mockImplementation(() => clock);
  const frame = spyOn(globalThis, 'requestAnimationFrame').mockImplementation(
    (callback) => {
      frames.push(callback);
      return frames.length;
    },
  );
  restore = [() => now.mockRestore(), () => frame.mockRestore()];
});
afterEach(async () => {
  // Let the slice of the last test end, and draw whatever it left waiting.
  await Promise.resolve();
  while (frames.length) {
    frames.shift()?.(clock);
  }
  for (const undo of restore) undo();
});

/** The next frame: its slice of the waiting draws. */
const nextFrame = () => {
  const pending = frames;
  frames = [];
  for (const callback of pending) callback(clock);
};

describe('drawing thumbnails in slices', () => {
  it('draws a thumbnail alone at once', () => {
    const drawn: string[] = [];
    drawInSlices(() => drawn.push('alone'));
    expect(drawn).toEqual(['alone']);
    expect(frames).toEqual([]);
  });

  it("draws a sheet in order, a slice a task and a frame, and never a thumbnail that's gone", async () => {
    await Promise.resolve();
    const drawn: number[] = [];
    // Each draw takes 1 ms: a slice holds DRAW_SLICE_MS of them.
    const draw = (index: number) => () => {
      drawn.push(index);
      clock += 1;
    };
    const forget: (() => void)[] = [];
    for (let index = 0; index < 3 * DRAW_SLICE_MS; index++) {
      forget.push(drawInSlices(draw(index)));
    }
    expect(drawn).toEqual([...Array(DRAW_SLICE_MS).keys()]);
    // One that changes before its turn isn't drawn as it was.
    forget[DRAW_SLICE_MS + 1]();
    nextFrame();
    expect(drawn.slice(DRAW_SLICE_MS)).toEqual([
      DRAW_SLICE_MS,
      ...[...Array(DRAW_SLICE_MS).keys()]
        .map((index) => index + DRAW_SLICE_MS + 2)
        .slice(0, DRAW_SLICE_MS - 1),
    ]);
    nextFrame();
    nextFrame();
    expect(drawn).toEqual(
      [...Array(3 * DRAW_SLICE_MS).keys()].filter(
        (index) => index !== DRAW_SLICE_MS + 1,
      ),
    );
    expect(frames).toEqual([]);
  });

  it('starts every task with a slice of its own', async () => {
    await Promise.resolve();
    const drawn: string[] = [];
    clock += 0;
    drawInSlices(() => {
      drawn.push('first task');
      clock += 2 * DRAW_SLICE_MS;
    });
    // Later in the same task: over its slice, so it waits.
    drawInSlices(() => drawn.push('waits'));
    expect(drawn).toEqual(['first task']);
    nextFrame();
    expect(drawn).toEqual(['first task', 'waits']);
    // A later task draws at once again.
    await Promise.resolve();
    drawInSlices(() => drawn.push('next task'));
    expect(drawn).toEqual(['first task', 'waits', 'next task']);
  });
});
