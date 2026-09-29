// THIS IS AN APHELION UI FILE
import {
  type PointerEvent as ReactPointerEvent,
  type RefObject,
  useEffect,
  useLayoutEffect,
  useRef,
} from 'react';

/** Horizontal drag, in pixels, that turns the character a quarter. */
export const DRAG_STEP = 40;

/** Wheel travel, in pixels, that zooms one step: one notch of a mouse wheel. */
export const WHEEL_STEP = 100;

/**
 * The quarter turns a drag has made, clockwise from above, and the travel left
 * over. Dragging right turns the character's front to the right, which is
 * anticlockwise from above.
 */
export function dragTurns(travel: number, step = DRAG_STEP) {
  const steps = Math.trunc(travel / step);
  return { turns: steps === 0 ? 0 : -steps, rest: travel - steps * step };
}

/** The zoom steps a run of wheel travel makes, and the travel left over. Wheeling up zooms in. */
export function wheelZooms(travel: number, step = WHEEL_STEP) {
  const steps = Math.trunc(travel / step);
  return { zooms: steps === 0 ? 0 : -steps, rest: travel - steps * step };
}

/** A wheel event's travel in pixels, whichever unit the device reports it in. */
function wheelPixels(event: WheelEvent) {
  if (event.deltaMode === 1) {
    return event.deltaY * 40;
  }
  if (event.deltaMode === 2) {
    return event.deltaY * WHEEL_STEP * 3;
  }
  return event.deltaY;
}

type GestureHandlers = {
  /** Quarter turns, clockwise from above. */
  onTurn: (turns: number) => void;
  /** Zoom steps; positive zooms in. */
  onZoom: (steps: number) => void;
};

/**
 * Drag to turn and wheel to zoom, on a box. Pointer and wheel travel collect
 * in refs, so nothing re-renders until a whole step is made: a drag across the
 * box renders once per quarter turn, not once per move.
 */
export function usePreviewGestures(
  box: RefObject<HTMLElement | null>,
  handlers: GestureHandlers,
) {
  const latest = useRef(handlers);
  useLayoutEffect(() => {
    latest.current = handlers;
  });
  const drag = useRef<{ pointer: number; x: number } | null>(null);

  // React listens for wheel passively, which can't keep the page from
  // scrolling under the preview, so this one is the element's own.
  useEffect(() => {
    const element = box.current;
    if (!element) {
      return;
    }
    let travel = 0;
    const onWheel = (event: WheelEvent) => {
      event.preventDefault();
      const { zooms, rest } = wheelZooms(travel + wheelPixels(event));
      travel = rest;
      if (zooms) {
        latest.current.onZoom(zooms);
      }
    };
    element.addEventListener('wheel', onWheel, { passive: false });
    return () => element.removeEventListener('wheel', onWheel);
  }, [box]);

  const release = (event: ReactPointerEvent<HTMLElement>) => {
    if (drag.current?.pointer === event.pointerId) {
      drag.current = null;
    }
  };

  return {
    onPointerDown(event: ReactPointerEvent<HTMLElement>) {
      if (event.button !== 0) {
        return;
      }
      drag.current = { pointer: event.pointerId, x: event.clientX };
      // Keep the drag when the pointer leaves the box.
      event.currentTarget.setPointerCapture?.(event.pointerId);
    },
    onPointerMove(event: ReactPointerEvent<HTMLElement>) {
      const held = drag.current;
      if (!held || held.pointer !== event.pointerId) {
        return;
      }
      const { turns, rest } = dragTurns(event.clientX - held.x);
      if (turns) {
        held.x = event.clientX - rest;
        latest.current.onTurn(turns);
      }
    },
    onPointerUp: release,
    onPointerCancel: release,
  };
}
