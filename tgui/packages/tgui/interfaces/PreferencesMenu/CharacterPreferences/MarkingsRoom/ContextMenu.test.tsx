// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it, mock } from 'bun:test';
import {
  cleanup,
  fireEvent,
  render,
  screen,
  act as update,
  within,
} from '@testing-library/react';
import { Provider, useAtomValue } from 'jotai';

import {
  configAtom,
  gameDataAtom,
  gameStaticDataAtom,
  store,
} from '../../../../events/store';
import type { ServerData } from '../../types';
import { ServerPrefs } from '../../useServerPrefs';
import { MarkingsRoom } from './index';
import { ROOM_THEMES } from './themes';

const originalConfig = store.get(configAtom);
const originalData = store.get(gameDataAtom);
const originalStatic = store.get(gameStaticDataAtom);
beforeEach(() => {
  store.set(configAtom, {
    ...originalConfig,
    meridianTheme: 'meridian_aphelion',
  });
  store.set(gameStaticDataAtom, {});
});
afterEach(async () => {
  await update(async () => {});
  cleanup();
  store.set(configAtom, originalConfig);
  store.set(gameDataAtom, originalData);
  store.set(gameStaticDataAtom, originalStatic);
});

function openRoom(emissive = 0, canGlow = true) {
  const act = mock();
  const marking = (marking_id: number, name: string) => ({
    marking_id: String(marking_id),
    name,
    color: '#ff0000',
    emissive,
    locked: 0,
  });
  store.set(gameDataAtom, {
    character_preferences: {
      misc: { species: 'human' },
      secondary_features: { allow_emissives_toggle: canGlow },
    },
    markings: {
      head: [marking(1, 'Head marking')],
      r_arm: [marking(2, 'Spots'), marking(3, 'Stripes')],
    },
  });
  const server = {
    species: {},
    limbs_and_markings: {
      augment_items: [],
      marking_choices: { r_arm: ['Spots', 'Stripes', 'Bands'] },
      marking_info: {},
      marking_presets: [],
    },
  } as unknown as ServerData;
  function ReactiveRoom() {
    useAtomValue(gameDataAtom);
    return (
      <MarkingsRoom theme={ROOM_THEMES.aphelion} act={act} onLook={() => {}} />
    );
  }
  render(
    <Provider store={store}>
      <ServerPrefs.Provider value={server}>
        <ReactiveRoom />
      </ServerPrefs.Provider>
    </Provider>,
  );
  return act;
}
const tile = () => screen.getByRole('button', { name: /^Stripes, slot 2/ });
const openMenu = async () => {
  await update(async () => fireEvent.contextMenu(tile()));
  return screen.getByRole('menu', { name: 'Stripes actions' });
};

describe('worn marking interactions', () => {
  it('left-click selects a marking without opening a picker', async () => {
    const act = openRoom();
    fireEvent.click(tile());
    expect(tile().getAttribute('aria-pressed')).toBe('true');
    expect(screen.queryByRole('dialog') === null).toBe(true);
    expect(screen.queryByRole('menu') === null).toBe(true);
    expect(act).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole('button', { name: 'Swap' }));
    expect(screen.getByText('Swap out Stripes')).toBeDefined();
  });

  it('right-click offers actions for that marking and Change opens its swap picker', async () => {
    const act = openRoom();
    const menu = await openMenu();
    expect(tile().getAttribute('aria-pressed')).toBe('true');
    expect(within(menu).queryByText('Stripes') === null).toBe(true);
    expect(
      within(menu)
        .getAllByRole('menuitem')
        .map((e) => e.textContent),
    ).toEqual(['Change', 'Enable glow', 'Remove']);
    fireEvent.click(within(menu).getByRole('menuitem', { name: 'Change' }));
    expect(screen.queryByRole('menu') === null).toBe(true);
    const drawer = screen.getByRole('dialog', { name: 'Right arm markings' });
    expect(within(drawer).getByText('Swap out Stripes')).toBeDefined();
    fireEvent.click(within(drawer).getByRole('button', { name: 'Bands' }));
    expect(act).toHaveBeenCalledWith('change_marking', {
      bodypart_slot: 'r_arm',
      marking_id: '3',
      marking_name: 'Bands',
    });
  });

  for (const emissive of [0, 1]) {
    it(`offers ${emissive ? 'Disable' : 'Enable'} glow and targets the clicked marking`, async () => {
      const act = openRoom(emissive);
      const menu = await openMenu();
      fireEvent.click(
        within(menu).getByRole('menuitem', {
          name: emissive ? 'Disable glow' : 'Enable glow',
        }),
      );
      expect(act).toHaveBeenCalledWith('change_emissive', {
        bodypart_slot: 'r_arm',
        marking_id: '3',
        emissive,
      });
      expect(screen.queryByRole('menu') === null).toBe(true);
    });
  }

  it('disables Enable glow when emissives are not allowed', async () => {
    const act = openRoom(0, false);
    const menu = await openMenu();
    const glow = within(menu).getByRole('menuitem', {
      name: 'Enable glow',
    }) as HTMLButtonElement;
    expect(glow.disabled).toBe(true);
    fireEvent.click(glow);
    expect(act).not.toHaveBeenCalled();
  });

  it('allows disabling an existing glow even when new emissives are disabled', async () => {
    const act = openRoom(1, false);
    fireEvent.click(
      within(await openMenu()).getByRole('menuitem', { name: 'Disable glow' }),
    );
    expect(act).toHaveBeenCalledWith('change_emissive', {
      bodypart_slot: 'r_arm',
      marking_id: '3',
      emissive: 1,
    });
  });

  it('removes the right-clicked marking rather than the previous selection', async () => {
    const act = openRoom();
    fireEvent.click(
      within(await openMenu()).getByRole('menuitem', { name: 'Remove' }),
    );
    expect(act).toHaveBeenCalledWith('remove_marking', {
      bodypart_slot: 'r_arm',
      marking_id: '3',
    });
    expect(screen.queryByRole('menu') === null).toBe(true);
  });

  it('dismisses on Escape and outside press without changing markings', async () => {
    const act = openRoom();
    await openMenu();
    fireEvent.keyDown(document, { key: 'Escape' });
    expect(screen.queryByRole('menu') === null).toBe(true);
    await openMenu();
    fireEvent.pointerDown(document.body);
    expect(screen.queryByRole('menu') === null).toBe(true);
    expect(act).not.toHaveBeenCalled();
  });

  it('opens from the keyboard and skips the disabled glow action', async () => {
    openRoom(0, false);
    await update(async () =>
      fireEvent.keyDown(tile(), { key: 'F10', shiftKey: true }),
    );
    const menu = screen.getByRole('menu');
    const change = within(menu).getByRole('menuitem', { name: 'Change' });
    update(() => change.focus());
    fireEvent.keyDown(change, { key: 'ArrowDown' });
    expect(
      document.activeElement ===
        within(menu).getByRole('menuitem', { name: 'Remove' }),
    ).toBe(true);
  });

  it('drops the menu if its marking disappears in a server update', async () => {
    openRoom();
    await openMenu();
    update(() =>
      store.set(gameDataAtom, { ...store.get(gameDataAtom), markings: {} }),
    );
    expect(screen.queryByRole('menu') === null).toBe(true);
  });
});
