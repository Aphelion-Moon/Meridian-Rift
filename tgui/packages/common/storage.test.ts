// THIS IS AN APHELION UI FILE
import { afterEach, describe, expect, it, mock } from 'bun:test';
import { IFrameIndexedDbBackend, StorageProxy } from './storage';

type Reply = { value?: unknown; error?: string } | null;

/**
 * A storage iframe's window that answers each `get` as `answer` says: a value,
 * an error, or nothing at all (null) for one that never replies.
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
    expect(backend.read('panel-settings')).rejects.toThrow();
  });

  it('fails when the store does not answer in time', async () => {
    const backend = backendWith(() => null);
    expect(backend.read('panel-settings')).rejects.toThrow();
  });

  it('still gives undefined from get when the read fails', async () => {
    const backend = backendWith(() => null);
    expect(await backend.get('geometries')).toBeUndefined();
  });
});

describe('importing settings from byondstorage', () => {
  const byond = Byond as unknown as { storageCdn: string };
  const cdn = byond.storageCdn;

  afterEach(() => {
    byond.storageCdn = cdn;
    Object.assign(window, { hubStorage: undefined });
  });

  /** A proxy over an iframe store that answers reads as `read` does. */
  async function proxyOver(read: (key: string) => Promise<unknown>) {
    byond.storageCdn = 'https://cdn.invalid/iframe.html';
    // Another server's settings, from when every server shared byondstorage.
    Object.assign(window, {
      hubStorage: {
        getItem: (key: string) =>
          key === 'panel-settings'
            ? JSON.stringify({ fontSize: 9, theme: 'light' })
            : null,
        setItem: () => {},
        removeItem: () => {},
        clear: () => {},
      },
    });
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
    // Any call waits for the backend to be chosen, the import included.
    await proxy.get('anything');
    return { proxy, writes };
  }

  it('does not copy byondstorage over iframe data it could not read', async () => {
    const { proxy, writes } = await proxyOver(() =>
      Promise.reject(new Error('storage did not answer')),
    );
    expect(writes).toEqual([]);
    expect(proxy.diagnostics.some((entry) => entry.level !== 'info')).toBe(
      true,
    );
  });

  it('still imports byondstorage into an iframe store that is really empty', async () => {
    const { writes } = await proxyOver(async () => undefined);
    expect(writes).toEqual(['panel-settings', 'byondstorage-migrated']);
  });
});
