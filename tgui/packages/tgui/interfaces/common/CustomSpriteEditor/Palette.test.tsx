// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, expect, it, spyOn } from 'bun:test';
import { join } from 'node:path';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { createStore, Provider } from 'jotai';
import type { ComponentProps } from 'react';
import { compileAsync } from 'sass-embedded';
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

it('keeps custom editor swatches plain while retaining a subtle selected border', async () => {
  const sheets = await Promise.all(
    [
      '../../../../../node_modules/tgui-core/styles/components/Button.scss',
      '../../../styles/meridianos/_components.scss',
      '../../../styles/meridianos/_neon-glass.scss',
      '../../../styles/interfaces/CustomSpriteEditor.scss',
    ].map(
      async (path) => (await compileAsync(join(import.meta.dir, path))).css,
    ),
  );
  const style = document.createElement('style');
  style.textContent = sheets.join('\n');
  document.head.appendChild(style);
  try {
    const view = render(
      <div className="theme-console theme-meridian_synapse">
        <Provider store={createStore()}>
          <CustomSpritePalette
            serverPalette={['#ffffff', '#12abef']}
            customPalette={['#808080']}
            availableColors={['#ffffff', '#12abef']}
            maxCustomColors={16}
            displayTint={null}
          />
        </Provider>
      </div>,
    );
    const swatches = view.container.querySelectorAll<HTMLElement>(
      '.SpriteEditor__plainSwatch',
    );
    expect(swatches).toHaveLength(3);
    for (const swatch of swatches) {
      const computed = getComputedStyle(swatch);
      expect(swatch.classList.contains('Button--selected')).toBe(false);
      expect(computed.backgroundBlendMode).toBe('normal');
      expect(computed.boxShadow).toBe('none');
      expect(computed.opacity).toBe('1');
    }
    expect(swatches[0].getAttribute('aria-pressed')).toBe('true');
    expect(getComputedStyle(swatches[0]).borderTopColor).not.toBe(
      getComputedStyle(swatches[1]).borderTopColor,
    );
    fireEvent.click(swatches[1]);
    expect(swatches[1].getAttribute('aria-pressed')).toBe('true');
    expect(swatches[0].getAttribute('aria-pressed')).toBe('false');
    expect(swatches[1].style.backgroundImage).toContain('#12abef');
    const add = view.container.querySelector('.Button--hasIcon')!;
    expect(add.classList.contains('SpriteEditor__plainSwatch')).toBe(false);
  } finally {
    style.remove();
  }
});

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

it('offers editing a custom swatch below Remove, starting from its saved color', async () => {
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
  const remove = (await screen.findByText('Remove')).closest('.Button')!;
  const edit = screen.getByText('Edit').closest('.Button')!;
  expect(remove.nextElementSibling).toBe(edit);
  fireEvent.click(edit);
  // The raw saved color, not its tinted display.
  expect(send).toHaveBeenCalledWith('editPaletteColor', { color: '#12abef' });
  await waitFor(() => expect(screen.queryByText('Edit')).toBeNull());
});

it.each([
  { customPalette: ['#12abef'], maxCustomColors: 16 },
  { customPalette: ['#ffffff'], maxCustomColors: 1 },
])('does not save duplicate or over-capacity swatches: %p', async ({
  customPalette,
  maxCustomColors,
}) => {
  const view = render(
    <CustomSpritePalette
      serverPalette={['#12abef']}
      customPalette={[...customPalette]}
      availableColors={['#12abef', '#ffffff']}
      maxCustomColors={maxCustomColors}
      displayTint={null}
    />,
  );
  fireEvent.contextMenu(view.container.querySelector('.Button')!);
  const save = (await screen.findByText('Save')).closest('.Button')!;
  expect(save.classList.contains('Button--disabled')).toBe(true);
  fireEvent.click(save);
  expect(send).not.toHaveBeenCalled();
});

it('keeps unavailable saved colors visible but unselectable until the drawing has room', async () => {
  const store = createStore();
  store.set(currentColorAtom, { r: 128, g: 128, b: 128, a: 1 });
  const view = render(
    <Provider store={store}>
      <CustomSpritePalette
        serverPalette={['#ffffff']}
        customPalette={['#808080']}
        availableColors={['#ffffff']}
        maxCustomColors={16}
        displayTint={null}
      />
    </Provider>,
  );
  let saved = view.container.querySelectorAll<HTMLElement>('.Button')[1];
  expect(saved.classList.contains('Button--disabled')).toBe(true);
  expect(store.get(currentColorAtom)).toEqual({ r: 255, g: 255, b: 255, a: 1 });
  fireEvent.click(saved);
  fireEvent.contextMenu(saved);
  await screen.findByText('Remove');
  saved = view.container.querySelectorAll<HTMLElement>('.Button')[1];
  expect(store.get(currentColorAtom)).toEqual({ r: 255, g: 255, b: 255, a: 1 });
  fireEvent.mouseOver(saved);
  expect(document.activeElement === saved).toBe(true);
  fireEvent.keyDown(saved, { keyCode: 46 });
  expect(send).toHaveBeenCalledWith('removePaletteColor', { color: '#808080' });
  await waitFor(() => expect(screen.queryByText('Remove')).toBeNull());
  view.rerender(
    <Provider store={store}>
      <CustomSpritePalette
        serverPalette={['#ffffff']}
        customPalette={['#808080']}
        availableColors={['#ffffff', '#808080']}
        maxCustomColors={16}
        displayTint={null}
      />
    </Provider>,
  );
  const enabled = view.container.querySelectorAll<HTMLElement>('.Button')[1];
  expect(enabled.classList.contains('Button--disabled')).toBe(false);
  fireEvent.click(enabled);
  expect(send).toHaveBeenLastCalledWith('selectCustomColor', {
    color: '#808080',
  });
  expect(store.get(currentColorAtom)).toEqual({ r: 255, g: 255, b: 255, a: 1 });
});

it('opens the saved-color picker even when the current shade is already saved', () => {
  const view = render(
    <CustomSpritePalette
      serverPalette={['#ffffff']}
      customPalette={['#ffffff']}
      availableColors={['#ffffff']}
      maxCustomColors={16}
      displayTint={null}
    />,
  );
  const buttons = view.container.querySelectorAll('.Button');
  fireEvent.click(buttons[2]);
  expect(send).toHaveBeenCalledWith('addPaletteColor');
  fireEvent.keyDown(buttons[0], { keyCode: 46 });
  expect(send).toHaveBeenCalledTimes(1);
  fireEvent.keyDown(buttons[1], { keyCode: 46 });
  expect(send).toHaveBeenLastCalledWith('removePaletteColor', {
    color: '#ffffff',
  });
});

it('uses acknowledged custom shades while automatic colors stay literal across tint changes', () => {
  const store = createStore();
  const TintedPalette = ({
    selected,
    tint,
    automatic,
  }: {
    selected: string;
    tint: string;
    automatic: string;
  }) => {
    return (
      <CustomSpritePalette
        selected={selected}
        serverPalette={[automatic]}
        customPalette={['#808080']}
        availableColors={['#ffffff', '#eeeeee', '#804000', '#004080']}
        maxCustomColors={16}
        displayTint={tint}
      />
    );
  };
  const view = render(
    <Provider store={store}>
      <TintedPalette selected="#ffffff" tint="#ff8000" automatic="#ffffff" />
    </Provider>,
  );
  fireEvent.click(view.container.querySelectorAll('.Button')[1]);
  expect(send).toHaveBeenLastCalledWith('selectCustomColor', {
    color: '#808080',
  });
  expect(store.get(currentColorAtom)).toEqual({ r: 255, g: 255, b: 255, a: 1 });
  view.rerender(
    <Provider store={store}>
      <TintedPalette selected="#804000" tint="#ff8000" automatic="#ffffff" />
    </Provider>,
  );
  expect(store.get(currentColorAtom)).toEqual({ r: 128, g: 64, b: 0, a: 1 });
  view.rerender(
    <Provider store={store}>
      <TintedPalette selected="#004080" tint="#0080ff" automatic="#eeeeee" />
    </Provider>,
  );
  expect(store.get(currentColorAtom)).toEqual({ r: 0, g: 64, b: 128, a: 1 });
  expect(
    view.container.querySelector<HTMLElement>('.Button')!.style.backgroundImage,
  ).toContain('#eeeeee');
  const selected = view.container.querySelector<HTMLElement>(
    '[aria-pressed="true"]',
  )!;
  expect(selected.style.backgroundImage).toContain('#004080');
  view.rerender(
    <Provider store={store}>
      <CustomSpritePalette
        serverPalette={['#eeeeee']}
        selected="#eeeeee"
        customPalette={[]}
        availableColors={['#eeeeee']}
        maxCustomColors={16}
        displayTint={null}
      />
    </Provider>,
  );
  expect(store.get(currentColorAtom)).toEqual({ r: 238, g: 238, b: 238, a: 1 });
});

it('hides adding at the account limit while keeping removal available', () => {
  const customPalette = Array.from(
    { length: 16 },
    (_, index) => `#${index.toString(16).padStart(6, '0')}`,
  );
  const view = render(
    <CustomSpritePalette
      serverPalette={['#ffffff']}
      customPalette={customPalette}
      availableColors={['#ffffff', ...customPalette]}
      maxCustomColors={16}
      displayTint={null}
    />,
  );
  const buttons = view.container.querySelectorAll('.Button');
  expect(buttons).toHaveLength(17);
  fireEvent.keyDown(buttons[1], { keyCode: 46 });
  expect(send).toHaveBeenCalledWith('removePaletteColor', { color: '#000000' });
  view.rerender(
    <CustomSpritePalette
      serverPalette={['#ffffff']}
      customPalette={customPalette.slice(1)}
      availableColors={['#ffffff', ...customPalette]}
      maxCustomColors={16}
      displayTint={null}
    />,
  );
  fireEvent.click(view.container.querySelectorAll('.Button')[16]);
  expect(send).toHaveBeenLastCalledWith('addPaletteColor');
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
