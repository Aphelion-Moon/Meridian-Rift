// THIS IS AN APHELION UI FILE
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  mock,
  spyOn,
} from 'bun:test';
import { act, cleanup, fireEvent, render } from '@testing-library/react';
import { Provider } from 'jotai';

import * as acts from '../../../../../events/act';
import {
  configAtom,
  gameDataAtom,
  gameStaticDataAtom,
  store,
  suspendedAtom,
} from '../../../../../events/store';
import type { ServerData } from '../../../types';
import { ServerPrefs } from '../../../useServerPrefs';
import { AugmentsRoom } from '../Room';
import { ROOM_THEMES } from '../themes';
import { brandSpritesAskedAtom } from './brands';
import { AugmentsStage } from './index';

// The window's own pages, which webpack's require.context loads and bun
// can't: the window opens on a page of nothing, and its tabs are as they are.
mock.module('../../AntagsPage', () => ({ AntagsPage: () => null }));
mock.module('../../MainPage', () => ({
  MainPage: () => null,
  PreferenceList: () => null,
  getRandomization: () => ({}),
}));

const server = { species: {} } as unknown as ServerData;
const originalConfig = store.get(configAtom);
const originalData = store.get(gameDataAtom);
const originalStatic = store.get(gameStaticDataAtom);
let sent: ReturnType<typeof spyOn>;
beforeEach(() => {
  store.set(configAtom, {
    ...originalConfig,
    meridianTheme: 'meridian_aphelion',
  });
  store.set(gameStaticDataAtom, {});
  store.set(gameDataAtom, {
    character_preferences: { misc: { species: 'human' } },
    character_profiles: ['Ash'],
    active_slot: 1,
    content_unlocked: 1,
  });
  store.set(brandSpritesAskedAtom, false);
  sent = spyOn(acts, 'sendAct');
});
afterEach(async () => {
  await act(async () => {});
  cleanup();
  sent.mockRestore();
  store.set(configAtom, originalConfig);
  store.set(gameDataAtom, originalData);
  store.set(gameStaticDataAtom, originalStatic);
});

/** Past the stage's wait for the window to be idle: happy-dom has no requestIdleCallback, so its 500 ms fallback. */
const IDLE = 600;

/** The window's asks for the brand sprites so far. */
const asks = () =>
  sent.mock.calls.filter(([action]) => action === 'augment_brand_sprites')
    .length;

const wait = (ms: number) =>
  act(() => new Promise((resolve) => setTimeout(resolve, ms)));
/** Past the 100 ms a pointer or the keyboard must rest on a way in before the window asks. */
const REST = 150;

/** The pointer resting on it, then the keyboard, then both moving on. */
async function rest(element: Element) {
  act(() => {
    fireEvent.mouseEnter(element);
  });
  await wait(REST);
  act(() => {
    fireEvent.mouseLeave(element);
    fireEvent.focus(element);
  });
  await wait(REST);
  act(() => {
    fireEvent.blur(element);
  });
}

/** The pointer passing over it, unhurried but never stopping, then the keyboard, moving on. */
async function pass(element: Element) {
  act(() => {
    fireEvent.mouseEnter(element);
  });
  for (let step = 0; step < 5; step++) {
    await wait(40);
    act(() => {
      fireEvent.mouseMove(element);
    });
  }
  await wait(40);
  act(() => {
    fireEvent.mouseLeave(element);
    fireEvent.focus(element);
  });
  await wait(40);
  act(() => {
    fireEvent.blur(element);
  });
  await wait(REST);
}

describe('the brand sprites', () => {
  it('are asked for once, from a rest on the Augments+ tab, never in passing or from the other tabs', async () => {
    const { CharacterPreferenceWindow } = await import('../..');
    render(
      <Provider store={store}>
        <ServerPrefs.Provider value={server}>
          <CharacterPreferenceWindow />
        </ServerPrefs.Provider>
      </Provider>,
    );
    const tabs = [...document.querySelectorAll('.Button')].filter(
      (button) => !['', 'Augments+'].includes(button.textContent?.trim() ?? ''),
    );
    expect(tabs.length).toBeGreaterThan(4);
    // The window opens on another tab, and the pointer and the keyboard rest on every other one.
    for (const tab of tabs) {
      await rest(tab);
    }
    expect(asks()).toBe(0);
    const augments = [...document.querySelectorAll('.Button')].find(
      (button) => button.textContent?.trim() === 'Augments+',
    ) as Element;
    await pass(augments);
    expect(asks()).toBe(0);
    await rest(augments);
    await rest(augments);
    expect(asks()).toBe(1);
  });

  it("are asked for from a rest on the room's Augments button, not as it opens on the markings", async () => {
    render(
      <Provider store={store}>
        <ServerPrefs.Provider value={server}>
          <AugmentsRoom
            theme={ROOM_THEMES.aphelion}
            mode="markings"
            onMode={() => {}}
            tools={null}
          >
            {null}
          </AugmentsRoom>
        </ServerPrefs.Provider>
      </Provider>,
    );
    await rest(
      document.querySelector('.AugmentsRoom__mode--markings') as Element,
    );
    const augments = document.querySelector(
      '.AugmentsRoom__mode--augments',
    ) as Element;
    await pass(augments);
    expect(asks()).toBe(0);
    await rest(augments);
    expect(asks()).toBe(1);
    // The window put away and opened again asks again, in case that ask went unanswered.
    act(() => {
      store.set(suspendedAtom, Date.now());
      store.set(suspendedAtom, false);
    });
    await rest(augments);
    expect(asks()).toBe(2);
  });

  it('are asked for once the window is idle after showing the stage, and only once', async () => {
    const stage = () =>
      render(
        <Provider store={store}>
          <ServerPrefs.Provider value={server}>
            <AugmentsStage
              internals={false}
              parts={[]}
              organs={[]}
              act={() => {}}
            />
          </ServerPrefs.Provider>
        </Provider>,
      );
    stage();
    // Not as it draws: the window's first load goes first.
    expect(asks()).toBe(0);
    await act(() => new Promise((resolve) => setTimeout(resolve, IDLE)));
    expect(asks()).toBe(1);
    cleanup();
    stage();
    await act(() => new Promise((resolve) => setTimeout(resolve, IDLE)));
    expect(asks()).toBe(1);
  });

  it('are asked for once when a rest and the stage both want them', async () => {
    // The room opening on the augments: the stage's ask waits for the window to be idle, while the pointer rests on its button.
    render(
      <Provider store={store}>
        <ServerPrefs.Provider value={server}>
          <AugmentsRoom
            theme={ROOM_THEMES.aphelion}
            mode="augments"
            onMode={() => {}}
            tools={null}
          >
            <AugmentsStage
              internals={false}
              parts={[]}
              organs={[]}
              act={() => {}}
            />
          </AugmentsRoom>
        </ServerPrefs.Provider>
      </Provider>,
    );
    act(() => {
      fireEvent.mouseEnter(
        document.querySelector('.AugmentsRoom__mode--augments') as Element,
      );
    });
    await wait(IDLE);
    expect(asks()).toBe(1);
  });
});
