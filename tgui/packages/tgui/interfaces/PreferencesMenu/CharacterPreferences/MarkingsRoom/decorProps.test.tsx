// THIS IS AN APHELION UI FILE
import { afterEach, describe, expect, it } from 'bun:test';
import { act, renderHook } from '@testing-library/react';
import { Provider } from 'jotai';
import type { ReactNode } from 'react';

import { gameDataAtom, store } from '../../../../events/store';
import { previewLightsOffAtom } from '../CharacterPreview/lights';
import { useDecorProps } from './Room';

const originalData = store.get(gameDataAtom);
afterEach(() => {
  store.set(previewLightsOffAtom, false);
  store.set(gameDataAtom, originalData);
});

const wrapper = ({ children }: { children: ReactNode }) => (
  <Provider store={store}>{children}</Provider>
);

describe("the rooms' decor props", () => {
  it('hold still until something they carry changes', () => {
    store.set(gameDataAtom, { markings_room_delam: 3 });
    const { result, rerender } = renderHook(() => useDecorProps(), {
      wrapper,
    });
    const first = result.current;
    // Drawn again, as the room is for an update that doesn't touch them.
    store.set(gameDataAtom, { markings_room_delam: 3, markings: null });
    rerender();
    expect(result.current).toBe(first);
    expect(result.current.onLights).toBe(first.onLights);
    expect(result.current.onLightEffects).toBe(first.onLightEffects);

    // The lights go off: new props, and a switch that turns them back on.
    act(() => first.onLights());
    const dark = result.current;
    expect(dark).not.toBe(first);
    expect(dark.lightsOff).toBe(true);
    act(() => dark.onLights());
    expect(result.current.lightsOff).toBe(false);

    // The engine's record changes.
    const lit = result.current;
    store.set(gameDataAtom, { markings_room_delam: 4 });
    rerender();
    expect(result.current).not.toBe(lit);
    expect(result.current.delamRounds).toBe(4);
  });
});
