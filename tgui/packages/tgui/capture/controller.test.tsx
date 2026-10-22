// THIS IS AN APHELION UI FILE

import { afterEach, beforeEach, expect, spyOn, test } from 'bun:test';
import { act } from 'react';
import { configAtom, store } from '../events/store';
import type { Config } from '../events/types';
import {
  abortUiSnapshot,
  cancelUiSnapshot,
  requestUiSnapshot,
} from './controller';
import * as snapshot from './dom-snapshot';
import * as topic from './topic';

let sent: ReturnType<typeof spyOn<typeof topic, 'sendLargeMessage'>>;
let render: ReturnType<typeof spyOn<typeof snapshot, 'renderUiSnapshot'>>;
/** Finishes the snapshot the window is drawing */
let finish: (canvas: HTMLCanvasElement) => void;

/** Asks this window for a snapshot, leaving it drawing until finish() */
async function ask(nonce: string) {
  let request: Promise<void> | undefined;
  await act(async () => {
    request = requestUiSnapshot({ nonce, chunk: 4, limit: 64 });
  });
  // Wrapped, since an async function would wait on the request it returns
  return { request: request! };
}

beforeEach(() => {
  store.set(configAtom, {
    ...store.get(configAtom),
    interface: { name: 'Vending' } as Config['interface'],
  });
  sent = spyOn(topic, 'sendLargeMessage').mockImplementation(() => undefined);
  render = spyOn(snapshot, 'renderUiSnapshot').mockImplementation(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      }),
  );
});

afterEach(() => {
  act(() => cancelUiSnapshot());
  sent.mockRestore();
  render.mockRestore();
});

test('the window says it is ready once its preview is up, and not before', async () => {
  const { request } = await ask('first');
  // Still drawing, which is where a renderer that runs out of memory stops for good
  expect(sent.mock.calls.length).toBe(0);
  await act(async () => {
    finish(document.createElement('canvas'));
    await request;
  });
  expect(sent.mock.calls).toEqual([
    ['bug-report/capture-ready', { nonce: 'first' }],
  ]);
});

test('a refused snapshot shows only its own line and Close, and the window still says it is ready', async () => {
  render.mockImplementation(async () => {
    throw new snapshot.SnapshotRefusal(snapshot.TOO_BIG);
  });
  await act(async () => {
    await requestUiSnapshot({ nonce: 'second', chunk: 4, limit: 64 });
  });
  expect(sent.mock.calls).toEqual([
    ['bug-report/capture-ready', { nonce: 'second' }],
  ]);
  const text = document.body.textContent ?? '';
  expect(text.includes(snapshot.TOO_BIG)).toBe(true);
  expect(text.includes('Close')).toBe(true);
  // There's nothing to preview, crop or attach
  expect(
    [
      'Could not create this UI snapshot',
      'Preview this UI snapshot',
      'Drag a rectangle',
      'Attach snapshot',
      'Use whole snapshot',
    ].filter((line) => text.includes(line)),
  ).toEqual([]);
});

test('a capture the server ended while it was drawing sends nothing', async () => {
  const { request } = await ask('third');
  abortUiSnapshot({ nonce: 'third' });
  await act(async () => {
    finish(document.createElement('canvas'));
    await request;
  });
  expect(sent.mock.calls.length).toBe(0);
});

test('a retry while an ended capture is still drawing is refused, so the window draws one snapshot at a time', async () => {
  const { request } = await ask('fourth');
  // The server gave up on it, but nothing stops a drawing once it starts
  abortUiSnapshot({ nonce: 'fourth' });
  await ask('fifth');
  expect(render.mock.calls.length).toBe(1);
  expect(sent.mock.calls).toEqual([
    ['bug-report/capture-cancel', { nonce: 'fifth' }],
  ]);
  await act(async () => {
    finish(document.createElement('canvas'));
    await request;
  });
  const { request: next } = await ask('sixth');
  await act(async () => {
    finish(document.createElement('canvas'));
    await next;
  });
  expect(render.mock.calls.length).toBe(2);
  expect(sent.mock.calls).toEqual([
    ['bug-report/capture-cancel', { nonce: 'fifth' }],
    ['bug-report/capture-ready', { nonce: 'sixth' }],
  ]);
});

test('a drawing that never settles stops holding the window at the deadline', async () => {
  let now = 1000000;
  const clock = spyOn(performance, 'now').mockImplementation(() => now);
  try {
    // The server gives up when no ready comes, but this render never finishes
    await ask('stuck');
    abortUiSnapshot({ nonce: 'stuck' });
    now += 169999;
    await ask('too soon');
    now += 1;
    const { request } = await ask('at the deadline');
    await act(async () => {
      finish(document.createElement('canvas'));
      await request;
    });
  } finally {
    clock.mockRestore();
  }
  expect(render.mock.calls.length).toBe(2);
  expect(sent.mock.calls).toEqual([
    ['bug-report/capture-cancel', { nonce: 'too soon' }],
    ['bug-report/capture-ready', { nonce: 'at the deadline' }],
  ]);
});

test('a stuck drawing that finishes late leaves the window to the one drawing now', async () => {
  let now = 1000000;
  const clock = spyOn(performance, 'now').mockImplementation(() => now);
  try {
    const { request: stuck } = await ask('stuck');
    const finishStuck = finish;
    abortUiSnapshot({ nonce: 'stuck' });
    now += 170000;
    const { request: slow } = await ask('slow');
    const finishSlow = finish;
    abortUiSnapshot({ nonce: 'slow' });
    await act(async () => {
      finishStuck(document.createElement('canvas'));
      await stuck;
    });
    await ask('while slow draws');
    await act(async () => {
      finishSlow(document.createElement('canvas'));
      await slow;
    });
  } finally {
    clock.mockRestore();
  }
  expect(render.mock.calls.length).toBe(2);
  expect(sent.mock.calls).toEqual([
    ['bug-report/capture-cancel', { nonce: 'while slow draws' }],
  ]);
});

test('a stuck drawing that finishes late while a newer one draws sends nothing, and the newer one still says ready', async () => {
  let now = 1000000;
  const clock = spyOn(performance, 'now').mockImplementation(() => now);
  try {
    const { request: stuck } = await ask('stuck');
    const finishStuck = finish;
    abortUiSnapshot({ nonce: 'stuck' });
    now += 170000;
    // Not aborted, so this one is the window's capture when the stuck one settles
    const { request: live } = await ask('live');
    const finishLive = finish;
    await act(async () => {
      finishStuck(document.createElement('canvas'));
      await stuck;
    });
    expect(sent.mock.calls.length).toBe(0);
    await act(async () => {
      finishLive(document.createElement('canvas'));
      await live;
    });
  } finally {
    clock.mockRestore();
  }
  expect(render.mock.calls.length).toBe(2);
  expect(sent.mock.calls).toEqual([
    ['bug-report/capture-ready', { nonce: 'live' }],
  ]);
});
