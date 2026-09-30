// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, expect, it } from 'bun:test';
import { act, cleanup, renderHook } from '@testing-library/react';
import { useLoadedImages } from './LayerCanvas';

const OriginalImage = globalThis.Image;
let requests: HTMLImageElement[];
beforeEach(() => {
  requests = [];
  globalThis.Image = class extends OriginalImage {
    constructor() {
      super();
      // Keep readiness under test control instead of HappyDOM's relative-URL errors.
      Object.defineProperty(this, 'src', { value: '', writable: true });
      requests.push(this);
    }
  };
});
afterEach(() => {
  cleanup();
  globalThis.Image = OriginalImage;
});

it('shares pending image loads across duplicate URLs and view changes', () => {
  const hook = renderHook(({ urls }) => useLoadedImages(urls), {
    initialProps: { urls: ['hat-front', 'hat-front'] },
  });
  expect(requests).toHaveLength(1);
  hook.rerender({ urls: ['hat-side', 'hat-front'] });
  expect(requests).toHaveLength(2);
  act(() => requests[0].dispatchEvent(new Event('load')));
  expect(hook.result.current['hat-front']).toBe(requests[0]);
  hook.rerender({ urls: ['hat-front', 'hat-side'] });
  expect(requests).toHaveLength(2);
  act(() => requests[1].dispatchEvent(new Event('load')));
  expect(hook.result.current['hat-side']).toBe(requests[1]);
  hook.unmount();
});

it('retries a failed image when requested again and detaches pending loads on close', () => {
  const hook = renderHook(({ urls }) => useLoadedImages(urls), {
    initialProps: { urls: ['hat-front'] },
  });
  act(() => requests[0].dispatchEvent(new Event('error')));
  hook.rerender({ urls: [] });
  hook.rerender({ urls: ['hat-front'] });
  expect(requests).toHaveLength(2);
  const lateLoad = requests[1].onload;
  hook.unmount();
  expect(requests[1].onload).toBeNull();
  expect(requests[1].onerror).toBeNull();
  act(() => lateLoad?.call(requests[1], new Event('load')));
  expect(hook.result.current).toEqual({});
});

it('ignores callbacks from a failed attempt after its replacement starts', () => {
  const hook = renderHook(({ urls }) => useLoadedImages(urls), {
    initialProps: { urls: ['hat-front'] },
  });
  const staleLoad = requests[0].onload;
  const staleError = requests[0].onerror;
  act(() => requests[0].dispatchEvent(new Event('error')));
  expect(requests[0].onload).toBeNull();
  expect(requests[0].onerror).toBeNull();
  hook.rerender({ urls: [] });
  hook.rerender({ urls: ['hat-front'] });
  act(() => {
    staleLoad?.call(requests[0], new Event('load'));
    staleError?.call(requests[0], new Event('error'));
  });
  expect(hook.result.current).toEqual({});
  act(() => requests[1].dispatchEvent(new Event('load')));
  expect(hook.result.current['hat-front']).toBe(requests[1]);
  expect(requests[1].onload).toBeNull();
  expect(requests[1].onerror).toBeNull();
});
