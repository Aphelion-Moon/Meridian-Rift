// THIS IS AN APHELION UI FILE
import { expect, it } from 'bun:test';
import { fireEvent, render, screen, within } from '@testing-library/react';
import { createStore, Provider } from 'jotai';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';
import {
  fixture,
  send,
  setupEditorTests,
} from '../../../__mocks__/customSpriteEditor';
import { currentToolAtom, tools } from '../SpriteEditor/atoms';
import { CustomSpriteEditor } from './index';

setupEditorTests();

const renderEditor = (target: 'hair' | 'markings' = 'markings') => {
  const store = createStore();
  const editor = () => (
    <Provider store={store}>
      <CustomSpriteEditor target={target} />
    </Provider>
  );
  const view = render(editor());
  return { store, view, editor };
};

const pip = (label: string) =>
  screen
    .getByText(label)
    .closest('.Button')!
    .querySelector('.CustomSpriteEditor__pip')!;

it('frames the views together and lights a pip on each view that has paint', () => {
  renderEditor();
  expect(
    screen.getByText('Front').closest('.CustomSpriteEditor__group'),
  ).toBeTruthy();
  expect(pip('Front').classList).toContain('CustomSpriteEditor__pip--lit');
  expect(pip('Front').getAttribute('aria-label')).toBe('Has markings');
  expect(pip('Back').classList).not.toContain('CustomSpriteEditor__pip--lit');
  expect(pip('Back').getAttribute('aria-label')).toBe('No markings yet');
  expect(pip('Front').getAttribute('role')).toBe('img');
  expect(screen.queryByText(/•/)).toBeNull();
  expect(screen.getByText('Front').closest('.Button')!.classList).toContain(
    'Button--selected',
  );
});

it('groups the tools with their hotkey letters and switches tools from them', () => {
  const { store, view } = renderEditor();
  const tool = (key: string) =>
    view.container.querySelector(
      `.Button[data-hotkey="${key}"]`,
    ) as HTMLElement;
  expect(tool('B').classList).toContain('Button--selected');
  expect(tool('B').closest('.CustomSpriteEditor__group')).toBeTruthy();
  expect(tool('M')).toBeTruthy();
  expect(tool('G')).toBeTruthy();
  // The stylesheet draws the letters, so they never widen a button or read as text.
  expect(screen.queryByText('B')).toBeNull();
  fireEvent.click(tool('E'));
  expect(store.get(currentToolAtom)).toBe(tools[1]);
});

it('frames Clear and history like their neighbours, and Import and Export as one pair', () => {
  const { view } = renderEditor('hair');
  const clear = screen.getByText('Clear layer').closest('.Button')!;
  expect(clear.classList).not.toContain('Button--color--transparent');
  expect(clear.classList).toContain('CustomSpriteEditor__clear');
  expect(view.container.querySelector('.CustomSpriteEditor__ghost')).toBeNull();
  fireEvent.click(clear);
  expect(send).toHaveBeenLastCalledWith('clear', { dir: '2' });
  const files = screen
    .getByText('Import')
    .closest('.CustomSpriteEditor__group')!;
  expect(within(files as HTMLElement).getByText('Export')).toBeTruthy();
  expect(
    view.container
      .querySelector('.Button[data-hotkey="B"]')!
      .closest('.CustomSpriteEditor__group'),
  ).not.toBe(files);
});

it('keeps every visibility toggle on show polarity in one tray', () => {
  backendStore.set(gameDataAtom, {
    ...fixture(),
    canHideParts: true,
    hideParts: false,
    canHideUnderwear: true,
    hideUnderwear: true,
  });
  renderEditor();
  const tray = screen.getByText('Guide').closest('.CustomSpriteEditor__tray')!;
  const toggle = (label: string) =>
    within(tray as HTMLElement)
      .getByText(label)
      .closest('.Button')!;
  expect(toggle('Guide').classList).toContain('Button--selected');
  expect(toggle('Parts').classList).toContain('Button--selected');
  expect(toggle('Underwear').classList).not.toContain('Button--selected');
  expect(toggle('Grid').classList).not.toContain('Button--selected');
  fireEvent.click(toggle('Grid'));
  expect(toggle('Grid').classList).toContain('Button--selected');
  expect(screen.queryByText('Hide parts')).toBeNull();
  expect(screen.queryByText('Hide underwear')).toBeNull();
});

it('follows the server when it flips a visibility flag on refresh', () => {
  backendStore.set(gameDataAtom, {
    ...fixture(),
    canHideParts: 1,
    hideParts: 1,
  });
  const { view, editor } = renderEditor();
  const parts = () => screen.getByText('Parts').closest('.Button')!;
  expect(parts().classList).not.toContain('Button--selected');
  backendStore.set(gameDataAtom, {
    ...fixture(),
    canHideParts: 1,
    hideParts: 0,
  });
  view.rerender(editor());
  expect(parts().classList).toContain('Button--selected');
});
