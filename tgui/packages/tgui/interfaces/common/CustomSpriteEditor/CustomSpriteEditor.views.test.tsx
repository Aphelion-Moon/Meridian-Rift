// THIS IS AN APHELION UI FILE
import { expect, it } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import { createStore, Provider } from 'jotai';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';
import {
  fixture,
  send,
  setupEditorTests,
} from '../../../__mocks__/customSpriteEditor';
import { CustomSpriteEditor } from './index';

setupEditorTests();

it('asks the server to draw a view only when the window shows a different one', () => {
  backendStore.set(gameDataAtom, { ...fixture(), visibleView: '2' });
  render(
    <Provider store={createStore()}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  expect(send).not.toHaveBeenCalled();
  fireEvent.click(screen.getByText('Back'));
  expect(send).toHaveBeenLastCalledWith('setView', { dir: '1' });
  send.mockClear();
  fireEvent.click(screen.getByText('Back'));
  expect(send).not.toHaveBeenCalled();
});

it('reopens on the Front view without asking for the view it closed on', () => {
  // A pooled window keeps its atoms between opens, so the last view shown is still set.
  const store = createStore();
  const editor = (
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>
  );
  backendStore.set(gameDataAtom, { ...fixture(), visibleView: '2' });
  const view = render(editor);
  fireEvent.click(screen.getByText('Back'));
  expect(send).toHaveBeenLastCalledWith('setView', { dir: '1' });
  view.unmount();
  // Closing returns the server to the Front view.
  backendStore.set(gameDataAtom, { ...fixture(), visibleView: '2' });
  send.mockClear();
  render(editor);
  expect(send).not.toHaveBeenCalled();
});
