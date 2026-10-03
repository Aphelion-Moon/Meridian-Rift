// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';

import { rejoinCompositor } from './compositor';

/** An animation as the test needs it: whether it runs, whether it's endless, and every time its time is set. */
function animation(playState: string, iterations: number, time: number) {
  const sets: number[] = [];
  const fake = {
    playState,
    effect: { getTiming: () => ({ iterations }) },
    get currentTime() {
      return time;
    },
    set currentTime(value: number) {
      sets.push(value);
    },
  };
  return { fake, sets };
}

describe("an animation's end hands its element's endless ones to the compositor", () => {
  it('sets a running endless animation to the time it is at, and leaves the rest alone', () => {
    const hum = animation('running', Number.POSITIVE_INFINITY, 4321);
    const flicker = animation('finished', 1, 1900);
    const held = animation('paused', Number.POSITIVE_INFINITY, 10);
    const pulse = animation('running', 3, 500);
    const target = {
      getAnimations: () => [hum.fake, flicker.fake, held.fake, pulse.fake],
    };
    rejoinCompositor({ target: target as unknown as EventTarget });
    expect(hum.sets).toEqual([4321]);
    expect(flicker.sets).toEqual([]);
    expect(held.sets).toEqual([]);
    expect(pulse.sets).toEqual([]);
  });

  it('does nothing for a target without animations', () => {
    expect(() => rejoinCompositor({ target: null })).not.toThrow();
    expect(() =>
      rejoinCompositor({ target: {} as unknown as EventTarget }),
    ).not.toThrow();
  });
});
