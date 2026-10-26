// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it, mock } from 'bun:test';
import { act, cleanup, render } from '@testing-library/react';
import { Provider } from 'jotai';

import {
  configAtom,
  gameDataAtom,
  gameStaticDataAtom,
  store,
} from '../../../../events/store';
import type { ServerData } from '../../types';
import { ServerPrefs } from '../../useServerPrefs';
import { AugmentsStage } from './augments';
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
  await act(async () => {});
  cleanup();
  store.set(configAtom, originalConfig);
  store.set(gameDataAtom, originalData);
  store.set(gameStaticDataAtom, originalStatic);
});

const drawing = (id: number) => ({
  id,
  species: 'human',
  slot: 1,
  image: 'data:image/png;base64,drawing',
  width: 32,
  height: 32,
  x: 0,
  y: 0,
  frames: { north: 0, south: 32, east: 64, west: 96 },
});

const server = {
  species: {},
  limbs_and_markings: {
    augment_items: [],
    marking_choices: {},
    marking_info: {},
    marking_presets: [],
  },
} as unknown as ServerData;

/** The page's data with drawing 5 shown, and a region map held for `regionsFor`, keyed "map-key". */
function seed(regionsFor: number | undefined) {
  store.set(gameDataAtom, {
    character_preferences: { misc: { species: 'human' } },
    character_preview: drawing(5),
    markings_room_regions: {
      id: 4,
      key: 'map-key',
      zones: ['chest'],
      width: 32,
      rows: {},
    },
    markings_room_regions_for: regionsFor,
  });
}

const regionAsks = (act: ReturnType<typeof mock>) =>
  act.mock.calls.filter(([action]) => action === 'markings_room_regions');

describe('asking for the region map', () => {
  for (const [name, view] of [
    [
      'the markings room',
      (act: ReturnType<typeof mock>) => (
        <MarkingsRoom
          theme={ROOM_THEMES.aphelion}
          act={act}
          onLook={() => {}}
        />
      ),
    ],
    [
      'the augments stage',
      (act: ReturnType<typeof mock>) => (
        <AugmentsStage internals={false} parts={[]} organs={[]} act={act} />
      ),
    ],
  ] as const) {
    it(`${name} asks for a drawing its map isn't known to fit, saying which map it holds`, () => {
      seed(4);
      const act = mock();
      render(
        <Provider store={store}>
          <ServerPrefs.Provider value={server}>
            {view(act)}
          </ServerPrefs.Provider>
        </Provider>,
      );
      expect(regionAsks(act)).toEqual([
        ['markings_room_regions', { id: 5, have: 'map-key' }],
      ]);
    });

    it(`${name} doesn't ask again for a drawing its map fits`, () => {
      seed(5);
      const act = mock();
      render(
        <Provider store={store}>
          <ServerPrefs.Provider value={server}>
            {view(act)}
          </ServerPrefs.Provider>
        </Provider>,
      );
      expect(regionAsks(act)).toEqual([]);
    });
  }
});
