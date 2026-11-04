// THIS IS AN APHELION UI FILE
import { atom } from 'jotai';
import { useEffect } from 'react';
import { sendAct } from 'tgui/events/act';
import { store, suspendedAtom } from 'tgui/events/store';

/**
 * The brand finishes' try-on sprites, the augment_brands spritesheet, come
 * only when asked for, unlike the rest of the window's sheets: once per
 * window, in the background, ahead of the augments stage that draws them, so
 * a window that never goes near Augments+ never loads them. A stylesheet that
 * arrives later is picked up as one (../sprites.ts); until it has, a brand
 * finish tries nothing on.
 */
export const brandSpritesAskedAtom = atom(false);

/**
 * How long the pointer or the keyboard rests on a way into the augments
 * before the window asks: counted from the pointer's last move there, so
 * passing over it, at any pace, never does.
 */
const INTENT_DWELL_MS = 100;
let dwell: ReturnType<typeof setTimeout> | undefined;

/** Asks the server for the brand sprites, unless this window has already. */
export function askForBrandSprites() {
  if (store.get(brandSpritesAskedAtom)) {
    return;
  }
  store.set(brandSpritesAskedAtom, true);
  sendAct('augment_brand_sprites');
}

function startDwell() {
  if (!store.get(brandSpritesAskedAtom)) {
    clearTimeout(dwell);
    dwell = setTimeout(askForBrandSprites, INTENT_DWELL_MS);
  }
}

function stopDwell() {
  clearTimeout(dwell);
  dwell = undefined;
}

/**
 * On a way into the augments (the Augments+ page's tab, the room's Augments
 * button): the pointer or the keyboard resting there asks, while there's a
 * moment to spare before the click; moving over it or on doesn't.
 */
export const BRAND_SPRITES_INTENT = {
  onMouseEnter: startDwell,
  onMouseMove: startDwell,
  onMouseLeave: stopDwell,
  onFocus: startDwell,
  onBlur: stopDwell,
};

// A window put away for its next use starts afresh, as its data does
// (resetStore()): it asks again when it's next opened, in case an ask went
// unanswered.
store.sub(suspendedAtom, () => {
  if (store.get(suspendedAtom)) {
    stopDwell();
    store.set(brandSpritesAskedAtom, false);
  }
});

/**
 * The augments stage on show, as a window that opens on it is: asks once the
 * window is idle after drawing it, as the markings' sheets are asked for
 * (usePrefetchMarkingSheets), so the ask never competes with the window's own
 * first load.
 */
export function useBrandSpritesWhenIdle() {
  useEffect(() => {
    if (store.get(brandSpritesAskedAtom)) {
      return;
    }
    if (typeof requestIdleCallback === 'function') {
      const id = requestIdleCallback(askForBrandSprites, { timeout: 2000 });
      return () => cancelIdleCallback(id);
    }
    const id = setTimeout(askForBrandSprites, 500);
    return () => clearTimeout(id);
  }, []);
}
