// THIS IS AN APHELION UI FILE

import { expect, spyOn, test } from 'bun:test';
import {
  MAX_NODES,
  MAX_SIDE,
  MAX_SVG_CHARS,
  renderUiSnapshot,
  SnapshotRefusal,
  svgDataUrl,
} from './dom-snapshot';
import * as cloning from './vendor/clone-node';

const PREFIX = 'data:image/svg+xml;charset=utf-8,';

function box(text: string) {
  const node = document.createElement('div');
  node.textContent = text;
  return node;
}

/** What the renderer would decode, back out of the data URL */
const svgOf = (url: string) => decodeURIComponent(url.slice(PREFIX.length));

/** How a snapshot of this root ends - its refusal's reason, failed or drawn - so no DOM node ever reaches expect() */
async function outcome(root: HTMLElement) {
  try {
    await renderUiSnapshot(root);
    return 'drawn';
  } catch (error) {
    return error instanceof SnapshotRefusal ? error.reason : 'failed';
  }
}

/** The reason a build was refused, 'none' if it wasn't, or 'failed' for any other error */
function refusal(build: () => unknown) {
  try {
    build();
    return 'none';
  } catch (error) {
    return error instanceof SnapshotRefusal ? error.reason : 'failed';
  }
}

/** A window with two boxes scrolled down, sized by hand since happy-dom lays nothing out */
function scrolledWindow() {
  const root = box('');
  root.getBoundingClientRect = () => ({ width: 300, height: 200 }) as DOMRect;
  for (const id of ['first', 'second']) {
    const pane = box(id);
    pane.id = id;
    pane.scrollTop = 50;
    root.appendChild(pane);
  }
  return root;
}

/** Which boxes a clone shifted by their scroll offsets */
const shifted = (clone: HTMLElement) =>
  ['first', 'second'].filter((id) =>
    clone
      .querySelector(`#${id}`)
      ?.firstElementChild?.getAttribute('style')
      ?.includes('translate'),
  );

/** How many boxes in the live window still carry a snapshot's scroll mark */
const marked = (root: HTMLElement) =>
  root.querySelectorAll('[data-meridian-report-scroll]').length;

/** Stands in for html-to-image's clone, each call answered by the next of these in turn */
function cloneBy(...answers: ((node: HTMLElement) => Promise<HTMLElement>)[]) {
  const spy = spyOn(cloning, 'cloneNode');
  for (const answer of answers) {
    spy.mockImplementationOnce(answer as unknown as typeof cloning.cloneNode);
  }
  return spy;
}

test('a snapshot under the budget becomes its SVG as a data URL', () => {
  const url = svgDataUrl(box('Changelog'), 40, 20);
  expect(url.startsWith(PREFIX)).toBe(true);
  const svg = svgOf(url);
  expect(svg.includes('viewBox="0 0 40 20"')).toBe(true);
  expect(svg.includes('Changelog')).toBe(true);
});

test('a snapshot exactly at the budget is built, and one character over it is refused before its URL', () => {
  const length = svgOf(svgDataUrl(box('Changelog'), 40, 20)).length;
  expect(svgOf(svgDataUrl(box('Changelog'), 40, 20, length)).length).toBe(
    length,
  );
  const encode = spyOn(globalThis, 'encodeURIComponent');
  try {
    expect(
      refusal(() => svgDataUrl(box('Changelog'), 40, 20, length - 1)),
    ).toBe('too_big');
    expect(encode.mock.calls.length).toBe(0);
  } finally {
    encode.mockRestore();
  }
});

test('the budget holds without being passed', () => {
  expect(
    refusal(() => svgDataUrl(box('x'.repeat(MAX_SVG_CHARS)), 40, 20)),
  ).toBe('too_big');
});

test('a window over the node or side limit is refused as too big, and one with no size as empty', async () => {
  const crowded = box('Changelog');
  for (let count = 0; count < MAX_NODES; count++) {
    crowded.appendChild(document.createElement('div'));
  }
  expect(await outcome(crowded)).toBe('too_big');
  const sides: [number, number][] = [
    [MAX_SIDE + 1, 300],
    [300, MAX_SIDE + 1],
  ];
  for (const [width, height] of sides) {
    const wide = box('Changelog');
    wide.getBoundingClientRect = () => ({ width, height }) as DOMRect;
    expect(await outcome(wide)).toBe('too_big');
  }
  // happy-dom lays nothing out, so this one has no size at all
  expect(await outcome(box('Changelog'))).toBe('empty');
});

test("a stuck snapshot's scroll marks never move another box in the next one", async () => {
  const root = scrolledWindow();
  let finishStuck: (clone: HTMLElement) => void = () => undefined;
  let next: HTMLElement | undefined;
  const clone = cloneBy(
    () =>
      new Promise((resolve) => {
        finishStuck = resolve;
      }),
    async (node) => {
      next = node.cloneNode(true) as HTMLElement;
      return next;
    },
  );
  try {
    const stuck = outcome(root);
    // Only the second box is still scrolled when the next snapshot starts
    root.querySelector<HTMLElement>('#first')!.scrollTop = 0;
    await outcome(root);
    expect(shifted(next!)).toEqual(['second']);
    finishStuck(root.cloneNode(true) as HTMLElement);
    await stuck;
  } finally {
    clone.mockRestore();
  }
  expect(marked(root)).toBe(0);
});

test('a stuck snapshot that ends while the next one clones leaves that one its scroll marks', async () => {
  const root = scrolledWindow();
  let finishStuck: (clone: HTMLElement) => void = () => undefined;
  let stuck: Promise<string> | undefined;
  let next: HTMLElement | undefined;
  const clone = cloneBy(
    () =>
      new Promise((resolve) => {
        finishStuck = resolve;
      }),
    async (node) => {
      // As a clone waiting on a canvas would, this one lets the stuck snapshot end partway
      finishStuck(node.cloneNode(true) as HTMLElement);
      await stuck;
      next = node.cloneNode(true) as HTMLElement;
      return next;
    },
  );
  try {
    stuck = outcome(root);
    await outcome(root);
  } finally {
    clone.mockRestore();
  }
  expect(shifted(next!)).toEqual(['first', 'second']);
  expect(marked(root)).toBe(0);
});

test('a snapshot the renderer cannot decode is refused instead of drawing forever', async () => {
  const root = scrolledWindow();
  const clone = cloneBy(async (node) => node.cloneNode(true) as HTMLElement);
  const decode = spyOn(HTMLImageElement.prototype, 'decode').mockImplementation(
    () =>
      Promise.reject(
        new DOMException(
          'The source image cannot be decoded.',
          'EncodingError',
        ),
      ),
  );
  try {
    // A drawing still going after a second is one that would never end
    const ended = await Promise.race([
      outcome(root),
      new Promise((resolve) => setTimeout(resolve, 1000, 'still drawing')),
    ]);
    expect(ended).toBe('too_big');
  } finally {
    clone.mockRestore();
    decode.mockRestore();
  }
  expect(marked(root)).toBe(0);
});
