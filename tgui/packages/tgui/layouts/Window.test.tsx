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
import { storage } from 'common/storage';
import { Provider } from 'jotai';
import { UI_INTERACTIVE } from 'tgui-core/constants';
import { globalEvents } from 'tgui-core/events';
import {
  configAtom,
  store,
  suspendedAtom,
} from '../events/store';
import { update } from '../events/handlers/update';
import { Window } from './Window';

const originalSendMessage = Byond.sendMessage;
const originalWinget = Byond.winget;
const originalWinset = Byond.winset;

const testConfig = {
  client: {
    address: '127.0.0.1',
    ckey: 'geometry_test',
    computer_id: 'test',
  },
  interface: {
    layout: 'default',
    name: 'PreferencesMenu',
  },
  meridianTheme: 'meridian' as const,
  refreshing: 0 as const,
  status: UI_INTERACTIVE,
  title: 'Preferences',
  user: {
    name: 'Geometry Tester',
    observer: 0,
  },
  window: {
    fancy: 1 as const,
    key: 'preferences',
    locked: 0 as const,
    scale: 1 as const,
    size: [575, 700] as [number, number],
  },
};

function deferred<T>() {
  let resolve!: (value: T | PromiseLike<T>) => void;
  const promise = new Promise<T>((resolver) => {
    resolve = resolver;
  });
  return { promise, resolve };
}

async function flushGeometryLifecycle() {
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
}

beforeEach(() => {
  store.set(configAtom, testConfig);
  store.set(suspendedAtom, false);
});

afterEach(() => {
  Byond.sendMessage = originalSendMessage;
  Byond.winget = originalWinget;
  Byond.winset = originalWinset;
  store.set(suspendedAtom, Date.now());
  jest.restoreAllMocks();
  jest.useRealTimers();
});

describe('Window geometry lifecycle', () => {
  it('does not unhide or signal DM until recalled geometry has finished', async () => {
    const recalledGeometry = deferred<undefined>();
    spyOn(storage, 'get').mockImplementation(() => recalledGeometry.promise);
    const winset = mock((..._args: any[]) => {});
    const sendMessage = mock((..._args: any[]) => {});
    Byond.winset = winset as typeof Byond.winset;
    Byond.sendMessage = sendMessage as typeof Byond.sendMessage;
    let geometryEvents = 0;
    const onGeometry = () => geometryEvents++;
    globalEvents.on('window-geometry-finished', onGeometry);

    const view = render(
      <Provider store={store}>
        <Window width={575} height={700}>
          Geometry test
        </Window>
      </Provider>,
    );

    expect(winset).toHaveBeenCalledWith(Byond.windowId, {
      'is-visible': false,
    });
    expect(
      winset.mock.calls.some(([, params]) => params?.['is-visible'] === true),
    ).toBe(false);
    expect(sendMessage).not.toHaveBeenCalledWith('visible');
    expect(geometryEvents).toBe(0);

    await act(async () => {
      recalledGeometry.resolve(undefined);
      await flushGeometryLifecycle();
    });

    const geometryCall = winset.mock.calls.findIndex(
      ([, params]) => params?.size === '575x700',
    );
    const visibleCall = winset.mock.calls.findIndex(
      ([, params]) => params?.['is-visible'] === true,
    );
    expect(geometryCall).toBeGreaterThanOrEqual(0);
    expect(visibleCall).toBeGreaterThan(geometryCall);
    expect(sendMessage).toHaveBeenCalledWith('visible');
    expect(geometryEvents).toBe(1);

    view.unmount();
    globalEvents.off('window-geometry-finished', onGeometry);
  });

  it('cancels a stale mount generation without suppressing a remount', async () => {
    const firstRecall = deferred<undefined>();
    const secondRecall = deferred<undefined>();
    const getGeometry = spyOn(storage, 'get');
    getGeometry.mockImplementationOnce(() => firstRecall.promise);
    getGeometry.mockImplementationOnce(() => secondRecall.promise);
    const winset = mock((..._args: any[]) => {});
    const sendMessage = mock((..._args: any[]) => {});
    Byond.winset = winset as typeof Byond.winset;
    Byond.sendMessage = sendMessage as typeof Byond.sendMessage;
    let geometryEvents = 0;
    const onGeometry = () => geometryEvents++;
    globalEvents.on('window-geometry-finished', onGeometry);

    const first = render(
      <Provider store={store}>
        <Window>First mount</Window>
      </Provider>,
    );
    first.unmount();

    const second = render(
      <Provider store={store}>
        <Window>Second mount</Window>
      </Provider>,
    );

    await act(async () => {
      secondRecall.resolve(undefined);
      await flushGeometryLifecycle();
    });
    expect(sendMessage.mock.calls.filter(([type]) => type === 'visible')).toHaveLength(
      1,
    );
    expect(geometryEvents).toBe(1);

    await act(async () => {
      firstRecall.resolve(undefined);
      await flushGeometryLifecycle();
    });
    expect(sendMessage.mock.calls.filter(([type]) => type === 'visible')).toHaveLength(
      1,
    );
    expect(geometryEvents).toBe(1);

    second.unmount();
    globalEvents.off('window-geometry-finished', onGeometry);
  });

  it('never unhides from the resume handler before Window owns geometry', () => {
    jest.useFakeTimers();
    store.set(suspendedAtom, Date.now());
    const winset = mock((..._args: any[]) => {});
    Byond.winset = winset as typeof Byond.winset;
    Byond.winget = mock(async () => ({ x: 0, y: 0 })) as typeof Byond.winget;

    update({
      config: testConfig,
      data: {},
      debug: {
        debugLayout: false,
        debugTheme: null,
        kitchenSink: false,
      },
      outgoingPayloadQueues: {},
      shared: {},
      static_data: {},
      staticData: {},
      suspended: false,
      suspending: false,
    });
    jest.runAllTimers();

    expect(
      winset.mock.calls.some(([, params]) => params?.['is-visible'] === true),
    ).toBe(false);
  });
});
