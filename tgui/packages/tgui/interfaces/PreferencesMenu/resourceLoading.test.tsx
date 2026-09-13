import { afterEach, beforeEach, describe, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import { gameDataAtom, store } from '../../events/store';
import { LoadoutPage } from './CharacterPreferences/loadout';
import { KeybindingsPage } from './GamePreferences/KeybindingsPage';
import type { ServerData } from './types';
import { ServerPrefs } from './useServerPrefs';

const previousState = store.get(gameDataAtom);

beforeEach(() => {
  store.set(gameDataAtom, {
    ...previousState,
    character_preferences: {
      misc: {
        loadout_index: 'Default',
        loadout_lists: { loadouts: ['Default'], loadout: {} },
      },
    },
    preview_options: [],
    character_preview_view: 'test-preview',
  });
});

afterEach(() => store.set(gameDataAtom, previousState));

describe('preference resource loading', () => {
  it('survives absent categories and selects the first category when it arrives', () => {
    const page = render(
      <ServerPrefs.Provider value={undefined}>
        <LoadoutPage />
      </ServerPrefs.Provider>,
    );
    expect(screen.getByText('Loading...')).toBeTruthy();
    const data = {
      loadout: {
        loadout_tabs: [
          { name: 'Clothes', contents: [], category_info: 'Clothes arrived' },
          {
            name: 'Accessories',
            contents: [],
            category_info: 'Accessories arrived',
          },
        ],
      },
    } as unknown as ServerData;
    page.rerender(
      <ServerPrefs.Provider value={data}>
        <LoadoutPage />
      </ServerPrefs.Provider>,
    );
    expect(screen.getByText('Clothes arrived')).toBeTruthy();
    fireEvent.click(screen.getByText('Accessories'));
    expect(screen.getByText('Accessories arrived')).toBeTruthy();
    page.rerender(
      <ServerPrefs.Provider value={{ ...data }}>
        <LoadoutPage />
      </ServerPrefs.Provider>,
    );
    expect(screen.getByText('Accessories arrived')).toBeTruthy();
  });

  it('accepts null hotkey lists and preserves configured bindings', () => {
    store.set(gameDataAtom, {
      ...store.get(gameDataAtom),
      keybindings: { unbound: null, move: ['Unbound', 'W'] },
    });
    const page = new KeybindingsPage({});
    const update = spyOn(page, 'setState').mockImplementation(() => {});
    page.populateSelectedKeybindings();
    expect(update).toHaveBeenCalledWith({
      selectedKeybindings: { unbound: [], move: ['W'] },
    });
    update.mockRestore();
  });
});
