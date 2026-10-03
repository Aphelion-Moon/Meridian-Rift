// THIS IS AN APHELION UI FILE
import { useLayoutEffect, useRef, useState } from 'react';

/** The plaque's width in its own units: one unit is one of the mockup's pixels (--forge-u). */
const WIDTH = 540;
/** The rivet band is 18 units wide; its rivets run down its middle. */
const SIDE = 9;
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
 * Foundry's lobby plaque, drawn behind the menu and laid on it by anchor (the lobby's
 * styles/meridianos/_foundry.scss): the forge markings room's steel with its rivet band and
 * engraved field, the steel boss at the arch's crown and a pixel torch on each shoulder. It
 * measures itself only to space the side rivets for the menu's height.
 */
export function ForgePlaque() {
  const ref = useRef<HTMLDivElement>(null);
  const [height, setHeight] = useState(616);

  useLayoutEffect(() => {
    const node = ref.current;
    if (!node) return;
    const observer = new ResizeObserver(([entry]) => {
      const { width, height: pixels } = entry.contentRect;
      if (!width) return;
      const next = Math.round((pixels * WIDTH) / width);
      setHeight((last) => (last === next ? last : next));
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
