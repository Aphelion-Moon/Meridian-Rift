// THIS IS AN APHELION UI FILE
import { expect, it } from 'bun:test';
import { fireEvent, screen } from '@testing-library/react';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';
import {
  fixture,
  send,
  setupEditorTests,
} from '../../../__mocks__/customSpriteEditor';
import { renderEditor } from '../../../__mocks__/renderCustomSpriteEditor';

setupEditorTests();

it('asks the server to draw a view only when the window shows a different one', () => {
  backendStore.set(gameDataAtom, { ...fixture(), visibleView: '2' });
  renderEditor('hair');
  expect(send).not.toHaveBeenCalled();
  fireEvent.click(screen.getByText('Back'));
  expect(send).toHaveBeenLastCalledWith('setView', { dir: '1' });
  send.mockClear();
  fireEvent.click(screen.getByText('Back'));
  expect(send).not.toHaveBeenCalled();
});

it('reopens on the Front view without asking for the view it closed on', () => {
  // A pooled window keeps its atoms between opens, so the last view shown is still set.
  backendStore.set(gameDataAtom, { ...fixture(), visibleView: '2' });
  const { store, view } = renderEditor();
  fireEvent.click(screen.getByText('Back'));
  expect(send).toHaveBeenLastCalledWith('setView', { dir: '1' });
  view.unmount();
  // Closing returns the server to the Front view.
  backendStore.set(gameDataAtom, { ...fixture(), visibleView: '2' });
  send.mockClear();
  renderEditor('hair', { store });
  expect(send).not.toHaveBeenCalled();
});

it('converges on the view the window shows when an older answer arrives late', () => {
  backendStore.set(gameDataAtom, { ...fixture(), visibleView: '2' });
  const { view, editor } = renderEditor();
  fireEvent.click(screen.getByText('Back'));
  expect(send).toHaveBeenLastCalledWith('setView', { dir: '1' });
  send.mockClear();
  backendStore.set(gameDataAtom, { ...fixture(), visibleView: '1' });
  view.rerender(editor());
  expect(send).not.toHaveBeenCalled();
  // The answer to an earlier request lands after the one for this view.
  backendStore.set(gameDataAtom, { ...fixture(), visibleView: '2' });
  view.rerender(editor());
  expect(send).toHaveBeenLastCalledWith('setView', { dir: '1' });
});

// Both rotation controls must switch the actual editable view in each UI context.
it.each([
  ['hair', 'preferences'],
  ['facial_hair', 'preferences'],
  ['markings', 'preferences'],
  ['hair', 'salon'],
  ['facial_hair', 'salon'],
  ['markings', 'salon'],
] as const)('rotates the canvas and preview together for %s in %s', (target, context) => {
  backendStore.set(gameDataAtom, { ...fixture(), context, visibleView: '2' });
  renderEditor(target);
  const clockwise = screen.getAllByLabelText('Rotate Clockwise');
  const counterclockwise = screen.getAllByLabelText('Rotate Counter-Clockwise');
  expect(clockwise).toHaveLength(2);
  expect(counterclockwise).toHaveLength(2);
  fireEvent.click(clockwise[0]);
  expect(send).toHaveBeenLastCalledWith('setView', { dir: '8' });
  fireEvent.click(clockwise[1]);
  expect(send).toHaveBeenLastCalledWith('setView', { dir: '1' });
  fireEvent.click(counterclockwise[0]);
  expect(send).toHaveBeenLastCalledWith('setView', { dir: '8' });
  fireEvent.click(counterclockwise[1]);
  // The initial server view is Front; returning to it needs no extra request.
  expect(send).toHaveBeenCalledTimes(3);
  expect(screen.getByText('Front').closest('.Button')?.className).toContain(
    'Button--selected',
  );
});
