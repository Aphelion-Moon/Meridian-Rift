// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it, mock } from 'bun:test';
import { act, cleanup, fireEvent, render } from '@testing-library/react';
import { Provider } from 'jotai';

import {
  configAtom,
  gameDataAtom,
  gameStaticDataAtom,
  store,
} from '../../../../../events/store';
import type { AugmentItem, ServerData } from '../../../types';
import { ServerPrefs } from '../../../useServerPrefs';
import { setStageHover, useStageHoverIs } from './hover';
import { AugmentsStage } from './index';
import { PART_SOCKETS, STOCK_AUGMENT, type StagePart } from './parts';

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
  act(() => setStageHover(null));
  store.set(configAtom, originalConfig);
  store.set(gameDataAtom, originalData);
  store.set(gameStaticDataAtom, originalStatic);
});

const chrome: AugmentItem = {
  ...STOCK_AUGMENT,
  path: '/datum/augment_item/limb/chrome',
  name: 'Chrome arm',
};

/** The stage's body parts: every socket, stock, each offering a chrome part. */
const parts: StagePart[] = PART_SOCKETS.map((socket) => ({
  socket,
  augment: STOCK_AUGMENT,
  options: [STOCK_AUGMENT, chrome],
  finish: 'None',
  finishes: [],
  implant: null,
  implants: null,
  unavailable: false,
}));

function openStage() {
  const send = mock();
  render(
    <Provider store={store}>
      <ServerPrefs.Provider value={{ species: {} } as unknown as ServerData}>
        <AugmentsStage internals={false} parts={parts} organs={[]} act={send} />
      </ServerPrefs.Provider>
    </Provider>,
  );
  return send;
}
const card = (name: string) =>
  [...document.querySelectorAll('.AugStage .sock')].find(
    (element) => element.querySelector('.sock-name')?.textContent === name,
  ) as HTMLElement;
const lit = () =>
  [...document.querySelectorAll('.AugStage .sock.on')].map(
    (element) => element.querySelector('.sock-name')?.textContent,
  );
const stage = () => document.querySelector('.AugStage') as HTMLElement;

describe('the augments stage under the pointer', () => {
  it('lights the card the pointer is on, and marks the stage as pointed at', () => {
    openStage();
    expect(lit()).toEqual([]);
    expect(stage().classList.contains('AugStage--hovering')).toBe(false);
    act(() => {
      fireEvent.mouseEnter(card('R ARM'));
    });
    expect(lit()).toEqual(['R ARM']);
    expect(stage().classList.contains('AugStage--hovering')).toBe(true);
    expect(document.querySelector('.ro-t')?.textContent).toBe('RIGHT ARM');
    act(() => {
      fireEvent.mouseLeave(card('R ARM'));
    });
    expect(lit()).toEqual([]);
    expect(stage().classList.contains('AugStage--hovering')).toBe(false);
    expect(document.querySelector('.ro-t')?.textContent).toBe('PICK A SLOT');
  });

  it("keeps a picker's card lit, whatever else the pointer is on", () => {
    openStage();
    act(() => {
      fireEvent.click(card('HEAD').querySelector('.row') as HTMLElement);
    });
    expect(lit()).toEqual(['HEAD']);
    act(() => {
      fireEvent.mouseEnter(card('L LEG'));
    });
    expect(lit()).toEqual(['HEAD']);
    expect(stage().classList.contains('AugStage--hovering')).toBe(true);
  });

  it('picks from the picker as before', () => {
    const send = openStage();
    act(() => {
      fireEvent.click(card('L ARM').querySelector('.row') as HTMLElement);
    });
    const chromeOption = [
      ...document.querySelectorAll('.AugStage .fly .opt'),
    ].find(
      (option) => option.querySelector('.opt-n')?.textContent === 'Chrome arm',
    ) as HTMLElement;
    act(() => {
      fireEvent.click(chromeOption);
    });
    expect(send).toHaveBeenCalledWith('set_bodypart_aug', {
      slot: 'Left Arm',
      augment_path: chrome.path,
    });
    expect(lit()).toEqual([]);
  });

  it('draws a slot again only when the pointer comes to it or leaves it', () => {
    let headRenders = 0;
    function HeadLight() {
      headRenders++;
      useStageHoverIs('Head');
      return null;
    }
    render(<HeadLight />);
    act(() => setStageHover('Head'));
    act(() => setStageHover('Chest'));
    act(() => setStageHover('Right Arm'));
    expect(headRenders).toBe(3);
  });
});
