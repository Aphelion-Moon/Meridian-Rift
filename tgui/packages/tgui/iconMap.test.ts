// THIS IS AN APHELION UI FILE
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
  spyOn,
} from 'bun:test';
import { store } from './events/store';
import { iconMapStateAtom, loadIconMap, retryIconMap } from './iconMap';

const refs = { 'icons/obj/drinks.dmi': '[0xc000020]' };
const newerRefs = { 'icons/obj/food.dmi': '[0xc000021]' };

/** What the cdn gives for one fetch - a body, an HTTP error, or no answer */
type Answer = { body: unknown } | { status: number } | 'stall';

/** How each fetch was asked, in order */
let asked: { url: string; cache?: RequestCache }[];

/** Answers each fetch with the next of `answers`, and the last one after that */
function stubFetch(...answers: Answer[]) {
  asked = [];
  spyOn(globalThis, 'fetch').mockImplementation(((
    url: string,
    init?: RequestInit,
  ) => {
    const answer = answers[Math.min(asked.length, answers.length - 1)];
    asked.push({ url, cache: init?.cache });
    if (answer === 'stall') {
      // Like a real fetch, it only ends when it's aborted
      return new Promise((_resolve, reject) => {
        init?.signal?.addEventListener('abort', () =>
          reject(new Error('aborted')),
        );
      });
    }
    if ('status' in answer) {
      return Promise.resolve({ ok: false, status: answer.status });
    }
    return Promise.resolve({
      ok: true,
      status: 200,
      json: async () => answer.body,
    });
  }) as unknown as typeof fetch);
}

/** Lets everything that's waiting on a promise run */
async function settle() {
  for (let turn = 0; turn < 50; turn++) {
    await Promise.resolve();
  }
}

/** Moves the clock, then lets what that started run */
async function wait(ms: number) {
  jest.advanceTimersByTime(ms);
  await settle();
}

const status = () => store.get(iconMapStateAtom).status;

describe('icon map loading', () => {
  beforeEach(() => {
    jest.useFakeTimers();
    Byond.iconRefMap = {};
    store.set(iconMapStateAtom, { status: 'idle' });
    // Failed tries are logged, which isn't what these tests look at
    spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.useRealTimers();
  });

  it('loads a map of icon refs', async () => {
    stubFetch({ body: refs });
    await loadIconMap('map-a.json');

    expect(Byond.iconRefMap).toEqual(refs);
    expect(store.get(iconMapStateAtom)).toEqual({
      url: 'map-a.json',
      status: 'ready',
    });
    expect(asked).toEqual([{ url: 'map-a.json', cache: 'default' }]);
  });

  it('loads a url once, however often it is asked for', async () => {
    stubFetch({ body: refs });
    const first = loadIconMap('map-b.json');
    const second = loadIconMap('map-b.json');
    expect(second).toBe(first);
    await first;

    await loadIconMap('map-b.json');
    expect(asked).toHaveLength(1);
  });

  it('turns down an answer that is not a map, and takes the next one', async () => {
    stubFetch(
      { body: { error: 'Not Found', message: 'gone' } },
      { body: refs },
    );
    const load = loadIconMap('map-c.json');
    await settle();
    expect(status()).toBe('loading');
    expect(Byond.iconRefMap).toEqual({});

    await wait(1_000);
    await load;
    expect(Byond.iconRefMap).toEqual(refs);
    // The second try doesn't trust the browser cache
    expect(asked.map((ask) => ask.cache)).toEqual(['default', 'reload']);
  });

  it('gives up on an answer that stalls, and tries again', async () => {
    stubFetch('stall', { body: refs });
    const load = loadIconMap('map-d.json');
    await wait(10_000);
    expect(asked).toHaveLength(1);

    await wait(1_000);
    await load;
    expect(status()).toBe('ready');
    expect(Byond.iconRefMap).toEqual(refs);
  });

  it('fails after three tries, and loads when asked to retry', async () => {
    stubFetch(
      { status: 503 },
      { status: 503 },
      { status: 503 },
      { body: refs },
    );
    const load = loadIconMap('map-e.json');
    await settle();
    await wait(1_000);
    await wait(3_000);
    await load;
    expect(status()).toBe('error');
    expect(asked).toHaveLength(3);
    expect(Byond.iconRefMap).toEqual({});

    retryIconMap();
    await settle();
    expect(status()).toBe('ready');
    expect(Byond.iconRefMap).toEqual(refs);
    // The retry skips the browser cache from its first try
    expect(asked[3].cache).toBe('reload');
  });

  it('does nothing on retry unless the load failed', async () => {
    stubFetch({ body: refs });
    await loadIconMap('map-f.json');

    retryIconMap();
    await settle();
    expect(asked).toHaveLength(1);
  });

  it('drops an older load when a newer url comes in', async () => {
    stubFetch('stall', { body: newerRefs });
    const older = loadIconMap('map-g.json');
    const newer = loadIconMap('map-h.json');
    await Promise.all([older, newer]);

    expect(Byond.iconRefMap).toEqual(newerRefs);
    expect(store.get(iconMapStateAtom)).toEqual({
      url: 'map-h.json',
      status: 'ready',
    });
  });
});
