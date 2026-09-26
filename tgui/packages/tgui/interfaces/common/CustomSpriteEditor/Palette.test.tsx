// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { createStore, Provider } from 'jotai';
import type { ComponentProps } from 'react';
import * as actions from 'tgui/events/act';
import { SpriteEditor } from '../SpriteEditor';
import { currentColorAtom } from '../SpriteEditor/atoms';
import { CustomSpritePalette as Palette } from './Palette';

const CustomSpritePalette = ({
  selected = '#ffffff',
  ...props
}: ComponentProps<typeof Palette> & { selected?: string }) => {
  SpriteEditor.syncBackend('selectColor', selected);
  return <Palette {...props} />;
};

const SyncedPalette = ({ selected }: { selected: string }) => {
  return (
    <CustomSpritePalette
      selected={selected}
      serverPalette={['#ffffff', selected]}
      customPalette={[]}
      availableColors={['#ffffff', selected]}
      maxCustomColors={16}
      displayTint={null}
    />
  );
};

let send: ReturnType<typeof spyOn>;
beforeEach(() => {
  send = spyOn(actions, 'sendAct');
});
afterEach(() => send.mockRestore());

it('confirms saving a regular swatch from an anchored menu without selecting it', async () => {
  const store = createStore();
  const view = render(
    <Provider store={store}>
      <CustomSpritePalette
        serverPalette={['#ffffff', '#12abef']}
        customPalette={[]}
        availableColors={['#ffffff', '#12abef']}
        maxCustomColors={16}
        displayTint={null}
      />
    </Provider>,
  );
  const swatch = view.container.querySelectorAll('.Button')[1];
  const anchor = swatch.parentElement;
  fireEvent.contextMenu(swatch);
  const save = await screen.findByText('Save');
  // Opening a popup must preserve its swatch and the surrounding layout.
  expect(view.container.querySelectorAll('.Button')[1] === swatch).toBe(true);
  expect(swatch.parentElement === anchor).toBe(true);
  fireEvent.mouseLeave(swatch);
  fireEvent.mouseEnter(save);
  expect(screen.queryByText('Save') === save).toBe(true);
  // Tooltip styling disables pointer events unless an interactive popup opts in.
  expect(getComputedStyle(save.closest('.Floating')!).pointerEvents).toBe(
    'auto',
  );
  expect(send).not.toHaveBeenCalled();
  expect(store.get(currentColorAtom)).toEqual({ r: 255, g: 255, b: 255, a: 1 });
  fireEvent.click(save);
  expect(send).toHaveBeenCalledWith('savePaletteColor', { color: '#12abef' });
  await waitFor(() => expect(screen.queryByText('Save')).toBeNull());
  const otherSwatch = view.container.querySelector('.Button')!;
  const otherAnchor = otherSwatch.parentElement;
  fireEvent.contextMenu(otherSwatch);
  const otherSave = await screen.findByText('Save');
  expect(view.container.querySelector('.Button')).toBe(otherSwatch);
  expect(otherSwatch.parentElement).toBe(otherAnchor);
  fireEvent.click(otherSave);
  expect(send).toHaveBeenLastCalledWith('savePaletteColor', {
    color: '#ffffff',
  });
  await waitFor(() => expect(screen.queryByText('Save')).toBeNull());
});

it('confirms removal of an unavailable custom swatch and dismisses menus without acting', async () => {
  const view = render(
    <CustomSpritePalette
      serverPalette={['#ffffff']}
      customPalette={['#12abef']}
      availableColors={['#ffffff']}
      maxCustomColors={16}
      displayTint={null}
    />,
  );
  const open = () =>
    fireEvent.contextMenu(view.container.querySelectorAll('.Button')[1]);
  open();
  await screen.findByText('Remove');
  expect(send).not.toHaveBeenCalled();
  fireEvent.mouseDown(document.body);
  await waitFor(() => expect(screen.queryByText('Remove')).toBeNull());
  open();
  await screen.findByText('Remove');
  fireEvent.keyDown(document, { key: 'Escape' });
  await waitFor(() => expect(screen.queryByText('Remove')).toBeNull());
  expect(send).not.toHaveBeenCalled();
  open();
  fireEvent.click(await screen.findByText('Remove'));
  expect(send).toHaveBeenCalledWith('removePaletteColor', { color: '#12abef' });
  await waitFor(() => expect(screen.queryByText('Remove')).toBeNull());
});

it('offers editing a custom swatch above Remove, starting from its saved color', async () => {
  const view = render(
    <CustomSpritePalette
      serverPalette={['#ffffff']}
      customPalette={['#12abef']}
      availableColors={['#ffffff', '#12abef']}
      maxCustomColors={16}
      displayTint="#ff0000"
    />,
  );
  const [regular, saved] = view.container.querySelectorAll('.Button');
  fireEvent.contextMenu(regular);
  await screen.findByText('Save');
  expect(screen.queryByText('Edit')).toBeNull();
  fireEvent.contextMenu(saved);
  const edit = (await screen.findByText('Edit')).closest('.Button')!;
  const remove = screen.getByText('Remove').closest('.Button')!;
  expect(edit.nextElementSibling).toBe(remove);
  fireEvent.click(edit);
  // The raw saved color, not its tinted display.
  expect(send).toHaveBeenCalledWith('editPaletteColor', { color: '#12abef' });
  await waitFor(() => expect(screen.queryByText('Edit')).toBeNull());
});

it('selects sampled guide colors after palette changes and repeated sampling', () => {
  const store = createStore();
  const renderPalette = (selected: string) => (
    <Provider store={store}>
      <SyncedPalette selected={selected} />
    </Provider>
  );
  const view = render(renderPalette('#ffffff'));
  view.rerender(renderPalette('#12abef'));
  expect(store.get(currentColorAtom)).toEqual({ r: 18, g: 171, b: 239, a: 1 });
  fireEvent.click(view.container.querySelector('.Button')!);
  expect(send).toHaveBeenLastCalledWith('selectColor', { color: '#ffffffff' });
  view.rerender(renderPalette('#ffffff'));
  view.rerender(renderPalette('#12abef'));
  expect(store.get(currentColorAtom)).toEqual({ r: 18, g: 171, b: 239, a: 1 });
  view.rerender(renderPalette('#abcdef'));
  expect(store.get(currentColorAtom)).toEqual({ r: 171, g: 205, b: 239, a: 1 });
});
