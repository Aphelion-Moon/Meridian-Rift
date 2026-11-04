// THIS IS AN APHELION UI FILE
import { afterEach, expect, it, spyOn } from 'bun:test';
import { CyborgGalleryCache } from './gallery';
import type { CyborgGallery } from './types';

const catalog = [
  { id: 'drake', department: 'Engineering', skin: 'Drake' },
  { id: 'borgi', department: 'Cargo', skin: 'Borgi' },
];
const descriptor: CyborgGallery = {
  generation: 'one',
  catalog_url: '/catalog-one.json',
  department: 'Engineering',
  thumbnails_url: '/engineering-one.json',
};
const pending: {
  url: string;
  signal: AbortSignal;
  resolve: (response: Response) => void;
  reject: (error: Error) => void;
}[] = [];
let fetchSpy: ReturnType<typeof spyOn>;
function fixture() {
  fetchSpy = spyOn(globalThis, 'fetch').mockImplementation(
    ((url, options) =>
      new Promise<Response>((resolve, reject) => {
        pending.push({
          url: String(url),
          signal: options!.signal!,
          resolve,
          reject,
        });
      })) as typeof fetch,
  );
  return new CyborgGalleryCache();
}
const settle = async () => {
  for (let n = 0; n < 12; n++) await Promise.resolve();
};
function reply(url: string, value: unknown) {
  pending.find((request) => request.url === url)!.resolve(Response.json(value));
}
afterEach(() => {
  fetchSpy?.mockRestore();
  pending.length = 0;
});

it('fetches public metadata and one department in parallel, shares requests, and reuses round artwork', async () => {
  const cache = fixture();
  const first = cache.acquire(descriptor, () => {});
  const second = cache.acquire(descriptor, () => {});
  expect(pending.map((request) => request.url).sort()).toEqual([
    '/catalog-one.json',
    '/engineering-one.json',
  ]);
  reply('/catalog-one.json', catalog);
  reply('/engineering-one.json', {
    drake: { '2': 'exact-png', '4': 'east-png' },
  });
  await settle();
  expect(cache.read(descriptor).models[0].thumbnail_directions).toEqual({
    '2': 'exact-png',
    '4': 'east-png',
  });
  expect(cache.read(descriptor).models[1].thumbnail_directions).toBeUndefined();
  first();
  second();
  cache.acquire(descriptor, () => {})();
  expect(pending).toHaveLength(2);
  expect(cache.read(descriptor)).toMatchObject({
    loading: false,
    error: false,
  });
});

it('immediately hides denied resources and ignores a completion after its consumer closes', async () => {
  const cache = fixture();
  const release = cache.acquire(descriptor, () => {});
  release();
  expect(pending.every((request) => request.signal.aborted)).toBe(true);
  reply('/catalog-one.json', catalog);
  reply('/engineering-one.json', { drake: { '2': 'late-png' } });
  await settle();
  expect(cache.read()).toEqual({ models: [], loading: false, error: false });
  expect(cache.read(descriptor).models).toEqual([]);
  cache.acquire(descriptor, () => {})();
  expect(pending).toHaveLength(4);
});

it('replaces one generation and cannot publish an older fetch over the current catalog', async () => {
  const cache = fixture();
  const first = cache.acquire(descriptor, () => {});
  const next = { generation: 'two', catalog_url: '/catalog-two.json' };
  const second = cache.acquire(next, () => {});
  reply('/catalog-two.json', [
    { id: 'new', department: 'Medical', skin: 'New' },
  ]);
  reply('/catalog-one.json', catalog);
  reply('/engineering-one.json', { drake: { '2': 'stale' } });
  await settle();
  expect(cache.read(next).models.map((model) => model.id)).toEqual(['new']);
  expect(cache.read(descriptor).models).toEqual([]);
  first();
  second();
});

it('keeps metadata selectable after an image failure and retries only on request', async () => {
  const cache = fixture();
  const release = cache.acquire(descriptor, () => {});
  reply('/catalog-one.json', catalog);
  pending
    .find((request) => request.url === '/engineering-one.json')!
    .resolve(new Response('', { status: 503 }));
  await settle();
  expect(cache.read(descriptor)).toMatchObject({
    models: catalog,
    error: true,
    loading: false,
  });
  expect(pending).toHaveLength(2);
  cache.retry(descriptor);
  expect(pending).toHaveLength(3);
  pending[2].resolve(Response.json({ drake: { '2': 'retried' } }));
  await settle();
  expect(cache.read(descriptor).models[0].thumbnail_directions?.['2']).toBe(
    'retried',
  );
  expect(cache.read(descriptor).error).toBe(false);
  release();
});

it('switches departments without keeping an obsolete pending image request', async () => {
  const cache = fixture();
  const release = cache.acquire(descriptor, () => {});
  reply('/catalog-one.json', catalog);
  await settle();
  release();
  const cargo = {
    ...descriptor,
    department: 'Cargo',
    thumbnails_url: '/cargo-one.json',
  };
  const releaseCargo = cache.acquire(cargo, () => {});
  expect(pending[0].signal.aborted).toBe(true); // Original image request started first.
  reply('/engineering-one.json', { drake: { '2': 'obsolete' } });
  reply('/cargo-one.json', { borgi: { '2': 'cargo' } });
  await settle();
  expect(cache.read(cargo).models[0].thumbnail_directions).toBeUndefined();
  expect(cache.read(cargo).models[1].thumbnail_directions?.['2']).toBe('cargo');
  expect(
    pending.filter((request) => request.url === '/catalog-one.json'),
  ).toHaveLength(1);
  releaseCargo();
});

it('rejects malformed asset content without retrying forever or losing valid labels', async () => {
  const cache = fixture();
  const release = cache.acquire(descriptor, () => {});
  reply('/catalog-one.json', catalog);
  reply('/engineering-one.json', { drake: { '3': 17 } });
  await settle();
  expect(cache.read(descriptor)).toMatchObject({
    models: catalog,
    error: true,
  });
  expect(pending).toHaveLength(2);
  release();
});
