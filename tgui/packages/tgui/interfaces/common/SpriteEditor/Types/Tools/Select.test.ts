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

it('moves hidden paint with the selection, but only onto the limb', () => {
  const frame = [[red, blue, clear, clear]];
  const { data, context, tool, select } = fixture(frame);
  context.drawMask = ['1011'];
  select([0, 0, 1, 0]);
  tool.onMouseDown(context, data, 0, 0);
  tool.onMouseMove(context, data, 1, 0);
  expect(context.setPreviewData).not.toHaveBeenCalled();
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
  tool.onMouseMove(context, data, 1, 0);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    Array(8).fill(clear),
    [clear, clear, blue, clear, clear, clear, clear, clear],
    [clear, clear, clear, clear, red, clear, clear, clear],
  ]);
  const updates = (context.setPreviewData as ReturnType<typeof mock>).mock.calls
    .length;
  tool.onMouseMove(context, data, 3, 0);
  expect(context.setPreviewData).toHaveBeenCalledTimes(updates);
  tool.onMouseUp(context, data, 1, 0);
  expect(send.mock.calls[0][1].transaction.rect).toEqual([0, 0, 2, 1]);
  expect(send.mock.calls[0][1].transaction.offset).toEqual([2, 1]);
  expect(frame[0][0]).toBe(blue);
});

it('clamps moved paint to drawing bounds even when the box includes shaded margins', () => {
  const { data, context, tool, select } = fixture(
    [[clear, clear, red, clear, clear, clear, clear, clear]],
    [2, 0, 5, 0],
  );
  select([1, 0, 2, 0]);
  tool.onMouseDown(context, data, 1, 0);
  tool.onMouseUp(context, data, 20, 0);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([4, 0, 5, 0]);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, clear, clear, clear, clear, red, clear, clear],
  ]);
  expect(send.mock.calls[0][1].transaction.offset).toEqual([3, 0]);
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

it('clamps the whole rectangle and its movement to editable bounds', () => {
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
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([2, 2, 3, 2]);
  expect(send).toHaveBeenLastCalledWith('spriteEditorCommand', {
    command: 'transaction',
    transaction: {
      type: 'move',
      name: 'Move selection',
      layer: 1,
      dir: '2',
      rect: [1, 1, 2, 1],
      offset: [1, 1],
    },
  });
});

it('reuses the preview at unchanged integer offsets and includes the release position', () => {
  const { data, context, tool, select } = fixture();
  select([0, 0, 0, 0]);
  tool.onMouseDown(context, data, 0.1, 0);
  tool.onMouseMove(context, data, 1.1, 0);
  const first = (context.setPreviewData as ReturnType<typeof mock>).mock
    .calls[0][0];
  tool.onMouseMove(context, data, 1.9, 0);
  expect(context.setPreviewData).toHaveBeenCalledTimes(1);
  tool.onMouseUp(context, data, 2, 0);
  expect(context.setPreviewData).toHaveBeenCalledTimes(2);
  expect(first).toEqual([[clear, red, blue, clear]]);
  expect(context.setPreviewData).toHaveBeenLastCalledWith([
    [clear, green, red, clear],
  ]);
  expect(send).toHaveBeenCalledTimes(1);
});

it('starts a new selection outside the old one and ignores out-of-canvas/right clicks', () => {
  const { data, context, tool, select } = fixture();
  select([0, 0, 0, 0]);
  select([2, 0, 3, 0]);
  expect(context.setSelectionBounds).toHaveBeenLastCalledWith([2, 0, 3, 0]);
  tool.onMouseDown(context, data, -1, 0);
  tool.onMouseDown(context, data, 1, 0, true);
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
