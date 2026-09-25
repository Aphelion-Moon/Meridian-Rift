// THIS IS AN APHELION UI FILE
import { expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import { createStore, Provider } from 'jotai';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';
import {
  compactSprite,
  fixture,
  fixtureFrames,
  send,
  setupEditorTests,
} from '../../../__mocks__/customSpriteEditor';
import { Dir } from '../SpriteEditor/Types/types';
import { CustomSpriteEditor } from './index';

setupEditorTests();

/**
 * Opens a hair editor whose front view starts with a red and a green pixel, turns that pair so it
 * floats, presses `button` and closes the editor. Returns the actions the press sent.
 */
const closeWithFloatingPaint = (
  context: 'salon' | 'preferences',
  button: string,
) => {
  const frames = fixtureFrames();
  frames[Dir.SOUTH][0][0] = '#ff0000ff';
  frames[Dir.SOUTH][0][1] = '#00ff00ff';
  const data = { ...fixture(), context, salonState: 'drafting' };
  data.editorData.sprite = compactSprite(32, 32, frames);
  backendStore.set(gameDataAtom, data);
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  try {
    const view = render(
      <Provider store={createStore()}>
        <CustomSpriteEditor target="hair" />
      </Provider>,
    );
    fireEvent.click(
      view.container.querySelector('.fa-vector-square')!.closest('.Button')!,
    );
    const canvas = view.container.querySelector('canvas')!;
    fireEvent.mouseDown(canvas, { clientX: 5, clientY: 5, button: 0 });
    fireEvent.mouseUp(window, { clientX: 15, clientY: 5, button: 0 });
    fireEvent.click(screen.getByLabelText('Turn clockwise'));
    send.mockClear();
    fireEvent.click(screen.getByText(button));
    const calls = [...send.mock.calls];
    view.unmount();
    return calls;
  } finally {
    getBounds.mockRestore();
  }
};

it.each([
  ['salon', 'Close', 'closeEditor'],
  ['salon', 'Finish', 'finishWork'],
  ['preferences', 'Save and close', 'save'],
] as const)('writes floating paint before the %s editor closes with %s', (context, button, action) => {
  const calls = closeWithFloatingPaint(context, button);
  expect(calls.map((call) => call[0])).toEqual(['spriteEditorCommand', action]);
  expect(calls[0][1].transaction).toMatchObject({ type: 'move', dir: '2' });
});

it('starts each editor from its own drawing, not a drop the last one left unconfirmed', () => {
  closeWithFloatingPaint('preferences', 'Save and close');
  // The server hasn't answered, so the next editor opens on the same drawing.
  const calls = closeWithFloatingPaint('preferences', 'Save and close');
  expect(calls.map((call) => call[0])).toEqual(['spriteEditorCommand', 'save']);
});
