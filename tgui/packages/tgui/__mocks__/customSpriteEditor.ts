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
import type { CustomSpriteEditorData } from '../interfaces/common/CustomSpriteEditor/types';
import {
  Dir,
  SpriteEditorToolFlags,
} from '../interfaces/common/SpriteEditor/Types/types';

export const fixture = (width = 32, height = 32): CustomSpriteEditorData => {
  const frame = () =>
    Array.from({ length: height }, () => Array(width).fill('#ffffffff'));
  return {
    bodyZone: null,
    bodyZoneLabel: null,
    candidate: null,
    editorData: {
      sprite: {
        width,
        height,
        dirs: 4,
        backdrop: '',
        layers: [
          {
            name: 'Drawing',
            visible: true,
            data: {
              [Dir.SOUTH]: frame(),
              [Dir.NORTH]: frame(),
              [Dir.EAST]: frame(),
              [Dir.WEST]: frame(),
            },
          },
        ],
      },
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
export let getContext: ReturnType<typeof spyOn>;
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
