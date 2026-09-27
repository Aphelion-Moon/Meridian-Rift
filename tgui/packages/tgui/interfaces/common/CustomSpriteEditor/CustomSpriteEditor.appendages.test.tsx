// THIS IS AN APHELION UI FILE
import { expect, it, jest, spyOn } from 'bun:test';
import { act, fireEvent, screen } from '@testing-library/react';
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
  send,
  setupEditorTests,
} from '../../../__mocks__/customSpriteEditor';
import { renderEditor } from '../../../__mocks__/renderCustomSpriteEditor';
import { Dir } from '../SpriteEditor/Types/types';
import { Zone } from './appendages';
import type { CustomSpriteEditorData } from './types';

setupEditorTests();

const red = '#ff0000ff';

/**
 * Hair with a Ponytail under hats and a Ponytail tip over them, both at the back of the head. Each
 * has a red pixel at the top left of the Front view, the only view the server sends of them.
 */
const layered = (
  overrides: Partial<CustomSpriteEditorData> = {},
): CustomSpriteEditorData => {
  const piece = fixtureFrames()[Dir.SOUTH].map((row) =>
    row.map(() => '#00000000'),
  );
  piece[0][0] = red;
  // A spare view key puts the piece's pixels in the drawing's own palette and codes.
  const sprite = compactSprite(32, 32, {
    ...fixtureFrames(),
    [99 as Dir]: piece,
  });
  const { 99: codes, ...views } = sprite.canvas.views;
  sprite.canvas.views = views;
  sprite.canvas.appendages = { a1: { 2: codes }, a2: { 2: codes } };
  const data = fixture();
  data.editorData.sprite = sprite;
  const appendage = (id: string, name: string, outer: boolean) => ({
    id,
    name,
    zone: Zone.REAR,
    outer,
    edited: { 2: true },
    emissive: {},
  });
  return {
    ...data,
    visibleView: '2',
    appendages: [
      appendage('a1', 'Ponytail', false),
      appendage('a2', 'Ponytail tip', true),
    ],
    maxAppendages: 3,
    maxAppendageName: 20,
    tryOn: null,
    tryOnHats: {
      fedora: {
        label: 'Fedora',
        group: 'Fedoras and security helmets',
        strict: Zone.TOP | Zone.LEFT | Zone.RIGHT | Zone.REAR,
        // The brim trims the top row. Rows travel as hex, four pixels a digit.
        masks: {
          2: ['00000000', ...Array(31).fill('ffffffff')],
        },
        views: { 2: 'data:fedora' },
      },
    },
    ...overrides,
  };
};

const applyUpdate = (data: CustomSpriteEditorData) =>
  act(() =>
    update({ ...backendStore.get(backendStateAtom), data, static_data: {} }),
  );

/** The layer tab with this name. */
const tab = (name: string) =>
  [...document.querySelectorAll('.CustomSpriteEditor__layerTab')].find(
    (element) => element.textContent?.startsWith(name),
  ) as HTMLElement;

/** Renders the hair editor on a 320 pixel canvas, ten screen pixels to an art pixel. */
const withCanvas = (run: (canvas: HTMLCanvasElement) => void) => {
  const bounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  try {
    const { view } = renderEditor('hair');
    run(view.container.querySelector('canvas')!);
  } finally {
    bounds.mockRestore();
  }
};

const paint = (canvas: HTMLCanvasElement, x: number, y: number) => {
  fireEvent.mouseDown(canvas, {
    clientX: x * 10 + 5,
    clientY: y * 10 + 5,
    button: 0,
  });
  fireEvent.mouseUp(window, {
    clientX: x * 10 + 5,
    clientY: y * 10 + 5,
    button: 0,
  });
};

it('paints one layer at a time, naming appendage layers by index and id', () => {
  backendStore.set(gameDataAtom, layered());
  withCanvas((canvas) => {
    fireEvent.click(tab('Ponytail tip'));
    send.mockClear();
    paint(canvas, 3, 4);
    expect(send.mock.calls[0][1].transaction).toMatchObject({
      type: 'pencil',
      layer: 3,
      layerId: 'a2',
    });
    fireEvent.click(tab('Base hair layer'));
    send.mockClear();
    paint(canvas, 3, 4);
    expect(send.mock.calls[0][1].transaction).toMatchObject({
      layer: 1,
      layerId: 'hair',
    });
  });
});

it('clears and lights up only the chosen layer', () => {
  backendStore.set(gameDataAtom, layered());
  renderEditor('hair');
  fireEvent.click(tab('Ponytail'));
  send.mockClear();
  fireEvent.click(screen.getByText('Clear ponytail'));
  expect(send).toHaveBeenLastCalledWith('clear', { dir: '2', layer: 'a1' });
  fireEvent.click(screen.getByText('Emissive - (Ponytail, Front)'));
  expect(send).toHaveBeenLastCalledWith('setEmissive', {
    layer: 'a1',
    dir: '2',
    enabled: true,
  });
  fireEvent.click(tab('Base hair layer'));
  fireEvent.click(screen.getByText('Clear direction'));
  expect(send).toHaveBeenLastCalledWith('clear', { dir: '2' });
});

it('offers Try on only for appendages, and paints the base hair with no hat on', () => {
  backendStore.set(gameDataAtom, layered());
  renderEditor('hair');
  expect(screen.queryByText('Try on')).toBeNull();
  fireEvent.click(tab('Ponytail'));
  send.mockClear();
  fireEvent.click(screen.getByText('Fedora'));
  expect(send).toHaveBeenLastCalledWith('setTryOn', { hat: 'fedora' });
  fireEvent.click(tab('Base hair layer'));
  expect(screen.queryByText('Try on')).toBeNull();
  expect(send).toHaveBeenLastCalledWith('setTryOn', { hat: null });
  // The hat stays chosen for when an appendage is painted again.
  fireEvent.click(tab('Ponytail tip'));
  expect(send).toHaveBeenLastCalledWith('setTryOn', { hat: 'fedora' });
});

it('renames with the pencil: Enter keeps a cleaned name, Esc backs out', () => {
  backendStore.set(gameDataAtom, layered());
  const { view } = renderEditor('hair');
  fireEvent.click(tab('Ponytail'));
  const rename = () => {
    fireEvent.click(
      view.container.querySelector('.CustomSpriteEditor__renameButton')!,
    );
    return view.container.querySelector<HTMLInputElement>(
      '.CustomSpriteEditor__rename input',
    )!;
  };
  let input = rename();
  expect(input.maxLength).toBe(20);
  send.mockClear();
  fireEvent.change(input, { target: { value: 'Bun' } });
  fireEvent.keyDown(input, { key: 'Escape' });
  expect(send).not.toHaveBeenCalled();
  input = rename();
  fireEvent.change(input, {
    target: { value: '  <b>Low</b>   <bun>\u0007 on  the  left side ' },
  });
  fireEvent.keyDown(input, { key: 'Enter' });
  expect(send).toHaveBeenCalledTimes(1);
  expect(send).toHaveBeenLastCalledWith('renameAppendage', {
    id: 'a1',
    name: 'Low on the left side',
  });
});

it('sends its panel choices for the chosen appendage', () => {
  backendStore.set(gameDataAtom, layered());
  renderEditor('hair');
  fireEvent.click(tab('Ponytail'));
  send.mockClear();
  fireEvent.click(screen.getByText('Crown'));
  expect(send).toHaveBeenLastCalledWith('setAppendageZone', {
    id: 'a1',
    zone: Zone.TOP,
  });
  fireEvent.click(screen.getByText('Over hats'));
  expect(send).toHaveBeenLastCalledWith('setAppendageKind', {
    id: 'a1',
    outer: true,
  });
  fireEvent.click(screen.getByText('Copy to over-hat layer'));
  expect(send).toHaveBeenLastCalledWith('copyToOverHat', { id: 'a1' });
  fireEvent.click(screen.getByText('Remove'));
  expect(send).toHaveBeenLastCalledWith('removeAppendage', { id: 'a1' });
  fireEvent.click(screen.getByText('Appendage layer'));
  expect(send).toHaveBeenLastCalledWith('addAppendage');
  // Over-hat pieces have nothing to copy over hats, and a full set can't grow.
  fireEvent.click(tab('Ponytail tip'));
  expect(screen.queryByText('Copy to over-hat layer')).toBeNull();
});

it('turns to a layer the server adds, and back to the hair when one goes away', () => {
  applyUpdate(layered());
  const { view, editor } = renderEditor('hair');
  const selected = () =>
    view.container
      .querySelector('.CustomSpriteEditor__layerTab.Button--selected')
      ?.textContent?.split('Back of head')[0];
  expect(selected()).toBe('Base hair layer');
  applyUpdate(layered({ focusLayer: 'a2' }));
  view.rerender(editor());
  expect(selected()).toBe('Ponytail tip');
  const data = layered();
  applyUpdate({ ...data, appendages: data.appendages!.slice(0, 1) });
  view.rerender(editor());
  expect(selected()).toBe('Base hair layer');
});

it('leaves the base hair the whole column, and offers another layer only below the cap', () => {
  backendStore.set(gameDataAtom, layered({ maxAppendages: 2 }));
  const { view } = renderEditor('hair');
  const panel = () =>
    view.container.querySelector('.CustomSpriteEditor__appendagePanel');
  expect(panel()).toBeNull();
  expect(screen.queryByText('Appendage layer')).toBeNull();
  fireEvent.click(tab('Ponytail'));
  expect(panel()).toBeTruthy();
});

it('gives only hair its layers', () => {
  for (const target of ['facial_hair', 'markings'] as const) {
    backendStore.set(gameDataAtom, layered());
    const { view } = renderEditor(target);
    expect(
      view.container.querySelector('.CustomSpriteEditor__strip'),
    ).toBeNull();
    view.unmount();
  }
});

it('holds the pen until the server sends the appendage view the window turned to', () => {
  backendStore.set(gameDataAtom, layered());
  withCanvas((canvas) => {
    fireEvent.click(tab('Ponytail'));
    fireEvent.click(screen.getByText('Back'));
    send.mockClear();
    paint(canvas, 3, 4);
    expect(send).not.toHaveBeenCalledWith(
      'spriteEditorCommand',
      expect.anything(),
    );
  });
});

it('names the hat that trims the paint under a resting cursor', () => {
  jest.useFakeTimers();
  backendStore.set(gameDataAtom, layered());
  withCanvas((canvas) => {
    fireEvent.click(tab('Ponytail'));
    fireEvent.click(screen.getByText('Fedora'));
    const box = canvas.closest('.CustomSpriteEditor__canvas')!;
    // The painted pixel at the top left sits above the brim.
    fireEvent.mouseMove(box, { clientX: 5, clientY: 5 });
    act(() => jest.advanceTimersByTime(1000));
    expect(screen.getByText('Trimmed by the fedora')).toBeTruthy();
    fireEvent.mouseMove(box, { clientX: 55, clientY: 55 });
    expect(screen.queryByText('Trimmed by the fedora')).toBeNull();
    // Over hats, the same piece is hidden outright.
    fireEvent.click(tab('Ponytail tip'));
    fireEvent.mouseMove(box, { clientX: 5, clientY: 5 });
    act(() => jest.advanceTimersByTime(1000));
    expect(screen.getByText('Hidden by the fedora')).toBeTruthy();
  });
});
