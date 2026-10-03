// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it, mock } from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  renderHook,
  screen,
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
import {
  pointedZone,
  resetPointer,
  setCardLight,
  setPointedZone,
  useCardLight,
  usePointedIs,
  usePointedZone,
} from './pointer';
import { ROOM_THEMES } from './themes';

afterEach(() => {
  act(() => resetPointer());
});

describe('where the pointer is', () => {
  it('tells what shows it, only when it changes', () => {
    let renders = 0;
    const shown = renderHook(() => {
      renders++;
      return usePointedZone();
    });
    act(() => setPointedZone('chest'));
    act(() => setPointedZone('chest'));
    expect(shown.result.current).toBe('chest');
    act(() => setPointedZone(null));
    expect(shown.result.current).toBeNull();
    // First render, chest, and null: the repeat of chest drew nothing.
    expect(renders).toBe(3);
  });

  it('keeps a lit tile until another is lit', () => {
    const shown = renderHook(() => useCardLight());
    act(() => setCardLight({ zone: 'head', what: 0 }));
    const lit = shown.result.current;
    act(() => setCardLight({ zone: 'head', what: 0 }));
    expect(shown.result.current).toBe(lit);
    act(() => setCardLight({ zone: 'head', what: 'custom' }));
    expect(shown.result.current).toEqual({ zone: 'head', what: 'custom' });
  });

  it('draws a card again only when its answer changes', () => {
    let headRenders = 0;
    let legRenders = 0;
    const head = renderHook(() => {
      headRenders++;
      return usePointedIs((zone) => zone === 'head');
    });
    renderHook(() => {
      legRenders++;
      return usePointedIs((zone) => zone === 'l_leg');
    });
    act(() => setPointedZone('head'));
    act(() => setPointedZone('chest'));
    act(() => setPointedZone('r_arm'));
    expect(head.result.current).toBe(false);
    // The head went on and off; the leg never moved.
    expect(headRenders).toBe(3);
    expect(legRenders).toBe(1);
  });
});

describe('the room under the pointer', () => {
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

  function openRoom(taurLegs = false) {
    store.set(gameDataAtom, {
      character_preferences: { misc: { species: 'human' } },
      taur_legs: taurLegs,
      markings: {
        r_arm: [
          {
            marking_id: 'r_arm_1',
            name: 'Spots',
            color: '#ff0000',
            emissive: 0,
            locked: 0,
          },
        ],
      },
    });
    const server = {
      species: {},
      limbs_and_markings: {
        augment_items: [],
        marking_choices: { r_arm: ['Spots', 'Stripes'] },
        marking_info: {},
        marking_presets: [],
      },
    } as unknown as ServerData;
    function ReactiveRoom() {
      useAtomValue(gameDataAtom);
      return (
        <MarkingsRoom
          theme={ROOM_THEMES.aphelion}
          act={mock()}
          onLook={() => {}}
        />
      );
    }
    return render(
      <Provider store={store}>
        <ServerPrefs.Provider value={server}>
          <ReactiveRoom />
        </ServerPrefs.Provider>
      </Provider>,
    );
  }
  const card = (name: string) =>
    [...document.querySelectorAll('.MarkingsRoom__card')].find(
      (element) =>
        element.querySelector('.MarkingsRoom__cardName')?.textContent === name,
    ) as HTMLElement;
  const lit = () =>
    [...document.querySelectorAll('.MarkingsRoom__card--lit')].map(
      (element) =>
        element.querySelector('.MarkingsRoom__cardName')?.textContent,
    );
  const glass = () =>
    document.querySelector('.MarkingsRoom__glass') as HTMLElement;

  it('lights the card the pointer is on, and marks the glass with its zone', () => {
    openRoom();
    expect(lit()).toEqual([]);
    act(() => {
      fireEvent.mouseEnter(card('Right arm'));
    });
    expect(lit()).toEqual(['Right arm']);
    expect(glass().dataset.zone).toBe('r_arm');
    act(() => {
      fireEvent.mouseLeave(card('Right arm'));
    });
    expect(lit()).toEqual([]);
    expect(glass().dataset.zone).toBeUndefined();
  });

  it('lights both legs for the taur body, which the glass marks as the taur', () => {
    openRoom(true);
    act(() => setPointedZone('taur'));
    expect(lit()).toEqual(['Right leg', 'Left leg']);
    act(() => setPointedZone('l_leg'));
    expect(glass().dataset.zone).toBe('taur');
  });

  it("lights the open drawer's card while the pointer is on no zone", () => {
    openRoom();
    fireEvent.click(
      screen.getAllByRole('button', {
        name: 'Add a marking to the right arm',
      })[0],
    );
    expect(lit()).toEqual(['Right arm']);
    act(() => setPointedZone('head'));
    expect(lit()).toEqual(['Head']);
  });

  it('forgets the pointer when the room goes', () => {
    const room = openRoom();
    act(() => setPointedZone('head'));
    room.unmount();
    expect(pointedZone()).toBeNull();
  });
});
