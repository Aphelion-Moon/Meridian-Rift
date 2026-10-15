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
import { Provider, useAtomValue } from 'jotai';

import {
  backendStateAtom,
  configAtom,
  gameDataAtom,
  gameStaticDataAtom,
  store,
} from '../../../../../events/store';
import type { AugmentItem, PaintFinish, ServerData } from '../../../types';
import { ServerPrefs } from '../../../useServerPrefs';
import { previewLightsOffAtom } from '../../CharacterPreview/lights';
import { previewTurnAtom } from '../../CharacterPreview/turn';
import * as sheets from '../sprites';
import { setStageHover } from './hover';
import { AugmentsStage } from './index';
import {
  PART_SOCKETS,
  STOCK_AUGMENT,
  type StagePart,
  stagePaint,
} from './parts';
import { useTried } from './tried';

/** A finish without lights: its colour string still carries one, unused. */
const BRAWLER: PaintFinish = {
  id: 'brawler',
  channels: [
    { key: 'paint', label: 'Plating' },
    { key: 'accent', label: 'Knuckles' },
    { key: 'frame', label: 'Frame' },
  ],
  default: '#b2202a#cdd2dc#2a282e#8ce8ff',
  presets: [
    { name: 'Crimson', colors: '#b2202a#cdd2dc#2a282e#8ce8ff' },
    { name: 'Olive drab', colors: '#5a6448#c8c2b0#24261e#ffb347' },
  ],
  zones: {
    r_arm: { paint: 1, glow: 1 },
    r_hand: { paint: 1, glow: 0 },
  },
};
const FINISH = 'Brawler';
const FINISHES = { [FINISH]: BRAWLER };
/** More brands, for the grid's rows. */
const MARKS = ['Mk1', 'Mk2', 'Mk3', 'Mk4', 'Mk5'];
/** The brands' sprites, by name, as the server lists them. */
const BRANDS = Object.fromEntries(
  ['Surplus', ...MARKS].map((name) => [
    name,
    { key: name.toLowerCase(), zones: ['r_arm', 'r_hand', 'r_leg', 'l_leg'] },
  ]),
);
const SAVED = '#5a6448#c8c2b0#24261e#ffb347';

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
    augment_colors: { 'Right Arm': SAVED },
    augment_paint_skin: { color: '#d9ae96', humanoid: 0 },
    augment_paint_emissive: 1,
  });
});
afterEach(async () => {
  await act(async () => {});
  cleanup();
  act(() => setStageHover(null));
  store.set(previewTurnAtom, 0);
  store.set(previewLightsOffAtom, false);
  store.set(configAtom, originalConfig);
  store.set(gameDataAtom, originalData);
  store.set(gameStaticDataAtom, originalStatic);
});

const chrome: AugmentItem = {
  ...STOCK_AUGMENT,
  path: '/datum/augment_item/limb/chrome',
  name: 'Chrome limb',
  allows_styles: 1,
};

/**
 * Every socket, chrome: the right arm in Brawler (its colours saved, in
 * the window's data), the left arm in it too on an augment that takes no
 * finish, the right leg in a brand finish, and the left leg in none, offered
 * a row of brands, as the stage's memo builds them.
 */
const parts: StagePart[] = PART_SOCKETS.map((socket) => {
  const worn: Record<string, [string, string[]]> = {
    'Right Arm': [FINISH, ['None', 'Surplus', FINISH]],
    'Left Arm': [FINISH, ['None']],
    'Right Leg': ['Surplus', ['None', 'Surplus']],
    'Left Leg': ['None', ['None', FINISH, 'Surplus', ...MARKS]],
  };
  const [finish, finishes] = worn[socket.slot] ?? ['None', ['None']];
  return {
    socket,
    augment: chrome,
    options: [STOCK_AUGMENT, chrome],
    finish,
    finishes,
    implant: null,
    implants: null,
    unavailable: false,
    paint: stagePaint(finish, finishes, FINISHES),
  };
});

/** What the body is trying on, as the stage's overlay reads it. */
function TriedProbe() {
  return <span className="tried-probe" data-tried={useTried() ?? ''} />;
}

/**
 * The stage as the window holds it: drawn again for each backend update as
 * the window's root (routes.tsx) draws it, under the title bar's drag zone,
 * beside another part of the window.
 */
function Stage(props: { act: (action: string, params?: object) => void }) {
  useAtomValue(backendStateAtom);
  return (
    <>
      <div className="TitleBar__dragZone" />
      <AugmentsStage
        internals={false}
        parts={parts}
        organs={[]}
        act={props.act}
      />
      <div className="elsewhere" />
      <TriedProbe />
    </>
  );
}

function openStage() {
  const send = mock();
  const server = {
    species: {},
    augment_paint: {
      brands: BRANDS,
      finishes: FINISHES,
      swatches: { metal: ['#e8eaee', '#26262b'], lights: ['#46ebff'] },
    },
  } as unknown as ServerData;
  render(
    <Provider store={store}>
      <ServerPrefs.Provider value={server}>
        <Stage act={send} />
      </ServerPrefs.Provider>
    </Provider>,
  );
  return send;
}
/** The server's answer to a colour action: the slots' colours alone. */
const answer = (colors: Record<string, string>) =>
  act(() => {
    store.set(gameDataAtom, (prev) => ({ ...prev, augment_colors: colors }));
  });
const card = (name: string) =>
  [...document.querySelectorAll('.AugStage .sock')].find(
    (element) => element.querySelector('.sock-name')?.textContent === name,
  ) as HTMLElement;
const editor = () => document.querySelector('.AugStage .fly.paint');
const click = (element: Element | null | undefined) =>
  act(() => {
    fireEvent.click(element as Element);
  });
const button = (text: string) =>
  [...document.querySelectorAll('.AugStage .fly.paint button')].find(
    (element) => element.textContent === text,
  );
const colorSends = (send: ReturnType<typeof mock>) =>
  send.mock.calls.filter(([action]) => action === 'set_augment_colors');
const finishList = () => document.querySelector('.AugStage .fly:not(.paint)');
/** A finish's tile in the finish picker, by the name its accessible name starts with. */
const finishOption = (name: string) =>
  [...document.querySelectorAll('.AugStage .fly .tile')].find(
    (tile) => tile.getAttribute('aria-label')?.split(', ')[0] === name,
  ) as HTMLElement;
const triedNow = () =>
  document.querySelector('.tried-probe')?.getAttribute('data-tried');
/** A test that showed the tooltip ends once floating-ui has placed it, a tick later. */
const tipPlaced = () =>
  act(async () => {
    await new Promise((resolve) => setTimeout(resolve));
  });

describe("the augments stage's recolourable finishes", () => {
  it('puts a palette on a recolourable finish the part wears, which opens its editor', () => {
    openStage();
    const palette = card('R ARM').querySelector('.row-paint');
    expect(palette).not.toBeNull();
    expect(card('L ARM').querySelector('.row-paint')).toBeNull();
    expect(card('R LEG').querySelector('.row-paint')).toBeNull();
    expect(editor()).toBeNull();
    click(palette);
    expect(editor()?.querySelector('.fly-t')?.textContent).toBe(FINISH);
    // No lights, so no dark view to see them glow in.
    expect(editor()?.querySelector('.paint-lights')).toBeNull();
  });

  it("acts on the readout's palette only while a flyout keeps it on the slot", () => {
    openStage();
    act(() => {
      fireEvent.mouseEnter(card('R ARM'));
    });
    const readoutPalette = () => document.querySelector('.ro-paint-btn');
    expect(readoutPalette()?.getAttribute('aria-disabled')).toBe('true');
    click(readoutPalette());
    expect(editor()).toBeNull();
    act(() => {
      fireEvent.mouseLeave(card('R ARM'));
    });
    // The augment picker keeps the readout on the right arm, once the pointer leaves its list.
    click(card('R ARM').querySelector('.row'));
    act(() => {
      fireEvent.mouseLeave(document.querySelector('.fly-list') as Element);
    });
    expect(readoutPalette()?.getAttribute('aria-disabled')).toBe('false');
    click(readoutPalette());
    expect(editor()).not.toBeNull();
    expect(document.querySelectorAll('.AugStage .fly')).toHaveLength(1);
  });

  it('saves a preset at once, the default as no colours, and nothing that changes nothing', () => {
    answer({});
    const send = openStage();
    const preset = (name: string) =>
      [...document.querySelectorAll('.paint-preset')].find(
        (tile) => tile.textContent === name,
      );
    click(card('R ARM').querySelector('.row-paint'));
    // Crimson is the default, and nothing is saved: it is already worn.
    click(preset('Crimson'));
    click(preset('Olive drab'));
    answer({ 'Right Arm': SAVED });
    click(preset('Olive drab'));
    click(preset('Crimson'));
    click(button('Reset'));
    expect(colorSends(send)).toEqual([
      ['set_augment_colors', { slot: 'Right Arm', colors: SAVED }],
      ['set_augment_colors', { slot: 'Right Arm', colors: null }],
      ['set_augment_colors', { slot: 'Right Arm', colors: null }],
    ]);
  });

  it('tries a finish on from its list, sending nothing, and marks the recolourable ones', async () => {
    const send = openStage();
    click(card('R ARM').querySelector('.row-paintable .row'));
    expect(
      finishOption(FINISH).querySelector('.tile-badge.paint .fa-palette'),
    ).not.toBeNull();
    expect(finishOption(FINISH).getAttribute('aria-label')).toBe(
      `${FINISH}, installed, recolourable`,
    );
    expect(finishOption('Surplus').querySelector('.tile-badge')).toBeNull();
    act(() => {
      fireEvent.mouseEnter(finishOption('Surplus'));
    });
    expect(triedNow()).toBe('Surplus');
    act(() => {
      fireEvent.mouseEnter(finishOption(FINISH));
    });
    expect(triedNow()).toBe(FINISH);
    act(() => {
      fireEvent.mouseLeave(document.querySelector('.fly-grid') as Element);
    });
    expect(triedNow()).toBe('');
    expect(send.mock.calls).toEqual([]);
    await tipPlaced();
  });

  it('puts a flyout away at a press anywhere else in the window, but not on its handles', () => {
    openStage();
    click(card('R ARM').querySelector('.row-paintable .row'));
    act(() => {
      fireEvent.pointerDown(finishOption(FINISH));
      fireEvent.pointerDown(
        document.querySelector('.TitleBar__dragZone') as Element,
      );
    });
    expect(finishList()).not.toBeNull();
    act(() => {
      fireEvent.pointerDown(document.querySelector('.elsewhere') as Element);
    });
    expect(finishList()).toBeNull();
    // The colour editor too, from the console under it.
    click(card('R ARM').querySelector('.row-paint'));
    act(() => {
      fireEvent.pointerDown(document.querySelector('.inst') as Element);
    });
    expect(editor()).toBeNull();
  });

  it('keeps a picked colour to the preview until it is applied', () => {
    const send = openStage();
    click(card('R ARM').querySelector('.row-paint'));
    click(
      [...document.querySelectorAll('.paint-row')].find((row) =>
        row.textContent?.startsWith('Plating'),
      ),
    );
    act(() => {
      fireEvent.change(
        document.querySelector('.paint-pick input') as HTMLInputElement,
        { target: { value: '336699' } },
      );
    });
    // The paint filter's rows start with the picked colour's red, green and blue.
    const values = document
      .querySelector('[id^="ap-paint-"] feColorMatrix')
      ?.getAttribute('values')
      ?.split(' ')
      .map(Number);
    expect(values?.[0]).toBeCloseTo(0.2);
    expect(values?.[5]).toBeCloseTo(0.4);
    expect(values?.[10]).toBeCloseTo(0.6);
    expect(colorSends(send)).toEqual([]);
    click(button('Apply'));
    expect(colorSends(send)).toEqual([
      [
        'set_augment_colors',
        { slot: 'Right Arm', colors: `#336699${SAVED.slice(7)}` },
      ],
    ]);
  });
});

const scan = (selector: string) =>
  document.querySelector(`.AugStage ${selector}`) as HTMLElement;
/** A press on something, and its click, as the pointer gives them. */
const press = (element: Element) =>
  act(() => {
    fireEvent.pointerDown(element);
    fireEvent.click(element);
  });

describe("the scan's controls with a flyout open", () => {
  it('turn and light the character, by pointer or keyboard, and the flyout stays', () => {
    openStage();
    click(card('R ARM').querySelector('.row-paintable .row'));
    press(scan('.rot.r'));
    expect(store.get(previewTurnAtom)).toBe(1);
    press(scan('.CharacterPreview__light'));
    expect(store.get(previewLightsOffAtom)).toBe(true);
    // The keyboard's press is a click alone.
    click(scan('.rot.l'));
    expect(store.get(previewTurnAtom)).toBe(0);
    expect(finishList()).not.toBeNull();
    // The colour editor too.
    click(card('R ARM').querySelector('.row-paint'));
    press(scan('.rot.l'));
    press(scan('.CharacterPreview__light'));
    expect(store.get(previewTurnAtom)).toBe(-1);
    expect(store.get(previewLightsOffAtom)).toBe(false);
    expect(editor()).not.toBeNull();
    // Anything else still puts it away.
    act(() => {
      fireEvent.pointerDown(document.querySelector('.elsewhere') as Element);
    });
    expect(editor()).toBeNull();
  });

  it('keep what is tried on for the trip to them, and take it off past them', async () => {
    openStage();
    click(card('R ARM').querySelector('.row-paintable .row'));
    const list = document.querySelector('.fly-grid') as Element;
    act(() => {
      fireEvent.mouseEnter(finishOption('Surplus'));
    });
    // Straight onto a control, then turning it.
    act(() => {
      fireEvent.mouseLeave(list, { relatedTarget: scan('.rot.r') });
    });
    press(scan('.rot.r'));
    expect(triedNow()).toBe('Surplus');
    // Across the stage from one control to the other.
    act(() => {
      fireEvent.mouseOut(scan('.rot.r'), { relatedTarget: scan('.scrim') });
      fireEvent.mouseOver(scan('.scrim'));
      fireEvent.mouseOver(scan('.CharacterPreview__light'));
    });
    press(scan('.CharacterPreview__light'));
    expect(triedNow()).toBe('Surplus');
    // From a control to anywhere but a row: off.
    act(() => {
      fireEvent.mouseOut(scan('.CharacterPreview__light'), {
        relatedTarget: scan('.ro-t'),
      });
    });
    expect(triedNow()).toBe('');
    // From a row across the stage, but never to a control: on while the
    // pointer keeps moving, off once it rests there.
    act(() => {
      fireEvent.mouseEnter(finishOption(FINISH));
      fireEvent.mouseLeave(list, { relatedTarget: scan('.scrim') });
    });
    for (let step = 0; step < 4; step++) {
      await act(() => new Promise((resolve) => setTimeout(resolve, 150)));
      act(() => {
        fireEvent.mouseMove(scan('.scrim'));
      });
    }
    expect(triedNow()).toBe(FINISH);
    await act(() => new Promise((resolve) => setTimeout(resolve, 400)));
    expect(triedNow()).toBe('');
    // The keyboard: from a row to a control keeps it, from there elsewhere takes it off.
    act(() => {
      finishOption('Surplus').focus();
    });
    expect(triedNow()).toBe('Surplus');
    act(() => {
      scan('.rot.l').focus();
    });
    expect(triedNow()).toBe('Surplus');
    act(() => {
      (document.querySelector('.fly .x') as HTMLElement).focus();
    });
    expect(triedNow()).toBe('');
  });

  it('keep it across the list on the way back to a row, and lose it by keyboard only if they held it', async () => {
    openStage();
    click(card('R ARM').querySelector('.row-paintable .row'));
    const list = document.querySelector('.fly-grid') as Element;
    act(() => {
      fireEvent.mouseEnter(finishOption('Surplus'));
      fireEvent.mouseLeave(list, { relatedTarget: scan('.rot.r') });
    });
    // Back from the control through the list's padding, onto another row: no moment without a try-on.
    act(() => {
      fireEvent.mouseOut(scan('.rot.r'), { relatedTarget: list });
    });
    expect(triedNow()).toBe('Surplus');
    act(() => {
      fireEvent.mouseOut(list, { relatedTarget: finishOption(FINISH) });
    });
    expect(triedNow()).toBe(FINISH);
    // Focus on a control, the pointer resting on a row: focus moving on leaves the pointer's try-on.
    act(() => {
      scan('.rot.r').focus();
      fireEvent.mouseEnter(finishOption('Surplus'));
    });
    act(() => {
      (card('HEAD').querySelector('.row') as HTMLElement).focus();
    });
    expect(triedNow()).toBe('Surplus');
    // A try-on the keyboard took to the controls comes off when focus moves on.
    act(() => {
      finishOption(FINISH).focus();
    });
    act(() => {
      scan('.rot.l').focus();
    });
    expect(triedNow()).toBe(FINISH);
    act(() => {
      (card('HEAD').querySelector('.row') as HTMLElement).focus();
    });
    expect(triedNow()).toBe('');
    await tipPlaced();
  });

  it("aren't lost to the rows the pointer crosses on its way out to them", async () => {
    openStage();
    click(card('R ARM').querySelector('.row-paintable .row'));
    const list = document.querySelector('.fly-grid') as Element;
    const at = (x: number, y: number) => ({ clientX: x, clientY: y });
    // From one row onto the next, as React hears it: the first one's mouseout.
    const onto = (from: string, to: string, x: number, y: number) =>
      fireEvent.mouseLeave(finishOption(from), {
        relatedTarget: finishOption(to),
        ...at(x, y),
      });
    act(() => {
      fireEvent.mouseEnter(finishOption('None'), at(100, 100));
      onto('None', 'Surplus', 100, 140);
    });
    expect(triedNow()).toBe('Surplus');
    // Out sideways for the stage, across the next row: Surplus stays.
    act(() => {
      fireEvent.mouseMove(list, at(130, 150));
      fireEvent.mouseMove(list, at(160, 160));
      onto('Surplus', FINISH, 190, 170);
      fireEvent.mouseMove(list, at(220, 180));
    });
    expect(triedNow()).toBe('Surplus');
    await act(() => new Promise((resolve) => setTimeout(resolve, 60)));
    act(() => {
      fireEvent.mouseMove(list, at(250, 190));
      fireEvent.mouseLeave(finishOption(FINISH), {
        relatedTarget: scan('.scrim'),
      });
    });
    expect(triedNow()).toBe('Surplus');
    // Onto that row again and resting there: it is tried on.
    act(() => {
      onto('Surplus', FINISH, 280, 200);
    });
    await act(() => new Promise((resolve) => setTimeout(resolve, 200)));
    expect(triedNow()).toBe(FINISH);
    // Down the list, each row at once.
    act(() => {
      fireEvent.mouseMove(list, at(280, 240));
      fireEvent.mouseMove(list, at(280, 280));
      onto(FINISH, 'Surplus', 280, 300);
    });
    expect(triedNow()).toBe('Surplus');
  });
});

/** The tooltip's name, or null when none shows. */
const tip = () =>
  document.querySelector('.AugStage__tip:not(.AugStage__tip--hidden)')
    ?.textContent ?? null;
const focused = () =>
  document.activeElement?.getAttribute('aria-label')?.split(', ')[0];
const pressKey = (key: string) =>
  act(() => {
    fireEvent.keyDown(document.activeElement as Element, { key });
  });

describe("the finish picker's thumbnails", () => {
  it('name the tile the pointer or the keyboard is on, and only that one', async () => {
    openStage();
    click(card('R ARM').querySelector('.row-paintable .row'));
    // Opened on what's installed: the keyboard is there, unnamed until it moves.
    expect(focused()).toBe(FINISH);
    expect(tip()).toBeNull();
    act(() => {
      fireEvent.mouseEnter(finishOption('Surplus'));
    });
    expect(tip()).toBe('Surplus');
    act(() => {
      fireEvent.mouseLeave(finishOption('Surplus'), {
        relatedTarget: finishOption(FINISH),
      });
    });
    expect(tip()).toBe(FINISH);
    act(() => {
      fireEvent.mouseLeave(finishOption(FINISH), {
        relatedTarget: document.querySelector('.elsewhere'),
      });
    });
    expect(tip()).toBeNull();
    pressKey('Home');
    expect(focused()).toBe('None');
    expect(tip()).toBe('None');
    act(() => {
      (document.activeElement as HTMLElement).blur();
    });
    expect(tip()).toBeNull();
    await tipPlaced();
  });

  it('go round the grid with the arrow keys, Home and End, and leave it with Tab', async () => {
    openStage();
    // None, then Brawler alone, then Surplus and the marks four to a row.
    click(card('L LEG').querySelectorAll('.row')[1]);
    expect(focused()).toBe('None');
    pressKey('ArrowLeft');
    expect(focused()).toBe('None');
    pressKey('ArrowDown');
    expect(focused()).toBe(FINISH);
    pressKey('ArrowDown');
    expect(focused()).toBe('Surplus');
    pressKey('ArrowRight');
    pressKey('ArrowRight');
    pressKey('ArrowRight');
    expect(focused()).toBe('Mk3');
    // A shorter row below: its last tile.
    pressKey('ArrowDown');
    expect(focused()).toBe('Mk5');
    pressKey('ArrowUp');
    expect(focused()).toBe('Mk1');
    // Up out of a set: the row above, in the set before.
    pressKey('ArrowUp');
    expect(focused()).toBe(FINISH);
    pressKey('End');
    expect(focused()).toBe('Mk5');
    pressKey('Home');
    expect(focused()).toBe('None');
    // Only the tile the keyboard is on is in the tab order.
    const tabbable = [...document.querySelectorAll('.AugStage .tile')].filter(
      (tile) => tile.getAttribute('tabindex') === '0',
    );
    expect(tabbable.map((tile) => tile.getAttribute('aria-label'))).toEqual([
      'None, installed',
    ]);
    const tab = new KeyboardEvent('keydown', {
      key: 'Tab',
      bubbles: true,
      cancelable: true,
    });
    act(() => {
      document.activeElement?.dispatchEvent(tab);
    });
    expect(tab.defaultPrevented).toBe(false);
    await tipPlaced();
  });

  it('show the body faintly in a tile until its sprites can be drawn', () => {
    // The brand sheet hasn't come: only the recolourable finishes' sprites can be drawn.
    let brandsCame = false;
    const sprites = spyOn(sheets, 'useSprites').mockImplementation((names) =>
      names.map((name) =>
        name && (brandsCame || !name.startsWith('augment_brands32x32'))
          ? {
              cell: { url: 'sheet.png', x: 0, y: 0, width: 32, height: 32 },
              image: {} as HTMLImageElement,
              source: {} as HTMLImageElement,
            }
          : undefined,
      ),
    );
    try {
      openStage();
      click(card('R ARM').querySelector('.row-paintable .row'));
      const pending = () =>
        [...document.querySelectorAll('.AugStage .tile--pending')].map(
          (tile) => tile.getAttribute('aria-label')?.split(', ')[0],
        );
      expect(pending()).toEqual(['Surplus']);
      // Opened again once the sheet has come: every tile drawn.
      brandsCame = true;
      act(() => {
        fireEvent.keyDown(window, { key: 'Escape' });
      });
      click(card('R ARM').querySelector('.row-paintable .row'));
      expect(pending()).toEqual([]);
    } finally {
      sprites.mockRestore();
    }
  });
});
