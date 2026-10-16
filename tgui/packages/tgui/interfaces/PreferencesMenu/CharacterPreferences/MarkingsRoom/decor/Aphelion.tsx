// THIS IS AN APHELION UI FILE
// The Aphelion markings room's decor, from its mockup (the lab's markings-themes run, canvas/project/
// Main.dc.html), written by the themes-impl run's tools/decor.py. Its CSS is in
// styles/meridianos/markings-room/_aphelion.scss. Hand edits are marked HAND.
import { memo } from 'react';

export const Header = memo(function AphelionHeader() {
  return (
    <>
      <span className="AugmentsRoom__tag AugmentsRoom__tag--g1">
        gonna burn
        <svg className="gdrip" viewBox="0 0 140 26" aria-hidden="true">
          <ellipse cx="13" cy="1.4" rx="3.4" ry="1.8" />
          <rect x="12.0" y="1" width="2" height="9" rx="1" />
          <circle cx="13.0" cy="9.4" r="2.1" />
          <ellipse cx="33" cy="1.4" rx="3.4" ry="1.8" />
          <rect x="32.0" y="1" width="2" height="16" rx="1" />
          <circle cx="33.0" cy="16.4" r="2.1" />
          <ellipse cx="64" cy="1.4" rx="3.4" ry="1.8" />
          <rect x="63.0" y="1" width="2" height="6" rx="1" />
          <circle cx="64.0" cy="6.4" r="2.1" />
          <ellipse cx="97" cy="1.4" rx="3.4" ry="1.8" />
          <rect x="96.0" y="1" width="2" height="13" rx="1" />
          <circle cx="97.0" cy="13.4" r="2.1" />
          <ellipse cx="121" cy="1.4" rx="3.4" ry="1.8" />
          <rect x="120.0" y="1" width="2" height="19" rx="1" />
          <circle cx="121.0" cy="19.4" r="2.1" />
        </svg>
      </span>
      <svg className="gsun" viewBox="0 0 44 24" aria-hidden="true">
        <circle cx="22" cy="12" r="4.6" />
        <path d="M22 3.5V1.5M22 20.5v2M17 7.2l-1.3-1.4M27 7.2l1.3-1.4M17 16.8l-1.3 1.4M27 16.8l1.3 1.4" />
        <path d="M15.5 11C11 7 6 6.5 1.5 8.5c3 .3 5 1.2 6.4 2.5-2.2-.1-4.2.6-5.6 2 4-.9 8.2-.9 13.2.4M28.5 11c4.5-4 9.5-4.5 14-2.5-3 .3-5 1.2-6.4 2.5 2.2-.1 4.2.6 5.6 2-4-.9-8.2-.9-13.2.4" />
      </svg>
    </>
  );
});

export const Glass = memo(function AphelionGlass() {
  return (
    <>
      <svg className="svgfill crack" viewBox="0 0 332 520" aria-hidden="true">
        <path
          className="d"
          d="M318 12 296 38 284 44 262 70M318 12 326 46 320 78M318 12 300 15 276 9M296 38 304 60"
        />
        <path d="M318 12 296 38 284 44 262 70M318 12 326 46 320 78M318 12 300 15 276 9M296 38 304 60" />
      </svg>
      <svg className="svgfill scratch" viewBox="0 0 332 520" aria-hidden="true">
        <path d="M236 128c5-8 9-6 8 0s-6 8-1 7 7-9 11-6-2 8 3 7" />
      </svg>
      <span className="stk m1">MERIDIAN</span>
      <span className="stk m2">
        <svg viewBox="0 0 40 40" aria-hidden="true">
          <ellipse
            cx="20"
            cy="20"
            rx="17"
            ry="9"
            stroke="#ece5d8"
            transform="rotate(-24 20 20)"
          />
          <circle cx="13" cy="23" r="4" fill="#ffd27a" stroke="none" />
          <circle cx="34" cy="12.5" r="2.4" fill="#56d4dc" stroke="none" />
        </svg>
      </span>
      <span className="ap-poly" />
    </>
  );
});

export const GlassAfter = memo(function AphelionGlassAfter() {
  return (
    <>
      <span className="stk m4">
        <span className="fluo">
          <b />
          <b />
          <i />
        </span>
      </span>
      <span className="ap-glow">
        <i className="sun" />
        <i className="planet" />
      </span>
    </>
  );
});
