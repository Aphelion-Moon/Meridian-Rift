// THIS IS AN APHELION UI FILE
import { useSyncExternalStore } from 'react';

/**
 * The slot the pointer is on in the augments stage: a card, a node, or a part
 * of the body. It lives outside the stage's state, as the markings room's
 * pointer does (../pointer.ts), so pointing draws again only what shows it:
 * the cards and traces it lights, the console's readout and the character's
 * lit part, not the whole stage.
 */
let hover: string | null = null;
const listeners = new Set<() => void>();

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

/** The pointer is on a slot, or off them all. */
export function setStageHover(slot: string | null) {
  if (hover === slot) {
    return;
  }
  hover = slot;
  for (const listener of listeners) {
    listener();
  }
}

/** The slot the pointer is on, or null. */
export const useStageHover = () => useSyncExternalStore(subscribe, () => hover);

/** Whether the pointer is on this slot: what asks draws again only when that changes. */
export const useStageHoverIs = (slot: string) =>
  useSyncExternalStore(subscribe, () => hover === slot);

/** Whether the pointer is on any slot. */
export const useStageHovering = () =>
  useSyncExternalStore(subscribe, () => hover !== null);
