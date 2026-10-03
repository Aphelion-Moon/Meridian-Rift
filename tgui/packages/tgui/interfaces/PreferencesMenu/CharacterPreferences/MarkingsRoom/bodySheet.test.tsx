// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it, spyOn } from 'bun:test';
import { act, cleanup, render } from '@testing-library/react';
import { Provider } from 'jotai';

import * as acts from '../../../../events/act';
import {
  configAtom,
  gameDataAtom,
  gameStaticDataAtom,
  store,
} from '../../../../events/store';
import type { ServerData } from '../../types';
import { ServerPrefs } from '../../useServerPrefs';
import { speciesSpriteClasses } from '../SpeciesRegistry/constants';
import { MarkingsRoom } from './index';
import { spriteCell } from './sprites';
import { ROOM_THEMES } from './themes';

// A species icon of this test's own, so no other test has found its body.
const ICON = 'body-sheet-test';
const BODY = speciesSpriteClasses(ICON, 'south', true);

const server = {
  species: { human: { name: 'Human', icon: ICON } },
  limbs_and_markings: {
    augment_items: [],
    marking_choices: {},
    marking_info: {},
    marking_presets: [],
  },
} as unknown as ServerData;

const originalConfig = store.get(configAtom);
const originalData = store.get(gameDataAtom);
const originalStatic = store.get(gameStaticDataAtom);
beforeEach(() => {
  store.set(configAtom, {
    ...originalConfig,
    meridianTheme: 'meridian_aphelion',
  });
  store.set(gameStaticDataAtom, {});
  store.set(gameDataAtom, {
    character_preferences: { misc: { species: 'human' } },
  });
});
afterEach(async () => {
  await act(async () => {});
  cleanup();
  store.set(configAtom, originalConfig);
  store.set(gameDataAtom, originalData);
  store.set(gameStaticDataAtom, originalStatic);
});

/** The room opened: what it asked the server for the species' bodies. */
function openRoom() {
  // The room asks through the window's own act, as useBackend gives it.
  const sent = spyOn(acts, 'sendAct');
  try {
    render(
      <Provider store={store}>
        <ServerPrefs.Provider value={server}>
          <MarkingsRoom
            theme={ROOM_THEMES.aphelion}
            act={() => {}}
            onLook={() => {}}
          />
        </ServerPrefs.Provider>
      </Provider>,
    );
    return sent.mock.calls.filter(
      ([action]) => action === 'species_page_sprites',
    );
  } finally {
    sent.mockRestore();
  }
}

describe("the species' bodies under the thumbnails", () => {
  it('are asked for until their sheet has come, and not again after', () => {
    // The sheet hasn't come: the body has no cell yet.
    expect(openRoom()).toEqual([['species_page_sprites', { body: true }]]);
    cleanup();

    // The sheet has come, and the room has found the body's cell in it.
    const style = spyOn(globalThis, 'getComputedStyle').mockImplementation(
      () =>
        ({
          backgroundImage: 'url("species_body.png")',
          backgroundPosition: '-32px 0px',
          width: '32px',
          height: '32px',
        }) as CSSStyleDeclaration,
    );
    try {
      expect(spriteCell(BODY)?.url).toBe('species_body.png');
    } finally {
      style.mockRestore();
    }
    expect(openRoom()).toEqual([]);
  });
});
