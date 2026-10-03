// THIS IS AN APHELION UI FILE
// The Shadowbroker markings room's decor, from its mockup (the lab's markings-themes run, canvas/project/
// Main.dc.html), written by the themes-impl run's tools/decor.py. Its CSS is in
// styles/meridianos/markings-room/_shadowbroker.scss. Hand edits are marked HAND.
import { memo } from 'react';

export const Header = memo(function ShadowbrokerHeader() {
  return (
    <>
      <span className="sb-open">
        <b>O</b>
        <b>P</b>
        <b className="dead">E</b>
        <b>N</b>
      </span>
      <span className="sb-card">
        <b>CASH ONLY</b>no refunds
      </span>
    </>
  );
});

export const Frame = memo(function ShadowbrokerFrame() {
  return (
    <>
      <span className="sb-door" />
      <span className="sb-louvre" />
      <span className="sb-num">13</span>
      <span className="sb-hasp">
        <i />
      </span>
      <span className="sb-clip a" />
      <span className="sb-clip b" />
      <span className="sb-clip c" />
      <span className="sb-clip d" />
      <span className="lamp sb-clamp">
        <i />
      </span>
      <span className="sb-stk px carp" />
      <span className="sb-haz">
        <i />
      </span>
      <svg className="sb-spray" viewBox="0 0 60 70" aria-hidden="true">
        <g className="os">
          <circle cx="30" cy="30" r="21" />
          <path d="M17.5 44 30 13 42.5 44M14 33.5H46" />
        </g>
        <g className="ln">
          <circle cx="30" cy="30" r="21" />
          <path d="M17.5 44 30 13 42.5 44M14 33.5H46" />
        </g>
        <g className="dr">
          <rect x="16.7" y="44.0" width="1.6" height="9" rx=".8" />
          <circle cx="17.5" cy="53.0" r="1.5" />
          <rect x="41.7" y="44.0" width="1.6" height="17" rx=".8" />
          <circle cx="42.5" cy="61.0" r="1.5" />
          <rect x="29.2" y="53.5" width="1.6" height="5" rx=".8" />
          <circle cx="30.0" cy="58.5" r="1.5" />
        </g>
      </svg>
    </>
  );
});

export const GlassAfter = memo(function ShadowbrokerGlassAfter() {
  return (
    <span className="sb-stk xd">
      <svg viewBox="0 0 34 34" aria-hidden="true">
        <circle className="face" cx="17" cy="17" r="15" strokeWidth="2" />
        <path
          className="ink"
          d="M10 11l5 5M15 11l-5 5M19 11l5 5M24 11l-5 5"
          strokeWidth="2"
          strokeLinecap="round"
        />
        <path
          className="ink"
          d="M10 21.5c3.5 4 10.5 4 14 0"
          fill="none"
          strokeWidth="2"
          strokeLinecap="round"
        />
        <path className="tongue" d="M19 23.6c0 3.4 4.6 3.6 4.6.4" />
      </svg>
    </span>
  );
});
