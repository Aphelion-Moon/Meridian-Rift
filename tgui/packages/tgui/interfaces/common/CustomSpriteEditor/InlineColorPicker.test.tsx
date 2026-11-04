// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, expect, it, jest, spyOn } from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import { Provider } from 'jotai';

import * as actions from '../../../events/act';
import { store } from '../../../events/store';
import {
  currentColorInternalAtom,
  onSelectServerColorAtom,
} from '../SpriteEditor/atoms';
import { parseHexColorString } from '../SpriteEditor/colorSpaces';
import { SpriteEditor } from '../SpriteEditor';
import { InlineColorPicker } from './InlineColorPicker';

let sendAct: ReturnType<typeof spyOn<typeof actions, 'sendAct'>>;
let previousBrush: ReturnType<typeof parseHexColorString>;

beforeEach(() => {
  sendAct = spyOn(actions, 'sendAct').mockImplementation(() => undefined);
  previousBrush = store.get(currentColorInternalAtom);
  // As the editor's syncBackend() sets it, so a brush set through currentColorAtom would send too.
  store.set(onSelectServerColorAtom, 'selectColor');
  store.set(currentColorInternalAtom, parseHexColorString('#0000ff'));
});

afterEach(() => {
  // Unmounted first, so putting the brush back renders nothing.
  cleanup();
  jest.useRealTimers();
  sendAct.mockRestore();
  store.set(onSelectServerColorAtom, undefined);
  store.set(currentColorInternalAtom, previousBrush);
});

/** A picker slider, `width` by `height` pixels from the page's corner. */
const slider = (name: string, width: number, height: number) => {
  const element = screen.getByRole('slider', { name });
  element.getBoundingClientRect = () =>
    ({ left: 0, top: 0, width, height }) as DOMRect;
  return element;
};

/** Sends a pointer event at a page position: happy-dom's carry no pageX, which Interactive measures from. */
const point = (target: Element, type: string, x: number, y: number) => {
  const event = new PointerEvent(type, { bubbles: true, pointerId: 1 });
  Object.defineProperties(event, { pageX: { value: x }, pageY: { value: y } });
  act(() => {
    target.dispatchEvent(event);
  });
};

it('paints with a colour as it is picked and sends it once an interaction', () => {
  render(
    <Provider store={store}>
      <InlineColorPicker />
    </Provider>,
  );
  const square = slider('Color', 100, 100);
  point(square, 'pointerdown', 0, 0);
  for (let step = 1; step <= 20; step++) {
    point(square, 'pointermove', step * 2.5, step * 2.5);
  }
  expect(store.get(currentColorInternalAtom)).toEqual(
    parseHexColorString('#404080'),
  );
  expect(sendAct).not.toHaveBeenCalled();
  point(square, 'pointerup', 50, 50);
  expect(sendAct).toHaveBeenCalledTimes(1);
  expect(sendAct).toHaveBeenLastCalledWith('addColor', { color: '#404080' });

  const hex = screen.getByRole('textbox');
  act(() => hex.focus());
  fireEvent.change(hex, { target: { value: '00ff00' } });
  fireEvent.keyDown(hex, { key: 'Enter' });
  expect(sendAct).toHaveBeenCalledTimes(2);
  expect(sendAct).toHaveBeenLastCalledWith('addColor', { color: '#00ff00' });

  const alpha = slider('Alpha', 200, 12);
  point(alpha, 'pointerdown', 150, 6);
  for (let step = 1; step <= 5; step++) {
    point(alpha, 'pointermove', 150 - step * 30, 6);
  }
  point(alpha, 'pointerup', 0, 6);
  expect(sendAct).toHaveBeenCalledTimes(3);
  // The bar's left end is the floor: alpha 33, a quarter of the ceiling's cc.
  expect(sendAct).toHaveBeenLastCalledWith('addColor', { color: '#00ff0033' });
  expect(screen.getByText('25%')).toBeTruthy();
});

it('sends an arrow key step once the keys pause, and never a colour that shows nothing', () => {
  jest.useFakeTimers();
  render(
    <Provider store={store}>
      <InlineColorPicker />
    </Provider>,
  );
  const square = screen.getByRole('slider', { name: 'Color' });
  fireEvent.keyDown(square, { key: 'ArrowLeft' });
  fireEvent.keyDown(square, { key: 'ArrowLeft' });
  expect(store.get(currentColorInternalAtom)).not.toEqual(
    parseHexColorString('#0000ff'),
  );
  expect(sendAct).not.toHaveBeenCalled();
  act(() => jest.advanceTimersByTime(300));
  expect(sendAct).toHaveBeenCalledTimes(1);
  // A brush no pick gives: it shows nothing, so nothing mixed from it is sent.
  act(() =>
    store.set(currentColorInternalAtom, parseHexColorString('#0000ff00')),
  );
  fireEvent.keyDown(square, { key: 'ArrowLeft' });
  act(() => jest.advanceTimersByTime(300));
  expect(sendAct).toHaveBeenCalledTimes(1);
});

/** The picker under the editor's syncBackend(), which gives the brush each colour a reply names. */
const Editor = (props: { serverColor?: string }) => {
  SpriteEditor.syncBackend('selectColor', props.serverColor);
  return <InlineColorPicker serverColor={props.serverColor} />;
};

it('keeps a later pick when the reply to an earlier one comes after it', () => {
  const editor = (serverColor?: string) => (
    <Provider store={store}>
      <Editor serverColor={serverColor} />
    </Provider>
  );
  const { rerender } = render(editor());
  const hex = screen.getByRole('textbox');
  const commit = (value: string) => {
    act(() => hex.focus());
    fireEvent.change(hex, { target: { value } });
    fireEvent.keyDown(hex, { key: 'Enter' });
  };
  commit('ffff00');
  commit('00ffff');
  expect(sendAct).toHaveBeenCalledTimes(2);
  rerender(editor('#ffff00'));
  expect(store.get(currentColorInternalAtom)).toEqual(
    parseHexColorString('#00ffff'),
  );
  // With both replies in, picking either colour again elsewhere holds.
  rerender(editor('#00ffff'));
  act(() =>
    store.set(currentColorInternalAtom, parseHexColorString('#ff0000')),
  );
  act(() =>
    store.set(currentColorInternalAtom, parseHexColorString('#00ffff')),
  );
  expect(store.get(currentColorInternalAtom)).toEqual(
    parseHexColorString('#00ffff'),
  );
  // A swatch picked while a reply is on its way keeps the brush too.
  commit('ff00ff');
  act(() =>
    store.set(currentColorInternalAtom, parseHexColorString('#ff0000')),
  );
  rerender(editor('#ff00ff'));
  expect(store.get(currentColorInternalAtom)).toEqual(
    parseHexColorString('#ff0000'),
  );
  // Picked again while the server's colour is already it, its reply changes nothing, so later picks of it hold.
  commit('ff00ff');
  act(() =>
    store.set(currentColorInternalAtom, parseHexColorString('#00ff00')),
  );
  act(() =>
    store.set(currentColorInternalAtom, parseHexColorString('#ff00ff')),
  );
  expect(store.get(currentColorInternalAtom)).toEqual(
    parseHexColorString('#ff00ff'),
  );
  expect(sendAct).toHaveBeenCalledTimes(4);
});
