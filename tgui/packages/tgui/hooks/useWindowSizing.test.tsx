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
import { act, fireEvent, renderHook, waitFor } from '@testing-library/react';
import { globalEvents } from 'tgui-core/events';
import { useWindowSizing } from './useWindowSizing';
import { applyContentSize, measureWindowContent } from './windowSizing';

function fit(prompt = false) {
  const measurement = measureWindowContent(prompt);
  if (measurement) applyContentSize(measurement);
}

const originalWinset = Byond.winset;
const restores: (() => void)[] = [];
function property(target: object, key: string, value: unknown) {
  const old = Object.getOwnPropertyDescriptor(target, key);
  Object.defineProperty(target, key, { configurable: true, value });
  restores.push(() =>
    old
      ? Object.defineProperty(target, key, old)
      : Reflect.deleteProperty(target, key),
  );
}

beforeEach(() => {
  property(window, 'innerWidth', 345);
  property(window, 'innerHeight', 175);
  property(window, 'devicePixelRatio', 1);
  property(window, 'screenTop', 0);
  property(window, 'screenLeft', 0);
  property(window.screen, 'availHeight', 900);
  property(window.screen, 'availWidth', 1500);
  Byond.winset = mock(() => {}) as typeof Byond.winset;
});

afterEach(() => {
  Byond.winset = originalWinset;
  document.body.innerHTML = '';
  while (restores.length) restores.pop()!();
});

function content(bottom: number, zoom = 1) {
  document.body.innerHTML =
    '<div class="MeridianContentFit"><div class="Window__content"><div class="Window__contentPadding" style="margin-bottom: 6px"></div></div></div>';
  const area = document.querySelector<HTMLElement>('.Window__content')!;
  const padding = document.querySelector<HTMLElement>(
    '.Window__contentPadding',
  )!;
  property(padding, 'offsetWidth', 300);
  spyOn(area, 'getBoundingClientRect').mockReturnValue({
    bottom: 165,
  } as DOMRect);
  spyOn(padding, 'getBoundingClientRect').mockReturnValue({
    bottom,
    width: 300 * zoom,
  } as DOMRect);
  return area;
}

describe('Content-sized window geometry', () => {
  it('opens tall enough for content and the bottom frame', () => {
    content(239);
    fit(true);
    expect(Byond.winset).toHaveBeenCalledWith(Byond.windowId, {
      size: '345x255',
    });
  });

  it('caps at the available screen and converts display pixels', () => {
    content(1200);
    property(window, 'devicePixelRatio', 2);
    property(window.screen, 'availHeight', 600);
    fit(true);
    expect(Byond.winset).toHaveBeenCalledWith(Byond.windowId, {
      size: '690x1200',
    });
  });

  it('accounts for unscaled BYOND content and scroll position', () => {
    const area = content(239, 0.5);
    area.scrollTop = 30;
    fit(true);
    expect(Byond.winset).toHaveBeenCalledWith(Byond.windowId, {
      size: '345x267',
    });
  });

  it('preserves a larger user window and ignores unrelated windows', () => {
    content(140);
    fit(true);
    document.querySelector('.MeridianContentFit')!.className = 'Window';
    fit(true);
    expect(Byond.winset).not.toHaveBeenCalled();
  });

  it('does not resize a removed window', () => {
    document.body.innerHTML = '';
    fit(true);
    expect(Byond.winset).not.toHaveBeenCalled();
  });
});

describe('Overflow-driven window growth', () => {
  function scrolling(scrollHeight: number, clientHeight = 175) {
    document.body.innerHTML = '<div class="Window__content"></div>';
    const area = document.querySelector<HTMLElement>('.Window__content')!;
    property(area, 'scrollHeight', scrollHeight);
    property(area, 'clientHeight', clientHeight);
    return area;
  }

  it('grows a window that hides content behind its scrollbar', () => {
    scrolling(215);
    fit();
    expect(Byond.winset).toHaveBeenCalledWith(Byond.windowId, {
      size: '345x215',
    });
  });

  it('grows past the low ceiling when nothing is meant to scroll', () => {
    scrolling(600);
    fit();
    expect(Byond.winset).toHaveBeenCalledWith(Byond.windowId, {
      size: '345x600',
    });
  });

  it('does not expand a deliberate list to expose every row', () => {
    const area = scrolling(175);
    const list = document.createElement('div');
    list.className = 'Section Section--fill Section--scrollable';
    list.innerHTML =
      '<div class="Section__rest"><div class="Section__content"></div></div>';
    property(list, 'scrollHeight', 175);
    property(list, 'clientHeight', 175);
    const scroller = list.querySelector('.Section__content')!;
    property(scroller, 'scrollHeight', 800);
    property(scroller, 'clientHeight', 120);
    area.appendChild(list);
    fit();
    expect(Byond.winset).not.toHaveBeenCalled();
  });

  it('preserves an explicitly scrolling Window.Content', () => {
    scrolling(800).classList.add('Layout__content--scrollable');
    fit();
    expect(Byond.winset).not.toHaveBeenCalled();
  });

  it('includes the bottom gutter even when the fixed padding box overflows', () => {
    const area = scrolling(215);
    area.innerHTML = '<div class="Window__contentPadding"></div>';
    const padding = area.firstElementChild!;
    property(padding, 'clientHeight', 163);
    property(padding, 'scrollHeight', 209);
    fit();
    expect(Byond.winset).toHaveBeenCalledWith(Byond.windowId, {
      size: '345x221',
    });
  });

  it('converts CSS zoom before converting viewport pixels to native pixels', () => {
    const area = scrolling(360, 318);
    property(window, 'devicePixelRatio', 2);
    property(window, 'innerWidth', 170);
    property(area, 'offsetWidth', 340);
    spyOn(area, 'getBoundingClientRect').mockReturnValue({
      width: 170,
    } as DOMRect);
    fit();
    expect(Byond.winset).toHaveBeenCalledWith(Byond.windowId, {
      size: '340x392',
    });
  });

  it('fits width before height so wrapped content can be measured again', () => {
    const area = scrolling(225);
    property(area, 'clientWidth', 345);
    property(area, 'scrollWidth', 405);
    fit();
    expect(Byond.winset).toHaveBeenCalledWith(Byond.windowId, {
      size: '405x175',
    });
  });

  it('does not leave a small strip of controls clipped', () => {
    scrolling(179);
    fit();
    expect(Byond.winset).toHaveBeenCalledWith(Byond.windowId, {
      size: '345x179',
    });
  });

  it('ignores content that already fits', () => {
    scrolling(175);
    fit();
    expect(Byond.winset).not.toHaveBeenCalled();
  });

  it('never grows past the available screen', () => {
    property(window.screen, 'availHeight', 200);
    const area = scrolling(400);
    fit();
    expect(Byond.winset).toHaveBeenCalledWith(Byond.windowId, {
      size: '345x200',
    });
    expect(area.classList.contains('Window__content--overflow-y')).toBe(true);
  });
});

describe('Shared window sizing lifecycle', () => {
  function layout(height = 175, requiredHeight = height) {
    document.body.innerHTML =
      '<div class="Window"><div class="Window__content"><div class="Window__contentPadding"><div class="Section">Controls</div></div></div><div class="Window__resizeHandle__se"></div></div>';
    const area = document.querySelector<HTMLElement>('.Window__content')!;
    property(area, 'clientHeight', height);
    property(area, 'scrollHeight', requiredHeight);
    return area;
  }

  async function pause() {
    await act(async () => new Promise((resolve) => setTimeout(resolve, 30)));
  }

  async function open(
    fitBeforeShow: ReturnType<typeof useWindowSizing>['fitBeforeShow'],
  ) {
    await act(async () => {
      await fitBeforeShow(() => false, { size: [345, 175], scale: 1 });
    });
  }

  function nativeResize() {
    Byond.winset = mock((_id?: unknown, params?: { size?: string }) => {
      if (!params?.size) return;
      const [width, height] = String(params.size).split('x').map(Number);
      property(window, 'innerWidth', width);
      property(window, 'innerHeight', height);
      const area = document.querySelector('.Window__content');
      if (area) property(area, 'clientHeight', height);
      window.dispatchEvent(new Event('resize'));
    }) as typeof Byond.winset;
  }

  it('waits for a pooled native viewport, then fits before finishing the opening pass', async () => {
    property(window, 'innerHeight', 600);
    const area = layout(600);
    const hook = renderHook(() => useWindowSizing('Smes', false));
    let finished = false;
    const fitting = hook.result.current
      .fitBeforeShow(() => false, { size: [345, 175], scale: 1 })
      .then(() => {
        finished = true;
      });
    await pause();
    expect(finished).toBe(false);
    expect(Byond.winset).not.toHaveBeenCalled();
    nativeResize();
    property(window, 'innerHeight', 175);
    property(area, 'clientHeight', 175);
    property(area, 'scrollHeight', 215);
    await act(async () => {
      window.dispatchEvent(new Event('resize'));
      await fitting;
    });
    expect(window.innerHeight).toBe(215);
    expect(finished).toBe(true);
    hook.unmount();
  });

  it('waits for fonts in an ordinary interface', async () => {
    layout(175, 215);
    let fontsReady!: () => void;
    property(
      document,
      'fonts',
      Object.assign(new EventTarget(), {
        status: 'loading',
        ready: new Promise<void>((resolve) => {
          fontsReady = resolve;
        }),
      }),
    );
    nativeResize();
    const hook = renderHook(() => useWindowSizing('Smes', false));
    const fitting = hook.result.current.fitBeforeShow(() => false, {
      size: [345, 175],
      scale: 1,
    });
    await pause();
    expect(Byond.winset).not.toHaveBeenCalled();
    await act(async () => {
      fontsReady();
      await fitting;
    });
    expect(window.innerHeight).toBe(215);
    hook.unmount();
  });

  it('rechecks a native resize that arrives after the geometry event', async () => {
    const area = layout();
    nativeResize();
    const hook = renderHook(() => useWindowSizing('Smes', false));
    await open(hook.result.current.fitBeforeShow);
    act(() => globalEvents.emit('window-geometry-finished'));
    await pause();
    property(area, 'scrollHeight', 215);
    act(() => window.dispatchEvent(new Event('resize')));
    await waitFor(() => expect(window.innerHeight).toBe(215));
    hook.unmount();
  });

  it('observes content changes inside a fixed-height padding wrapper', async () => {
    const area = layout();
    nativeResize();
    const hook = renderHook(() => useWindowSizing('Smes', false));
    await open(hook.result.current.fitBeforeShow);
    act(() => globalEvents.emit('window-geometry-finished'));
    await pause();
    // Mutation subscriptions must survive collection between layout updates.
    Bun.gc(true);
    property(area, 'scrollHeight', 240);
    act(() => {
      area.querySelector('.Section')!.textContent = 'Additional controls';
    });
    await waitFor(() => expect(window.innerHeight).toBe(240));
    hook.unmount();
  });

  it('keeps nested scroll containers observed inside a scrolling aperture', async () => {
    const area = layout();
    area.classList.add('Layout__content--scrollable');
    const section = area.querySelector('.Section')!;
    section.classList.add('Section--scrollable');
    section.innerHTML = '<div class="Stack">Scrolled content</div>';
    const observe = spyOn(ResizeObserver.prototype, 'observe');
    const unobserve = spyOn(ResizeObserver.prototype, 'unobserve');
    try {
      const hook = renderHook(() => useWindowSizing('Smes', false));
      await open(hook.result.current.fitBeforeShow);
      // Compare identity without dumping Happy DOM's entire object graph on failure.
      const wasObserved = (element: Element | null) =>
        observe.mock.calls.some(([target]) => target === element);
      expect(wasObserved(area)).toBe(true);
      expect(wasObserved(section)).toBe(true);
      expect(wasObserved(section.firstElementChild)).toBe(false);
      await pause();
      Bun.gc(true);
      act(() => section.classList.remove('Section--scrollable'));
      await waitFor(() =>
        expect(
          unobserve.mock.calls.some(([target]) => target === section),
        ).toBe(true),
      );
      act(() => area.classList.remove('Layout__content--scrollable'));
      await waitFor(() =>
        expect(wasObserved(section.firstElementChild)).toBe(true),
      );
      hook.unmount();
    } finally {
      observe.mockRestore();
      unobserve.mockRestore();
    }
  });

  it('batches repeated class mutations while retaining newly added content', async () => {
    const area = layout();
    const frames: FrameRequestCallback[] = [];
    let deliverMutations: (records: MutationRecord[]) => void;
    // Control delivery separately from RAF. Real observer delivery is covered
    // by the completed Chrome benchmarks; this checks multiple deliveries in one frame.
    property(
      globalThis,
      'MutationObserver',
      class {
        constructor(callback: MutationCallback) {
          deliverMutations = (records) =>
            callback(records, this as unknown as MutationObserver);
        }
        observe() {}
        disconnect() {}
        takeRecords() {
          return [];
        }
      },
    );
    property(
      globalThis,
      'requestAnimationFrame',
      (callback: FrameRequestCallback) => {
        frames.push(callback);
        return frames.length;
      },
    );
    property(globalThis, 'cancelAnimationFrame', () => {});
    const hook = renderHook(() => useWindowSizing('Smes', false));
    await open(hook.result.current.fitBeforeShow);
    const query = spyOn(area, 'querySelectorAll');
    const observe = spyOn(ResizeObserver.prototype, 'observe');
    try {
      for (let index = 0; index < 4; index++) {
        act(() => {
          area.classList.toggle('updated');
          deliverMutations([
            { type: 'attributes', attributeName: 'class' } as MutationRecord,
          ]);
        });
      }
      const section = document.createElement('div');
      section.className = 'Section';
      act(() => {
        area.append(section);
        deliverMutations([{ type: 'childList' } as MutationRecord]);
      });
      expect(query).not.toHaveBeenCalled();
      expect(frames).toHaveLength(1);
      act(() => frames[0](performance.now()));
      expect(query).toHaveBeenCalledTimes(1);
      expect(observe).toHaveBeenCalledWith(section);
    } finally {
      hook.unmount();
      query.mockRestore();
      observe.mockRestore();
    }
  });

  it('rechecks late font layout after the window is visible', async () => {
    const area = layout();
    const fonts = new EventTarget();
    property(document, 'fonts', fonts);
    nativeResize();
    const hook = renderHook(() => useWindowSizing('Smes', false));
    await open(hook.result.current.fitBeforeShow);
    act(() => globalEvents.emit('window-geometry-finished'));
    await pause();
    property(area, 'scrollHeight', 215);
    act(() => fonts.dispatchEvent(new Event('loadingdone')));
    await waitFor(() => expect(window.innerHeight).toBe(215));
    hook.unmount();
  });

  it('preserves a manual resize and makes the remaining overflow scrollable', async () => {
    const area = layout();
    nativeResize();
    const hook = renderHook(() => useWindowSizing('Smes', false));
    await open(hook.result.current.fitBeforeShow);
    act(() => globalEvents.emit('window-geometry-finished'));
    await pause();
    fireEvent.mouseDown(document.querySelector('.Window__resizeHandle__se')!);
    property(area, 'scrollHeight', 215);
    act(() => window.dispatchEvent(new Event('resize')));
    await waitFor(() =>
      expect(area.classList.contains('Window__content--overflow-y')).toBe(true),
    );
    expect(Byond.winset).not.toHaveBeenCalled();
    hook.unmount();
  });

  it('cancels work queued for a suspended window', async () => {
    const area = layout();
    nativeResize();
    const hook = renderHook(
      ({ suspended }) => useWindowSizing('Smes', suspended),
      { initialProps: { suspended: false as boolean | number } },
    );
    await open(hook.result.current.fitBeforeShow);
    act(() => globalEvents.emit('window-geometry-finished'));
    await pause();
    property(area, 'scrollHeight', 215);
    act(() => {
      window.dispatchEvent(new Event('resize'));
      hook.rerender({ suspended: 1 });
    });
    await pause();
    expect(Byond.winset).not.toHaveBeenCalled();
    hook.unmount();
  });

  it('does not run an old queued fit while a new opening is waiting for geometry', async () => {
    const area = layout();
    let frame: FrameRequestCallback | undefined;
    property(
      globalThis,
      'requestAnimationFrame',
      (callback: FrameRequestCallback) => {
        frame = callback;
        return 1;
      },
    );
    property(globalThis, 'cancelAnimationFrame', () => {});
    const hook = renderHook(() => useWindowSizing('Smes', false));
    await open(hook.result.current.fitBeforeShow);
    act(() => globalEvents.emit('window-geometry-finished'));
    property(area, 'scrollHeight', 215);
    const opening = hook.result.current.fitBeforeShow(() => false, {
      size: [345, 160],
      scale: 1,
    });
    act(() => frame!(0));
    expect(Byond.winset).not.toHaveBeenCalled();
    hook.unmount();
    await opening;
  });

  it('stops growing when a viewport-relative layout keeps the same overflow', async () => {
    const area = layout();
    Object.defineProperty(area, 'scrollHeight', {
      configurable: true,
      get: () => window.innerHeight + 20,
    });
    nativeResize();
    const hook = renderHook(() => useWindowSizing('Smes', false));
    await act(async () => {
      await hook.result.current.fitBeforeShow(() => false, {
        size: [345, 175],
        scale: 1,
      });
    });
    act(() => globalEvents.emit('window-geometry-finished'));
    await pause();
    expect(window.innerHeight).toBe(195);
    expect(area.classList.contains('Window__content--overflow-y')).toBe(true);
    hook.unmount();
  });

  it('does not let a cancelled caller disable a reused hook', async () => {
    const area = layout();
    nativeResize();
    const hook = renderHook(({ name }) => useWindowSizing(name, false), {
      initialProps: { name: 'Smes' },
    });
    const staleFit = hook.result.current.fitBeforeShow;
    hook.rerender({ name: 'PortablePump' });
    await open(hook.result.current.fitBeforeShow);
    await act(async () => {
      await staleFit(() => true, { size: [345, 175], scale: 1 });
    });
    property(area, 'scrollHeight', 215);
    act(() => window.dispatchEvent(new Event('resize')));
    await waitFor(() => expect(window.innerHeight).toBe(215));
    hook.unmount();
  });

  it('keeps controls reachable if the native window refuses the fitted size', async () => {
    const area = layout(175, 215);
    const hook = renderHook(() => useWindowSizing('Smes', false));
    await open(hook.result.current.fitBeforeShow);
    expect(window.innerHeight).toBe(175);
    expect(area.classList.contains('Window__content--overflow-y')).toBe(true);
    hook.unmount();
  });

  it('provides scrolling if the initial native geometry never arrives', async () => {
    const area = layout(175, 215);
    const hook = renderHook(() => useWindowSizing('Smes', false));
    await act(async () => {
      await hook.result.current.fitBeforeShow(() => false, {
        size: [345, 200],
        scale: 1,
      });
    });
    act(() => globalEvents.emit('window-geometry-finished'));
    await pause();
    expect((Byond.winset as ReturnType<typeof mock>).mock.calls).toEqual([]);
    expect(area.classList.contains('Window__content--overflow-y')).toBe(true);
    hook.unmount();
  });

  it('still fits when initial native geometry arrives after the bounded wait', async () => {
    const area = layout(175, 215);
    const hook = renderHook(() => useWindowSizing('Smes', false));
    await act(async () => {
      await hook.result.current.fitBeforeShow(() => false, {
        size: [345, 200],
        scale: 1,
      });
    });
    act(() => globalEvents.emit('window-geometry-finished'));
    await pause();
    expect(Byond.winset).not.toHaveBeenCalled();
    nativeResize();
    property(window, 'innerHeight', 200);
    property(area, 'clientHeight', 200);
    act(() => window.dispatchEvent(new Event('resize')));
    await waitFor(() => expect(window.innerHeight).toBe(215));
    expect(area.classList.contains('Window__content--overflow-y')).toBe(false);
    hook.unmount();
  });
});
