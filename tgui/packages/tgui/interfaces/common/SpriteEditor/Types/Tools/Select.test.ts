// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, expect, it, mock, spyOn } from 'bun:test';
import * as actions from 'tgui/events/act';
import {
  Dir,
  type SelectionBounds,
  type SpriteData,
  type SpriteEditorToolContext,
  type StringLayer,
} from '../types';
import { Select } from './Select';

const clear = '#00000000';
const red = '#ff0000ff';
const green = '#00ff00ff';
const blue = '#0000ffff';

const fixture = (
  frame: StringLayer = [[red, green, blue, clear]],
  drawBounds?: SelectionBounds,
) => {
  const data: SpriteData = {
    width: frame[0].length,
    height: frame.length,
    dirs: 1,
    backdrop: '',
    layers: [
      {
        name: 'Paint',
        visible: true,
        data: {
          [Dir.SOUTH]: frame,
          [Dir.NORTH]: undefined,
          [Dir.EAST]: undefined,
          [Dir.WEST]: undefined,
        },
      },
    ],
  };
  const context: SpriteEditorToolContext = {
    currentColor: { r: 255, g: 255, b: 255 },
    selectedDir: Dir.SOUTH,
    selectedLayer: 0,
    drawBounds,
    setCurrentColor: mock(),
    setPreviewLayer: mock(),
    setPreviewData: mock(),
    setSelectionBounds: mock(),
    setSelectionMask: mock(),
  };
  const tool = new Select();
  const select = (rect: SelectionBounds) => {
    tool.onMouseDown(context, data, rect[0], rect[1]);
    tool.onMouseUp(context, data, rect[2], rect[3]);
  };
  return { data, context, tool, select };
};

let send: ReturnType<typeof spyOn>;
beforeEach(() => {
  send = spyOn(actions, 'sendAct');
});
afterEach(() => send.mockRestore());

/** The pixels a placed selection sent, as x, y and color, read back from its area, values and codes. */
const placed = (call = 0) => {
  const { area, palette, digits, codes } = send.mock.calls[call][1].transaction;
  const alphabet =
    '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_';
  const pixels: [number, number, string][] = [];
  let position = 0;
  for (let y = area[1]; y <= area[3]; y++) {
    for (let x = area[0]; x <= area[2]; x++) {
      const code: string = codes.slice(position, position + digits);
      position += digits;
      if (code[0] === '.') continue;
      let index = 0;
      for (const character of code) {
        index = index * alphabet.length + alphabet.indexOf(character);
      }
      pixels.push([x, y, palette[index]]);
    }
  }
  return pixels;
};

it('moves hidden paint with the selection, and sends it once it all lands on the limb', () => {
  const frame = [[red, blue, clear, clear]];
  const { data, context, tool, select } = fixture(frame);
  context.drawMask = ['1011'];
  select([0, 0, 1, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseMove(context, data, 1, 0);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, red, blue, clear],
  ]);
  tool.onMouseUp(context, data, 2, 0);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, clear, red, blue],
  ]);
  expect(send).toHaveBeenCalledTimes(1);
  expect(send.mock.calls[0][1].transaction.offset).toEqual([2, 0]);
});

it('grabs a selection in shaded pixels and brings hidden paint back inside the bounds', () => {
  const frame = [
    [blue, clear, clear, clear, clear, clear, clear, clear],
    [clear, clear, red, clear, clear, clear, clear, clear],
    Array(8).fill(clear),
  ];
  const { data, context, tool, select } = fixture(frame, [2, 1, 5, 2]);
  context.drawMask = ['00000000', '00111000', '00111000'];
  select([0, 0, 2, 1]);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([0, 0, 2, 1]);
  expect(send).not.toHaveBeenCalled();
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 2, 1);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    Array(8).fill(clear),
    [clear, clear, blue, clear, clear, clear, clear, clear],
    [clear, clear, clear, clear, red, clear, clear, clear],
  ]);
  expect(send.mock.calls[0][1].transaction.rect).toEqual([0, 0, 2, 1]);
  expect(send.mock.calls[0][1].transaction.offset).toEqual([2, 1]);
  expect(frame[0][0]).toBe(blue);
});

it('floats paint that does not all land, and cuts off what is off the canvas or shaded when dropped', () => {
  const { data, context, tool, select } = fixture(
    [[clear, clear, red, green, clear, clear, clear, clear]],
    [0, 0, 5, 0],
  );
  select([2, 0, 3, 0]);
  tool.onMouseDown(context, data, 2, 0);
  tool.onMouseUp(context, data, 20, 0);
  // Part of the box stays on the canvas; red hangs over shaded pixels, green off the edge.
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([7, 0, 8, 0]);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, clear, clear, clear, clear, clear, clear, red],
  ]);
  tool.onMouseDown(context, data, 7, 0);
  tool.onMouseUp(context, data, 5, 0);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, clear, clear, clear, clear, red, green, clear],
  ]);
  expect(send).not.toHaveBeenCalled();
  tool.release(context);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith(undefined);
  expect(send).toHaveBeenCalledTimes(1);
  expect(send.mock.calls[0][1].transaction).toMatchObject({
    type: 'move',
    name: 'Move selection',
    layer: 1,
    dir: '2',
  });
  expect(placed()).toEqual([
    [2, 0, clear],
    [3, 0, clear],
    [5, 0, red],
  ]);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, clear, clear, clear, clear, red, clear, clear],
  ]);
});

it('selects a normalized rectangle without previewing or changing pixels', () => {
  const { data, context, tool } = fixture();
  tool.onMouseDown(context, data, 2.8, 0.4);
  tool.onMouseUp(context, data, -10, 0);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([0, 0, 2, 0]);
  expect(context.setPreviewData).not.toHaveBeenCalled();
  expect(send).not.toHaveBeenCalled();
});

it('moves overlapping pixels from one snapshot and commits once at release', () => {
  const frame = [[red, green, blue, clear]];
  const original = structuredClone(frame);
  const { data, context, tool, select } = fixture(frame);
  select([0, 0, 1, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseMove(context, data, 1, 0);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, red, green, clear],
  ]);
  expect(frame).toEqual(original);
  tool.onMouseUp(context, data, 1, 0);
  expect(send).toHaveBeenCalledTimes(1);
  expect(send).toHaveBeenCalledWith('spriteEditorCommand', {
    command: 'transaction',
    transaction: {
      type: 'move',
      name: 'Move selection',
      layer: 1,
      dir: '2',
      rect: [0, 0, 1, 0],
      offset: [1, 0],
    },
  });
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([1, 0, 2, 0]);
});

it('preserves destination under transparent source and directly replaces partial alpha', () => {
  const translucent = '#12345680';
  const { data, context, tool, select } = fixture([
    [translucent, clear, red, blue],
  ]);
  select([0, 0, 1, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 2, 0);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, clear, translucent, blue],
  ]);
});

it('keeps part of a dragged box on the canvas either way', () => {
  const { data, context, tool, select } = fixture(
    [
      [clear, clear, clear, clear],
      [clear, red, green, clear],
      [clear, clear, clear, clear],
    ],
    [1, 0, 3, 2],
  );
  select([1, 1, 2, 1]);
  tool.onMouseDown(context, data, 1, 1);
  tool.onMouseUp(context, data, 40, 40);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([3, 2, 4, 2]);
  tool.onMouseDown(context, data, 3, 2);
  tool.onMouseUp(context, data, -40, -40);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([-1, 0, 0, 0]);
  expect(send).not.toHaveBeenCalled();
});

it('starts a new selection outside the old one and ignores clicks off the canvas', () => {
  const { data, context, tool, select } = fixture();
  select([0, 0, 0, 0]);
  select([2, 0, 3, 0]);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([2, 0, 3, 0]);
  tool.onMouseDown(context, data, -1, 0);
  tool.onMouseUp(context, data, 2, 0);
  expect(send).not.toHaveBeenCalled();
  const blocked = fixture([[red]], [0, 0, -1, -1]);
  blocked.tool.onMouseDown(blocked.context, blocked.data, 0, 0);
  blocked.tool.onMouseUp(blocked.context, blocked.data, 0, 0);
  expect(blocked.context.setSelectionBounds).toHaveBeenLastCalledWith([
    0, 0, 0, 0,
  ]);
  blocked.tool.onMouseDown(blocked.context, blocked.data, 0, 0);
  blocked.tool.onMouseUp(blocked.context, blocked.data, 1, 0);
  expect(send).not.toHaveBeenCalled();
});

it('cancels selection and optimistic movement without committing', () => {
  const { data, context, tool, select } = fixture();
  select([0, 0, 0, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseMove(context, data, 1, 0);
  tool.cancel(context);
  tool.onMouseUp(context, data, 2, 0);
  expect(context.setPreviewData).toHaveBeenLastCalledWith(undefined);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith(undefined);
  expect(send).not.toHaveBeenCalled();
});

it.each([
  { selectedDir: Dir.NORTH },
  { selectedLayer: 1 },
])('cancels a drag when its direction or layer changes: %p', (changed) => {
  const { data, context, tool, select } = fixture();
  select([0, 0, 0, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseMove({ ...context, ...changed }, data, 1, 0);
  tool.onMouseUp(context, data, 2, 0);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith(undefined);
  expect(context.setPreviewData).toHaveBeenLastCalledWith(undefined);
  expect(send).not.toHaveBeenCalled();
});

it('keeps the destination selected for another move using the updated frame', () => {
  const { data, context, tool, select } = fixture();
  select([0, 0, 0, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 1, 0);
  data.layers[0].data[Dir.SOUTH] = [[clear, red, blue, clear]];
  tool.onMouseDown(context, data, 1, 0);
  tool.onMouseUp(context, data, 3, 0);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, clear, blue, red],
  ]);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([3, 0, 3, 0]);
  expect(send).toHaveBeenCalledTimes(2);
  expect(send).toHaveBeenLastCalledWith('spriteEditorCommand', {
    command: 'transaction',
    transaction: {
      type: 'move',
      name: 'Move selection',
      layer: 1,
      dir: '2',
      rect: [1, 0, 1, 0],
      offset: [2, 0],
    },
  });
});

it('does not create history or leave previews for empty and zero-offset moves', () => {
  for (const frame of [[[clear, clear]], [[red, green]]]) {
    const { data, context, tool, select } = fixture(frame);
    select([0, 0, 0, 0]);
    tool.onMouseDown(context, data, 0, 0);
    tool.onMouseMove(context, data, 1, 0);
    tool.onMouseUp(context, data, 0, 0);
    expect(context.setPreviewData).toHaveBeenLastCalledWith(undefined);
  }
  expect(send).not.toHaveBeenCalled();
});

it('moves an empty selection border without creating a pixel transaction', () => {
  const { data, context, tool, select } = fixture([[clear, clear]]);
  select([0, 0, 0, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 1, 0);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([1, 0, 1, 0]);
  expect(context.setPreviewData).toHaveBeenLastCalledWith(undefined);
  expect(send).not.toHaveBeenCalled();
});

it('chains rapid moves against the optimistic frame and adopts a new server frame', () => {
  const { data, context, tool, select } = fixture([[red, clear, clear, clear]]);
  select([0, 0, 0, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 1, 0);
  tool.onMouseDown(context, data, 1, 0);
  tool.onMouseUp(context, data, 2, 0);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, clear, red, clear],
  ]);
  expect(send).toHaveBeenCalledTimes(2);
  expect(data.layers[0].data[Dir.SOUTH]).toEqual([[red, clear, clear, clear]]);
  data.layers[0].data[Dir.SOUTH] = [[blue, clear, green, clear]];
  tool.onMouseDown(context, data, 2, 0);
  tool.onMouseUp(context, data, 3, 0);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [blue, clear, clear, green],
  ]);
  expect(send).toHaveBeenCalledTimes(3);
});

it('retains a pending preview when a later drag returns to its starting point', () => {
  const { data, context, tool, select } = fixture([[red, clear, clear]]);
  select([0, 0, 0, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 1, 0);
  tool.onMouseDown(context, data, 1, 0);
  tool.onMouseMove(context, data, 2, 0);
  tool.onMouseUp(context, data, 1, 0);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, red, clear],
  ]);
  expect(send).toHaveBeenCalledTimes(1);
});

it('keeps earlier pending pixels visible when moving an empty selection', () => {
  const { data, context, tool, select } = fixture([[red, clear, clear, clear]]);
  select([0, 0, 0, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 1, 0);
  select([2, 0, 2, 0]);
  tool.onMouseDown(context, data, 2, 0);
  tool.onMouseUp(context, data, 3, 0);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, red, clear, clear],
  ]);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([3, 0, 3, 0]);
  expect(send).toHaveBeenCalledTimes(1);
});

it('keeps later moves pending after an intermediate acknowledgement', () => {
  const { data, context, tool, select } = fixture([[red, clear, clear, clear]]);
  select([0, 0, 0, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 1, 0);
  tool.onMouseDown(context, data, 1, 0);
  tool.onMouseUp(context, data, 2, 0);
  data.layers[0].data[Dir.SOUTH] = [[clear, red, clear, clear]];
  tool.reconcile(context, data);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, clear, red, clear],
  ]);
  tool.onMouseDown(context, data, 2, 0);
  tool.onMouseUp(context, data, 3, 0);
  expect(send).toHaveBeenCalledTimes(3);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, clear, clear, red],
  ]);
  data.layers[0].data[Dir.SOUTH] = [[clear, clear, red, clear]];
  tool.reconcile(context, data);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, clear, clear, red],
  ]);
  data.layers[0].data[Dir.SOUTH] = [[clear, clear, clear, red]];
  tool.reconcile(context, data);
  expect(context.setPreviewData).toHaveBeenLastCalledWith(undefined);
});

it('uses unexpected server changes made in place instead of an old pending frame', () => {
  const { data, context, tool, select } = fixture([[red, clear, clear, clear]]);
  select([0, 0, 0, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 1, 0);
  data.layers[0].data[Dir.SOUTH][0] = [blue, green, clear, clear];
  tool.onMouseDown(context, data, 1, 0);
  tool.onMouseUp(context, data, 2, 0);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [blue, clear, green, clear],
  ]);
  expect(send).toHaveBeenCalledTimes(2);
});

it('restores an active drag preview when an earlier move is acknowledged', () => {
  const { data, context, tool, select } = fixture([[red, clear, clear]]);
  select([0, 0, 0, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 1, 0);
  tool.onMouseDown(context, data, 1, 0);
  tool.onMouseMove(context, data, 2, 0);
  data.layers[0].data[Dir.SOUTH] = [[clear, red, clear]];
  tool.reconcile(context, data);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, clear, red],
  ]);
  tool.onMouseUp(context, data, 2, 0);
  expect(send).toHaveBeenCalledTimes(2);
});

it('recognizes equivalent opacity spellings in acknowledged pixel frames', () => {
  const { data, context, tool, select } = fixture([[red, '#12345600', clear]]);
  select([0, 0, 0, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 1, 0);
  data.layers[0].data[Dir.SOUTH] = [[clear, '#ff0000', '#abcdef00']];
  tool.reconcile(context, data);
  expect(context.setPreviewData).toHaveBeenLastCalledWith(undefined);
  expect(send).toHaveBeenCalledTimes(1);
});

it('copies a selection and pastes it as floating paint that is sent once, when dropped', () => {
  const { data, context, tool, select } = fixture([
    [red, green, clear, clear, clear],
  ]);
  select([0, 0, 1, 0]);
  expect(tool.copy(context, data)).toBe(true);
  expect(tool.paste(context, data)).toBe(true);
  // It floats where it was copied from.
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([0, 0, 1, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 3, 0);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [red, green, clear, red, green],
  ]);
  expect(send).not.toHaveBeenCalled();
  tool.release(context);
  expect(send).toHaveBeenCalledTimes(1);
  expect(placed()).toEqual([
    [3, 0, red],
    [4, 0, green],
  ]);
});

it('pastes what was copied in one view into another', () => {
  const { data, context, tool, select } = fixture([[red, green, clear]]);
  data.layers[0].data[Dir.NORTH] = [[clear, clear, blue]];
  select([0, 0, 1, 0]);
  tool.copy(context, data);
  const back = { ...context, selectedDir: Dir.NORTH };
  expect(tool.paste(back, data)).toBe(true);
  expect(back.setPreviewData).toHaveBeenLastCalledWith([[red, green, blue]]);
  tool.release(back);
  expect(send.mock.calls[0][1].transaction.dir).toBe('1');
  expect(placed()).toEqual([
    [0, 0, red],
    [1, 0, green],
  ]);
});

it('takes a right-dragged rectangle out of the selection and moves only what is left', () => {
  const { data, context, tool, select } = fixture([
    [red, green, blue, clear, clear, clear],
  ]);
  // With nothing selected, the right button does nothing.
  expect(tool.onMouseDown(context, data, 1, 0, true)).toBeUndefined();
  select([0, 0, 2, 0]);
  tool.onMouseDown(context, data, 1, 0, true);
  tool.onMouseUp(context, data, 1, 0);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([0, 0, 2, 0]);
  expect(context.setSelectionMask).toHaveBeenLastCalledWith(['101']);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 3, 0);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, green, clear, red, clear, blue],
  ]);
  expect(placed()).toEqual([
    [0, 0, clear],
    [2, 0, clear],
    [3, 0, red],
    [5, 0, blue],
  ]);
  // Taking out everything that's left drops the selection.
  tool.onMouseDown(context, data, 3, 0, true);
  tool.onMouseUp(context, data, 5, 0);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith(undefined);
});

it('turns the selection a quarter turn about its middle and drops it where it shows', () => {
  const { data, context, tool, select } = fixture([
    [red, green, clear],
    [clear, clear, clear],
    [clear, clear, clear],
  ]);
  select([0, 0, 1, 0]);
  expect(tool.rotate(context, data, 1)).toBe(true);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([0, 0, 0, 1]);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [red, clear, clear],
    [green, clear, clear],
    [clear, clear, clear],
  ]);
  expect(send).not.toHaveBeenCalled();
  tool.release(context);
  expect(placed()).toEqual([
    [1, 0, clear],
    [0, 1, green],
  ]);
});

it('turns back to where it started without sending anything', () => {
  const { data, context, tool, select } = fixture([[red, green, blue, clear]]);
  select([0, 0, 2, 0]);
  tool.rotate(context, data, 1);
  tool.rotate(context, data, -1);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([0, 0, 2, 0]);
  tool.release(context);
  expect(send).not.toHaveBeenCalled();
});

it('throws floating paint away on Escape and drops it when a new selection starts', () => {
  const { data, context, tool, select } = fixture([[red, clear, clear, clear]]);
  select([0, 0, 0, 0]);
  tool.copy(context, data);
  tool.paste(context, data);
  tool.cancel(context);
  expect(context.setPreviewData).toHaveBeenLastCalledWith(undefined);
  tool.paste(context, data);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 2, 0);
  expect(send).not.toHaveBeenCalled();
  select([3, 0, 3, 0]);
  expect(placed()).toEqual([[2, 0, red]]);
});

it('mirrors the selection left to right about its middle and drops it where it shows', () => {
  const { data, context, tool, select } = fixture([[red, green, blue, clear]]);
  select([0, 0, 2, 0]);
  expect(tool.flip(context, data)).toBe(true);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([0, 0, 2, 0]);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [blue, green, red, clear],
  ]);
  expect(send).not.toHaveBeenCalled();
  tool.release(context);
  expect(placed()).toEqual([
    [0, 0, blue],
    [2, 0, red],
  ]);
});

it('mirrors back to where it started without sending anything', () => {
  const { data, context, tool, select } = fixture([[red, green, blue, clear]]);
  select([0, 0, 2, 0]);
  tool.flip(context, data);
  tool.flip(context, data);
  tool.release(context);
  expect(send).not.toHaveBeenCalled();
});

it('mirrors floating paint where it floats', () => {
  const { data, context, tool, select } = fixture([
    [red, green, clear, clear, clear],
  ]);
  select([0, 0, 1, 0]);
  tool.copy(context, data);
  tool.paste(context, data);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 3, 0);
  expect(tool.flip(context, data)).toBe(true);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [red, green, clear, green, red],
  ]);
  tool.release(context);
  expect(placed()).toEqual([
    [3, 0, green],
    [4, 0, red],
  ]);
});

it('mirrors only the selected pixels, and the shape of the selection with them', () => {
  const { data, context, tool, select } = fixture([
    [red, green, blue],
    [blue, red, clear],
  ]);
  select([0, 0, 2, 0]);
  // With the middle taken out, its paint stays put while the ends swap.
  tool.onMouseDown(context, data, 1, 0, true);
  tool.onMouseUp(context, data, 1, 0);
  tool.flip(context, data);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [blue, green, red],
    [blue, red, clear],
  ]);
  tool.cancel(context);
  select([0, 0, 1, 1]);
  tool.onMouseDown(context, data, 1, 1, true);
  tool.onMouseUp(context, data, 1, 1);
  expect(context.setSelectionMask).toHaveBeenLastCalledWith(['11', '10']);
  tool.flip(context, data);
  expect(context.setSelectionMask).toHaveBeenLastCalledWith(['11', '01']);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [green, red, blue],
    [clear, blue, clear],
  ]);
});

it('writes paint that floated off the paintable area as soon as a drag lands all of it', () => {
  const { data, context, tool, select } = fixture(
    [[red, clear, clear, clear]],
    [0, 0, 2, 0],
  );
  select([0, 0, 0, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 3, 0);
  expect(tool.isFloating()).toBe(true);
  expect(send).not.toHaveBeenCalled();
  // Back where it all fits, it's written at once, as a move that lands is.
  tool.onMouseDown(context, data, 3, 0);
  tool.onMouseUp(context, data, 1, 0);
  expect(tool.isFloating()).toBe(false);
  expect(send).toHaveBeenCalledTimes(1);
  expect(placed()).toEqual([
    [0, 0, clear],
    [1, 0, red],
  ]);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([1, 0, 1, 0]);
  // Pasted and turned paint keep floating wherever they land, until the marquee goes away.
  tool.copy(context, data);
  tool.paste(context, data);
  tool.onMouseDown(context, data, 1, 0);
  tool.onMouseUp(context, data, 2, 0);
  tool.rotate(context, data, 1);
  tool.onMouseDown(context, data, 2, 0);
  tool.onMouseUp(context, data, 0, 0);
  expect(tool.isFloating()).toBe(true);
  expect(send).toHaveBeenCalledTimes(1);
});

it('previews a move across region gaps without committing or losing floating pixels', () => {
  const frame = [[red, green, clear, clear, clear, clear]];
  const { data, context, tool, select } = fixture(frame);
  data.selectionPreview = true;
  context.drawMask = ['110011'];
  select([0, 0, 1, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseMove(context, data, 1, 0);
  expect(send).not.toHaveBeenCalled();
  tool.onMouseUp(context, data, 1, 0);
  expect(tool.isFloating()).toBe(true);
  expect(send).toHaveBeenCalledTimes(1);
  expect(send.mock.calls[0][0]).toBe('previewSelection');
  // Only the paint on a body region enters the thumbnail; the shaded green pixel still floats.
  expect(placed()).toEqual([
    [0, 0, clear],
    [1, 0, red],
  ]);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, red, green, clear, clear, clear],
  ]);
  expect(frame).toEqual([[red, green, clear, clear, clear, clear]]);
  // Repositioning onto the other region keeps both original pixels and commits one history step.
  tool.onMouseDown(context, data, 1, 0);
  expect(send.mock.calls[1]).toEqual([
    'previewSelection',
    { transaction: null },
  ]);
  tool.onMouseUp(context, data, 4, 0);
  expect(tool.isFloating()).toBe(false);
  expect(send.mock.calls[2][0]).toBe('spriteEditorCommand');
  expect(placed(2)).toEqual([
    [0, 0, clear],
    [1, 0, clear],
    [4, 0, red],
    [5, 0, green],
  ]);
  expect(send).toHaveBeenCalledTimes(3);
});

it.each([
  'cancel',
  'direction',
  'layer',
] as const)('clears a temporary character preview on %s without committing floating paint', (reason) => {
  const { data, context, tool, select } = fixture([[red, green, clear]]);
  data.selectionPreview = true;
  context.drawMask = ['110'];
  select([0, 0, 1, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseUp(context, data, 1, 0);
  send.mockClear();
  if (reason === 'cancel') {
    tool.cancel(context);
  } else {
    if (reason === 'direction') context.selectedDir = Dir.NORTH;
    if (reason === 'layer') context.selectedLayer = 1;
    tool.reconcile(context, data);
  }
  expect(tool.isFloating()).toBe(false);
  expect(send.mock.calls).toEqual([
    ['previewSelection', { transaction: null }],
  ]);
});

const hairInfo = (height: number, origin: [number, number] = [0, 0]) => ({
  source: 'hair-editor',
  style: 'Test hair',
  origin,
  height,
});

it('copies selected base hair beneath custom paint without writing until paste is dropped', () => {
  const { tool, data, context, select } = fixture([[clear, red, clear, clear]]);
  data.baseCopyInfo = hairInfo(1);
  select([0, 0, 2, 0]);
  expect(tool.copyBaseLayer(context, data)).toBe(true);
  expect(send).toHaveBeenLastCalledWith('copyBaseLayer', {
    request: 1,
    dir: '2',
    rect: [0, 0, 2, 0],
    mask: undefined,
  });
  expect(
    tool.receiveBaseCopy({
      request: 1,
      source: 'hair-editor',
      origin: [0, 0],
      width: 4,
      height: 1,
      palette: [clear, blue, green],
      codes: '1120',
    }),
  ).toBe(true);
  expect(send).toHaveBeenCalledTimes(1);
  send.mockClear();
  expect(tool.paste(context, data)).toBe(true);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [blue, red, green, clear],
  ]);
  expect(send).not.toHaveBeenCalled();
  tool.release(context);
  expect(placed()).toEqual([
    [0, 0, blue],
    [2, 0, green],
  ]);
  expect(send.mock.calls[0][1].transaction).toMatchObject({
    baseCopy: 1,
    baseCopySource: 'hair-editor',
  });
});

it('keeps selection holes out of base-hair copies', () => {
  const { tool, data, context, select } = fixture([
    [clear, clear, clear, clear],
  ]);
  data.baseCopyInfo = hairInfo(1);
  select([0, 0, 2, 0]);
  tool.onMouseDown(context, data, 1, 0, true);
  tool.onMouseUp(context, data, 1, 0);
  tool.copyBaseLayer(context, data);
  expect(send.mock.calls[0][1].mask).toEqual(['101']);
  tool.receiveBaseCopy({
    request: 1,
    source: 'hair-editor',
    origin: [0, 0],
    width: 4,
    height: 1,
    palette: [clear, blue],
    codes: '1110',
  });
  send.mockClear();
  tool.paste(context, data);
  tool.release(context);
  expect(placed()).toEqual([
    [0, 0, blue],
    [2, 0, blue],
  ]);
});

it('does not let a delayed base response replace a later ordinary copy', () => {
  const { tool, data, context, select } = fixture([[red, clear, clear, clear]]);
  data.baseCopyInfo = hairInfo(1);
  select([0, 0, 1, 0]);
  tool.copyBaseLayer(context, data);
  tool.copy(context, data);
  expect(
    tool.receiveBaseCopy({
      request: 1,
      source: 'hair-editor',
      origin: [0, 0],
      width: 4,
      height: 1,
      palette: [clear, blue],
      codes: '1100',
    }),
  ).toBe(false);
  data.layers[0].data[Dir.SOUTH] = [[clear, clear, clear, clear]];
  send.mockClear();
  tool.paste(context, data);
  tool.release(context);
  expect(placed()).toEqual([[0, 0, red]]);
  expect(send.mock.calls[0][1].transaction.baseCopy).toBeUndefined();
});

it('preserves hair placement through a lifted style changing to a tall bald canvas', () => {
  const rows = Array.from({ length: 32 }, () => Array(32).fill(clear));
  const { tool, data, context, select } = fixture(rows);
  data.baseCopyInfo = hairInfo(32, [1, 16]);
  select([3, 20, 3, 20]);
  tool.copyBaseLayer(context, data);
  const codes = Array(1024).fill('0');
  codes[20 * 32 + 3] = '1';
  tool.receiveBaseCopy({
    request: 1,
    source: 'hair-editor',
    origin: [1, 16],
    width: 32,
    height: 32,
    palette: [clear, blue],
    codes: codes.join(''),
  });
  data.height = 48;
  data.layers[0].data[Dir.SOUTH] = Array.from({ length: 48 }, () =>
    Array(32).fill(clear),
  );
  data.baseCopyInfo = { ...hairInfo(48, [1, 0]), style: 'Bald (Tall Canvas)' };
  send.mockClear();
  tool.paste(context, data);
  tool.release(context);
  expect(placed()).toEqual([[3, 20, blue]]);
});

it('refuses a base paste that would clip hair and keeps its clipboard for a taller destination', () => {
  const { tool, data, context, select } = fixture([
    [clear, clear, clear, clear],
  ]);
  data.baseCopyInfo = hairInfo(1, [0, 2]);
  select([0, 0, 1, 0]);
  tool.copyBaseLayer(context, data);
  tool.receiveBaseCopy({
    request: 1,
    source: 'hair-editor',
    origin: [0, 2],
    width: 4,
    height: 1,
    palette: [clear, blue],
    codes: '1000',
  });
  data.baseCopyInfo = hairInfo(1);
  send.mockClear();
  tool.paste(context, data);
  expect(tool.isFloating()).toBe(false);
  expect(send).toHaveBeenLastCalledWith('baseCopyProblem', {
    problem: 'bounds',
  });
  data.height = 3;
  data.layers[0].data[Dir.SOUTH] = Array.from({ length: 3 }, () =>
    Array(4).fill(clear),
  );
  data.baseCopyInfo = hairInfo(3);
  send.mockClear();
  tool.paste(context, data);
  tool.release(context);
  expect(placed()).toEqual([[0, 0, blue]]);
});

it('leaves base copying disabled for other editors and rejects cross-editor base pastes', () => {
  const { tool, data, context, select } = fixture([
    [clear, clear, clear, clear],
  ]);
  select([0, 0, 1, 0]);
  expect(tool.copyBaseLayer(context, data)).toBe(false);
  expect(send).not.toHaveBeenCalled();
  data.baseCopyInfo = hairInfo(1);
  tool.copyBaseLayer(context, data);
  tool.receiveBaseCopy({
    request: 1,
    source: 'hair-editor',
    origin: [0, 0],
    width: 4,
    height: 1,
    palette: [clear, blue],
    codes: '1000',
  });
  data.baseCopyInfo = undefined;
  send.mockClear();
  tool.paste(context, data);
  expect(tool.isFloating()).toBe(false);
  expect(send).toHaveBeenLastCalledWith('baseCopyProblem', {
    problem: 'context',
  });
});

it('previews copied base markings with their trusted token before a normal undoable drop', () => {
  const { tool, data, context, select } = fixture([[clear, red, clear, clear]]);
  data.baseCopyInfo = { source: 'marking-editor', origin: [0, 0], height: 1 };
  data.selectionPreview = true;
  context.drawMask = ['1110'];
  select([0, 0, 2, 0]);
  tool.copyBaseLayer(context, data);
  tool.receiveBaseCopy({
    request: 1,
    source: 'marking-editor',
    origin: [0, 0],
    width: 4,
    height: 1,
    palette: [clear, blue, green],
    codes: '1120',
  });
  send.mockClear();
  tool.paste(context, data);
  expect(send).toHaveBeenCalledTimes(1);
  expect(send).toHaveBeenLastCalledWith('previewSelection', {
    transaction: expect.objectContaining({
      baseCopy: 1,
      baseCopySource: 'marking-editor',
      dir: '2',
      palette: [blue, green],
    }),
  });
  expect(data.layers[0].data[Dir.SOUTH]).toEqual([[clear, red, clear, clear]]);
  tool.release(context);
  expect(send).toHaveBeenCalledWith('spriteEditorCommand', {
    command: 'transaction',
    transaction: expect.objectContaining({
      baseCopy: 1,
      baseCopySource: 'marking-editor',
    }),
  });
});

it('keeps a base clipboard when destination regions become locked instead of clipping its pixels', () => {
  const { tool, data, context, select } = fixture([
    [clear, clear, clear, clear],
  ]);
  data.baseCopyInfo = { source: 'marking-editor', origin: [0, 0], height: 1 };
  context.drawMask = ['1110'];
  select([0, 0, 1, 0]);
  tool.copyBaseLayer(context, data);
  tool.receiveBaseCopy({
    request: 1,
    source: 'marking-editor',
    origin: [0, 0],
    width: 4,
    height: 1,
    palette: [clear, blue],
    codes: '1100',
  });
  context.drawMask = ['1000'];
  send.mockClear();
  expect(tool.paste(context, data)).toBe(true);
  expect(tool.isFloating()).toBe(false);
  expect(send).toHaveBeenLastCalledWith('baseCopyProblem', {
    problem: 'bounds',
  });
  context.drawMask = ['1110'];
  send.mockClear();
  expect(tool.paste(context, data)).toBe(true);
  tool.release(context);
  expect(placed()).toEqual([
    [0, 0, blue],
    [1, 0, blue],
  ]);
});

it('keeps humanoid body coordinates centered when a wide marking copy is pasted on a narrow canvas', () => {
  const frame = [Array(64).fill(clear)];
  const { tool, data, context, select } = fixture(frame);
  data.baseCopyInfo = { source: 'marking-editor', origin: [0, 0], height: 1 };
  select([16, 0, 16, 0]);
  tool.copyBaseLayer(context, data);
  tool.receiveBaseCopy({
    request: 1,
    source: 'marking-editor',
    origin: [0, 0],
    width: 64,
    height: 1,
    palette: [clear, blue],
    codes: `${'0'.repeat(16)}1${'0'.repeat(47)}`,
  });
  data.width = 32;
  data.layers[0].data[Dir.SOUTH] = [Array(32).fill(clear)];
  send.mockClear();
  tool.paste(context, data);
  tool.release(context);
  expect(placed()).toEqual([[0, 0, blue]]);
});
