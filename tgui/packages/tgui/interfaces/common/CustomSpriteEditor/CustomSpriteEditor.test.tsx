// THIS IS AN APHELION UI FILE

import { expect, it, jest, spyOn } from 'bun:test';
import { act, fireEvent, render, screen, within } from '@testing-library/react';
import { createStore, Provider } from 'jotai';
import { update } from 'tgui/events/handlers/update';
import {
  backendStateAtom,
  store as backendStore,
  gameDataAtom,
} from 'tgui/events/store';
import {
  compactSprite,
  fixture,
  fixtureFrames,
  getContext,
  painted,
  send,
  setupEditorTests,
} from '../../../__mocks__/customSpriteEditor';
import {
  currentColorAtom,
  currentToolAtom,
  dirAtom,
  previewDataAtom,
  previewLayerAtom,
  tools,
} from '../SpriteEditor/atoms';
import {
  colorToHexString,
  parseHexColorString,
} from '../SpriteEditor/colorSpaces';
import { Dir } from '../SpriteEditor/Types/types';
import { CustomSpriteEditor } from './index';
import type { CustomSpriteEditorData } from './types';

setupEditorTests();

it.each([
  'hair',
  'facial_hair',
  'markings',
] as const)('temporarily samples painted pixels and the guide with Alt+click in %s', (target) => {
  const frames = fixtureFrames();
  frames[Dir.SOUTH][0][0] = '#12abefff';
  frames[Dir.SOUTH][0][1] = '#00000000';
  const data = { ...fixture(), context: 'salon' };
  data.editorData.sprite = compactSprite(32, 32, frames);
  backendStore.set(gameDataAtom, data);
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  try {
    const store = createStore();
    const view = render(
      <Provider store={store}>
        <CustomSpriteEditor target={target} />
      </Provider>,
    );
    const canvas = view.container.querySelector('canvas')!;
    fireEvent.click(
      view.container.querySelector('.fa-eraser')!.closest('.Button')!,
    );
    const sample = (x: number) => {
      fireEvent.mouseDown(canvas, {
        clientX: x * 10 + 5,
        clientY: 5,
        button: 0,
        altKey: true,
      });
      // Releasing Alt during the gesture must not turn sampling into a stroke.
      fireEvent.mouseMove(window, { clientX: 35, clientY: 5 });
      fireEvent.mouseUp(window, { clientX: 35, clientY: 5, button: 0 });
    };
    send.mockClear();
    sample(0);
    expect(send.mock.calls).toEqual([['selectColor', { color: '#12abefff' }]]);
    expect(colorToHexString(store.get(currentColorAtom))).toBe('#12abefff');
    sample(1);
    expect(send).toHaveBeenLastCalledWith('sampleGuide', {
      dir: '2',
      x: 1,
      y: 0,
    });
    expect(send).toHaveBeenCalledTimes(2);
    expect(store.get(currentToolAtom)).toBe(tools[1]);
    expect(store.get(previewDataAtom)).toBeUndefined();
    fireEvent.click(screen.getByText('Guide'));
    sample(1);
    expect(send).toHaveBeenCalledTimes(2);
    fireEvent.mouseDown(canvas, { clientX: 5, clientY: 5, button: 0 });
    fireEvent.mouseUp(window, { clientX: 5, clientY: 5, button: 0 });
    expect(send).toHaveBeenLastCalledWith('spriteEditorCommand', {
      command: 'transaction',
      transaction: expect.objectContaining({ type: 'eraser' }),
    });
  } finally {
    getBounds.mockRestore();
  }
});

it('cycles available displayed swatches through canvas wheel and brackets, including pending custom selections', () => {
  const data = fixture();
  data.colorMode = 'tint';
  data.editorData.serverPalette = ['#ffffff', '#123456'];
  data.customPalette = ['#801111', '#802222', '#ff0000'];
  data.availableColors = ['#ffffff', '#123456', '#800000'];
  backendStore.set(gameDataAtom, data);
  const store = createStore();
  const view = render(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  const canvas = view.container.querySelector('canvas')!;
  expect(fireEvent.wheel(canvas, { deltaY: 100 })).toBe(false);
  expect(send).toHaveBeenLastCalledWith('selectColor', { color: '#123456ff' });
  fireEvent.keyDown(document, { key: ']' });
  expect(send).toHaveBeenLastCalledWith('selectCustomColor', {
    color: '#801111',
  });
  expect(colorToHexString(store.get(currentColorAtom))).toBe('#123456ff');
  fireEvent.keyDown(document, { key: ']' });
  expect(send).toHaveBeenLastCalledWith('selectCustomColor', {
    color: '#802222',
  });
  fireEvent.keyDown(document, { key: ']' });
  expect(send).toHaveBeenLastCalledWith('selectColor', { color: '#ffffffff' });
  // Backwards wrapping skips the unavailable red custom swatch.
  fireEvent.keyDown(document, { key: '[' });
  expect(send).toHaveBeenLastCalledWith('selectCustomColor', {
    color: '#802222',
  });
  const swatches = view.container.querySelectorAll(
    '.SpriteEditor__plainSwatch',
  );
  expect(fireEvent.wheel(swatches[0], { deltaY: -100 })).toBe(false);
  expect(send).toHaveBeenLastCalledWith('selectCustomColor', {
    color: '#801111',
  });
  // A click establishes the cursor even when multiple swatches share a tint.
  fireEvent.click(swatches[3]);
  fireEvent.keyDown(document, { key: ']' });
  expect(send).toHaveBeenLastCalledWith('selectColor', { color: '#ffffffff' });
});

it('leaves form input, dialogs, modified shortcuts and scrolling outside color controls alone', () => {
  const data = fixture();
  data.editorData.serverPalette.push('#123456');
  data.availableColors.push('#123456');
  backendStore.set(gameDataAtom, data);
  const view = render(
    <Provider store={createStore()}>
      <CustomSpriteEditor target="hair" />
      <input aria-label="Name" />
      <textarea aria-label="Notes" />
      <select aria-label="Choice">
        <option>One</option>
      </select>
      <div contentEditable suppressContentEditableWarning>
        <span>Editable text</span>
      </div>
    </Provider>,
  );
  for (const target of [
    screen.getByLabelText('Name'),
    screen.getByLabelText('Notes'),
    screen.getByLabelText('Choice'),
    screen.getByText('Editable text'),
  ]) {
    expect(fireEvent.keyDown(target, { key: ']' })).toBe(true);
    expect(fireEvent.wheel(target, { deltaY: 100 })).toBe(true);
  }
  const canvas = view.container.querySelector('canvas')!;
  for (const modifier of ['ctrlKey', 'altKey', 'metaKey', 'shiftKey']) {
    expect(fireEvent.keyDown(document, { key: ']', [modifier]: true })).toBe(
      true,
    );
    const wheel = new WheelEvent('wheel', {
      deltaY: 100,
      bubbles: true,
      cancelable: true,
    });
    // Happy DOM's WheelEvent omits the inherited MouseEvent modifier fields.
    Object.defineProperty(wheel, modifier, { value: true });
    expect(fireEvent(canvas, wheel)).toBe(true);
  }
  expect(fireEvent.wheel(canvas, { deltaY: 0, deltaX: 100 })).toBe(true);
  expect(fireEvent.wheel(screen.getByText('Preview'), { deltaY: 100 })).toBe(
    true,
  );
  const dialog = document.createElement('div');
  dialog.className = 'Modal';
  document.body.appendChild(dialog);
  try {
    expect(fireEvent.keyDown(document, { key: ']' })).toBe(true);
    expect(fireEvent.wheel(canvas, { deltaY: 100 })).toBe(true);
  } finally {
    dialog.remove();
  }
  expect(send).not.toHaveBeenCalled();
  view.unmount();
  expect(fireEvent.keyDown(document, { key: ']' })).toBe(true);
  expect(send).not.toHaveBeenCalled();
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
  fireEvent.click(screen.getByText('Blending options'));
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
  fireEvent.click(screen.getByText('Blending options'));
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
  fireEvent.click(screen.getByText('Blending options'));
  expect(screen.queryByText('Blend with hair color')).toBeNull();
  fireEvent.click(screen.getByText('Blend with color'));
  expect(send).toHaveBeenLastCalledWith('setColorMode', { mode: 'tint' });
  fireEvent.click(screen.getByText('Back'));
  fireEvent.click(screen.getByText('Clear layer'));
  expect(send).toHaveBeenLastCalledWith('clear', { dir: '1' });
});

it.each([
  [32, 320],
  [64, 640],
])('scales the %d-pixel-wide guide with the canvas and ignores stale loads', (width, canvasWidth) => {
  const images: HTMLImageElement[] = [];
  const OriginalImage = globalThis.Image;
  globalThis.Image = class extends OriginalImage {
    constructor() {
      super();
      images.push(this);
    }
  };
  let drawnGuide: string | undefined;
  let drawnSize: number[] | undefined;
  getContext.mockReturnValue({
    clearRect: () => {
      drawnGuide = undefined;
      drawnSize = undefined;
    },
    fillRect: () => {},
    drawImage: (image: HTMLImageElement, ...dimensions: number[]) => {
      drawnGuide = image.src;
      drawnSize = dimensions;
    },
  } as unknown as CanvasRenderingContext2D);
  backendStore.set(gameDataAtom, {
    ...fixture(width),
    guides: { 1: 'back.png', 2: 'front.png', 4: '', 8: '' },
  });
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 640, 320));
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
    expect(drawnSize).toEqual([0, 0, canvasWidth, 320]);
    const canvas = view.container.querySelector('canvas')!;
    expect(canvas.width).toBe(canvasWidth);
    expect(canvas.height).toBe(320);
    fireEvent.click(screen.getByText('Guide'));
    expect(drawnGuide).toBeUndefined();
    fireEvent.click(screen.getByText('Guide'));
    expect(drawnGuide).toBe('back.png');
    expect(images).toHaveLength(2);
    view.unmount();
    expect(images[1].onload).toBeNull();
  } finally {
    globalThis.Image = OriginalImage;
    getBounds.mockRestore();
  }
});

it('lets preview images retain their own proportions independently of canvas dimensions', () => {
  backendStore.set(gameDataAtom, {
    ...fixture(),
    previews: { 1: '', 2: 'wide-front.png', 4: '', 8: '' },
    candidate: {
      source: 'import',
      previews: {
        1: 'wide-back.png',
        2: 'wide-front.png',
        4: 'wide-right.png',
        8: 'wide-left.png',
      },
    },
  });
  render(
    <Provider store={createStore()}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  const preview = screen.getByAltText('Character with your drawing');
  expect(preview.getAttribute('width')).toBe('128');
  expect(preview.getAttribute('height')).toBeNull();
  expect(preview.style.height).toBe('auto');
  const candidate = screen.getByAltText('Left preview');
  expect(candidate.getAttribute('width')).toBe('96');
  expect(candidate.getAttribute('height')).toBeNull();
  expect(candidate.style.height).toBe('auto');
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

it('only reports salon brush activity, immediately and at most once a second during a stroke', () => {
  const data = { ...fixture(), context: 'salon', salonState: 'drafting' };
  data.drawBounds[Dir.SOUTH] = [1, 0, 31, 31];
  backendStore.set(gameDataAtom, data);
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  let now = 1000;
  const clock = spyOn(Date, 'now').mockImplementation(() => now);
  try {
    const view = render(
      <Provider store={createStore()}>
        <CustomSpriteEditor target="hair" />
      </Provider>,
    );
    const canvas = view.container.querySelector('canvas')!;
    send.mockClear();
    fireEvent.mouseDown(canvas, { clientX: 5, clientY: 5, button: 0 });
    expect(send).not.toHaveBeenCalled();
    fireEvent.mouseMove(window, { clientX: 15, clientY: 5 });
    expect(send).toHaveBeenCalledTimes(1);
    expect(send).toHaveBeenLastCalledWith('drawing', {
      dir: '2',
      x: 1,
      y: 0,
      erasing: false,
    });
    fireEvent.mouseMove(window, { clientX: 25, clientY: 5 });
    expect(send).toHaveBeenCalledTimes(1);
    now += 1000;
    fireEvent.mouseMove(window, { clientX: 35, clientY: 5 });
    expect(send).toHaveBeenCalledTimes(2);
    fireEvent.mouseUp(window, { clientX: 35, clientY: 5, button: 0 });
    expect(send).toHaveBeenLastCalledWith(
      'spriteEditorCommand',
      expect.anything(),
    );
    send.mockClear();
    now += 1000;
    fireEvent.mouseMove(window, { clientX: 45, clientY: 5 });
    fireEvent.click(
      view.container.querySelector('.fa-vector-square')!.closest('.Button')!,
    );
    fireEvent.mouseDown(canvas, { clientX: 15, clientY: 5, button: 0 });
    fireEvent.mouseUp(window, { clientX: 25, clientY: 15, button: 0 });
    expect(send).not.toHaveBeenCalled();
  } finally {
    getBounds.mockRestore();
    clock.mockRestore();
  }
});

it.each([
  ['pencil', false],
  ['eraser', true],
  ['fill-drip', false],
] as const)('starts salon activity on the first %s pixel', (icon, erasing) => {
  backendStore.set(gameDataAtom, { ...fixture(), context: 'salon' });
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
    fireEvent.click(
      view.container.querySelector(`.fa-${icon}`)!.closest('.Button')!,
    );
    send.mockClear();
    fireEvent.mouseDown(view.container.querySelector('canvas')!, {
      clientX: 15,
      clientY: 15,
      button: 0,
    });
    expect(send).toHaveBeenCalledWith('drawing', {
      dir: '2',
      x: 1,
      y: 1,
      erasing,
    });
    fireEvent.mouseUp(window, { clientX: 15, clientY: 15, button: 0 });
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
    store.set(previewDataAtom, fixtureFrames()[Dir.SOUTH]);
  });
  view.unmount();
  expect(store.get(currentToolAtom) === tools[0]).toBe(true);
  expect(store.get(previewDataAtom)).toBeUndefined();
  expect(store.get(previewLayerAtom)).toBeUndefined();
  render(editor);
  expect(store.get(currentToolAtom) === tools[0]).toBe(true);
});

it('locks views you need a mirror for and explains why', () => {
  const store = createStore();
  backendStore.set(gameDataAtom, {
    ...fixture(),
    context: 'salon',
    canChangeHair: true,
    hairStyle: 'Short Hair',
    hairStyles: ['Short Hair'],
    hairColor: '#583820',
    recipientName: 'Leia',
    lockedDirections: ['1'],
  });
  render(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  expect(screen.queryByText(/need a mirror/)).toBeNull();
  fireEvent.click(screen.getByText('Back'));
  expect(screen.getByText(/stand next to a mirror/)).toBeTruthy();
});

it('hides markings another row already uses, and steps past them', () => {
  const store = createStore();
  // The backend refuses a marking a sibling row already holds, so 'Dots' must
  // be unreachable from the 'Stripe' row in both the list and the arrows.
  backendStore.set(gameDataAtom, {
    ...fixture(),
    bodyZone: 'l_arm',
    bodyZoneLabel: 'Left arm',
    canChangeMarkings: true,
    maxBaseMarkings: 4,
    baseMarkingChoices: ['Stripe', 'Spots', 'Dots'],
    baseMarkings: [
      { index: 1, name: 'Stripe', color: '#112233' },
      { index: 2, name: 'Dots', color: '#445566' },
    ],
  });
  render(
    <Provider store={store}>
      <CustomSpriteEditor target="markings" />
    </Provider>,
  );
  const section = screen.getByText('Base markings').closest('.Section')!;
  const firstRow = (section as HTMLElement).querySelectorAll(
    '.Stack',
  )[0] as HTMLElement;

  // Stepping either way from 'Stripe' lands on 'Spots', never the taken 'Dots'.
  const arrows = firstRow.querySelectorAll('.Button');
  fireEvent.click(arrows[1]);
  expect(send).toHaveBeenLastCalledWith('setBaseMarking', {
    index: 1,
    name: 'Spots',
  });
  fireEvent.click(arrows[0]);
  expect(send).toHaveBeenLastCalledWith('setBaseMarking', {
    index: 1,
    name: 'Spots',
  });

  // The selected name shows as a placeholder, so open menu entries are the
  // only plain text matches for a marking name.
  act(() => {
    fireEvent.click(within(firstRow).getByPlaceholderText('Stripe'));
  });
  expect(screen.queryAllByText('Spots').length).toBeGreaterThan(0);
  expect(screen.queryAllByText('Dots')).toHaveLength(0);
});

it('disables the marking arrows when every other name is taken', () => {
  const store = createStore();
  backendStore.set(gameDataAtom, {
    ...fixture(),
    bodyZone: 'l_arm',
    bodyZoneLabel: 'Left arm',
    canChangeMarkings: true,
    maxBaseMarkings: 4,
    baseMarkingChoices: ['Stripe', 'Dots'],
    baseMarkings: [
      { index: 1, name: 'Stripe', color: '#112233' },
      { index: 2, name: 'Dots', color: '#445566' },
    ],
  });
  render(
    <Provider store={store}>
      <CustomSpriteEditor target="markings" />
    </Provider>,
  );
  const section = screen.getByText('Base markings').closest('.Section')!;
  const firstRow = (section as HTMLElement).querySelectorAll('.Stack')[0];
  const arrows = (firstRow as HTMLElement).querySelectorAll('.Button');
  send.mockClear();
  fireEvent.click(arrows[0]);
  fireEvent.click(arrows[1]);
  expect(send).not.toHaveBeenCalled();
  expect(arrows[0].classList.contains('Button--disabled')).toBe(true);
  expect(arrows[1].classList.contains('Button--disabled')).toBe(true);
});

it('steps base hair with the cycle arrows, wrapping at both ends', () => {
  const store = createStore();
  const hair = (hairStyle: string) => ({
    ...fixture(),
    canChangeHair: true,
    hairStyle,
    hairStyles: ['Bald', 'Short Hair', 'Bedhead'],
    hairColor: '#583820',
  });
  const editor = () => (
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>
  );
  backendStore.set(gameDataAtom, hair('Short Hair'));
  const view = render(editor());
  const arrows = () => {
    const section = screen.getByText('Base hair').closest('.Section')!;
    return (section as HTMLElement).querySelectorAll('.Button');
  };
  fireEvent.click(arrows()[1]);
  expect(send).toHaveBeenLastCalledWith('setHairStyle', { style: 'Bedhead' });
  fireEvent.click(arrows()[0]);
  expect(send).toHaveBeenLastCalledWith('setHairStyle', { style: 'Bald' });

  backendStore.set(gameDataAtom, hair('Bedhead'));
  view.rerender(editor());
  fireEvent.click(arrows()[1]);
  expect(send).toHaveBeenLastCalledWith('setHairStyle', { style: 'Bald' });

  backendStore.set(gameDataAtom, hair('Bald'));
  view.rerender(editor());
  fireEvent.click(arrows()[0]);
  expect(send).toHaveBeenLastCalledWith('setHairStyle', { style: 'Bedhead' });
});

it('steps base markings with the cycle arrows and stops when there is nothing to pick', () => {
  const store = createStore();
  const limb = (choices: string[]) => ({
    ...fixture(),
    bodyZone: 'l_arm',
    bodyZoneLabel: 'Left arm',
    canChangeMarkings: true,
    maxBaseMarkings: 3,
    baseMarkingChoices: choices,
    baseMarkings: [{ index: 1, name: 'Spots', color: '#112233' }],
  });
  const editor = () => (
    <Provider store={store}>
      <CustomSpriteEditor target="markings" />
    </Provider>
  );
  backendStore.set(gameDataAtom, limb(['Stripe', 'Spots', 'Dots']));
  const view = render(editor());
  const buttons = () => {
    const section = screen.getByText('Base markings').closest('.Section')!;
    return (section as HTMLElement).querySelectorAll('.Button');
  };
  // [previous, next, color, remove, add]
  fireEvent.click(buttons()[1]);
  expect(send).toHaveBeenLastCalledWith('setBaseMarking', {
    index: 1,
    name: 'Dots',
  });
  fireEvent.click(buttons()[0]);
  expect(send).toHaveBeenLastCalledWith('setBaseMarking', {
    index: 1,
    name: 'Stripe',
  });
  // The add button sits under the rows, green, as in character setup.
  expect(buttons()[4].textContent).toBe('+');
  expect(buttons()[4].classList.contains('Button--color--good')).toBe(true);
  fireEvent.click(buttons()[4]);
  expect(send).toHaveBeenLastCalledWith('addBaseMarking');
  fireEvent.click(buttons()[3]);
  expect(send).toHaveBeenLastCalledWith('removeBaseMarking', { index: 1 });

  backendStore.set(gameDataAtom, limb([]));
  view.rerender(editor());
  send.mockClear();
  fireEvent.click(buttons()[0]);
  fireEvent.click(buttons()[1]);
  expect(send).not.toHaveBeenCalled();
});

it('offers the limb’s own markings only when the backend permits it', () => {
  const store = createStore();
  const limb = {
    ...fixture(),
    bodyZone: 'l_arm',
    bodyZoneLabel: 'Left arm',
    canChangeMarkings: true,
    maxBaseMarkings: 3,
    baseMarkingChoices: ['Stripe', 'Spots'],
    baseMarkings: [{ index: 1, name: 'Stripe', color: '#112233' }],
  };
  backendStore.set(gameDataAtom, limb);
  const editor = () => (
    <Provider store={store}>
      <CustomSpriteEditor target="markings" />
    </Provider>
  );
  const view = render(editor());
  const section = screen.getByText('Base markings').closest('.Section')!;
  expect(
    within(section as HTMLElement).getByPlaceholderText('Stripe'),
  ).toBeTruthy();
  fireEvent.click(
    (section as HTMLElement).querySelector('.fa-trash')!.closest('.Button')!,
  );
  expect(send).toHaveBeenLastCalledWith('removeBaseMarking', { index: 1 });
  fireEvent.click(within(section as HTMLElement).getByText('+'));
  expect(send).toHaveBeenLastCalledWith('addBaseMarking');
  backendStore.set(gameDataAtom, { ...limb, canChangeMarkings: false });
  view.rerender(editor());
  expect(screen.queryByText('Base markings')).toBeNull();
});

it.each([
  'preferences',
  'salon',
] as const)('changes base hair in %s when the backend permits it', (context) => {
  const store = createStore();
  const hair = {
    context,
    ...fixture(),
    canChangeHair: true,
    hairStyle: 'Short Hair',
    hairStyles: ['Bald', 'Short Hair', 'Bedhead'],
    hairColor: '#583820',
  };
  backendStore.set(gameDataAtom, hair);
  const editor = () => (
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>
  );
  const view = render(editor());
  fireEvent.click(screen.getByText('Hair color'));
  expect(send).toHaveBeenLastCalledWith('pickHairColor');
  fireEvent.click(screen.getByPlaceholderText('Short Hair'));
  fireEvent.click(screen.getByText('Bedhead'));
  expect(send).toHaveBeenLastCalledWith('setHairStyle', { style: 'Bedhead' });
  backendStore.set(gameDataAtom, {
    ...hair,
    context: 'salon',
    canChangeHair: false,
    recipientName: 'Leia',
  });
  view.rerender(editor());
  expect(screen.queryByText('Base hair')).toBeNull();
  expect(screen.queryByText('Hair color')).toBeNull();
});

it('sends import and export requests without saving and confirms a previewed candidate', () => {
  const store = createStore();
  const editor = () => (
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>
  );
  const view = render(editor());
  fireEvent.click(screen.getByText('Export'));
  expect(send).toHaveBeenLastCalledWith('exportStyle');
  fireEvent.click(screen.getByText('Import'));
  expect(send).toHaveBeenLastCalledWith('importStyle');
  expect(send).not.toHaveBeenCalledWith('saveDraft');
  backendStore.set(gameDataAtom, {
    ...fixture(),
    candidate: {
      source: 'import',
      summary: 'Short Hair, #583820',
      previews: { 1: 'data:b', 2: 'data:f', 4: 'data:r', 8: 'data:l' },
    },
  });
  view.rerender(editor());
  expect(screen.getByText('Import this style?')).toBeTruthy();
  expect(screen.getByAltText('Left preview').getAttribute('src')).toBe(
    'data:l',
  );
  fireEvent.click(screen.getByText('Cancel'));
  expect(send).toHaveBeenLastCalledWith('cancelCandidate');
  fireEvent.click(screen.getByText('Replace draft'));
  expect(send).toHaveBeenLastCalledWith('confirmCandidate');
  backendStore.set(gameDataAtom, {
    ...fixture(),
    transferError: 'The file repeats the field "target".',
  });
  view.rerender(editor());
  expect(screen.getByRole('alert').textContent).toBe(
    'The file repeats the field "target".',
  );
});

it.each([
  ['import', 'Cancel', 'cancelCandidate'],
  ['import', 'Replace draft', 'confirmCandidate'],
  ['restore', 'Cancel', 'cancelCandidate'],
  ['restore', 'Replace draft', 'confirmCandidate'],
] as const)('dismisses the %s preview after %s receives a backend update', (source, button, action) => {
  const store = createStore();
  const editor = () => (
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>
  );
  const applyUpdate = (data: CustomSpriteEditorData) => {
    update({ ...backendStore.get(backendStateAtom), data, static_data: {} });
  };
  applyUpdate({
    ...fixture(),
    candidate: {
      source,
      summary: 'Short Hair, #583820',
      previews: { 1: 'data:b', 2: 'data:f', 4: 'data:r', 8: 'data:l' },
    },
  });
  const view = render(editor());
  expect(screen.getByAltText('Left preview')).toBeTruthy();
  fireEvent.click(screen.getByText(button));
  expect(send).toHaveBeenLastCalledWith(action);
  // The server owns dismissal. Exercise TGUI's merging update handler, which
  // retains a previous candidate if the next UI payload omits that field.
  view.rerender(editor());
  expect(screen.getByAltText('Left preview')).toBeTruthy();
  applyUpdate(fixture());
  view.rerender(editor());
  expect(screen.queryAllByAltText('Left preview')).toHaveLength(0);
  expect(screen.queryAllByText('Replace draft')).toHaveLength(0);
});

it('offers restoring the previous saved style only when one exists', () => {
  const store = createStore();
  const editor = () => (
    <Provider store={store}>
      <CustomSpriteEditor target="markings" />
    </Provider>
  );
  const view = render(editor());
  expect(screen.queryByText('Restore previous saved style')).toBeNull();
  backendStore.set(gameDataAtom, { ...fixture(), canRestorePrevious: true });
  view.rerender(editor());
  fireEvent.click(screen.getByText('Restore previous saved style'));
  expect(send).toHaveBeenLastCalledWith('restorePrevious');
});

it('uses round-only draft wording and salon actions in the salon context', () => {
  const store = createStore();
  const salon = {
    ...fixture(),
    context: 'salon' as const,
    bodyZone: 'l_arm',
    bodyZoneLabel: 'Left arm',
    recipientName: 'Leia',
    salonState: 'drafting' as const,
  };
  backendStore.set(gameDataAtom, salon);
  const editor = () => (
    <Provider store={store}>
      <CustomSpriteEditor target="markings" />
    </Provider>
  );
  const view = render(editor());
  expect(screen.queryByText('Save and close')).toBeNull();
  expect(
    screen.getByText('Finish next to Leia with the tool in hand.'),
  ).toBeTruthy();
  backendStore.set(gameDataAtom, { ...salon, selfWork: true });
  view.rerender(editor());
  expect(
    screen.queryByText('Finish next to Leia with the tool in hand.'),
  ).toBeNull();
  backendStore.set(gameDataAtom, salon);
  view.rerender(editor());
  expect(
    screen.queryByText(
      'Closing keeps this draft until you save or discard it.',
    ),
  ).toBeNull();
  fireEvent.keyDown(document, { key: 's', ctrlKey: true });
  expect(send).toHaveBeenLastCalledWith('saveDraft');
  backendStore.set(gameDataAtom, { ...salon, saveRevision: 1 });
  view.rerender(editor());
  expect(screen.getByRole('status').textContent).toBe(
    'Draft saved for this round',
  );
  fireEvent.click(screen.getByText('Finish'));
  expect(send).toHaveBeenLastCalledWith('finishWork');
  fireEvent.click(screen.getByText('Close'));
  expect(send).toHaveBeenLastCalledWith('closeEditor');
  backendStore.set(gameDataAtom, {
    ...salon,
    saveRevision: 1,
    salonState: 'awaiting approval',
  });
  view.rerender(editor());
  expect(screen.getByText('Finish').closest('.Button')!.classList).toContain(
    'Button--disabled',
  );
  expect(screen.getByText(/Waiting for Leia/)).toBeTruthy();
});

it('groups blending with the custom colors and hides hair on demand', () => {
  const store = createStore();
  backendStore.set(gameDataAtom, {
    ...fixture(),
    bodyZone: 'chest',
    bodyZoneLabel: 'Torso',
    canHideParts: true,
    hideParts: true,
  });
  render(
    <Provider store={store}>
      <CustomSpriteEditor target="markings" />
    </Provider>,
  );
  const custom = screen.getByText('Custom').closest('.Section')!;
  expect(
    within(custom as HTMLElement).getByText('Blending options'),
  ).toBeTruthy();
  const parts = screen.getByText('Hide parts').closest('.Button')!;
  expect(parts.classList).toContain('Button--selected');
  fireEvent.click(parts);
  expect(send).toHaveBeenLastCalledWith('toggleParts');
});

it('offers hiding underwear only where the backend allows it', () => {
  const store = createStore();
  const editor = () => (
    <Provider store={store}>
      <CustomSpriteEditor target="markings" />
    </Provider>
  );
  const view = render(editor());
  expect(screen.queryByText('Hide underwear')).toBeNull();
  backendStore.set(gameDataAtom, {
    ...fixture(),
    canHideUnderwear: true,
    hideUnderwear: false,
  });
  view.rerender(editor());
  const underwear = screen.getByText('Hide underwear').closest('.Button')!;
  expect(underwear.classList).not.toContain('Button--selected');
  fireEvent.click(underwear);
  expect(send).toHaveBeenLastCalledWith('toggleUnderwear');
});

it('rotates through the views in the same order as the character preview', () => {
  const store = createStore();
  render(
    <Provider store={store}>
      <CustomSpriteEditor target="markings" />
    </Provider>,
  );
  const [clockwise, counterClockwise] = screen
    .getByText('Preview')
    .closest('.Section')!
    .querySelectorAll('.Button');
  const seen: Dir[] = [];
  for (let turn = 0; turn < 4; turn++) {
    fireEvent.click(clockwise);
    seen.push(store.get(dirAtom));
  }
  expect(seen).toEqual([Dir.WEST, Dir.NORTH, Dir.EAST, Dir.SOUTH]);
  fireEvent.click(counterClockwise);
  expect(store.get(dirAtom)).toBe(Dir.EAST);
  expect(screen.getByText('Right').closest('.Button')!.classList).toContain(
    'Button--selected',
  );
  expect(send).not.toHaveBeenCalled();
});

it('switches the canvas and preview backdrop with the tile swatches, without touching preferences', () => {
  const data = fixture();
  data.backgrounds = [
    { name: 'Plating', url: 'data:plating', wideUrl: 'data:plating-wide' },
    { name: 'Grey', url: 'data:grey', wideUrl: 'data:grey-wide' },
  ];
  data.defaultBackground = 'Plating';
  data.previews = { 1: 'a', 2: 'a', 4: 'a', 8: 'a' };
  backendStore.set(gameDataAtom, data);
  const view = render(
    <Provider store={createStore()}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  const canvas = view.container.querySelector('canvas')!;
  expect(canvas.style.backgroundImage).toContain('data:plating');
  send.mockClear();
  fireEvent.click(screen.getByLabelText('Grey'));
  expect(canvas.style.backgroundImage).toContain('data:grey');
  expect(
    (view.container.querySelector('.CustomSpriteEditor__tile') as HTMLElement)
      .style.backgroundImage,
  ).toContain('data:grey');
  fireEvent.click(screen.getByLabelText('Transparent'));
  expect(canvas.style.backgroundImage).not.toContain('data:grey');
  expect(send).not.toHaveBeenCalled();
});
