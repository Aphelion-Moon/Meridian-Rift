// THIS IS AN APHELION UI FILE
// Test support shared by the custom sprite editor's test files. It lives here, outside
// interfaces/, so the interface bundle never picks it up.
import { afterEach, beforeEach, jest, spyOn } from 'bun:test';
import * as actions from 'tgui/events/act';
import {
  store as backendStore,
  gameDataAtom,
  suspendedAtom,
} from 'tgui/events/store';
import {
  releaseHeldKeys,
  startKeyPassthrough,
  stopKeyPassthrough,
} from 'tgui-core/hotkeys';
import {
  CANVAS_ALPHABET,
  type CompactSprite,
} from '../interfaces/common/CustomSpriteEditor/canvas';
import type { CustomSpriteEditorData } from '../interfaces/common/CustomSpriteEditor/types';
import {
  Dir,
  SpriteEditorToolFlags,
} from '../interfaces/common/SpriteEditor/Types/types';

/** Four views of `width` by `height` white pixels, as SpriteEditor holds them, for tests that set pixels. */
export const fixtureFrames = (width = 32, height = 32) => {
  const frame = () =>
    Array.from({ length: height }, () => Array(width).fill('#ffffffff'));
  return {
    [Dir.SOUTH]: frame(),
    [Dir.NORTH]: frame(),
    [Dir.EAST]: frame(),
    [Dir.WEST]: frame(),
  };
};

/** Encodes frames the way the server does: every pixel value once, and each view as index codes. */
export const compactSprite = (
  width: number,
  height: number,
  frames: Partial<Record<Dir, string[][]>>,
): CompactSprite => {
  const palette: string[] = [];
  const indexes = new Map<string, number>();
  for (const frame of Object.values(frames)) {
    for (const row of frame ?? []) {
      for (const pixel of row) {
        if (!indexes.has(pixel)) {
          indexes.set(pixel, palette.length);
          palette.push(pixel);
        }
      }
    }
  }
  const digits = palette.length <= 64 ? 1 : palette.length <= 4096 ? 2 : 3;
  const code = (index: number) => {
    let text = '';
    for (let digit = 0; digit < digits; digit++) {
      text = CANVAS_ALPHABET[index % 64] + text;
      index = Math.floor(index / 64);
    }
    return text;
  };
  const views: Record<string, string> = {};
  for (const [dir, frame] of Object.entries(frames)) {
    views[dir] = (frame ?? [])
      .map((row) => row.map((pixel) => code(indexes.get(pixel)!)).join(''))
      .join('');
  }
  return {
    width,
    height,
    dirs: 4,
    backdrop: '',
    canvas: { palette, digits, views },
  };
};

export const fixture = (width = 32, height = 32): CustomSpriteEditorData => {
  return {
    candidate: null,
    editorData: {
      sprite: compactSprite(width, height, fixtureFrames(width, height)),
      undoStack: ['Pencil'],
      redoStack: [],
      toolFlags: SpriteEditorToolFlags.All,
      serverPalette: ['#ffffff'],
      serverSelectedColor: '#ffffff',
    },
    colorMode: 'literal',
    emissive: { 1: false, 2: false, 4: false, 8: false },
    emissiveAllowed: true,
    saveRevision: 0,
    customTint: '#ffffff',
    displayTint: '#ff0000',
    customPalette: [],
    availableColors: ['#ffffff'],
    maxCustomColors: 16,
    guides: { 1: '', 2: '', 4: '', 8: '' },
    previews: { 1: '', 2: '', 4: '', 8: '' },
    edited: { 1: false, 2: true, 4: false, 8: false },
    drawBounds: {
      1: [0, 0, width - 1, height - 1],
      2: [0, 0, width - 1, height - 1],
      4: [0, 0, width - 1, height - 1],
      8: [0, 0, width - 1, height - 1],
    },
  };
};

export let send: ReturnType<typeof spyOn>;
let getContext: ReturnType<typeof spyOn>;
/** Fill styles the mocked canvas has painted since it was last cleared. */
export const painted: string[] = [];

/** Registers the game data, act spy, canvas mock and key passthrough every editor test runs with. */
export const setupEditorTests = () => {
  let previousData: Record<string, unknown>;
  let previousSuspended: number | false;
  beforeEach(() => {
    previousData = backendStore.get(gameDataAtom);
    previousSuspended = backendStore.get(suspendedAtom);
    backendStore.set(suspendedAtom, false);
    backendStore.set(gameDataAtom, fixture());
    send = spyOn(actions, 'sendAct');
    startKeyPassthrough();
    const context = {
      fillStyle: '',
      clearRect: () => {
        painted.length = 0;
      },
      fillRect: () => {
        painted.push(context.fillStyle);
      },
    };
    getContext = spyOn(
      HTMLCanvasElement.prototype,
      'getContext',
    ).mockReturnValue(context as unknown as CanvasRenderingContext2D);
  });
  afterEach(() => {
    releaseHeldKeys();
    stopKeyPassthrough();
    jest.useRealTimers();
    send.mockRestore();
    getContext.mockRestore();
    backendStore.set(gameDataAtom, previousData);
    backendStore.set(suspendedAtom, previousSuspended);
  });
};
