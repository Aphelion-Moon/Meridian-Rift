// THIS IS AN APHELION UI FILE
import { useSyncExternalStore } from 'react';

import type { MarkingZone } from './constants';

/** What the pointer has lit on a card: a worn marking by its place, or the custom drawing. */
export type CardLight = { zone: MarkingZone; what: number | 'custom' };

/**
 * Where the pointer is in the markings room: the zone it points at, on a card
 * or on the body (a marking zone, or the taur's), and what it lights on a
 * card. It lives outside the room's state, as what the drawer tries on does
 * (tryOn.ts), so pointing draws again only what shows it: the cards it lights
 * and the mirror's halo, dimming and lit marking, not the whole room.
 */
let zone: string | null = null;
let light: CardLight | null = null;
/** Bumped whenever the character moves in the glass, so the dimming follows it. */
let placed = 0;
const listeners = new Set<() => void>();

function notify() {
  for (const listener of listeners) {
    listener();
  }
}

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

/** Hears every change, for what follows the pointer outside React: returns the unsubscribe. */
export const subscribePointer = subscribe;

/** The zone the pointer is on, or null, as it is now. */
export const pointedZone = () => zone;

/** The pointer is on a zone, on a card or the body, or off them all. */
export function setPointedZone(next: string | null) {
  if (zone === next) {
    return;
  }
  zone = next;
  notify();
}

/** The pointer is on a worn marking's tile or a custom drawing's, or off them. */
export function setCardLight(next: CardLight | null) {
  if (
    light === next ||
    (light && next && light.zone === next.zone && light.what === next.what)
  ) {
    return;
  }
  light = next;
  notify();
}

/** The character moved in the glass. */
export function markPlaced() {
  placed++;
  notify();
}

/** Nothing pointed at: the room goes, or a test starts afresh. */
export function resetPointer() {
  if (zone === null && light === null) {
    return;
  }
  zone = null;
  light = null;
  notify();
}

/** The zone the pointer is on, or null. */
export const usePointedZone = () => useSyncExternalStore(subscribe, () => zone);

/** What the pointer lights on a card, or null. */
export const useCardLight = () => useSyncExternalStore(subscribe, () => light);

/** How many times the character has moved in the glass. */
export const usePlaced = () => useSyncExternalStore(subscribe, () => placed);

/**
 * A yes or no about the pointed zone, such as whether a card is lit: what
 * asks draws again only when the answer changes.
 */
export const usePointedIs = (test: (pointed: string | null) => boolean) =>
  useSyncExternalStore(subscribe, () => test(zone));
