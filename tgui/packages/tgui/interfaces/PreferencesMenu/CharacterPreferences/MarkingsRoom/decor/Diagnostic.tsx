// THIS IS AN APHELION UI FILE
// The Diagnostic markings room's decor, from its mockup (the lab's markings-themes run, canvas/project/
// Main.dc.html), written by the themes-impl run's tools/decor.py. Its CSS is in
// styles/meridianos/markings-room/_diagnostic.scss. Hand edits are marked HAND.
import { memo } from 'react';

export const Wall = memo(function DiagnosticWall() {
  return (
    <svg className="dx-graf" viewBox="0 0 900 820" aria-hidden="true">
      <g className="os">
        <text
          className="or"
          x="286"
          y="86"
          fontSize="34"
          transform="rotate(-5 286 86)"
        >
          skulk
        </text>
      </g>
      <g className="pt">
        <text
          className="or"
          x="286"
          y="86"
          fontSize="34"
          transform="rotate(-5 286 86)"
        >
          skulk
        </text>
      </g>
      <g className="dr" transform="rotate(-5 286 86)">
        <rect x="299.1" y="84.0" width="1.8" height="8" rx=".9" />
        <circle cx="300.0" cy="92.0" r="1.6" />
        <rect x="337.1" y="86.0" width="1.8" height="13" rx=".9" />
        <circle cx="338.0" cy="99.0" r="1.6" />
      </g>
      <g className="os">
        <text
          className="si"
          x="520"
          y="84"
          fontSize="30"
          transform="rotate(4 520 84)"
        >
          hollow
        </text>
      </g>
      <g className="pt">
        <text
          className="si"
          x="520"
          y="84"
          fontSize="30"
          transform="rotate(4 520 84)"
        >
          hollow
        </text>
      </g>
      <g className="dr" transform="rotate(4 520 84)">
        <rect x="559.1" y="84.0" width="1.8" height="9" rx=".9" />
        <circle cx="560.0" cy="93.0" r="1.6" />
        <rect x="599.1" y="86.0" width="1.8" height="6" rx=".9" />
        <circle cx="600.0" cy="92.0" r="1.6" />
      </g>
      <g className="os">
        <text
          className="or"
          x="296"
          y="638"
          fontSize="26"
          transform="rotate(-2 296 638)"
        >
          no rest here
        </text>
      </g>
      <g className="pt">
        <text
          className="or"
          x="296"
          y="638"
          fontSize="26"
          transform="rotate(-2 296 638)"
        >
          no rest here
        </text>
      </g>
      <g className="dr" transform="rotate(-2 296 638)">
        <rect x="351.1" y="636.0" width="1.8" height="10" rx=".9" />
        <circle cx="352.0" cy="646.0" r="1.6" />
        <rect x="447.1" y="632.0" width="1.8" height="7" rx=".9" />
        <circle cx="448.0" cy="639.0" r="1.6" />
        <rect x="519.1" y="630.0" width="1.8" height="12" rx=".9" />
        <circle cx="520.0" cy="642.0" r="1.6" />
      </g>
      <g className="os">
        <text
          className="or"
          x="20"
          y="404"
          fontSize="112"
          transform="rotate(-8 20 404)"
        >
          kill
        </text>
      </g>
      <g className="pt">
        <text
          className="or"
          x="20"
          y="404"
          fontSize="112"
          transform="rotate(-8 20 404)"
        >
          kill
        </text>
      </g>
      <g className="os">
        <text
          className="si"
          x="640"
          y="262"
          fontSize="118"
          transform="rotate(6 640 262)"
        >
          rot
        </text>
      </g>
      <g className="pt">
        <text
          className="si"
          x="640"
          y="262"
          fontSize="118"
          transform="rotate(6 640 262)"
        >
          rot
        </text>
      </g>
      <g className="os">
        <text
          className="si"
          x="26"
          y="560"
          fontSize="70"
          transform="rotate(3 26 560)"
        >
          dust
        </text>
      </g>
      <g className="pt">
        <text
          className="si"
          x="26"
          y="560"
          fontSize="70"
          transform="rotate(3 26 560)"
        >
          dust
        </text>
      </g>
    </svg>
  );
});

export const Frame = memo(function DiagnosticFrame() {
  return (
    <>
      <span className="lamp dx-lamp" />
      <span className="dx-br a" />
      <span className="dx-br b" />
      <span className="dx-br c" />
      <span className="dx-br d" />
      <span className="dx-rule" />
    </>
  );
});

export const Glass = memo(function DiagnosticGlass() {
  return (
    <>
      <span className="dx-scan" />
      <svg className="dx-trace" viewBox="0 0 200 36" preserveAspectRatio="none">
        <path
          className="bg"
          d="M0 22H34l4-3 4 3h8l3 6 4-24 4 26 3-8h10l5-4 6 4H112l4-3 4 3h8l3 6 4-24 4 26 3-8h10l5-4 6 4H200"
        />
        <path
          className="hot"
          pathLength="100"
          d="M0 22H34l4-3 4 3h8l3 6 4-24 4 26 3-8h10l5-4 6 4H112l4-3 4 3h8l3 6 4-24 4 26 3-8h10l5-4 6 4H200"
        />
      </svg>
    </>
  );
});
