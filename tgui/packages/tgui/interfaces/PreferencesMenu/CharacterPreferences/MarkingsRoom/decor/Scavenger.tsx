// THIS IS AN APHELION UI FILE
// The Scavenger markings room's decor, from its mockup (the lab's markings-themes run, canvas/project/
// Main.dc.html), written by the themes-impl run's tools/decor.py. Its CSS is in
// styles/meridianos/markings-room/_scavenger.scss. Hand edits are marked HAND.
import { memo } from 'react';

export const Frame = memo(function ScavengerFrame() {
  return (
    <>
      <span className="sv-frame" />
      <span className="sv-weld a" />
      <span className="sv-weld b" />
      <span className="sv-bolt a" />
      <span className="sv-bolt b" />
      <span className="sv-bolt c" />
      <span className="sv-bolt d" />
      <span className="sv-cord" />
      <span className="lamp sv-bulb">
        <i />
      </span>
      <span className="sv-tape t1" />
      <span className="sv-tape t2" />
      <span className="sv-tape t3" />
    </>
  );
});

export const Glass = memo(function ScavengerGlass() {
  return (
    <>
      <svg className="svgfill crack" viewBox="0 0 332 520" aria-hidden="true">
        <path
          className="d"
          d="M70 440 22 472M70 440 8 404M70 440 58 516M70 440 128 470 170 518M70 440 108 384 150 330M70 440 42 362 30 300M62 430a12 12 0 0 1 18 2M54 448a20 20 0 0 1 2-22M236 6 222 62 228 112M222 62 196 84"
        />
        <path d="M70 440 22 472M70 440 8 404M70 440 58 516M70 440 128 470 170 518M70 440 108 384 150 330M70 440 42 362 30 300M62 430a12 12 0 0 1 18 2M54 448a20 20 0 0 1 2-22M236 6 222 62 228 112M222 62 196 84" />
      </svg>
      <svg className="svgfill scratch" viewBox="0 0 332 520" aria-hidden="true">
        <path d="M262 470v24M268 469v25M274 470v24M280 470v24M257 488l28-14M294 470v24M300 469v25" />
      </svg>
    </>
  );
});
