// THIS IS AN APHELION UI FILE
// The Wastelander markings room's decor, from its mockup (the lab's markings-themes run, canvas/project/
// Main.dc.html), written by the themes-impl run's tools/decor.py. Its CSS is in
// styles/meridianos/markings-room/_wastelander.scss. Hand edits are marked HAND.
import { memo } from 'react';

export const Frame = memo(function WastelanderFrame() {
  return (
    <>
      <span className="wl-case" />
      <span className="wl-screw a" />
      <span className="wl-screw b" />
      <span className="wl-screw c" />
      <span className="wl-screw d" />
      <span className="wl-grille" />
      <span className="wl-dymo b">MIRROR 02</span>
      <span className="lamp wl-lamp" />
      <span className="wl-ian" />
    </>
  );
});

export const Glass = memo(function WastelanderGlass() {
  return (
    <>
      <span className="wl-scan" />
      <span className="wl-roll" />
      <span className="wl-vig" />
    </>
  );
});

// HAND: the powered scanner stays outside the glass decor's lights-off filter.
export const GlassAfter = memo(function WastelanderGlassAfter() {
  return (
    <span className="wl-radar" aria-hidden="true">
      <i />
      <b className="p1" />
      <b className="p2" />
    </span>
  );
});
