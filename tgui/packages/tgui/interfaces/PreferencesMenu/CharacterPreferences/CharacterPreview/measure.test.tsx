// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { act, cleanup, render } from '@testing-library/react';
import { Provider } from 'jotai';

import { gameDataAtom, store } from '../../../../events/store';
import { CharacterPreview } from './index';

const originalData = store.get(gameDataAtom);
const originalObserver = globalThis.ResizeObserver;
const originalImage = globalThis.Image;
/** Each observer's callback, to speak for it. */
let observed: (() => void)[] = [];
beforeEach(() => {
  observed = [];
  globalThis.ResizeObserver = class {
    callback: () => void;
    constructor(callback: () => void) {
      this.callback = callback;
    }
    observe() {
      observed.push(this.callback);
    }
    disconnect() {}
    unobserve() {}
  } as unknown as typeof ResizeObserver;
  // An image that loads as soon as it's given a source.
  globalThis.Image = class {
    onload: (() => void) | null = null;
    onerror: (() => void) | null = null;
    naturalWidth = 128;
    naturalHeight = 32;
    set src(_value: string) {
      queueMicrotask(() => this.onload?.());
    }
  } as unknown as typeof Image;
});
afterEach(() => {
  cleanup();
  globalThis.ResizeObserver = originalObserver;
  globalThis.Image = originalImage;
  store.set(gameDataAtom, originalData);
});

describe("the preview's box", () => {
  it('draws the character again only when the box changes size', async () => {
    store.set(gameDataAtom, {
      character_preview: {
        id: 1,
        species: 'human',
        slot: 1,
        image: 'data:image/png;base64,drawing',
        width: 32,
        height: 32,
        x: 0,
        y: 0,
        frames: { north: 0, south: 32, east: 64, west: 96 },
      },
    });
    let drawn = 0;
    const overlay = () => {
      drawn++;
      return null;
    };
    await act(async () => {
      render(
        <Provider store={store}>
          <CharacterPreview width="300px" height="400px" overlay={overlay} />
        </Provider>,
      );
    });
    expect(drawn).toBeGreaterThan(0);
    expect(observed).toHaveLength(1);
    const before = drawn;
    // The observer's first callback: the size the box was measured at.
    act(() => observed[0]());
    expect(drawn).toBe(before);
  });
});
