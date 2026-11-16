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
import { act, render } from '@testing-library/react';
import { storage } from 'common/storage';
import { Provider } from 'jotai';
import { store } from '../events/store';
import {
  defaultHighlights,
  defaultSettings,
  highlightsAtom,
  settingsAtom,
  settingsLoadedAtom,
  settingsReadAtom,
} from './atoms';
import { useSettings } from './use-settings';

// What a player had saved before the session: not the defaults.
const saved = {
  ...defaultSettings,
  ...defaultHighlights,
  fontSize: 16,
  theme: 'dark',
  initialized: true,
};

let settingsApi: ReturnType<typeof useSettings> | undefined;

function Probe() {
  settingsApi = useSettings();
  return null;
}

/** The panel-settings writes made during a test. */
let panelWrites: unknown[];

/**
 * Stubs the storage the panel reads its settings from. `read` is what the
 * store answers: a value, undefined for nothing stored, or a rejection when it
 * couldn't be read. A store that can't answer gave `get` undefined, so `get`
 * resolves that way whenever `read` doesn't resolve a value.
 */
function stubStorage(read: () => Promise<unknown>) {
  panelWrites = [];
  const strict = mock(read);
  Object.assign(storage, { read: strict });
  spyOn(storage, 'get').mockImplementation(async (key: string) => {
    if (key !== 'panel-settings') return undefined;
    try {
      return await strict();
    } catch {
      return undefined;
    }
  });
  spyOn(storage, 'set').mockImplementation(async (key: string, value) => {
    if (key === 'panel-settings') panelWrites.push(value);
  });
}

async function mountPanel() {
  render(
    <Provider store={store}>
      <Probe />
    </Provider>,
  );
  // Let the load and anything it chains run out.
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 20));
  });
}

describe('panel settings load', () => {
  beforeEach(() => {
    store.set(settingsAtom, defaultSettings);
    store.set(highlightsAtom, defaultHighlights);
    store.set(settingsLoadedAtom, false);
    store.set(settingsReadAtom, false);
    settingsApi = undefined;
  });

  afterEach(() => {
    mock.restore();
    Object.assign(storage, { read: undefined });
  });

  it('keeps the stored settings when they could not be read', async () => {
    stubStorage(() => Promise.reject(new Error('storage did not answer')));
    await mountPanel();

    expect(panelWrites).toEqual([]);
    expect(store.get(settingsAtom).fontSize).toBe(defaultSettings.fontSize);
    expect(store.get(settingsLoadedAtom)).toBe(true);
  });

  it('does not save over settings it could not read when one changes', async () => {
    stubStorage(() => Promise.reject(new Error('storage did not answer')));
    await mountPanel();

    act(() => settingsApi?.updateSettings({ fontSize: 20 }));

    expect(panelWrites).toEqual([]);
    expect(store.get(settingsAtom).fontSize).toBe(20);
  });

  it('saves the defaults when nothing is stored yet', async () => {
    stubStorage(() => Promise.resolve(undefined));
    await mountPanel();

    expect(panelWrites).toHaveLength(1);
    expect(panelWrites[0]).toMatchObject({
      fontSize: defaultSettings.fontSize,
      theme: defaultSettings.theme,
      initialized: true,
    });
  });

  it('loads stored settings, and saves changes after that', async () => {
    stubStorage(() => Promise.resolve(saved));
    await mountPanel();

    expect(store.get(settingsAtom)).toMatchObject({
      fontSize: 16,
      theme: 'dark',
    });

    act(() => settingsApi?.updateSettings({ fontSize: 18 }));

    expect(panelWrites.at(-1)).toMatchObject({ fontSize: 18, theme: 'dark' });
  });

  it('does not save a change made before the stored settings are read', async () => {
    let answer: (value: unknown) => void = () => {};
    stubStorage(
      () =>
        new Promise((resolve) => {
          answer = resolve;
        }),
    );
    render(
      <Provider store={store}>
        <Probe />
      </Provider>,
    );

    act(() => settingsApi?.updateSettings({ fontSize: 20 }));
    expect(panelWrites).toEqual([]);

    await act(async () => {
      answer(saved);
      await new Promise((resolve) => setTimeout(resolve, 20));
    });

    expect(panelWrites).toEqual([]);
    expect(store.get(settingsAtom)).toMatchObject({
      fontSize: 16,
      theme: 'dark',
    });
  });
});
