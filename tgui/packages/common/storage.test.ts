// THIS IS AN APHELION UI FILE
import { afterEach, describe, expect, it, mock } from 'bun:test';
import { IFrameIndexedDbBackend, StorageProxy } from './storage';

type Reply = { value?: unknown; error?: string } | null;

/**
 * A storage iframe window that answers each `get` with what `answer` gives: a
 * value, an error, or nothing (null) for an iframe that never answers.
 */
function fakeIframe(answer: (key: string) => Reply) {
  const frame = {
    postMessage: (message: { type: string; key: string }) => {
      if (message.type !== 'get') return;
      const reply = answer(message.key);
      if (!reply) return;
      setTimeout(() =>
        window.dispatchEvent(
          new MessageEvent('message', {
            data: { key: message.key, ...reply },
            source: frame as unknown as Window,
          }),
        ),
      );
    },
  };
  return frame;
}

function backendWith(answer: (key: string) => Reply) {
  const backend = new IFrameIndexedDbBackend(30);
  Object.assign(backend, { iframeWindow: fakeIframe(answer) });
  return backend;
}

describe('iframe storage reads', () => {
  it('gives what is stored', async () => {
    const backend = backendWith(() => ({ value: { fontSize: 16 } }));
    expect(await backend.read('panel-settings')).toEqual({ fontSize: 16 });
  });

  it('gives undefined when nothing is stored', async () => {
    const backend = backendWith(() => ({ value: undefined }));
    expect(await backend.read('panel-settings')).toBeUndefined();
  });

  it('fails when the store reports an error', async () => {
    const backend = backendWith(() => ({ error: 'InvalidStateError' }));
    await expect(backend.read('panel-settings')).rejects.toThrow();
  });

  it('fails when the store does not answer in time', async () => {
    const backend = backendWith(() => null);
    await expect(backend.read('panel-settings')).rejects.toThrow();
  });

  it('still gives undefined from get when the read fails', async () => {
    const backend = backendWith(() => null);
    expect(await backend.get('geometries')).toBeUndefined();
  });
});

const byond = Byond as unknown as { storageCdn: string };
const cdn = byond.storageCdn;

/** A byondstorage that holds `stored` under panel-settings and nothing else. */
function stubHubStorage(stored: string) {
  Object.assign(window, {
    hubStorage: {
      getItem: (key: string) => (key === 'panel-settings' ? stored : null),
      setItem: () => {},
      removeItem: () => {},
      clear: () => {},
    },
  });
}

/** A proxy over an iframe store whose reads answer like `read`. */
async function proxyOver(read: (key: string) => Promise<unknown>) {
  byond.storageCdn = 'https://cdn.invalid/iframe.html';
  // Another server's settings, from when all servers shared byondstorage.
  stubHubStorage(JSON.stringify({ fontSize: 9, theme: 'light' }));
  const writes: string[] = [];
  const iframe = {
    impl: 2,
    ready: async () => true,
    read,
    get: (key: string) => read(key).catch(() => undefined),
    set: mock(async (key: string) => {
      writes.push(key);
    }),
    remove: async () => {},
    clear: async () => {},
    destroy: async () => {},
  };
  const proxy = new StorageProxy(
    () => iframe as unknown as IFrameIndexedDbBackend,
  );
  // Any call waits until the backend is picked, which includes the import.
  await proxy.get('anything');
  return { proxy, writes };
}

afterEach(() => {
  byond.storageCdn = cdn;
  Object.assign(window, { hubStorage: undefined });
});

describe('importing settings from byondstorage', () => {
  it('does not copy byondstorage over iframe data it could not read', async () => {
    const { proxy, writes } = await proxyOver(() =>
      Promise.reject(new Error('storage did not answer')),
    );
    expect(writes).toEqual([]);
    expect(
      proxy.diagnostics.some((entry) =>
        entry.message.includes('nothing was imported'),
      ),
    ).toBe(true);
    // Nothing the player has to read in chat.
    expect(proxy.diagnostics.every((entry) => entry.level === 'info')).toBe(
      true,
    );
  });

  it('still imports byondstorage into an iframe store that is really empty', async () => {
    const { writes } = await proxyOver(async () => undefined);
    expect(writes).toEqual(['panel-settings', 'byondstorage-migrated']);
  });
});

describe('storage reads', () => {
  /**
   * A proxy over a store that holds a font size. Once `store.failing` is set,
   * that many of its next reads fail.
   */
  async function proxyOverFlakyStore() {
    const store = { failing: 0 };
    const read = mock(async (key: string) => {
      if (store.failing > 0) {
        store.failing--;
        throw new Error('storage did not answer');
      }
      return key === 'panel-settings' ? { fontSize: 16 } : undefined;
    });
    const { proxy } = await proxyOver(read);
    read.mockClear();
    return { proxy, read, store };
  }

  it('asks again when a read fails once', async () => {
    const { proxy, read, store } = await proxyOverFlakyStore();
    store.failing = 1;

    expect(await proxy.read('panel-settings')).toEqual({ fontSize: 16 });
    expect(read).toHaveBeenCalledTimes(2);
  });

  it('fails when the second try fails too, and asks once from then on', async () => {
    const { proxy, read, store } = await proxyOverFlakyStore();
    store.failing = 3;

    await expect(proxy.read('panel-settings')).rejects.toThrow();
    expect(read).toHaveBeenCalledTimes(2);

    await expect(proxy.read('chat-state')).rejects.toThrow();
    expect(read).toHaveBeenCalledTimes(3);
  });

  it('counts a byondstorage value that does not parse as nothing saved', async () => {
    byond.storageCdn = '';
    stubHubStorage('{"fontSize": 16');
    const proxy = new StorageProxy();

    expect(await proxy.read('panel-settings')).toBeUndefined();
  });
});
