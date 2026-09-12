// THIS IS AN APHELION UI FILE
import { globalEvents } from 'tgui-core/events';

// Core ByondUi debounces native positioning for 100ms. This quiet period also
// covers a picker opened immediately after a resize while it was closed.
export const NATIVE_UI_SETTLE_MS = 150;
const elements = new Set<HTMLElement>();
const listeners = new Set<() => void>();
let revision = 0;
let settleUntil = 0;
function geometryChanged() {
  settleUntil = performance.now() + NATIVE_UI_SETTLE_MS;
}
export const nativeUiSettleDelay = () =>
  Math.max(0, settleUntil - performance.now());

function notify() {
  revision++;
  for (const listener of listeners) listener();
}

/** Mount/unmount notifications only: no polling, geometry reads or winsets. */
export function registerNativeUi(element: HTMLElement) {
  if (!elements.size) {
    // Timestamp only: no measurements, timers, notifications or React updates.
    window.addEventListener('resize', geometryChanged);
    globalEvents.on('window-geometry-finished', geometryChanged);
  }
  elements.add(element);
  notify();
  return () => {
    elements.delete(element);
    if (!elements.size) {
      window.removeEventListener('resize', geometryChanged);
      globalEvents.off('window-geometry-finished', geometryChanged);
      settleUntil = 0;
    }
    notify();
  };
}

export const getNativeUiElements = (): ReadonlySet<HTMLElement> => elements;
export const getNativeUiRevision = () => revision;
export function subscribeNativeUi(listener: () => void) {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}
