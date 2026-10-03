// THIS IS AN APHELION UI FILE
import { describe, expect, it, spyOn } from 'bun:test';
import { act, renderHook, waitFor } from '@testing-library/react';

import { drawSprite, type Sprite, useSprites } from './sprites';

describe('native marking placement', () => {
  for (const [width, height, left, top, zoom, want] of [
    [32, 32, 0, 16, 1, [0, 16, 32, 32]],
    [45, 34, 0, 16, 1, [0, 14, 45, 34]],
    [64, 32, 16, 32, 1, [16, 32, 64, 32]],
    [32, 48, 0, 16, 1, [0, 0, 32, 48]],
    [45, 34, 32, 48, 2, [32, 44, 90, 68]],
  ] as const) {
    it(`keeps ${width}x${height} art at the tile bottom at ${zoom}x`, () => {
      const calls: unknown[][] = [];
      const context = {
        imageSmoothingEnabled: true,
        drawImage: (...args: unknown[]) => calls.push(args),
      } as unknown as CanvasRenderingContext2D;
      const sprite: Sprite = {
        cell: { url: 'native', x: 64, y: 96, width, height },
        image: new Image(),
      };
      // The sixth argument requests native tile-bottom alignment. Ordinary
      // thumbnail calls omit it and retain their top-left positioning.
      drawSprite(context, sprite, left, top, zoom, 32);
      expect(calls).toHaveLength(1);
      expect(calls[0][0]).toBe(sprite.image);
      expect(calls[0].slice(1)).toEqual([64, 96, width, height, ...want]);
      expect(context.imageSmoothingEnabled).toBe(false);
    });
  }

  it('bottom-aligns the tinted canvas used by a mirror highlight', () => {
    const calls: unknown[][] = [];
    const context = {
      drawImage: (...args: unknown[]) => calls.push(args),
    } as unknown as CanvasRenderingContext2D;
    const canvas = document.createElement('canvas');
    canvas.width = 45;
    canvas.height = 34;
    drawSprite(context, canvas, 16, 32, 1, 32);
    expect(calls).toHaveLength(1);
    expect(calls[0][0]).toBe(canvas);
    expect(calls[0].slice(1)).toEqual([16, 30, 45, 34]);
  });

  it('keeps the existing top-left placement for picker thumbnails', () => {
    const calls: unknown[][] = [];
    const context = {
      drawImage: (...args: unknown[]) => calls.push(args),
    } as unknown as CanvasRenderingContext2D;
    const sprite: Sprite = {
      cell: { url: 'picker', x: 0, y: 0, width: 32, height: 32 },
      image: new Image(),
    };
    drawSprite(context, sprite, 7, 11, 3);
    expect(calls[0]).toEqual([sprite.image, 0, 0, 32, 32, 7, 11, 96, 96]);
  });
});

describe('useSprites', () => {
  it('loads every native size family and pairs each cell with its own sheet', () => {
    const originalImage = globalThis.Image;
    const getStyle = globalThis.getComputedStyle;
    const loaded: TestImage[] = [];
    class TestImage extends EventTarget {
      src = '';
      complete = false;
      naturalWidth = 0;
      constructor() {
        super();
        loaded.push(this);
      }
    }
    globalThis.Image = TestImage as unknown as typeof Image;
    const styles = spyOn(globalThis, 'getComputedStyle').mockImplementation(
      (element) => {
        const family = element.className;
        if (typeof family === 'string' && family.startsWith('native-test-')) {
          return {
            backgroundImage: `url("${family}.png")`,
            backgroundPosition: '0px 0px',
            width: '32px',
            height: '32px',
          } as CSSStyleDeclaration;
        }
        return getStyle(element);
      },
    );
    let unmount: (() => void) | undefined;
    let unmountCached: (() => void) | undefined;
    try {
      const hook = renderHook(() =>
        useSprites(['native-test-32', 'native-test-45', 'native-test-64']),
      );
      unmount = hook.unmount;
      act(() => {
        for (const image of loaded) {
          image.complete = true;
          image.naturalWidth = 256;
          image.dispatchEvent(new Event('load'));
        }
      });
      expect(hook.result.current.map((sprite) => sprite?.image.src)).toEqual([
        'native-test-32.png',
        'native-test-45.png',
        'native-test-64.png',
      ]);
      let renders = 0;
      const cached = renderHook(() => {
        renders++;
        return useSprites([
          'native-test-32',
          'native-test-45',
          'native-test-64',
        ]);
      });
      unmountCached = cached.unmount;
      expect(cached.result.current.every((sprite) => !!sprite)).toBe(true);
      expect(renders).toBe(1);
    } finally {
      unmountCached?.();
      unmount?.();
      styles.mockRestore();
      globalThis.Image = originalImage;
    }
  });
});

describe('decoded sheets', () => {
  it('draws from a sheet decoded apart, once it is', async () => {
    const originalImage = globalThis.Image;
    const originalDecode = globalThis.createImageBitmap;
    const getStyle = globalThis.getComputedStyle;
    const made: HTMLImageElement[] = [];
    globalThis.Image = class extends originalImage {
      constructor() {
        super();
        made.push(this);
      }
    };
    const originalFetch = globalThis.fetch;
    const file = new Blob(['png']);
    globalThis.fetch = (() =>
      Promise.resolve({
        ok: true,
        blob: () => Promise.resolve(file),
      })) as unknown as typeof fetch;
    const bitmap = { width: 256, height: 256 } as ImageBitmap;
    let decodedFrom: unknown;
    globalThis.createImageBitmap = ((from: unknown) => {
      decodedFrom = from;
      return Promise.resolve(bitmap);
    }) as unknown as typeof createImageBitmap;
    const styles = spyOn(globalThis, 'getComputedStyle').mockImplementation(
      (element) =>
        element.className === 'decoded-test'
          ? ({
              backgroundImage: 'url("decoded-test.png")',
              backgroundPosition: '0px 0px',
              width: '32px',
              height: '32px',
            } as CSSStyleDeclaration)
          : getStyle(element),
    );
    let unmount: (() => void) | undefined;
    try {
      const hook = renderHook(() => useSprites(['decoded-test']));
      unmount = hook.unmount;
      // Loaded, but not decoded yet: nothing to draw.
      const [image] = made;
      Object.defineProperty(image, 'complete', { value: true });
      Object.defineProperty(image, 'naturalWidth', { value: 256 });
      act(() => {
        image.dispatchEvent(new Event('load'));
      });
      expect(hook.result.current[0]).toBeUndefined();
      await waitFor(() => expect(hook.result.current[0]).toBeDefined());
      expect(hook.result.current[0]?.image).toBe(image);
      expect(hook.result.current[0]?.source).toBe(bitmap);
      // From the file, which decodes apart, not the image, which wouldn't.
      expect(decodedFrom).toBe(file);
    } finally {
      unmount?.();
      styles.mockRestore();
      globalThis.Image = originalImage;
      globalThis.createImageBitmap = originalDecode;
      globalThis.fetch = originalFetch;
    }
  });
});

describe('a sheet ready between render and effect', () => {
  it('renders again with it, with nothing else to wait for', async () => {
    const originalImage = globalThis.Image;
    const originalDecode = globalThis.createImageBitmap;
    const originalFetch = globalThis.fetch;
    const getStyle = globalThis.getComputedStyle;
    const made: HTMLImageElement[] = [];
    globalThis.Image = class extends originalImage {
      constructor() {
        super();
        made.push(this);
      }
    };
    globalThis.fetch = (() =>
      Promise.resolve({
        ok: true,
        blob: () => Promise.resolve(new Blob(['png'])),
      })) as unknown as typeof fetch;
    globalThis.createImageBitmap = (() =>
      Promise.resolve({
        width: 256,
        height: 256,
      } as ImageBitmap)) as unknown as typeof createImageBitmap;
    const styles = spyOn(globalThis, 'getComputedStyle').mockImplementation(
      (element) =>
        element.className === 'race-test'
          ? ({
              backgroundImage: 'url("race-test.png")',
              backgroundPosition: '0px 0px',
              width: '32px',
              height: '32px',
            } as CSSStyleDeclaration)
          : getStyle(element),
    );
    const unmounts: (() => void)[] = [];
    try {
      // One thumbnail loads and decodes the sheet.
      const first = renderHook(() => useSprites(['race-test']));
      unmounts.push(first.unmount);
      const [image] = made;
      let complete = true;
      Object.defineProperty(image, 'complete', { get: () => complete });
      Object.defineProperty(image, 'naturalWidth', { value: 256 });
      act(() => {
        image.dispatchEvent(new Event('load'));
      });
      await waitFor(() => expect(first.result.current[0]).toBeDefined());
      // The next one renders while the sheet isn't drawable yet, and by its
      // effect it is: no load or decode is left to tell it so.
      complete = false;
      let renders = 0;
      const second = renderHook(() => {
        const sprites = useSprites(['race-test']);
        if (renders++ === 0) {
          complete = true;
        }
        return sprites;
      });
      unmounts.push(second.unmount);
      await waitFor(() => expect(second.result.current[0]).toBeDefined());
      expect(renders).toBe(2);
    } finally {
      for (const unmount of unmounts) {
        unmount();
      }
      styles.mockRestore();
      globalThis.Image = originalImage;
      globalThis.createImageBitmap = originalDecode;
      globalThis.fetch = originalFetch;
    }
  });
});
