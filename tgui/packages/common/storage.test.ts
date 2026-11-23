// THIS IS AN APHELION UI FILE
import { afterEach, describe, expect, it, jest, mock } from 'bun:test';
import { IFrameIndexedDbBackend, StorageProxy } from './storage';

type Reply = { value?: unknown; error?: string };

/**
 * A fake storage iframe window. It answers each `get` with what `answer`
 * returns, once that's ready, and counts every get and set.
 */
function fakeIframe(answer: (key: string) => Reply | Promise<Reply>) {
  const seen = { gets: 0, writes: [] as string[] };
  const frame = {
    seen,
    postMessage: async (message: { type: string; key: string }) => {
      if (message.type === 'set') seen.writes.push(message.key);
      if (message.type !== 'get') return;
      seen.gets++;
      const reply = await answer(message.key);
      window.dispatchEvent(
        new MessageEvent('message', {
          data: { key: message.key, ...reply },
          source: frame as unknown as Window,
        }),
      );
    },
  };
  return frame;
}

function backendOver(answer: (key: string) => Reply | Promise<Reply>) {
  const onReadTimeout = mock(() => {});
  const backend = new IFrameIndexedDbBackend(onReadTimeout);
  const frame = fakeIframe(answer);
  Object.assign(backend, { iframeWindow: frame });
  return { backend, seen: frame.seen, onReadTimeout };
}

/** Moves the fake clock past each read timeout until `read` settles */
async function timeOut<T>(read: Promise<T>): Promise<T> {
  let settled = false;
  read.then(() => {
    settled = true;
  });
  for (let round = 0; !settled && round < 10; round++) {
    jest.advanceTimersByTime(5000);
    for (let tick = 0; tick < 10; tick++) await Promise.resolve();
  }
  return read;
}

afterEach(() => {
  jest.useRealTimers();
});

describe('iframe storage reads', () => {
  it('does not save over a key while its read is still waiting', async () => {
    let answer: (reply: Reply) => void = () => {};
    const { backend, seen } = backendOver(
      () =>
        new Promise((resolve) => {
          answer = resolve;
        }),
    );

    const read = backend.get('panel-settings');
    await backend.set('panel-settings', { fontSize: 9 });
    expect(seen.writes).toEqual([]);

    answer({ value: { fontSize: 16 } });
    expect(await read).toEqual({ fontSize: 16 });
    await backend.set('panel-settings', { fontSize: 9 });
    expect(seen.writes).toEqual(['panel-settings']);
  });

  it('asks again when a read fails once', async () => {
    const { backend, seen, onReadTimeout } = backendOver(() =>
      seen.gets === 1
        ? { error: 'InvalidStateError' }
        : { value: { fontSize: 16 } },
    );

    expect(await backend.get('panel-settings')).toEqual({ fontSize: 16 });
    expect(seen.gets).toBe(2);
    expect(onReadTimeout).not.toHaveBeenCalled();
    await backend.set('panel-settings', {});
    expect(seen.writes).toEqual(['panel-settings']);
  });

  it('never saves over a key the store did not answer for, and warns once', async () => {
    jest.useFakeTimers();
    const { backend, seen, onReadTimeout } = backendOver(
      () => new Promise(() => {}),
    );

    expect(await timeOut(backend.get('panel-settings'))).toBeUndefined();
    expect(seen.gets).toBe(2);
    await backend.set('panel-settings', {});
    expect(seen.writes).toEqual([]);

    // after that, a store that's down only gets one try per read
    expect(await timeOut(backend.get('chat-state'))).toBeUndefined();
    expect(seen.gets).toBe(3);
    expect(onReadTimeout).toHaveBeenCalledTimes(1);
  });
});

describe('importing settings from byondstorage', () => {
  const byond = Byond as unknown as { storageCdn: string };
  const cdn = byond.storageCdn;
  const ready = IFrameIndexedDbBackend.prototype.ready;

  afterEach(() => {
    byond.storageCdn = cdn;
    IFrameIndexedDbBackend.prototype.ready = ready;
    Object.assign(window, { hubStorage: undefined });
  });

  /**
   * A proxy over an iframe store that answers like `answer`. byondstorage
   * holds another server's settings, left from when all servers shared it.
   */
  async function proxyOver(answer: (key: string) => Reply) {
    byond.storageCdn = 'https://cdn.invalid/iframe.html';
    Object.assign(window, {
      hubStorage: {
        getItem: (key: string) =>
          key === 'panel-settings' ? JSON.stringify({ fontSize: 9 }) : null,
        setItem: () => {},
        removeItem: () => {},
        clear: () => {},
      },
    });
    const frame = fakeIframe(answer);
    IFrameIndexedDbBackend.prototype.ready = async function (
      this: IFrameIndexedDbBackend,
    ) {
      Object.assign(this, { iframeWindow: frame });
      return true;
    };

    const proxy = new StorageProxy();
    const warnings: string[] = [];
    proxy.subscribe((diagnostic) => {
      if (diagnostic.level !== 'info') warnings.push(diagnostic.message);
    });
    // resolves once the backend is picked, and picking it runs the byondstorage import
    await proxy.getImpl();
    return { proxy, writes: frame.seen.writes, warnings };
  }

  it('does not import into a store that did not answer', async () => {
    const { writes, warnings } = await proxyOver(() => ({
      error: 'InvalidStateError',
    }));
    expect(writes).toEqual([]);
    expect(warnings).toHaveLength(1);
  });

  it('imports into a store that answered it is empty', async () => {
    const { writes, warnings } = await proxyOver(() => ({ value: undefined }));
    expect(writes).toEqual(['panel-settings', 'byondstorage-migrated']);
    expect(warnings).toEqual([]);
  });

  it('saves what the player picked over settings that did not load', async () => {
    const { proxy, writes } = await proxyOver(() => ({
      error: 'InvalidStateError',
    }));
    await proxy.get('panel-settings');
    await proxy.set('panel-settings', { fontSize: 9 });
    expect(writes).toEqual([]);

    await proxy.allowSaving('panel-settings');
    await proxy.set('panel-settings', { fontSize: 9 });
    expect(writes).toEqual(['panel-settings']);
  });
});
