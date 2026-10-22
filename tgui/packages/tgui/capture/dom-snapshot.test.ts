// THIS IS AN APHELION UI FILE

import { expect, spyOn, test } from 'bun:test';
import {
  MAX_NODES,
  MAX_SIDE,
  MAX_SVG_CHARS,
  renderUiSnapshot,
  SnapshotRefusal,
  svgDataUrl,
  TOO_BIG,
} from './dom-snapshot';

const PREFIX = 'data:image/svg+xml;charset=utf-8,';

function box(text: string) {
  const node = document.createElement('div');
  node.textContent = text;
  return node;
}

/** What the renderer would decode, back out of the data URL */
const svgOf = (url: string) => decodeURIComponent(url.slice(PREFIX.length));

/** How a snapshot of this root ends - its refusal's line, failed or drawn - so no DOM node ever reaches expect() */
async function outcome(root: HTMLElement) {
  try {
    await renderUiSnapshot(root);
    return 'drawn';
  } catch (error) {
    return error instanceof SnapshotRefusal ? error.message : 'failed';
  }
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
    expect(() => svgDataUrl(box('Changelog'), 40, 20, length - 1)).toThrow(
      SnapshotRefusal,
    );
    expect(() => svgDataUrl(box('Changelog'), 40, 20, length - 1)).toThrow(
      TOO_BIG,
    );
    expect(encode.mock.calls.length).toBe(0);
  } finally {
    encode.mockRestore();
  }
});

test('the budget holds without being passed', () => {
  expect(() => svgDataUrl(box('x'.repeat(MAX_SVG_CHARS)), 40, 20)).toThrow(
    TOO_BIG,
  );
});

test('a window over the node or side limit is refused with the same line, and one with no size is not', async () => {
  const crowded = box('Changelog');
  for (let count = 0; count < MAX_NODES; count++) {
    crowded.appendChild(document.createElement('div'));
  }
  expect(await outcome(crowded)).toBe(TOO_BIG);
  const sides: [number, number][] = [
    [MAX_SIDE + 1, 300],
    [300, MAX_SIDE + 1],
  ];
  for (const [width, height] of sides) {
    const wide = box('Changelog');
    wide.getBoundingClientRect = () => ({ width, height }) as DOMRect;
    expect(await outcome(wide)).toBe(TOO_BIG);
  }
  // happy-dom lays nothing out, so this one has no size at all
  expect(await outcome(box('Changelog'))).toBe('failed');
});
