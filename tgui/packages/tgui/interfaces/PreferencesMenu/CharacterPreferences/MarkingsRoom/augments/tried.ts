// THIS IS AN APHELION UI FILE
import { useSyncExternalStore } from 'react';

/**
 * The option the pointer or the keyboard is on in the open picker, by its
 * key: what the body tries on, and what the console reads out. It lives
 * outside the stage's state, as the markings room's drawer does
 * (../tryOn.ts), so trying one on draws again only what shows it: the try-on
 * on the body and the console's readout, never the stage, a card or a row.
 * Nothing goes to the server until a pick.
 */
let tried: string | null = null;
const listeners = new Set<() => void>();
// A try-on on its way out: the pointer crossing the stage between a picker's
// rows and the scan's controls (holdTried), since `crossedAt`.
let leaving: ReturnType<typeof setTimeout> | undefined;
let crossedAt = 0;
// Whether the scan's controls hold what is tried on: the pointer or the
// keyboard took it there from its row (keepTried).
let kept = false;
/** How long the pointer may rest, crossing the stage, before what it tried on comes off. */
const CROSSING_REST_MS = 250;
/** The longest a crossing lasts, the pointer moving all the while. */
const CROSSING_MAX_MS = 2000;

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

/** The pointer or the keyboard is on an option, or on none. */
export function setTried(key: string | null) {
  stopCrossing();
  kept = false;
  if (tried === key) {
    return;
  }
  tried = key;
  for (const listener of listeners) {
    listener();
  }
}

/** The keyboard left an option: it comes off, unless the pointer has tried on another since. */
export function untry(key: string) {
  if (tried === key) {
    setTried(null);
  }
}

/**
 * The pointer left a picker's rows or the scan's controls for the stage
 * between them: what is tried on stays for the crossing, so it can be turned
 * and lit, and comes off once the pointer rests on the way (crossTried), or
 * after the longest crossing.
 */
export function holdTried() {
  if (tried !== null && leaving === undefined) {
    crossedAt = performance.now();
    restTried();
  }
}

/** The pointer moved on, crossing the stage: the crossing goes on, up to its longest. */
export function crossTried() {
  if (
    leaving !== undefined &&
    performance.now() - crossedAt < CROSSING_MAX_MS
  ) {
    restTried();
  }
}

function restTried() {
  clearTimeout(leaving);
  leaving = setTimeout(() => {
    leaving = undefined;
    setTried(null);
  }, CROSSING_REST_MS);
}

/** The option being tried on now, by its key, or null: for a handler, which mustn't subscribe. */
export const triedNow = () => tried;

/** Whether what is tried on is held for a crossing (holdTried). */
export const heldTried = () => leaving !== undefined;

/** The pointer or the keyboard took what is tried on to the scan's controls: it stays, theirs to hold. */
export function keepTried() {
  stopCrossing();
  kept = true;
}

/**
 * Focus left the scan's controls for something that tries nothing on: what
 * they held comes off; what the pointer gives from a row since stays.
 */
export function dropKept() {
  if (kept) {
    setTried(null);
  }
}

function stopCrossing() {
  if (leaving !== undefined) {
    clearTimeout(leaving);
    leaving = undefined;
  }
}

/** The option being tried on, by its key, or null. */
export const useTried = () => useSyncExternalStore(subscribe, () => tried);
