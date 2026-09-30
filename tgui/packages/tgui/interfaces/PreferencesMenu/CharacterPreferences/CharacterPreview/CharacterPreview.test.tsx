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
import { act, cleanup, fireEvent, render } from '@testing-library/react';
import { getDefaultStore } from 'jotai';
import { Profiler } from 'react';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';

import type { CharacterPreviewDrawing, ServerData } from '../../types';
import { ServerPrefs } from '../../useServerPrefs';
import { type DrawnBounds, previewFit } from './drawing';
import { dragGesture, dragTurns, wheelZooms } from './gestures';
import { CharacterPreview } from './index';
import { createPreviewPan } from './pan';
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

  it('zooms a whole step at a time, from 1x to twice the fit, still centred', () => {
    const bounds = [8, 2, 24, 32] as const;
    const closer = previewFit(tile, 272, 480, [...bounds], 1);

    expect(closer.fitScale).toBe(8);
    expect(closer.scale).toBe(9);
    expect(closer.y).toBe(240 + 15 * 9);
    expect(previewFit(tile, 272, 480, [...bounds], 100).scale).toBe(16);
    expect(previewFit(tile, 272, 480, [...bounds], -100).scale).toBe(1);
  });

  it('pans as far as brings any part of what it draws to the middle, at any zoom', () => {
    const bounds: DrawnBounds = [8, 2, 24, 32];
    // 8px each side of the tile's centre, and 30 rows centred up and down.
    const across = { minX: -8, maxX: 8, minY: -15, maxY: 15 };

    expect(previewFit(tile, 272, 480, bounds).panBounds).toEqual(across);
    expect(previewFit(tile, 272, 480, bounds, 1).panBounds).toEqual(across);
    // A taur drawn from 32px left of its tile's centre to 8px right of it.
    const taur = { ...tile, width: 64, x: 16 };
    const wide = previewFit(taur, 272, 480, [0, 0, 40, 32]).panBounds;
    expect([wide.minX, wide.maxX]).toEqual([-8, 32]);
  });
});

describe('dragTurns and wheelZooms', () => {
  it('turns a quarter per step of drag, the front following the pointer', () => {
    expect(dragTurns(39)).toEqual({ turns: 0, rest: 39 });
    // Dragging right turns the front to the right: anticlockwise from above.
    expect(dragTurns(95)).toEqual({ turns: -2, rest: 15 });
    expect(dragTurns(-45)).toEqual({ turns: 1, rest: -5 });
  });

  it('zooms a step per wheel notch, wheeling up zooming in', () => {
    expect(wheelZooms(-100)).toEqual({ zooms: 1, rest: 0 });
    expect(wheelZooms(250)).toEqual({ zooms: -2, rest: 50 });
    expect(wheelZooms(-60)).toEqual({ zooms: 0, rest: -60 });
  });

  it("lets a drag's first few pixels decide: across turns, up or down pans", () => {
    expect(dragGesture(3, 4)).toBeUndefined();
    expect(dragGesture(-6, 0)).toBeUndefined();
    expect(dragGesture(7, -2)).toBe('turn');
    expect(dragGesture(-2, 7)).toBe('pan');
    expect(dragGesture(1, -9)).toBe('pan');
    // Exactly diagonal turns, as dragging did before panning.
    expect(dragGesture(5, 5)).toBe('turn');
  });
});

/** How far a part of the preview in this box has been moved, or '' if it hasn't. */
const movedBy = (box: HTMLElement, part: string) =>
  (
    box.querySelector(`.CharacterPreview__${part}`) as HTMLElement
  ).style.getPropertyValue('translate');

describe('createPreviewPan', () => {
  const across = { minX: -8, maxX: 8, minY: -15, maxY: 15 };
  const part = (tag: string, name: string) => {
    const element = document.createElement(tag);
    element.className = `CharacterPreview__${name}`;
    return element;
  };
  const panned = () => {
    const element = document.createElement('div');
    element.append(part('span', 'background'), part('canvas', 'figure'));
    const pan = createPreviewPan({ current: element });
    const moved = (name: string) => movedBy(element, name);
    return { element, pan, moved };
  };

  it('moves the drawing with the pointer, in whole pixels, as far as its bounds', () => {
    const { pan, moved } = panned();
    pan.place(8, across);
    pan.start(100, 100);
    pan.move(123, 70);
    expect(moved('figure')).toBe('23px -30px');
    // The floor moves by the same, less whole tiles.
    expect(moved('background')).toBe('23px 226px');

    // Past the bounds it stops, and comes back as soon as the pointer does.
    pan.move(400, -400);
    expect(moved('figure')).toBe('64px -120px');
    pan.move(99, 101);
    expect(moved('figure')).toBe('-1px 1px');
  });

  it('keeps what is at the middle there through a zoom, even mid-pan', () => {
    const { pan, moved } = panned();
    pan.place(8, across);
    pan.start(0, 0);
    pan.move(40, 0);
    pan.place(9, across);
    expect(moved('figure')).toBe('45px 0px');
    // From the zoom on, the drawing keeps up with the pointer at 9x.
    pan.move(49, 0);
    expect(moved('figure')).toBe('54px 0px');
    pan.end();

    // Bounds that shrink take it back within them.
    pan.place(9, { ...across, maxX: 2 });
    expect(moved('figure')).toBe('18px 0px');
    // Back in the middle, nothing is moved at all.
    pan.reset();
    expect([moved('figure'), moved('background')]).toEqual(['', '']);
  });

  it('moves parts a render drew anew', () => {
    const { element, pan, moved } = panned();
    pan.place(8, across);
    pan.start(0, 0);
    pan.move(16, 8);
    pan.end();
    element
      .querySelector('.CharacterPreview__figure')
      ?.replaceWith(part('canvas', 'figure'));
    expect(moved('figure')).toBe('');

    pan.place(8, across);
    expect(moved('figure')).toBe('16px 8px');
  });

  it('takes hold only of a placed drawing, and marks the box while it pans', () => {
    const { element, pan, moved } = panned();
    pan.start(0, 0);
    pan.move(50, 50);
    expect(element.hasAttribute('data-panning')).toBe(false);
    expect(moved('figure')).toBe('');

    pan.place(8, across);
    pan.start(0, 0);
    expect(element.hasAttribute('data-panning')).toBe(true);
    pan.end();
    expect(element.hasAttribute('data-panning')).toBe(false);
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

  /** The preview's box in a rendered view. */
  const boxOf = (view: ReturnType<typeof render>) =>
    view.container.querySelector('.CharacterPreview') as HTMLElement;

  /** The pointer goes down on the box here. */
  const press = (box: HTMLElement, clientX: number, clientY = 0) =>
    fireEvent.pointerDown(box, { pointerId: 1, button: 0, clientX, clientY });

  /** Wheels over the box, returning the event to see whether it was handled. */
  const wheel = (box: HTMLElement, deltaY: number) => {
    const event = new WheelEvent('wheel', {
      deltaY,
      bubbles: true,
      cancelable: true,
    });
    act(() => {
      box.dispatchEvent(event);
    });
    return event;
  };

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
    // A tile past the box above and to the left, for a pan to move it into.
    expect([background.style.top, background.style.left]).toEqual([
      '-256px',
      '-256px',
    ]);
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

  it('turns with a drag, a quarter per step, until the pointer lets go', async () => {
    setData({ character_preview: tile });
    const view = renderPreview();
    await settle();
    const box = boxOf(view);
    const canvas = () =>
      view.container.querySelector('canvas') as HTMLCanvasElement;

    act(() => {
      press(box, 100);
      fireEvent.pointerMove(box, { pointerId: 1, clientX: 130 });
    });
    // Short of a step: nothing turns.
    expect(drawnFrom.get(canvas())).toBe(tile.frames.south);

    act(() => {
      fireEvent.pointerMove(box, { pointerId: 1, clientX: 145 });
    });
    // Dragged right a step: the front turns right, to face east.
    expect(drawnFrom.get(canvas())).toBe(tile.frames.east);

    act(() => {
      // Two steps back left, counting from where the last step ended.
      fireEvent.pointerMove(box, { pointerId: 1, clientX: 60 });
      fireEvent.pointerUp(box, { pointerId: 1 });
      fireEvent.pointerMove(box, { pointerId: 1, clientX: 400 });
    });
    expect(drawnFrom.get(canvas())).toBe(tile.frames.west);
    expect(getDefaultStore().get(previewTurnAtom)).toBe(1);
  });

  it('zooms a whole step per wheel notch without scrolling the page, and a double-click fits it again', async () => {
    setData({ character_preview: tile });
    const view = renderPreview();
    await settle();
    const box = boxOf(view);
    const width = () =>
      (view.container.querySelector('canvas') as HTMLCanvasElement).style.width;

    expect(width()).toBe('256px');
    expect(wheel(box, -100).defaultPrevented).toBe(true);
    expect(width()).toBe(`${9 * 32}px`);
    // Part of a notch waits for the rest.
    wheel(box, -60);
    expect(width()).toBe(`${9 * 32}px`);
    wheel(box, -40);
    expect(width()).toBe(`${10 * 32}px`);
    // Up to twice the fit and no further, and back out at once from there.
    for (let notch = 0; notch < 20; notch++) {
      wheel(box, -100);
    }
    expect(width()).toBe(`${16 * 32}px`);
    wheel(box, 100);
    expect(width()).toBe(`${15 * 32}px`);

    act(() => {
      fireEvent.doubleClick(box);
    });
    expect(width()).toBe('256px');
  });

  it('pans with a drag that sets off up or down, every way after, rendering nothing', async () => {
    setData({ character_preview: tile });
    let commits = 0;
    const view = render(
      <Profiler id="preview" onRender={() => commits++}>
        {preview()}
      </Profiler>,
    );
    await settle();
    const box = boxOf(view);
    const canvas = view.container.querySelector('canvas') as HTMLCanvasElement;
    const rendered = commits;

    act(() => {
      press(box, 100, 100);
      // Inside the slop, nothing is decided.
      fireEvent.pointerMove(box, { pointerId: 1, clientX: 102, clientY: 104 });
    });
    expect(box.hasAttribute('data-panning')).toBe(false);
    expect(movedBy(box, 'figure')).toBe('');

    act(() => {
      // Off downwards: it pans, from where the pointer went down.
      fireEvent.pointerMove(box, { pointerId: 1, clientX: 101, clientY: 110 });
    });
    expect(box.hasAttribute('data-panning')).toBe(true);
    expect(movedBy(box, 'figure')).toBe('1px 10px');

    act(() => {
      // From there it goes every way, across included, and never turns.
      for (let move = 1; move <= 20; move++) {
        fireEvent.pointerMove(box, {
          pointerId: 1,
          clientX: 101 + 3 * move,
          clientY: 110 - 2 * move,
        });
      }
    });
    expect(movedBy(box, 'figure')).toBe('61px -30px');
    expect(movedBy(box, 'background')).toBe('61px 226px');
    expect(drawnFrom.get(canvas)).toBe(tile.frames.south);
    expect(commits).toBe(rendered);

    act(() => {
      fireEvent.pointerUp(box, { pointerId: 1 });
    });
    expect(box.hasAttribute('data-panning')).toBe(false);
    expect(movedBy(box, 'figure')).toBe('61px -30px');
    expect(commits).toBe(rendered);
  });

  it('turns with a drag that sets off across, however it goes after', async () => {
    setData({ character_preview: tile });
    const view = renderPreview();
    await settle();
    const box = boxOf(view);
    const canvas = view.container.querySelector('canvas') as HTMLCanvasElement;

    act(() => {
      press(box, 100, 100);
      fireEvent.pointerMove(box, { pointerId: 1, clientX: 110, clientY: 102 });
      // Up and down from here only turns it, never pans.
      fireEvent.pointerMove(box, { pointerId: 1, clientX: 145, clientY: 180 });
    });
    expect(box.hasAttribute('data-panning')).toBe(false);
    expect(drawnFrom.get(canvas)).toBe(tile.frames.east);
    expect(movedBy(box, 'figure')).toBe('');
  });

  it('zooms about what a pan brought to the middle, and a double-click brings it back', async () => {
    setData({ character_preview: tile });
    const view = renderPreview();
    await settle();
    const box = boxOf(view);
    const canvas = view.container.querySelector('canvas') as HTMLCanvasElement;

    act(() => {
      press(box, 100, 100);
      fireEvent.pointerMove(box, { pointerId: 1, clientX: 100, clientY: 110 });
      // Past the drawing's edge, 16px from its tile's centre: it stops with
      // that edge at the middle.
      fireEvent.pointerMove(box, { pointerId: 1, clientX: 400, clientY: 116 });
      fireEvent.pointerUp(box, { pointerId: 1 });
    });
    expect(movedBy(box, 'figure')).toBe('128px 16px');

    wheel(box, -100);
    // At 9x, what was at the middle still is.
    expect(canvas.style.width).toBe(`${9 * 32}px`);
    expect(movedBy(box, 'figure')).toBe('144px 18px');
    expect(movedBy(box, 'background')).toBe('144px 18px');

    act(() => {
      fireEvent.doubleClick(box);
    });
    expect(canvas.style.width).toBe('256px');
    expect(movedBy(box, 'figure')).toBe('');
  });

  it("frames itself for the tab's motif, a portrait unless the tab says", async () => {
    setData({});
    const view = render(
      <ServerPrefs.Provider value={serverData}>
        <CharacterPreview height="100%" />
        <CharacterPreview height="100%" motif="mirror" />
      </ServerPrefs.Provider>,
    );
    await settle();
    const [portrait, mirror] =
      view.container.querySelectorAll('.CharacterPreview');

    expect(portrait.classList.contains('CharacterPreview--portrait')).toBe(
      true,
    );
    expect(mirror.classList.contains('CharacterPreview--mirror')).toBe(true);
    // Every theme builds its frame from the same parts; its styles pick them.
    const parts = (selector: string) =>
      mirror.querySelectorAll(selector).length;
    expect(parts('.CharacterPreview__case')).toBe(1);
    expect(parts('.CharacterPreview__trim')).toBe(1);
    expect(parts('.CharacterPreview__glass')).toBe(1);
    expect(parts('.CharacterPreview__mark')).toBe(4);
    expect(parts('.CharacterPreview__clip')).toBe(4);
  });

  it("lays the scanner's rule along the character's own tile, and keeps it there through zoom and pan", async () => {
    setData({ character_preview: tile });
    const view = render(
      <ServerPrefs.Provider value={serverData}>
        <CharacterPreview height="100%" motif="scanner" />
      </ServerPrefs.Provider>,
    );
    await settle();
    const box = boxOf(view);
    const rule = () =>
      view.container.querySelector('.CharacterPreview__rule') as HTMLElement;
    const placed = () => [
      rule().style.top,
      rule().style.height,
      rule().style.getPropertyValue('--preview-pixel'),
      rule().style.getPropertyValue('translate'),
    ];

    // At 8x the tile's floor is 368px down the 480px box, its top 256px above.
    expect(placed()).toEqual(['112px', '257px', '8px', '']);

    // Zoomed a step and panned, the character moves; the frame's rule doesn't.
    wheel(box, -100);
    act(() => {
      press(box, 100, 100);
      fireEvent.pointerMove(box, { pointerId: 1, clientX: 110, clientY: 140 });
      fireEvent.pointerUp(box, { pointerId: 1 });
    });
    expect(movedBy(box, 'figure')).toBe('10px 40px');
    expect(placed()).toEqual(['112px', '257px', '8px', '']);
  });
});
