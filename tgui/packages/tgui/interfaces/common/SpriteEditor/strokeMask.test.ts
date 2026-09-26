// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, expect, it, mock, spyOn } from 'bun:test';
import * as actions from 'tgui/events/act';
import { encodeStrokeMask } from './strokeMask';
import { Eraser } from './Types/Tools/Eraser';
import { Pencil } from './Types/Tools/Pencil';
import {
  Dir,
  type SpriteData,
  type SpriteEditorToolContext,
  type StringLayer,
} from './Types/types';

const alphabet =
  '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_';

/** Reads a stroke mask back into sorted "x,y" keys, as the server does. */
const unpack = (mask: string, width: number) => {
  const pixels: string[] = [];
  [...mask].forEach((character, cell) => {
    const bits = alphabet.indexOf(character);
    for (let bit = 0; bit < 6; bit++) {
      if (bits & (1 << bit)) {
        const index = cell * 6 + bit;
        pixels.push(`${index % width},${Math.floor(index / width)}`);
      }
    }
  });
  return pixels.sort();
};

const keys = (points: [number, number][]) =>
  points.map(([x, y]) => `${x},${y}`).sort();

let send: ReturnType<typeof spyOn>;
beforeEach(() => {
  send = spyOn(actions, 'sendAct');
});
afterEach(() => send.mockRestore());

const red = '#ff0000ff';
const clear = '#00000000';

/** A four by two canvas; the server's custom editors mark theirs compactStrokes. */
const canvas = (compactStrokes: boolean, fill = clear) => {
  const frame: StringLayer = [
    [fill, fill, fill, fill],
    [fill, fill, fill, fill],
  ];
  const data: SpriteData = {
    width: 4,
    height: 2,
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
    compactStrokes,
  };
  const context = {
    currentColor: { r: 255, g: 0, b: 0 },
    selectedDir: Dir.SOUTH,
    selectedLayer: 0,
    setCurrentColor: mock(),
    setPreviewLayer: mock(),
    setPreviewData: mock(),
    setSelectionBounds: mock(),
  } as unknown as SpriteEditorToolContext;
  return { data, context };
};

it('packs a stroke across a whole wide view into one short mask', () => {
  const points: [number, number][] = [];
  for (let y = 0; y < 32; y++) {
    for (let x = 0; x < 64; x++) points.push([x, y]);
  }
  const mask = encodeStrokeMask(points, 64, 32);
  expect(mask.length).toBe(342);
  expect(unpack(mask, 64)).toEqual(keys(points));
});

it('marks exactly the stroke pixels', () => {
  const points: [number, number][] = [
    [0, 0],
    [5, 0],
    [6, 0],
    [7, 12],
    [31, 31],
  ];
  expect(unpack(encodeStrokeMask(points, 32, 32), 32)).toEqual(keys(points));
});

it('sends pencil strokes as a mask only where the server reads one', () => {
  for (const compact of [true, false]) {
    send.mockClear();
    const { data, context } = canvas(compact);
    const pencil = new Pencil();
    pencil.onMouseDown(context, data, 1, 0, false);
    pencil.onMouseUp(context, data, 3, 0);
    const { transaction } = send.mock.calls[0][1];
    if (compact) {
      expect(transaction.points).toBeUndefined();
      expect(unpack(transaction.mask, 4)).toEqual(['1,0', '2,0', '3,0']);
    } else {
      expect(transaction.mask).toBeUndefined();
      expect(transaction.points).toEqual([
        [1, 0],
        [2, 0],
        [3, 0],
      ]);
    }
  }
});

it('sends eraser strokes as a mask where the server reads one', () => {
  const { data, context } = canvas(true, red);
  const eraser = new Eraser();
  eraser.onMouseDown(context, data, 0, 1, false);
  eraser.onMouseUp(context, data, 2, 1);
  const { transaction } = send.mock.calls[0][1];
  expect(transaction.type).toBe('eraser');
  expect(unpack(transaction.mask, 4)).toEqual(['0,1', '1,1', '2,1']);
});
