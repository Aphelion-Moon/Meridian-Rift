// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it, spyOn } from 'bun:test';
import { cleanup, render } from '@testing-library/react';
import { Provider } from 'jotai';

import { gameDataAtom, store } from '../../../../../events/store';
import type { AugmentItem, ServerData } from '../../../types';
import { ServerPrefs } from '../../../useServerPrefs';
import type { PreviewView } from '../../CharacterPreview/drawing';
import type { FrameRegions } from '../regions';
import * as sheets from '../sprites';
import {
  landingsOf,
  PART_SOCKETS,
  STOCK_AUGMENT,
  type StagePart,
} from './parts';
import { useFinishTryOn } from './tryOn';

/** A 4x2 frame: the left arm drawn at (2, 0)-(3, 1), the chest at (0, 0)-(1, 1). */
const frame = (zones: string[]): FrameRegions => ({
  width: 4,
  height: 2,
  zones,
  index: new Uint8Array(
    [0, 0, 1, 1, 0, 0, 1, 1].map((n) =>
      n ? zones.indexOf('l_arm') + 1 : zones.indexOf('chest') + 1,
    ),
  ),
});

describe("the augments stage's traces", () => {
  it('keeps an amputated part on its port, and lands a hidden one on its pair', () => {
    // No right arm: the server leaves the stump out of the map.
    const amputated = landingsOf(
      frame(['chest', 'l_arm']),
      PART_SOCKETS,
      false,
    );
    expect(amputated['Right Arm']).toBeUndefined();
    expect(amputated['Left Arm']).toEqual([3, 1]);
    // On the body but drawn nowhere in this facing, as the far arm in profile.
    const hidden = landingsOf(
      frame(['chest', 'l_arm', 'r_arm']),
      PART_SOCKETS,
      false,
    );
    expect(hidden['Right Arm']).toEqual([3, 1]);
  });
});

const SURPLUS = {
  key: 'surplus',
  zones: ['r_arm', 'r_hand', 'r_leg', 'r_leg_digi'],
};
const chrome: AugmentItem = {
  ...STOCK_AUGMENT,
  path: '/datum/augment_item/limb/chrome',
  name: 'Chrome limb',
  allows_styles: 1,
};
const part = (
  finish: string,
  augment: AugmentItem,
  socket = PART_SOCKETS[1],
): StagePart => ({
  socket,
  augment,
  options: [STOCK_AUGMENT, augment],
  finish,
  finishes: ['None', 'Surplus', finish],
  implant: null,
  implants: null,
  unavailable: false,
  paint: null,
});

/** What the body would try on, as the stage's overlay asks for it. */
function TryOnProbe(props: { part: StagePart; name: string }) {
  const tryOn = useFinishTryOn(
    { dir: 'south', dark: false } as PreviewView,
    props.part,
    props.name,
  );
  return (
    <span
      className="try-probe"
      data-layers={tryOn?.tryOn.layers.map((layer) => layer.className).join()}
    />
  );
}

// The try-on's sprites, drawable or not: a window's sheets don't load here.
let drawable = true;
let sprites: ReturnType<typeof spyOn>;
const original = store.get(gameDataAtom);
beforeEach(() => {
  drawable = true;
  sprites = spyOn(sheets, 'useSprites').mockImplementation((names) =>
    names.map((name) =>
      drawable && name
        ? {
            cell: { url: 'sheet.png', x: 0, y: 0, width: 32, height: 32 },
            image: {} as HTMLImageElement,
            source: {} as HTMLImageElement,
          }
        : undefined,
    ),
  );
});
afterEach(() => {
  cleanup();
  store.set(gameDataAtom, original);
  sprites.mockRestore();
});

function tryOn(probePart: StagePart, name: string, digi = false) {
  store.set(gameDataAtom, {
    augment_paint_skin: { color: '#d9ae96', humanoid: 0 },
    digi_legs: digi ? 1 : 0,
  });
  const server = {
    augment_paint: {
      finishes: {},
      swatches: { metal: [], lights: [] },
      brands: { Surplus: SURPLUS },
    },
  } as unknown as ServerData;
  render(
    <Provider store={store}>
      <ServerPrefs.Provider value={server}>
        <TryOnProbe part={probePart} name={name} />
      </ServerPrefs.Provider>
    </Provider>,
  );
  const layers = document
    .querySelector('.try-probe')
    ?.getAttribute('data-layers');
  cleanup();
  return layers;
}

describe("the augments stage's try-on", () => {
  it('tries on what a part would wear instead, never what it wears', () => {
    const own = { ...chrome, default_style: 'Surplus' };
    // The worn finish, as the picker opens on it.
    expect(tryOn(part('Surplus', own), 'Surplus')).toBeNull();
    // "None" is the augment's own look, a brand's sprites when its item says so.
    expect(tryOn(part('Surplus', own), 'None')).toBe(
      'augment_brands32x32 brand-surplus-r_arm-south,augment_brands32x32 brand-surplus-r_hand-south',
    );
    expect(tryOn(part('Surplus', chrome), 'None')).toBeNull();
    expect(tryOn(part('None', own), 'None')).toBeNull();
    // A leg's own look on a digitigrade body is a digitigrade cybernetic leg,
    // which no brand draws, its digitigrade sprites included.
    const leg = part('Surplus', own, PART_SOCKETS[2]);
    expect(tryOn(leg, 'None')).toBe(
      'augment_brands32x32 brand-surplus-r_leg-south',
    );
    expect(tryOn(leg, 'None', true)).toBeNull();
  });

  it('tries nothing on until its sprites can be drawn, as before its sheet has come', () => {
    drawable = false;
    expect(tryOn(part('None', chrome), 'Surplus')).toBeNull();
    drawable = true;
    expect(tryOn(part('None', chrome), 'Surplus')).toBe(
      'augment_brands32x32 brand-surplus-r_arm-south,augment_brands32x32 brand-surplus-r_hand-south',
    );
  });
});
