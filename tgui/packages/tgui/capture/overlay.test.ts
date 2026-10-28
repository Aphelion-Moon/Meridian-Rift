// THIS IS AN APHELION UI FILE

import { expect, test } from 'bun:test';
import { SnapshotRefusal } from './dom-snapshot';
import {
  CORNERS,
  cropBetween,
  isSlip,
  keyAction,
  nextFocus,
  pivotFor,
  reasonOf,
} from './overlay';

test('a drag makes the same box whichever way it goes', () => {
  const box = { x: 0.25, y: 0.5, width: 0.5, height: 0.25 };
  const corners = [
    [
      { x: 0.25, y: 0.5 },
      { x: 0.75, y: 0.75 },
    ],
    [
      { x: 0.75, y: 0.75 },
      { x: 0.25, y: 0.5 },
    ],
    [
      { x: 0.75, y: 0.5 },
      { x: 0.25, y: 0.75 },
    ],
    [
      { x: 0.25, y: 0.75 },
      { x: 0.75, y: 0.5 },
    ],
  ];
  for (const [start, end] of corners) {
    expect(cropBetween(start, end)).toEqual(box);
  }
});

test('a box under 8 screen pixels either way is a slip, and 8 is a crop', () => {
  // A 400 by 200 preview, so 8 pixels is 0.02 across and 0.04 down
  expect(isSlip({ x: 0, y: 0, width: 0.0199, height: 0.5 }, 400, 200)).toBe(
    true,
  );
  expect(isSlip({ x: 0, y: 0, width: 0.5, height: 0.0399 }, 400, 200)).toBe(
    true,
  );
  expect(isSlip({ x: 0, y: 0, width: 0.02, height: 0.04 }, 400, 200)).toBe(
    false,
  );
});

test('dragging a corner pivots on the one across from it, so the rest of the box stays', () => {
  // Halves and eighths, which add up exactly
  const box = { x: 0.25, y: 0.125, width: 0.5, height: 0.625 };
  const pivots = Object.fromEntries(
    CORNERS.map((corner) => [corner, pivotFor(box, corner)]),
  );
  expect(pivots).toEqual({
    nw: { x: 0.75, y: 0.75 },
    ne: { x: 0.25, y: 0.75 },
    sw: { x: 0.75, y: 0.125 },
    se: { x: 0.25, y: 0.125 },
  });
  // Pulling the south-east corner out to the edge grows the box from its north-west corner
  expect(cropBetween(pivotFor(box, 'se'), { x: 1, y: 1 })).toEqual({
    x: 0.25,
    y: 0.125,
    width: 0.75,
    height: 0.875,
  });
});

test('Enter adds unless a focused button took it, and Esc cancels whatever has focus', () => {
  expect(keyAction('Enter', false)).toBe('add');
  // A focused Cancel or Clear crop presses itself
  expect(keyAction('Enter', true)).toBe(null);
  expect(keyAction('Escape', false)).toBe('cancel');
  // tgui-core's Button takes Esc's default away too
  expect(keyAction('Escape', true)).toBe('cancel');
  expect(keyAction('Esc', false)).toBe('cancel');
  expect(keyAction(' ', false)).toBe(null);
  expect(keyAction('a', false)).toBe(null);
});

test('Tab goes round the dialog and never out of it', () => {
  expect(nextFocus(0, 3, false)).toBe(1);
  expect(nextFocus(2, 3, false)).toBe(0);
  expect(nextFocus(0, 3, true)).toBe(2);
  expect(nextFocus(1, 3, true)).toBe(0);
  // Focus on the dialog itself, after a click on the preview
  expect(nextFocus(-1, 3, false)).toBe(0);
  expect(nextFocus(-1, 3, true)).toBe(2);
  expect(nextFocus(0, 1, false)).toBe(0);
});

test('a refusal keeps its reason, and anything else is the window failing', () => {
  expect(reasonOf(new SnapshotRefusal('too_big'))).toBe('too_big');
  expect(reasonOf(new SnapshotRefusal('empty'))).toBe('empty');
  expect(reasonOf(new SnapshotRefusal('timed_out'))).toBe('timed_out');
  expect(reasonOf(new Error('The source image cannot be decoded.'))).toBe(
    'failed',
  );
  expect(reasonOf('a string')).toBe('failed');
});
