// THIS IS AN APHELION UI FILE
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
  mock,
} from 'bun:test';
import { store } from './events/store';
import { iconMapStateAtom, loadIconMap, retryIconMap } from './iconMap';

const originalFetch = globalThis.fetch;
const valid = { 'icons/test.dmi': '[0x123]' };
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
async function flush() {
  for (let index = 0; index < 30; index++) await Promise.resolve();
}
async function tick(ms: number) {
  jest.advanceTimersByTime(ms);
  await flush();
}

beforeEach(() => {
  jest.useFakeTimers();
  Byond.iconRefMap = {};
  store.set(iconMapStateAtom, { status: 'idle' });
});
afterEach(() => {
  globalThis.fetch = originalFetch;
  jest.useRealTimers();
});

describe('icon reference map delivery', () => {
  it('retries HTTP failure and commits a valid map', async () => {
    const fetcher = mock()
      .mockResolvedValueOnce(reply({}, 503))
      .mockResolvedValueOnce(reply(valid));
    globalThis.fetch = fetcher as unknown as typeof fetch;
    const pending = loadIconMap('https://assets.test/http.json');
    await flush();
    expect(Byond.iconRefMap).toEqual({});
    await tick(1_000);
    await pending;
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(Byond.iconRefMap).toEqual(valid);
    expect(store.get(iconMapStateAtom).status).toBe('ready');
  });

  it('retries both invalid JSON and invalid map shape', async () => {
    const fetcher = mock()
      .mockResolvedValueOnce(new Response('<html>error</html>'))
      .mockResolvedValueOnce(reply({ icon: null }))
      .mockResolvedValueOnce(reply(valid));
    globalThis.fetch = fetcher as unknown as typeof fetch;
    const pending = loadIconMap('https://assets.test/json.json');
    await flush();
    await tick(1_000);
    await tick(3_000);
    await pending;
    expect(fetcher).toHaveBeenCalledTimes(3);
    expect(Byond.iconRefMap).toEqual(valid);
  });

  it('stops after three failures and permits a later manual retry', async () => {
    const fetcher = mock().mockRejectedValue(new TypeError('Network error'));
    globalThis.fetch = fetcher as unknown as typeof fetch;
    const pending = loadIconMap('https://assets.test/retry.json');
    await flush();
    await tick(1_000);
    await tick(3_000);
    await pending;
    expect(fetcher).toHaveBeenCalledTimes(3);
    expect(store.get(iconMapStateAtom).status).toBe('error');
    fetcher.mockResolvedValue(reply(valid));
    retryIconMap();
    await flush();
    expect(store.get(iconMapStateAtom).status).toBe('ready');
  });

  it('aborts a hung attempt and retries it', async () => {
    const fetcher = mock()
      .mockImplementationOnce(
        (_url: string, options: RequestInit) =>
          new Promise((_resolve, reject) => {
            options.signal?.addEventListener('abort', () =>
              reject(new Error('Timed out')),
            );
          }),
      )
      .mockResolvedValueOnce(reply(valid));
    globalThis.fetch = fetcher as unknown as typeof fetch;
    const pending = loadIconMap('https://assets.test/timeout.json');
    await tick(10_000);
    await tick(1_000);
    await pending;
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(store.get(iconMapStateAtom).status).toBe('ready');
  });

  it('shares in-flight requests and does not fetch an already loaded URL again', async () => {
    const fetcher = mock().mockResolvedValue(reply(valid));
    globalThis.fetch = fetcher as unknown as typeof fetch;
    const first = loadIconMap('https://assets.test/single.json');
    expect(loadIconMap('https://assets.test/single.json')).toBe(first);
    await first;
    await loadIconMap('https://assets.test/single.json');
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('never lets a late old response overwrite a newer map', async () => {
    let resolveOld!: (response: Response) => void;
    const fetcher = mock()
      .mockImplementationOnce(
        () =>
          new Promise((resolve) => {
            resolveOld = resolve;
          }),
      )
      .mockResolvedValueOnce(reply({ 'icons/new.dmi': '[0x456]' }));
    globalThis.fetch = fetcher as unknown as typeof fetch;
    const old = loadIconMap('https://assets.test/old.json');
    await loadIconMap('https://assets.test/new.json');
    resolveOld(reply(valid));
    await old;
    expect(Byond.iconRefMap).toEqual({ 'icons/new.dmi': '[0x456]' });
    expect(store.get(iconMapStateAtom).url).toBe(
      'https://assets.test/new.json',
    );
  });
});
