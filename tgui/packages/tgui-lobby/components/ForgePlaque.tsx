// THIS IS AN APHELION UI FILE
import { useLayoutEffect, useReducer, useRef, useState } from 'react';

/** The plaque's width in its own units: one unit is one of the mockup's pixels (--forge-u). */
const WIDTH = 540;
/** The rivet band is 18 units wide; its rivets run down its middle. */
const BAND = 18;
const SIDE = BAND / 2;
/** The side runs start below the torch mounts, at this pitch down to the bottom corners. */
const SIDE_TOP = 167.8;
const PITCH = 34;
/** The bottom run, between the corners. */
const BOTTOM_FIRST = 43;
const BOTTOM_LAST = WIDTH - BOTTOM_FIRST;

/**
 * The rivets along the arch's left half, from the springline to the boss at the crown, as the
 * art review placed them (lab foundry-refresh-mockup, harness/plaque_rivets.py): an even pitch
 * on the band's middle line, none under the boss or the torch mounts. The right half mirrors it.
 */
const ARCH: readonly (readonly [number, number])[] = [
  [29.2, 64.9],
  [46.4, 53.1],
  [65.1, 43.6],
  [84.5, 36.0],
  [104.5, 29.6],
  [124.7, 24.4],
  [145.2, 20.1],
  [165.8, 16.6],
  [186.5, 13.8],
  [207.3, 11.7],
  [228.2, 10.2],
];

/** Every rivet of a plaque `height` units tall: the arch, both sides and the bottom. */
export function forgeRivets(height: number): [number, number][] {
  const points: [number, number][] = [];
  for (const [x, y] of ARCH) {
    points.push([x, y], [WIDTH - x, y]);
  }
  const bottom = height - SIDE;
  if (bottom > SIDE_TOP) {
    const runs = Math.max(1, Math.round((bottom - SIDE_TOP) / PITCH));
    for (let i = 0; i <= runs; i++) {
      const y = SIDE_TOP + ((bottom - SIDE_TOP) * i) / runs;
      points.push([SIDE, y], [WIDTH - SIDE, y]);
    }
  }
  const runs = Math.round((BOTTOM_LAST - BOTTOM_FIRST) / PITCH);
  for (let i = 0; i <= runs; i++) {
    points.push([
      BOTTOM_FIRST + ((BOTTOM_LAST - BOTTOM_FIRST) * i) / runs,
      bottom,
    ]);
  }
  return points;
}

/**
 * The least height the lobby is given (--forge-h, the stylesheet's fallback): up to it the
 * plaque keeps its scale, so a shorter menu needn't tell the lobby anything.
 */
const NEEDED_LEAST = 640;

/** A length in units, kept within a unit of the last: a fraction either way doesn't move it. */
function settle(last: number, units: number) {
  return Math.abs(units - last) < 1 ? last : Math.round(units);
}

/**
 * The plaque's size in units: its height, and the height every row of its menu needs, those
 * a window too short for it scrolls out of sight too.
 */
function measure(plaque: HTMLElement) {
  const menu = plaque.parentElement?.querySelector('.container_nav');
  const { width, height } = plaque.getBoundingClientRect();
  if (!menu || !width) return null;
  const units = WIDTH / width;
  return {
    height: height * units,
    needed: menu.scrollHeight * units + 2 * BAND,
  };
}

/**
 * Foundry's lobby plaque, drawn behind the menu and laid on it by anchor (the lobby's
 * styles/meridianos/_foundry.scss): the forge markings room's steel with its rivet band and
 * engraved field, the steel boss at the arch's crown and a pixel torch on each shoulder. It
 * grows with the menu: it gives the lobby the height its menu needs (--forge-h), so that it
 * scales to fit under the title whatever rows it holds, and measures itself to space the
 * side rivets.
 */
export function ForgePlaque() {
  const ref = useRef<HTMLDivElement>(null);
  const [height, setHeight] = useState(616);
  const [, redraw] = useReducer((count: number) => count + 1, 0);
  /** The height the lobby was last given. */
  const given = useRef(NEEDED_LEAST);
  /** Whether this render is the plaque's own, for the height it has just measured. */
  const own = useRef(false);
  /** The height its rivets are spaced for, as the last render drew them. */
  const drawn = useRef(height);

  useLayoutEffect(() => {
    const lobby = ref.current?.parentElement;
    return () => {
      lobby?.style.removeProperty('--forge-h');
    };
  }, []);

  // The lobby draws this again with the menu, whose rows may have changed: measured before
  // the frame is painted, the plaque never shows at the old height's scale. The scale goes
  // first, so the plaque is measured once, at the scale it will show at; past the 12px the
  // lettering keeps at the least, a smaller scale can lengthen the menu, so it may take more.
  useLayoutEffect(() => {
    drawn.current = height;
    if (own.current) {
      own.current = false;
      return;
    }
    const node = ref.current;
    const lobby = node?.parentElement;
    if (!node || !lobby) return;
    let size = measure(node);
    for (let pass = 0; size && pass < 3; pass++) {
      const needed = Math.max(NEEDED_LEAST, settle(given.current, size.needed));
      if (needed === given.current) break;
      given.current = needed;
      lobby.style.setProperty('--forge-h', `${needed}`);
      size = measure(node);
    }
    const next = size ? settle(height, size.height) : height;
    if (next !== height) {
      own.current = true;
      setHeight(next);
    }
  });

  // Resizes and late fonts: measured again on the next render, never within this callback,
  // which would resize what it observes and stop the page with a loop error.
  useLayoutEffect(() => {
    const node = ref.current;
    if (!node) return;
    const observer = new ResizeObserver(() => {
      const size = measure(node);
      if (
        size &&
        (Math.abs(size.height - drawn.current) >= 1 ||
          Math.max(NEEDED_LEAST, settle(given.current, size.needed)) !==
            given.current)
      ) {
        redraw();
      }
    });
    observer.observe(node);
    return () => observer.disconnect();
  }, []);

  return (
    <div aria-hidden="true" className="lobby-forge" ref={ref}>
      <div className="lobby-forge__plaque" />
      <div className="lobby-forge__field" />
      <svg
        className="lobby-forge__rivets"
        viewBox={`0 0 ${WIDTH} ${height}`}
        preserveAspectRatio="none"
      >
        {forgeRivets(height).map(([x, y]) => (
          <g key={`${x.toFixed(1)},${y.toFixed(1)}`}>
            <circle className="b" cx={x} cy={y} r={4.2} />
            <circle className="h" cx={x - 1.2} cy={y - 1.3} r={1.6} />
          </g>
        ))}
      </svg>
      <span className="lobby-forge__boss">
        <svg viewBox="1.75 3.4 24 24">
          <path d="M15 15m-1 0a1 1 0 1 1 2 0a3 3 0 1 1-6 0a5 5 0 1 1 10 0a7 7 0 1 1-14 0" />
        </svg>
      </span>
      {(['left', 'right'] as const).map((side) => (
        <span
          key={side}
          className={`lobby-forge__torch lobby-forge__torch--${side}`}
        >
          <i className="lobby-forge__flame--a" />
          <i className="lobby-forge__flame--b" />
        </span>
      ))}
    </div>
  );
}
