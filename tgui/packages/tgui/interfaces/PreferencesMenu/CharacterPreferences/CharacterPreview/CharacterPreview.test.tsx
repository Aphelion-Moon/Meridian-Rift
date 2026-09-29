// THIS IS AN APHELION UI FILE
import {
  afterAll,
  afterEach,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
} from 'bun:test';
import { act, cleanup, render } from '@testing-library/react';
import { getDefaultStore } from 'jotai';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';

import type { CharacterPreviewDrawing, ServerData } from '../../types';
import { ServerPrefs } from '../../useServerPrefs';
import { previewFit } from './drawing';
import { CharacterPreview } from './index';
import { previewTurnAtom, turnPreview } from './turn';

const tile: CharacterPreviewDrawing = {
  id: 1,
  species: 'human',
  image: 'data:image/png;base64,tile',
  width: 32,
  height: 32,
  x: 0,
  y: 0,
  frames: { north: 0, south: 32, east: 64, west: 96 },
};

describe('previewFit', () => {
  it('stands a character as large as the box is wide, all it draws centred', () => {
    // Drawn from its feet to 2px under the top of its tile.
    const fit = previewFit(tile, 272, 480, [8, 2, 24, 32]);

    expect(fit.scale).toBe(8);
    // The tile's centre across the middle; its floor 15 rows of 8 below the
    // middle, so the 30 drawn rows sit centred.
    expect(fit.x).toBe(136);
    expect(fit.y).toBe(240 + 15 * 8);
  });

  it('fits a tile, stood in the middle, until the drawing is known', () => {
    const fit = previewFit(undefined, 240, 300);

    expect(fit.scale).toBe(7);
    expect(fit.y).toBe(150 + 16 * 7);
  });

  it('fits a wide character by how far it reaches from its tile', () => {
    // A taur: 16px past each side of its tile.
    const taur = { ...tile, width: 64, x: 16 };

    expect(previewFit(taur, 272, 480, [0, 0, 64, 32]).scale).toBe(4);
  });

  it("fits what a tall character draws, not its frame's empty headroom", () => {
    const tallest = { ...tile, height: 64 };

    expect(previewFit(tallest, 272, 300).scale).toBe(4);
    expect(previewFit(tallest, 272, 300, [8, 30, 24, 64]).scale).toBe(8);
  });

  it('fits a grown character by what it draws once grown', () => {
    // Body size 1.25: 20px each side of the tile's centre, 40px tall.
    const grown = {
      ...tile,
      transform: [
        1.25, 0, 0, 0, 1.25, 4,
      ] as CharacterPreviewDrawing['transform'],
    };

    expect(previewFit(grown, 272, 480, [0, 0, 32, 32]).scale).toBe(6);
  });
});

describe('CharacterPreview', () => {
  /** Images that load at once, as a data URL does. */
  class LoadedImage extends EventTarget {
    set src(value: string) {
      queueMicrotask(() => this.dispatchEvent(new Event('load')));
    }
  }
  const RealImage = globalThis.Image;
  const realGetContext = HTMLCanvasElement.prototype.getContext;
  const sizes = {
    clientWidth: Object.getOwnPropertyDescriptor(
      HTMLElement.prototype,
      'clientWidth',
    ),
    clientHeight: Object.getOwnPropertyDescriptor(
      HTMLElement.prototype,
      'clientHeight',
    ),
  };
  /** The frame each canvas last drew, by where it was taken from the image. */
  let drawnFrom: Map<HTMLCanvasElement, number>;
  let previousData: unknown;

  const serverData = {
    background_state: {
      choices: ['floor'],
      tiles: { floor: 'data:image/png;base64,floor' },
    },
  } as unknown as ServerData;

  const setData = (data: Record<string, unknown>) =>
    backendStore.set(gameDataAtom, {
      character_preferences: { misc: { background_state: 'floor' } },
      ...data,
    } as never);

  const preview = (width?: string) => (
    <ServerPrefs.Provider value={serverData}>
      <CharacterPreview height="100%" width={width} />
    </ServerPrefs.Provider>
  );

  const renderPreview = (width?: string) => render(preview(width));

  const settle = () => act(async () => {});

  beforeAll(() => {
    globalThis.Image = LoadedImage as never;
    Object.defineProperty(HTMLElement.prototype, 'clientWidth', {
      configurable: true,
      get: () => 272,
    });
    Object.defineProperty(HTMLElement.prototype, 'clientHeight', {
      configurable: true,
      get: () => 480,
    });
    HTMLCanvasElement.prototype.getContext = function (
      this: HTMLCanvasElement,
    ) {
      return {
        imageSmoothingEnabled: true,
        clearRect: () => {},
        drawImage: (_image: unknown, left: number, top: number) => {
          if (top === 0) {
            drawnFrom.set(this, left);
          }
        },
        // Every pixel drawn.
        getImageData: (
          _x: number,
          _y: number,
          width: number,
          height: number,
        ) => ({
          data: new Uint8ClampedArray(width * height * 4).fill(255),
        }),
      };
    } as never;
  });

  afterAll(() => {
    globalThis.Image = RealImage;
    HTMLCanvasElement.prototype.getContext = realGetContext;
    for (const [name, descriptor] of Object.entries(sizes)) {
      if (descriptor) {
        Object.defineProperty(HTMLElement.prototype, name, descriptor);
      }
    }
  });

  beforeEach(() => {
    drawnFrom = new Map();
    previousData = backendStore.get(gameDataAtom);
  });

  afterEach(() => {
    cleanup();
    getDefaultStore().set(previewTurnAtom, 0);
    backendStore.set(gameDataAtom, previousData as never);
  });

  it('shows a wordless loader on the background until the first drawing comes', async () => {
    setData({});
    const view = renderPreview();
    await settle();

    const loader = view.container.querySelector('[role="progressbar"]');
    expect(loader?.getAttribute('aria-label')).toBe('Drawing your character');
    expect(view.container.textContent).toBe('');
    expect(view.container.querySelector('canvas')).toBeNull();
    // A tile of the background stands where the character will.
    const background = view.container.querySelector(
      '.CharacterPreview__background',
    ) as HTMLElement;
    expect(background.style.backgroundImage).toBe(
      'url("data:image/png;base64,floor")',
    );
    expect(background.style.backgroundSize).toBe('256px 256px');
    expect(background.style.backgroundPosition).toBe('8px 112px');
  });

  it('shows the drawing, and the loader over it only while a newer one is on its way', async () => {
    setData({ character_preview: tile });
    const view = renderPreview();
    await settle();

    const canvas = view.container.querySelector('canvas') as HTMLCanvasElement;
    expect(canvas.style.width).toBe('256px');
    expect(view.container.querySelector('[role="progressbar"]')).toBeNull();

    // tgui draws the whole window again with each update.
    setData({ character_preview: tile, character_preview_pending: 1 });
    view.rerender(preview());
    expect(view.container.querySelector('[role="progressbar"]')).not.toBeNull();
    // The drawing it has stays up underneath.
    expect(view.container.querySelector('canvas')).toBe(canvas);
  });

  it('turns every tab showing it together, and holds the turn for the next tab', async () => {
    setData({ character_preview: tile });
    const character = renderPreview();
    const loadout = renderPreview('240px');
    await settle();
    const canvases = () =>
      [character, loadout].map(
        (view) => view.container.querySelector('canvas') as HTMLCanvasElement,
      );
    expect(canvases().map((canvas) => drawnFrom.get(canvas))).toEqual([
      tile.frames.south,
      tile.frames.south,
    ]);

    act(() => getDefaultStore().set(turnPreview, false));
    expect(canvases().map((canvas) => drawnFrom.get(canvas))).toEqual([
      tile.frames.west,
      tile.frames.west,
    ]);

    act(() => getDefaultStore().set(turnPreview, true));
    act(() => getDefaultStore().set(turnPreview, true));
    // A tab opened now shows the character the way the others turned it.
    const augments = renderPreview('280px');
    await settle();
    const canvas = augments.container.querySelector(
      'canvas',
    ) as HTMLCanvasElement;
    expect(drawnFrom.get(canvas)).toBe(tile.frames.east);
  });
});
