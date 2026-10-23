// THIS IS AN APHELION UI FILE

import {
  afterEach,
  beforeEach,
  expect,
  type Mock,
  spyOn,
  test,
} from 'bun:test';
import { act } from 'react';
import { configAtom, store } from '../events/store';
import type { Config } from '../events/types';
import {
  abortUiSnapshot,
  acknowledgeUiSnapshot,
  cancelUiSnapshot,
  requestUiSnapshot,
} from './controller';
import * as snapshot from './dom-snapshot';
import { say } from './strings';

/** Byond.sendMessage, typed as the window calls it, since spyOn takes its last overload */
let sent: Mock<(type: string, payload: object) => void>;
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

/** The words on screen, so no DOM node ever reaches expect() */
const shown = () => document.body.textContent ?? '';
/** Whether the overlay is up */
const overlayUp = () => document.querySelector('[role=dialog]') !== null;
/** The words on whatever has keyboard focus */
const focusedText = () => document.activeElement?.textContent ?? '';

/** A drawn snapshot laid out 400 by 200 on screen, since happy-dom lays nothing out */
function sized() {
  const canvas = document.createElement('canvas');
  canvas.width = 400;
  canvas.height = 200;
  canvas.getBoundingClientRect = () =>
    ({ x: 0, y: 0, width: 400, height: 200 }) as DOMRect;
  return canvas;
}

/** Asks for a snapshot and lets it draw, so its preview is up */
async function preview(nonce: string) {
  const { request } = await ask(nonce);
  await act(async () => {
    finish(sized());
    await request;
  });
}

/** Presses a key wherever the overlay's focus is, or on the given control */
function press(key: string, options: { shift?: boolean; on?: Element } = {}) {
  act(() => {
    (options.on ?? document.activeElement ?? document.body).dispatchEvent(
      new KeyboardEvent('keydown', {
        key,
        shiftKey: !!options.shift,
        bubbles: true,
        cancelable: true,
      }),
    );
  });
}

/** One of the overlay's buttons, by its words */
function button(words: string) {
  return [...document.querySelectorAll('[role=dialog] .Button')].find(
    (element) => element.textContent === words,
  ) as HTMLElement | undefined;
}

/** Drags on the preview between two points on screen, from a corner handle if one is named */
function drag(from: [number, number], to: [number, number], corner?: string) {
  const stage = document.querySelector('.BugReportCapture__stage')!;
  const start =
    (corner && stage.querySelector(`.BugReportCapture__handle--${corner}`)) ||
    stage;
  const at = ([clientX, clientY]: [number, number]) => ({
    clientX,
    clientY,
    pointerId: 1,
    bubbles: true,
    cancelable: true,
  });
  act(() => {
    start.dispatchEvent(new PointerEvent('pointerdown', at(from)));
    stage.dispatchEvent(new PointerEvent('pointermove', at(to)));
    stage.dispatchEvent(new PointerEvent('pointerup', at(to)));
  });
}

/** Lets the transfer's first chunk go, which waits on a timer */
const tick = () =>
  act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 5));
  });

beforeEach(() => {
  store.set(configAtom, {
    ...store.get(configAtom),
    interface: { name: 'Vending' } as Config['interface'],
  });
  sent = spyOn(Byond, 'sendMessage').mockImplementation(
    () => undefined,
  ) as Mock<(type: string, payload: object) => void>;
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
    throw new snapshot.SnapshotRefusal('too_big');
  });
  await act(async () => {
    await requestUiSnapshot({ nonce: 'second', chunk: 4, limit: 64 });
  });
  expect(sent.mock.calls).toEqual([
    ['bug-report/capture-ready', { nonce: 'second' }],
  ]);
  const text = shown();
  expect(text.includes(say('cap.too_big'))).toBe(true);
  expect(text.includes(say('ov.close'))).toBe(true);
  // There's nothing to preview, crop or attach
  expect(
    [say('ov.text'), say('ov.add'), say('ov.clear'), say('ov.keys')].filter(
      (line) => text.includes(line),
    ),
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
    ['bug-report/capture-cancel', { nonce: 'fifth', reason: 'busy' }],
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
    ['bug-report/capture-cancel', { nonce: 'fifth', reason: 'busy' }],
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
    ['bug-report/capture-cancel', { nonce: 'too soon', reason: 'busy' }],
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
    [
      'bug-report/capture-cancel',
      { nonce: 'while slow draws', reason: 'busy' },
    ],
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

test('the report window itself, or a window with no interface, is not allowed', async () => {
  for (const name of ['BugReport', '']) {
    store.set(configAtom, {
      ...store.get(configAtom),
      interface: { name } as Config['interface'],
    });
    await ask(`not ${name}`);
  }
  expect(render.mock.calls.length).toBe(0);
  expect(sent.mock.calls).toEqual([
    [
      'bug-report/capture-cancel',
      { nonce: 'not BugReport', reason: 'not_allowed' },
    ],
    ['bug-report/capture-cancel', { nonce: 'not ', reason: 'not_allowed' }],
  ]);
});

test('each failed drawing says why in its own words, and closing it tells the server that reason', async () => {
  const failures: [unknown, string][] = [
    [new snapshot.SnapshotRefusal('too_big'), 'too_big'],
    [new snapshot.SnapshotRefusal('empty'), 'empty'],
    [new snapshot.SnapshotRefusal('timed_out'), 'timed_out'],
    [new Error('The source image cannot be decoded.'), 'failed'],
  ];
  const seen: string[] = [];
  for (const [failure, reason] of failures) {
    render.mockImplementation(async () => {
      throw failure;
    });
    await act(async () => {
      await requestUiSnapshot({ nonce: reason, chunk: 4, limit: 64 });
    });
    const line = say(`cap.${reason}` as Parameters<typeof say>[0]);
    seen.push(
      `${reason}: ${shown().includes(line)} ${shown().includes('cannot be decoded')} ${focusedText()}`,
    );
    press('Escape');
    seen.push(`${reason} after Esc: ${overlayUp()}`);
  }
  expect(seen).toEqual(
    failures.flatMap(([, reason]) => [
      `${reason}: true false ${say('ov.close')}`,
      `${reason} after Esc: false`,
    ]),
  );
  expect(
    sent.mock.calls.filter(([type]) => type === 'bug-report/capture-cancel'),
  ).toEqual(
    failures.map(([, reason]) => [
      'bug-report/capture-cancel',
      { nonce: reason, reason },
    ]),
  );
});

test('the preview opens on Add to report with one live region, Tab stays inside, and Esc cancels', async () => {
  await preview('keys');
  const before = [
    focusedText(),
    String(document.querySelectorAll('[role=dialog] [role=status]').length),
    String(shown().includes(say('ov.keys'))),
  ];
  press('Tab');
  const forward = focusedText();
  press('Tab', { shift: true });
  const back = focusedText();
  press('Escape');
  expect([...before, forward, back, String(overlayUp())]).toEqual([
    say('ov.add'),
    '1',
    'true',
    say('ov.cancel'),
    say('ov.add'),
    'false',
  ]);
  expect(sent.mock.calls.at(-1)).toEqual([
    'bug-report/capture-cancel',
    { nonce: 'keys', reason: 'cancelled' },
  ]);
});

test('Enter on a focused Cancel cancels rather than adds', async () => {
  const encode = spyOn(snapshot, 'encodeSnapshot');
  try {
    await preview('cancel key');
    const cancel = button(say('ov.cancel'))!;
    act(() => cancel.focus());
    press('Enter', { on: cancel });
    expect(encode.mock.calls.length).toBe(0);
  } finally {
    encode.mockRestore();
  }
  expect(overlayUp()).toBe(false);
  expect(sent.mock.calls.at(-1)).toEqual([
    'bug-report/capture-cancel',
    { nonce: 'cancel key', reason: 'cancelled' },
  ]);
});

test('Clear crop shows only while there is a crop, a corner handle resizes it, and Enter sends that crop', async () => {
  const encode = spyOn(snapshot, 'encodeSnapshot').mockImplementation(
    () => new Promise(() => undefined),
  );
  const steps: string[] = [];
  const clear = () => String(shown().includes(say('ov.clear')));
  try {
    await preview('crop');
    steps.push(clear());
    // A slip of the mouse
    drag([100, 50], [104, 150]);
    steps.push(clear());
    drag([100, 50], [300, 150]);
    steps.push(clear());
    act(() => button(say('ov.clear'))!.click());
    steps.push(clear(), focusedText());
    drag([300, 150], [100, 50]);
    drag([300, 150], [400, 200], 'se');
    press('Enter');
    steps.push(shown().includes(say('ov.preparing')) ? 'preparing' : 'idle');
    expect(encode.mock.calls.map((call) => call[2])).toEqual([
      { x: 0.25, y: 0.25, width: 0.75, height: 0.75 },
    ]);
  } finally {
    encode.mockRestore();
  }
  expect(steps).toEqual([
    'false',
    'false',
    'true',
    'false',
    say('ov.add'),
    'preparing',
  ]);
});

test('Enter adds it, sends it with its progress, and the overlay closes once the report window comes forward', async () => {
  const encode = spyOn(snapshot, 'encodeSnapshot').mockResolvedValue(
    'AAAABBBB',
  );
  try {
    await preview('forward');
    press('Enter');
    await tick();
    expect(sent.mock.calls.at(-1)?.[0]).toBe('bug-report/capture-chunk');
    act(() => acknowledgeUiSnapshot({ nonce: 'forward', index: 0 }));
    expect(shown().includes(say('ov.sending', { n: 50 }))).toBe(true);
    act(() =>
      acknowledgeUiSnapshot({ nonce: 'forward', index: 1, forward: 1 }),
    );
    expect(overlayUp()).toBe(false);
  } finally {
    encode.mockRestore();
  }
  expect(
    sent.mock.calls.filter(([type]) => type === 'bug-report/capture-cancel'),
  ).toEqual([]);
});

test('with no report window to come forward, it says where the picture went, and closing sends nothing', async () => {
  const encode = spyOn(snapshot, 'encodeSnapshot').mockResolvedValue(
    'AAAABBBB',
  );
  try {
    await preview('no window');
    press('Enter');
    await tick();
    act(() => acknowledgeUiSnapshot({ nonce: 'no window', index: 0 }));
    act(() =>
      acknowledgeUiSnapshot({ nonce: 'no window', index: 1, forward: 0 }),
    );
    expect([shown().includes(say('ov.sent')), focusedText()]).toEqual([
      true,
      say('ov.close'),
    ]);
    press('Escape');
    expect(overlayUp()).toBe(false);
  } finally {
    encode.mockRestore();
  }
  expect(
    sent.mock.calls.filter(([type]) => type === 'bug-report/capture-cancel'),
  ).toEqual([]);
});

test('a crop too big to send stays on the preview and says so', async () => {
  const encode = spyOn(snapshot, 'encodeSnapshot').mockRejectedValue(
    new snapshot.SnapshotRefusal('too_big'),
  );
  try {
    await preview('too big');
    press('Enter');
    await tick();
  } finally {
    encode.mockRestore();
  }
  expect([
    shown().includes(say('ov.tooBigCrop')),
    shown().includes(say('ov.add')),
    overlayUp(),
  ]).toEqual([true, true, true]);
});
