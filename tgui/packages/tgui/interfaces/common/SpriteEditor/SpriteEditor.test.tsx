// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it, spyOn } from 'bun:test';
import * as actions from 'tgui/events/act';
import { Eraser } from './Types/Tools/Eraser';
import { Pencil } from './Types/Tools/Pencil';
import {
  Dir,
  type SpriteData,
  type SpriteEditorToolContext,
} from './Types/types';

describe('sprite editor interactions', () => {
  let send: ReturnType<typeof spyOn>;
  beforeEach(() => {
    send = spyOn(actions, 'sendAct');
  });
  afterEach(() => {
    send.mockRestore();
  });

  it('erases existing paint outside the bounds without reaching unpainted shaded pixels', () => {
    const frame = Array.from({ length: 32 }, () => Array(32).fill('#00000000'));
    frame[0][0] = '#ffffffff';
    for (let pixel = 8; pixel <= 23; pixel++) frame[pixel][pixel] = '#ffffffff';
    const data: SpriteData = {
      width: 32,
      height: 32,
      dirs: 1,
      backdrop: '',
      layers: [
        {
          name: 'Drawing',
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
      drawBounds: [8, 8, 23, 23],
      setCurrentColor: () => {},
      setPreviewLayer: () => {},
      setPreviewData: () => {},
    };
    const eraser = new Eraser();
    eraser.onMouseDown(context, data, 0, 0, false);
    eraser.onMouseUp(context, data, 31, 31);
    const points = send.mock.calls[0][1].transaction.points;
    expect(points).toHaveLength(17);
    expect(points[0]).toEqual([0, 0]);
    expect(points).not.toContainEqual([31, 31]);
  });

  it.each([
    Pencil,
  ])('clips forbidden pixels from previews and transactions for %p', (Tool) => {
    const initial = Tool === Pencil ? '#00000000' : '#ffffffff';
    const data: SpriteData = {
      width: 32,
      height: 32,
      dirs: 1,
      backdrop: '',
      layers: [
        {
          name: 'Drawing',
          visible: true,
          data: {
            [Dir.SOUTH]: Array.from({ length: 32 }, () =>
              Array(32).fill(initial),
            ),
            [Dir.NORTH]: undefined,
            [Dir.EAST]: undefined,
            [Dir.WEST]: undefined,
          },
        },
      ],
    };
    let preview: string[][] | undefined;
    const context: SpriteEditorToolContext = {
      currentColor: { r: 255, g: 255, b: 255 },
      selectedDir: Dir.SOUTH,
      selectedLayer: 0,
      drawBounds: [8, 8, 23, 23],
      setCurrentColor: () => {},
      setPreviewLayer: () => {},
      setPreviewData: (value) => {
        if (typeof value !== 'function') preview = value;
      },
    };
    const tool = new Tool();
    tool.onMouseDown(context, data, 0, 0, false);
    tool.onMouseUp(context, data, 5, 5);
    expect(send).not.toHaveBeenCalled();
    expect(preview).toBeUndefined();
    tool.onMouseDown(context, data, 0, 0, false);
    tool.onMouseUp(context, data, 31, 31);
    expect(send).toHaveBeenCalledTimes(1);
    const points = send.mock.calls[0][1].transaction.points;
    expect(points).toHaveLength(16);
    expect(points[0]).toEqual([8, 8]);
    expect(points[15]).toEqual([23, 23]);
    expect(preview?.[0][0]).toBe(initial);
    expect(preview?.[31][31]).toBe(initial);
    context.drawMask = Array.from({ length: 32 }, (_, y) =>
      Array.from({ length: 32 }, (_, x) =>
        x === y && x !== 12 ? '1' : '0',
      ).join(''),
    );
    send.mockClear();
    const maskedTool = new Tool();
    maskedTool.onMouseDown(context, data, 8, 8, false);
    maskedTool.onMouseUp(context, data, 23, 23);
    expect(send.mock.calls[0][1].transaction.points).toHaveLength(15);
    expect(send.mock.calls[0][1].transaction.points).not.toContainEqual([
      12, 12,
    ]);
    expect(preview?.[12][12]).toBe(initial);
  });
});
