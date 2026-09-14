// THIS IS AN APHELION UI FILE

import { afterEach, beforeEach, expect, it, jest, spyOn } from 'bun:test';
import { act, fireEvent, render, screen } from '@testing-library/react';
import { createStore, Provider } from 'jotai';
import * as actions from 'tgui/events/act';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';
import {
  currentColorAtom,
  currentToolAtom,
  previewDataAtom,
  previewLayerAtom,
  tools,
} from '../SpriteEditor/atoms';
import {
  colorToHexString,
  parseHexColorString,
} from '../SpriteEditor/colorSpaces';
import { Dir, SpriteEditorToolFlags } from '../SpriteEditor/Types/types';
import { CustomSpriteEditor } from './index';
import type { CustomSpriteEditorData } from './types';

const fixture = (): CustomSpriteEditorData => {
  const frame = () =>
    Array.from({ length: 32 }, () => Array(32).fill('#ffffffff'));
  return {
    bodyZone: null,
    bodyZoneLabel: null,
    editorData: {
      sprite: {
        width: 32,
        height: 32,
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
      1: [0, 0, 31, 31],
      2: [0, 0, 31, 31],
      4: [0, 0, 31, 31],
      8: [0, 0, 31, 31],
    },
    unsupportedZones: [],
  };
};

let send: ReturnType<typeof spyOn>;
let getContext: ReturnType<typeof spyOn>;
let previousData: Record<string, unknown>;
const painted: string[] = [];
beforeEach(() => {
  previousData = backendStore.get(gameDataAtom);
  backendStore.set(gameDataAtom, fixture());
  send = spyOn(actions, 'sendAct');
  const context = {
    fillStyle: '',
    clearRect: () => {
      painted.length = 0;
    },
    fillRect: () => {
      painted.push(context.fillStyle);
    },
  };
  getContext = spyOn(HTMLCanvasElement.prototype, 'getContext').mockReturnValue(
    context as unknown as CanvasRenderingContext2D,
  );
});
afterEach(() => {
  jest.useRealTimers();
  send.mockRestore();
  getContext.mockRestore();
  backendStore.set(gameDataAtom, previousData);
});

it.each([
  'hair',
  'markings',
] as const)('keeps %s emissive directions independent and waits for acknowledgement', (target) => {
  const store = createStore();
  const data = { ...fixture(), colorMode: 'tint' as const };
  backendStore.set(gameDataAtom, data);
  const view = render(
    <Provider store={store}>
      <CustomSpriteEditor target={target} />
    </Provider>,
  );
  const checkbox = () => screen.getByText('Emissive').closest('.Button')!;
  expect(checkbox().classList.contains('Button--selected')).toBe(false);
  fireEvent.click(checkbox());
  expect(send).toHaveBeenLastCalledWith('setEmissive', {
    dir: '2',
    enabled: true,
  });
  expect(checkbox().classList.contains('Button--selected')).toBe(false);
  backendStore.set(gameDataAtom, {
    ...data,
    emissive: { ...data.emissive, 2: true },
  });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target={target} />
    </Provider>,
  );
  expect(checkbox().classList.contains('Button--selected')).toBe(true);
  fireEvent.click(screen.getByText('Back'));
  expect(checkbox().classList.contains('Button--selected')).toBe(false);
  fireEvent.click(checkbox());
  expect(send).toHaveBeenLastCalledWith('setEmissive', {
    dir: '1',
    enabled: true,
  });
  backendStore.set(gameDataAtom, {
    ...data,
    emissive: { ...data.emissive, 1: true, 2: true },
  });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target={target} />
    </Provider>,
  );
  expect(checkbox().classList.contains('Button--selected')).toBe(true);
  fireEvent.click(screen.getByText(/^Front/));
  expect(checkbox().classList.contains('Button--selected')).toBe(true);
  fireEvent.click(screen.getByText('Color blending'));
  expect(
    screen
      .getByText('Blend with color')
      .closest('.Button')!
      .classList.contains('Button--selected'),
  ).toBe(true);
  expect(store.get(currentColorAtom)).toEqual({ r: 255, g: 255, b: 255, a: 1 });
  fireEvent.click(checkbox());
  expect(send).toHaveBeenLastCalledWith('setEmissive', {
    dir: '2',
    enabled: false,
  });
  backendStore.set(gameDataAtom, {
    ...data,
    emissive: { ...data.emissive, 1: true },
  });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target={target} />
    </Provider>,
  );
  expect(checkbox().classList.contains('Button--selected')).toBe(false);
  fireEvent.click(screen.getByText('Back'));
  expect(checkbox().classList.contains('Button--selected')).toBe(true);
  for (const label of ['Right', 'Left']) {
    fireEvent.click(screen.getByText(label));
    expect(checkbox().classList.contains('Button--selected')).toBe(false);
  }
  expect(send).toHaveBeenCalledTimes(3);
});

it('disables the emissive control when the character does not allow emissive appearance', () => {
  backendStore.set(gameDataAtom, { ...fixture(), emissiveAllowed: false });
  render(
    <Provider store={createStore()}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  const checkbox = screen.getByText('Emissive').closest('.Button')!;
  expect(checkbox.classList.contains('Button--disabled')).toBe(true);
  fireEvent.click(checkbox);
  expect(send).not.toHaveBeenCalled();
});

it('shows temporary save feedback only after acknowledgment and resets it on reopen', () => {
  jest.useFakeTimers();
  const store = createStore();
  const editor = (
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>
  );
  const view = render(editor);
  fireEvent.keyDown(document, { key: 's', ctrlKey: true });
  expect(send).toHaveBeenLastCalledWith('saveDraft');
  expect(screen.queryByText('Saved')).toBeNull();
  backendStore.set(gameDataAtom, { ...fixture(), saveRevision: 1 });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  expect(screen.getByRole('status').textContent).toBe('Saved');
  act(() => jest.advanceTimersByTime(1500));
  backendStore.set(gameDataAtom, { ...fixture(), saveRevision: 2 });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  act(() => jest.advanceTimersByTime(1500));
  expect(screen.getByRole('status').textContent).toBe('Saved');
  act(() => jest.advanceTimersByTime(501));
  expect(screen.queryByText('Saved')).toBeNull();
  view.unmount();
  render(editor);
  expect(screen.queryByText('Saved')).toBeNull();
});

it('shows failed saves without a success flash and allows retry', () => {
  const store = createStore();
  const editor = (
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>
  );
  const view = render(editor);
  backendStore.set(gameDataAtom, { ...fixture(), saveRevision: 1 });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  expect(screen.getByRole('status').textContent).toBe('Saved');
  const saveError = "Couldn't save to disk. Press Ctrl+S to retry.";
  backendStore.set(gameDataAtom, { ...fixture(), saveRevision: 1, saveError });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  expect(screen.queryByText('Saved')).toBeNull();
  expect(screen.getByRole('alert').textContent).toBe(saveError);
  fireEvent.keyDown(document, { key: 's', ctrlKey: true });
  expect(send).toHaveBeenLastCalledWith('saveDraft');
  backendStore.set(gameDataAtom, { ...fixture(), saveRevision: 2 });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  expect(screen.queryByRole('alert')).toBeNull();
  expect(screen.getByRole('status').textContent).toBe('Saved');
});

it('tints only custom swatches and selects their effective color after server acknowledgement', () => {
  const store = createStore();
  const data = {
    ...fixture(),
    customPalette: ['#808080'],
    availableColors: ['#ffffff', '#808080', '#800000'],
  };
  backendStore.set(gameDataAtom, data);
  const view = render(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  expect(
    painted.map((color) => colorToHexString(parseHexColorString(color))),
  ).toContain('#ffffffff');
  expect(screen.queryByText('Blend with hair color')).toBeNull();
  fireEvent.click(screen.getByText('Color blending'));
  expect(
    screen
      .getByText('Blend with hair color')
      .closest('.Button')!
      .classList.contains('Button--selected'),
  ).toBe(false);
  expect(
    screen
      .getByText('Blend with color')
      .closest('.Button')!
      .classList.contains('Button--selected'),
  ).toBe(false);
  fireEvent.click(screen.getByText('Blend with hair color'));
  expect(send).toHaveBeenLastCalledWith('setColorMode', { mode: 'hair' });
  backendStore.set(gameDataAtom, { ...data, colorMode: 'hair' });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  expect(
    painted.map((color) => colorToHexString(parseHexColorString(color))),
  ).toContain('#ffffffff');
  expect(
    painted.map((color) => colorToHexString(parseHexColorString(color))),
  ).not.toContain('#ff0000ff');
  const swatches = view.container.querySelectorAll<HTMLElement>(
    '.SpriteEditor__plainSwatch',
  );
  expect(swatches[0].style.backgroundImage).toContain('#ffffff');
  expect(swatches[1].style.backgroundImage).toContain('#800000');
  fireEvent.click(swatches[1]);
  expect(send).toHaveBeenLastCalledWith('selectCustomColor', {
    color: '#808080',
  });
  expect(store.get(currentColorAtom)).toEqual({ r: 255, g: 255, b: 255, a: 1 });
  backendStore.set(gameDataAtom, {
    ...data,
    colorMode: 'hair',
    editorData: { ...data.editorData, serverSelectedColor: '#800000' },
  });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  expect(store.get(currentColorAtom)).toEqual({ r: 128, g: 0, b: 0, a: 1 });
  expect(swatches[1].getAttribute('aria-pressed')).toBe('true');
  fireEvent.click(screen.getByText('Blend with hair color'));
  expect(send).toHaveBeenLastCalledWith('setColorMode', { mode: 'literal' });
  fireEvent.click(screen.getByText('Blend with color'));
  expect(send).toHaveBeenLastCalledWith('setColorMode', { mode: 'tint' });
  expect(screen.queryByLabelText('Choose blending color')).toBeNull();
  backendStore.set(gameDataAtom, { ...data, colorMode: 'tint' });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  const picker = screen.getByLabelText('Choose blending color');
  expect(picker.classList.contains('SpriteEditor__plainSwatch')).toBe(true);
  expect(picker.style.backgroundImage).toContain('#ffffff');
  fireEvent.click(picker);
  expect(send).toHaveBeenLastCalledWith('pickTint');
  backendStore.set(gameDataAtom, {
    ...data,
    colorMode: 'tint',
    customTint: '#00ff00',
  });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  expect(
    screen.getByLabelText('Choose blending color').style.backgroundImage,
  ).toContain('#00ff00');
});

it('accepts the acknowledged custom brush when a mode change replaces available colors', () => {
  const store = createStore();
  const data = {
    ...fixture(),
    customPalette: ['#808080'],
    availableColors: ['#ffffff', '#808080'],
    editorData: { ...fixture().editorData, serverSelectedColor: '#808080' },
  };
  backendStore.set(gameDataAtom, data);
  const view = render(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  send.mockClear();
  backendStore.set(gameDataAtom, {
    ...data,
    colorMode: 'hair',
    availableColors: ['#ffffff', '#800000'],
    editorData: { ...data.editorData, serverSelectedColor: '#800000' },
  });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  expect(send).not.toHaveBeenCalled();
  expect(store.get(currentColorAtom)).toEqual({ r: 128, g: 0, b: 0, a: 1 });
  backendStore.set(gameDataAtom, {
    ...data,
    colorMode: 'tint',
    customTint: '#00ff00',
    displayTint: '#00ff00',
    availableColors: ['#ffffff', '#008000'],
    editorData: { ...data.editorData, serverSelectedColor: '#008000' },
  });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  expect(send).not.toHaveBeenCalled();
  expect(store.get(currentColorAtom)).toEqual({ r: 0, g: 128, b: 0, a: 1 });
  fireEvent.click(
    view.container.querySelectorAll('.SpriteEditor__plainSwatch')[1],
  );
  expect(send).toHaveBeenLastCalledWith('selectCustomColor', {
    color: '#808080',
  });
});

it('preserves the clicked saved color when two custom shades tint to the same RGB', () => {
  backendStore.set(gameDataAtom, {
    ...fixture(),
    colorMode: 'hair',
    customPalette: ['#801111', '#802222'],
    availableColors: ['#ffffff', '#800000'],
  });
  const view = render(
    <Provider store={createStore()}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  const swatches = view.container.querySelectorAll<HTMLElement>(
    '.SpriteEditor__plainSwatch',
  );
  expect(swatches[1].style.backgroundImage).toBe(
    swatches[2].style.backgroundImage,
  );
  fireEvent.click(swatches[2]);
  expect(send).toHaveBeenLastCalledWith('selectCustomColor', {
    color: '#802222',
  });
});

it('offers literal colors and tint for markings, and clears the selected direction', () => {
  render(
    <Provider store={createStore()}>
      <CustomSpriteEditor target="markings" />
    </Provider>,
  );
  fireEvent.click(screen.getByText('Color blending'));
  expect(screen.queryByText('Blend with hair color')).toBeNull();
  fireEvent.click(screen.getByText('Blend with color'));
  expect(send).toHaveBeenLastCalledWith('setColorMode', { mode: 'tint' });
  fireEvent.click(screen.getByText('Back'));
  fireEvent.click(screen.getByText('Clear layer'));
  expect(send).toHaveBeenLastCalledWith('clear', { dir: '1' });
});

it('loads the current direction guide, ignores stale loads, and reuses it after toggling Guide', () => {
  const images: HTMLImageElement[] = [];
  const OriginalImage = globalThis.Image;
  globalThis.Image = class extends OriginalImage {
    constructor() {
      super();
      images.push(this);
    }
  };
  let drawnGuide: string | undefined;
  getContext.mockReturnValue({
    clearRect: () => {
      drawnGuide = undefined;
    },
    fillRect: () => {},
    drawImage: (image: HTMLImageElement) => {
      drawnGuide = image.src;
    },
  } as unknown as CanvasRenderingContext2D);
  backendStore.set(gameDataAtom, {
    ...fixture(),
    guides: { 1: 'back.png', 2: 'front.png', 4: '', 8: '' },
  });
  try {
    const view = render(
      <Provider store={createStore()}>
        <CustomSpriteEditor target="hair" />
      </Provider>,
    );
    expect(images).toHaveLength(1);
    fireEvent.click(screen.getByText('Back'));
    expect(images).toHaveLength(2);
    fireEvent.load(images[0]);
    expect(drawnGuide).toBeUndefined();
    fireEvent.load(images[1]);
    expect(drawnGuide).toBe('back.png');
    fireEvent.click(screen.getByText('Guide'));
    expect(drawnGuide).toBeUndefined();
    fireEvent.click(screen.getByText('Guide'));
    expect(drawnGuide).toBe('back.png');
    expect(images).toHaveLength(2);
    view.unmount();
    expect(images[1].onload).toBeNull();
  } finally {
    globalThis.Image = OriginalImage;
  }
});

it.each([
  ['hair', null, null, 'Custom Hair'],
  ['markings', null, null, 'Custom Markings'],
  ['markings', 'l_arm', 'Left arm', 'Custom Left arm markings'],
] as const)('identifies the %s drawing scope for %s', (target, bodyZone, bodyZoneLabel, title) => {
  backendStore.set(gameDataAtom, { ...fixture(), bodyZone, bodyZoneLabel });
  render(
    <Provider store={createStore()}>
      <CustomSpriteEditor target={target} />
    </Provider>,
  );
  expect(screen.getByText(title)).toBeTruthy();
});

it('uses the selected direction limb silhouette to reject painting outside that limb', () => {
  const drawMask = {
    [Dir.SOUTH]: [
      '01000000000000000000000000000000',
      ...Array(31).fill('0'.repeat(32)),
    ],
    [Dir.NORTH]: [
      '00100000000000000000000000000000',
      ...Array(31).fill('0'.repeat(32)),
    ],
  };
  backendStore.set(gameDataAtom, {
    ...fixture(),
    bodyZone: 'l_arm',
    bodyZoneLabel: 'Left arm',
    drawMask,
  });
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  try {
    const view = render(
      <Provider store={createStore()}>
        <CustomSpriteEditor target="markings" />
      </Provider>,
    );
    const canvas = view.container.querySelector('canvas')!;
    const paint = (x: number) => {
      fireEvent.mouseDown(canvas, {
        clientX: x * 10 + 5,
        clientY: 5,
        button: 0,
      });
      fireEvent.mouseUp(window, { clientX: x * 10 + 5, clientY: 5, button: 0 });
    };
    send.mockClear();
    paint(0);
    expect(send).not.toHaveBeenCalled();
    paint(1);
    expect(send).toHaveBeenLastCalledWith('spriteEditorCommand', {
      command: 'transaction',
      transaction: {
        type: 'pencil',
        name: 'Pencil',
        layer: 1,
        dir: '2',
        color: '#ffffffff',
        points: [[1, 0]],
      },
    });
    fireEvent.click(screen.getByText('Back'));
    send.mockClear();
    paint(1);
    expect(send).not.toHaveBeenCalled();
    paint(2);
    expect(send.mock.calls[0][1].transaction.dir).toBe('1');
    expect(send.mock.calls[0][1].transaction.points).toEqual([[2, 0]]);
  } finally {
    getBounds.mockRestore();
  }
});

it('reopens with Pencil and clears the previous tool and optimistic stroke on close', () => {
  const store = createStore();
  const context = {
    setPreviewLayer: (value: number | undefined) =>
      store.set(previewLayerAtom, value),
    setPreviewData: (value: string[][] | undefined) =>
      store.set(previewDataAtom, value),
  };
  store.set(currentToolAtom, tools[2], context);
  const editor = (
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>
  );
  const view = render(editor);
  expect(store.get(currentToolAtom) === tools[0]).toBe(true);
  act(() => {
    store.set(currentToolAtom, tools[2], context);
    store.set(previewLayerAtom, 0);
    store.set(
      previewDataAtom,
      fixture().editorData.sprite.layers[0].data[Dir.SOUTH],
    );
  });
  view.unmount();
  expect(store.get(currentToolAtom) === tools[0]).toBe(true);
  expect(store.get(previewDataAtom)).toBeUndefined();
  expect(store.get(previewLayerAtom)).toBeUndefined();
  render(editor);
  expect(store.get(currentToolAtom) === tools[0]).toBe(true);
});
