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
import { act, fireEvent, render, screen } from '@testing-library/react';
import { storage } from 'common/storage';
import { Provider } from 'jotai';
import { UI_INTERACTIVE } from 'tgui-core/constants';
import { configAtom, store, suspendedAtom } from '../events/store';
import { iconMapStateAtom } from '../iconMap';
import { IconResourceNotice } from './IconResourceNotice';
import { Window } from './Window';

const originalFetch = globalThis.fetch;
const originalWinset = Byond.winset;
const validMap = { 'icons/test.dmi': '[0x123]' };
let failures = 0;

/** Puts the loader in its terminal error state for a fresh URL, as three failed attempts leave it */
function failedMap() {
  const url = `https://assets.test/notice-${++failures}.json`;
  store.set(iconMapStateAtom, { url, status: 'error' });
  return url;
}

function mapFetch() {
  const fetcher = mock(() =>
    Promise.resolve(
      new Response(JSON.stringify(validMap), {
        headers: { 'content-type': 'application/json' },
      }),
    ),
  );
  globalThis.fetch = fetcher as unknown as typeof fetch;
  return fetcher;
}

function renderNotice() {
  return render(
    <Provider store={store}>
      <IconResourceNotice>
        <input aria-label="window content" />
      </IconResourceNotice>
    </Provider>,
  );
}

const retryButton = () => screen.getByText('Retry icons').closest('.Button')!;

beforeEach(() => {
  Byond.iconRefMap = {};
  store.set(iconMapStateAtom, { status: 'idle' });
});

afterEach(() => {
  globalThis.fetch = originalFetch;
  Byond.winset = originalWinset;
  jest.restoreAllMocks();
});

describe('Icon resource notice', () => {
  it('stays hidden unless the icon map has failed', () => {
    const view = renderNotice();
    const status = () =>
      view.container.querySelector('.IconResourceNotice__status')?.textContent;
    for (const state of [
      { status: 'idle' as const },
      { url: 'https://assets.test/loading.json', status: 'loading' as const },
      { url: 'https://assets.test/ready.json', status: 'ready' as const },
    ]) {
      act(() => store.set(iconMapStateAtom, state));
      expect(screen.queryByText('Retry icons') === null).toBe(true);
      expect(status()).toBe('');
      expect(
        view.container.querySelector('.IconResourceNotice--shown') === null,
      ).toBe(true);
    }
    act(() => {
      failedMap();
    });
    expect(status()).toBe('Some icons could not load.Retry icons');
    expect(
      view.container.querySelector('.IconResourceNotice--shown') !== null,
    ).toBe(true);
  });

  it('announces through a status region that is mounted before the notice', () => {
    const view = renderNotice();
    const region = () => view.container.querySelector('[role="status"]');
    expect(region()?.className).toBe('IconResourceNotice__status');
    act(() => {
      failedMap();
    });
    expect(region()?.className).toBe('IconResourceNotice__status');
    expect(region()?.textContent).toBe('Some icons could not load.Retry icons');
  });

  for (const [label, activate] of [
    ['a click', (button: Element) => fireEvent.click(button)],
    ['Enter', (button: Element) => fireEvent.keyDown(button, { key: 'Enter' })],
    ['Space', (button: Element) => fireEvent.keyDown(button, { key: ' ' })],
  ] as const) {
    it(`re-requests the map on ${label} and leaves the error state`, async () => {
      renderNotice();
      let url = '';
      act(() => {
        url = failedMap();
      });
      const fetcher = mapFetch();
      expect(retryButton().getAttribute('tabindex')).toBe('0');
      act(() => {
        activate(retryButton());
      });
      expect(fetcher.mock.calls.length).toBe(1);
      expect(String((fetcher.mock.calls[0] as unknown[])[0])).toBe(url);
      expect(store.get(iconMapStateAtom).status).toBe('loading');
      expect(screen.queryByText('Retry icons') === null).toBe(true);
      await act(async () => {
        for (let index = 0; index < 30; index++) await Promise.resolve();
      });
      expect(store.get(iconMapStateAtom).status).toBe('ready');
      expect(Byond.iconRefMap['icons/test.dmi']).toBe('[0x123]');
    });
  }

  it('sits in Window below the title bar and outside the content box', async () => {
    spyOn(storage, 'get').mockImplementation(() => new Promise(() => {}));
    Byond.winset = mock(() => {}) as typeof Byond.winset;
    store.set(configAtom, {
      client: {
        address: '127.0.0.1',
        ckey: 'notice_test',
        computer_id: 'test',
      },
      interface: { layout: 'default', name: 'NoticeTest' },
      meridianTheme: 'meridian_aphelion' as const,
      refreshing: 0 as const,
      status: UI_INTERACTIVE,
      title: 'Notice test',
      user: { name: 'Notice Tester', observer: 0 },
      window: {
        fancy: 1 as const,
        key: 'notice-test',
        locked: 0 as const,
        scale: 1 as const,
        size: [400, 300] as [number, number],
      },
    });
    store.set(suspendedAtom, false);
    try {
      const view = render(
        <Provider store={store}>
          <Window>
            <Window.Content>
              <input aria-label="unsaved edit" />
            </Window.Content>
          </Window>
        </Provider>,
      );
      const input = screen.getByLabelText('unsaved edit') as HTMLInputElement;
      input.value = 'typed before the failure';
      act(() => {
        failedMap();
      });
      const box = view.container.querySelector('.NoticeBox');
      expect(
        box?.closest(
          '.Window__rest > .IconResourceNotice > .IconResourceNotice__status',
        ) !== null,
      ).toBe(true);
      expect(box?.closest('.Window__content') === null).toBe(true);
      expect(
        view.container.querySelector(
          '.IconResourceNotice__content > .Window__content',
        ) !== null,
      ).toBe(true);
      // The content keeps its own nodes across the notice, so nothing typed is lost
      expect(screen.getByLabelText('unsaved edit') === input).toBe(true);
      expect(input.value).toBe('typed before the failure');
      view.unmount();
    } finally {
      store.set(suspendedAtom, Date.now());
    }
  });
});
