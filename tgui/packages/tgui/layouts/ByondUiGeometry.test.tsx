// THIS IS AN APHELION UI FILE
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
  mock,
  spyOn,
} from 'bun:test';
import { act, render } from '@testing-library/react';
import { globalEvents } from 'tgui-core/events';
import { useRootThemeClasses } from '../hooks/useRootThemeClasses';
import { CharacterPreview } from '../interfaces/common/CharacterPreview';
import { ByondUi } from './ByondUi';

type TestRect = {
  bottom: number;
  height: number;
  left: number;
  right: number;
  top: number;
  width: number;
  x: number;
  y: number;
  toJSON: () => object;
};

const originalDevicePixelRatio = Object.getOwnPropertyDescriptor(
  window,
  'devicePixelRatio',
);
const originalSendMessage = Byond.sendMessage;
const originalWinset = Byond.winset;

let currentRect: TestRect;

function makeRect(left: number, top: number, width: number, height: number) {
  return {
    bottom: top + height,
    height,
    left,
    right: left + width,
    top,
    width,
    x: left,
    y: top,
    toJSON: () => ({}),
  } satisfies TestRect;
}

beforeEach(() => {
  jest.useFakeTimers();
  currentRect = makeRect(0, 0, 16, 16);
  Object.defineProperty(window, 'devicePixelRatio', {
    configurable: true,
    value: 1.5,
  });
  spyOn(HTMLElement.prototype, 'getBoundingClientRect').mockImplementation(
    () => currentRect as DOMRect,
  );
});

afterEach(() => {
  Byond.sendMessage = originalSendMessage;
  Byond.winset = originalWinset;
  if (originalDevicePixelRatio) {
    Object.defineProperty(window, 'devicePixelRatio', originalDevicePixelRatio);
  }
  jest.restoreAllMocks();
  jest.useRealTimers();
});

describe('ByondUi geometry lifecycle', () => {
  it('resizes the native character preview after a theme change without a window resize', () => {
    const winset = mock((..._args: any[]) => {});
    Byond.winset = winset as typeof Byond.winset;

    function ThemedPreview({ theme }: { theme: string }) {
      useRootThemeClasses([theme]);
      return <CharacterPreview id="theme_preview" height="100%" />;
    }

    currentRect = makeRect(10, 40, 272, 480);
    const view = render(<ThemedPreview theme="theme-nanotrasen" />);
    const renderCalls = () =>
      winset.mock.calls.filter(
        ([id, params]) => id === 'theme_preview' && params?.parent,
      );
    expect(renderCalls().at(-1)?.[1]).toMatchObject({ size: '408x720' });

    currentRect = makeRect(22, 52, 248, 440);
    view.rerender(<ThemedPreview theme="theme-meridian_foundry" />);
    act(() => jest.advanceTimersByTime(150));
    expect(renderCalls()).toHaveLength(2);
    expect(renderCalls().at(-1)?.[1]).toMatchObject({
      pos: '33,78',
      size: '372x660',
    });

    view.rerender(<ThemedPreview theme="theme-meridian_foundry" />);
    act(() => jest.advanceTimersByTime(150));
    expect(renderCalls()).toHaveLength(2);

    currentRect = makeRect(10, 40, 272, 480);
    view.rerender(<ThemedPreview theme="theme-nanotrasen" />);
    act(() => jest.advanceTimersByTime(150));
    expect(renderCalls().at(-1)?.[1]).toMatchObject({
      pos: '15,60',
      size: '408x720',
    });
    view.unmount();
  });

  it('remeasures the final rectangle and device-pixel ratio after geometry', () => {
    const winset = mock((..._args: any[]) => {});
    Byond.winset = winset as typeof Byond.winset;

    const view = render(
      <ByondUi params={{ id: 'preferences_character_preview', type: 'map' }} />,
    );

    const renderCalls = () =>
      winset.mock.calls.filter(
        ([id, params]) =>
          id === 'preferences_character_preview' && params?.parent,
      );

    expect(renderCalls()).toHaveLength(1);
    expect(renderCalls()[0][1]).toMatchObject({
      pos: '0,0',
      size: '24x24',
    });

    currentRect = makeRect(12, 24, 96, 128);
    act(() => globalEvents.emit('window-geometry-finished'));
    act(() => jest.advanceTimersByTime(100));

    expect(renderCalls()).toHaveLength(2);
    expect(renderCalls()[1][1]).toMatchObject({
      pos: '18,36',
      size: '144x192',
    });

    view.unmount();
  });

  it('handles an event before mount, remounts, and unparents cleanly', () => {
    const winset = mock((..._args: any[]) => {});
    const sendMessage = mock((..._args: any[]) => {});
    Byond.winset = winset as typeof Byond.winset;
    Byond.sendMessage = sendMessage as typeof Byond.sendMessage;

    // An early geometry event must be harmless. ByondUi performs an immediate
    // measurement when it mounts specifically to cover this ordering.
    globalEvents.emit('window-geometry-finished');
    act(() => jest.advanceTimersByTime(100));

    currentRect = makeRect(4, 8, 64, 96);
    const first = render(
      <ByondUi params={{ id: 'preferences_character_preview', type: 'map' }} />,
    );
    expect(
      winset.mock.calls.filter(
        ([id, params]) =>
          id === 'preferences_character_preview' && params?.size === '96x144',
      ),
    ).toHaveLength(1);

    first.unmount();
    expect(winset).toHaveBeenCalledWith('preferences_character_preview', {
      parent: '',
    });
    expect(sendMessage).toHaveBeenCalledWith('unmountByondUi', {
      renderByondUi: 'preferences_character_preview',
    });

    const callCountAfterUnmount = winset.mock.calls.length;
    globalEvents.emit('window-geometry-finished');
    act(() => jest.advanceTimersByTime(100));
    expect(winset.mock.calls).toHaveLength(callCountAfterUnmount);

    currentRect = makeRect(10, 20, 96, 96);
    const second = render(
      <ByondUi params={{ id: 'preferences_character_preview', type: 'map' }} />,
    );
    expect(
      winset.mock.calls.filter(
        ([id, params]) =>
          id === 'preferences_character_preview' &&
          params?.pos === '15,30' &&
          params?.size === '144x144',
      ),
    ).toHaveLength(1);

    second.unmount();
  });
});

describe('persistent ByondUi', () => {
  // Pages that each show the same preview, as the preferences tabs do.
  function Pages({ page }: { page: 'character' | 'loadout' | 'jobs' }) {
    if (page === 'jobs') {
      return <div>No preview here</div>;
    }
    return (
      <div key={page}>
        <CharacterPreview id="persist_a" height="100%" />
      </div>
    );
  }

  it('moves one control between pages instead of making another', async () => {
    const winset = mock((..._args: any[]) => {});
    const sendMessage = mock((..._args: any[]) => {});
    Byond.winset = winset as typeof Byond.winset;
    Byond.sendMessage = sendMessage as typeof Byond.sendMessage;
    const calls = () => winset.mock.calls.filter(([id]) => id === 'persist_a');

    currentRect = makeRect(4, 110, 272, 494);
    const view = render(<Pages page="character" />);
    currentRect = makeRect(8, 180, 240, 202);
    view.rerender(<Pages page="loadout" />);
    await act(async () => {});

    // Never destroyed or hidden: the loadout page took it over, where it now sits.
    expect(calls().some(([, params]) => params.parent === '')).toBe(false);
    expect(calls().some(([, params]) => params['is-visible'] === false)).toBe(
      false,
    );
    expect(calls().at(-1)?.[1]).toMatchObject({
      pos: '12,270',
      size: '360x303',
      'is-visible': true,
    });
    // The server keeps it on its list, to destroy with the window.
    expect(
      sendMessage.mock.calls.filter(([type]) => type === 'renderByondUi'),
    ).toHaveLength(2);
    expect(
      sendMessage.mock.calls.filter(([type]) => type === 'unmountByondUi'),
    ).toHaveLength(0);
    view.unmount();
  });

  it('hides the control while no page shows it, and shows it again', async () => {
    const winset = mock((..._args: any[]) => {});
    Byond.winset = winset as typeof Byond.winset;
    Byond.sendMessage = mock(() => {}) as typeof Byond.sendMessage;
    const last = () =>
      winset.mock.calls.filter(([id]) => id === 'persist_a').at(-1)?.[1];

    const view = render(<Pages page="character" />);
    view.rerender(<Pages page="jobs" />);
    await act(async () => {});
    expect(last()).toEqual({ 'is-visible': false });

    view.rerender(<Pages page="character" />);
    await act(async () => {});
    expect(last()).toMatchObject({ type: 'map', 'is-visible': true });
    expect(
      winset.mock.calls.some(
        ([id, params]) => id === 'persist_a' && params.parent === '',
      ),
    ).toBe(false);
    view.unmount();
  });
});
