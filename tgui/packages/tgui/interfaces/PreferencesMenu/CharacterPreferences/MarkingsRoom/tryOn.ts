// THIS IS AN APHELION UI FILE
import { useSyncExternalStore } from 'react';

/**
 * What the pointer is trying on in the drawer: a marking's name, or a look's.
 * It lives outside the room's state, so trying one on draws again only what
 * shows it (the ghost in the mirror, the drawer's foot, and the two picks the
 * pointer moves between), not the whole room.
 */
let tried: string | null = null;
const listeners = new Set<() => void>();

export function setTried(name: string | null) {
  if (tried === name) {
    return;
  }
  tried = name;
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

/** What is being tried on, or null. */
export const useTried = () => useSyncExternalStore(subscribe, () => tried);

/** Whether this one is being tried on. */
export const useIsTried = (name: string) =>
  useSyncExternalStore(subscribe, () => tried === name);
