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

/** How long, in milliseconds, a pointer is held still before its drag pans. */
export const HOLD_TIME = 300;

/** How far, in pixels, a held pointer may stray and still be held still. */
export const HOLD_SLOP = 6;

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

/** Whether a pointer this far from where it went down is still held still. */
export const heldStill = (dx: number, dy: number, slop = HOLD_SLOP) =>
  Math.hypot(dx, dy) <= slop;

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
  /** A held pointer begins to pan, from where it is. */
  onPanStart: (x: number, y: number) => void;
  /** The panning pointer is here now. */
  onPan: (x: number, y: number) => void;
  /** The panning pointer let go. */
  onPanEnd: () => void;
};

type Drag = {
  pointer: number;
  /** Where the pointer went down. */
  downX: number;
  downY: number;
  /** Where the pointer is. */
  x: number;
  y: number;
  /** Where the turn's travel counts from. */
  turnX: number;
  /** Held still so far, until it moves or is held long enough. */
  gesture: 'hold' | 'turn' | 'pan';
  hold: ReturnType<typeof setTimeout>;
};

/**
 * Drag to turn, hold still and then drag to pan, and wheel to zoom, on a box.
 * A drag that moves at once turns; one held still for HOLD_TIME pans instead.
 * Pointer and wheel travel collect in refs, so a turn renders once per quarter
 * turn, not once per move, and a pan never renders: its handlers see every move.
 */
export function usePreviewGestures(
  box: RefObject<HTMLElement | null>,
  handlers: GestureHandlers,
) {
  const latest = useRef(handlers);
  useLayoutEffect(() => {
    latest.current = handlers;
  });
  const drag = useRef<Drag | null>(null);

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

  // A pointer still held as the box goes stops waiting to pan.
  useEffect(() => () => clearTimeout(drag.current?.hold), []);

  const letGo = () => {
    const held = drag.current;
    if (!held) {
      return;
    }
    clearTimeout(held.hold);
    drag.current = null;
    if (held.gesture === 'pan') {
      latest.current.onPanEnd();
    }
  };

  const release = (event: ReactPointerEvent<HTMLElement>) => {
    if (drag.current?.pointer === event.pointerId) {
      letGo();
    }
  };

  return {
    onPointerDown(event: ReactPointerEvent<HTMLElement>) {
      if (event.button !== 0) {
        return;
      }
      // A second finger takes over from the first.
      letGo();
      const { clientX: x, clientY: y } = event;
      const held: Drag = {
        pointer: event.pointerId,
        downX: x,
        downY: y,
        x,
        y,
        turnX: x,
        gesture: 'hold',
        hold: setTimeout(() => {
          held.gesture = 'pan';
          latest.current.onPanStart(held.x, held.y);
        }, HOLD_TIME),
      };
      drag.current = held;
      // Keep the drag when the pointer leaves the box.
      event.currentTarget.setPointerCapture?.(event.pointerId);
    },
    onPointerMove(event: ReactPointerEvent<HTMLElement>) {
      const held = drag.current;
      if (!held || held.pointer !== event.pointerId) {
        return;
      }
      held.x = event.clientX;
      held.y = event.clientY;
      if (held.gesture === 'pan') {
        latest.current.onPan(held.x, held.y);
        return;
      }
      if (
        held.gesture === 'hold' &&
        !heldStill(held.x - held.downX, held.y - held.downY)
      ) {
        held.gesture = 'turn';
        clearTimeout(held.hold);
      }
      const { turns, rest } = dragTurns(held.x - held.turnX);
      if (turns) {
        held.turnX = held.x - rest;
        latest.current.onTurn(turns);
      }
    },
    onPointerUp: release,
    onPointerCancel: release,
  };
}
