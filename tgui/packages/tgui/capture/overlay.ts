// THIS IS AN APHELION UI FILE

import { type Crop, SnapshotRefusal } from './dom-snapshot';

/** Why this window ends a capture, in the words the server reads (bug_reporting_capture.dm cancel_ui_capture) */
export type Reason =
  | 'cancelled'
  | 'too_big'
  | 'empty'
  | 'failed'
  | 'timed_out'
  | 'interrupted'
  | 'busy'
  | 'not_allowed';

/** A point on the preview, each side a fraction of it from 0 to 1 */
export type Point = { x: number; y: number };

/** The crop's corner handles, by compass point */
export const CORNERS = ['nw', 'ne', 'sw', 'se'] as const;
export type Corner = (typeof CORNERS)[number];

/** Screen pixels a crop needs each way, since anything smaller is a slip of the mouse */
const SLIP = 8;

/** The box between where a drag started and where the pointer is now, whichever way it went */
export function cropBetween(start: Point, end: Point): Crop {
  return {
    x: Math.min(start.x, end.x),
    y: Math.min(start.y, end.y),
    width: Math.abs(start.x - end.x),
    height: Math.abs(start.y - end.y),
  };
}

/** Whether a crop is too small on a preview this many pixels across and down to be meant */
export function isSlip(crop: Crop, width: number, height: number) {
  return crop.width * width < SLIP || crop.height * height < SLIP;
}

/** The corner across from the one being dragged, which stays put while the box resizes */
export function pivotFor(crop: Crop, corner: Corner): Point {
  return {
    x: corner.endsWith('w') ? crop.x + crop.width : crop.x,
    y: corner.startsWith('n') ? crop.y + crop.height : crop.y,
  };
}

/**
 * What a key does in the overlay.
 *
 * Enter adds, unless a focused button already pressed itself with it. Esc cancels whatever has focus, since
 * tgui-core's Button takes Esc's default away as well
 */
export function keyAction(key: string, taken: boolean) {
  if (key === 'Escape' || key === 'Esc') return 'cancel';
  if (key === 'Enter' && !taken) return 'add';
  return null;
}

/** Where Tab moves focus among the dialog's controls, going round so it never leaves; -1 is the dialog itself */
export function nextFocus(index: number, count: number, back: boolean) {
  if (index < 0) return back ? count - 1 : 0;
  return (index + (back ? count - 1 : 1)) % count;
}

/** Why a drawing failed, a refusal's own reason or the window failing */
export function reasonOf(error: unknown): Reason {
  return error instanceof SnapshotRefusal ? error.reason : 'failed';
}
