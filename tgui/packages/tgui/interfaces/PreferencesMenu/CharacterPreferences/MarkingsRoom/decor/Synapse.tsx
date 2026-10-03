// THIS IS AN APHELION UI FILE
// The Synapse markings room's decor, from its mockup (the lab's markings-themes run, canvas/project/
// Main.dc.html), written by the themes-impl run's tools/decor.py. Its CSS is in
// styles/meridianos/markings-room/_synapse.scss. Hand edits are marked HAND.
import { memo } from 'react';

export const Wall = memo(function SynapseWall() {
  return (
    <svg className="filament" viewBox="0 0 900 820" aria-hidden="true">
      <path d="M318 34C350 12 384 52 420 30S488 10 520 32 572 46 596 22" />
      <path className="c" d="M0 201C60 190 120 212 180 199S250 194 300 204" />
      <path d="M0 345C70 352 150 336 220 347S280 352 300 344" />
      <path className="c" d="M0 489C80 480 160 498 230 486S280 484 300 492" />
      <path d="M600 201C660 210 740 190 810 202S880 206 900 198" />
      <path
        className="c"
        d="M600 345C680 336 760 358 830 344S880 340 900 348"
      />
      <path d="M600 489C660 498 740 480 810 492S880 494 900 486" />
      <path d="M271 58C266 200 278 400 270 632" />
      <path className="c" d="M629 58C634 210 624 420 630 632" />
      <path d="M0 633C200 627 420 640 900 631" />
      <circle cx="420" cy="30" r="2.6" />
      <circle className="c" cx="520" cy="32" r="2.2" />
      <circle className="c" cx="96" cy="201" r="2.4" />
      <circle cx="268" cy="345" r="2.6" />
      <circle cx="164" cy="490" r="2.2" />
      <circle cx="742" cy="196" r="2.4" />
      <circle className="c" cx="631" cy="345" r="2.6" />
      <circle cx="820" cy="492" r="2.2" />
      <circle className="c" cx="271" cy="489" r="2.2" />
      <circle cx="630" cy="201" r="2.2" />
    </svg>
  );
});

export const Frame = memo(function SynapseFrame() {
  return (
    <>
      <span className="syn-frame" />
      <span className="syn-cut" />
      <span className="lamp syn-under" />
    </>
  );
});

export const Glass = memo(function SynapseGlass() {
  return (
    <span className="syn-chip">
      <svg viewBox="0 0 96 80" aria-hidden="true">
        <path
          className="tr"
          d="M30 32H14Q8 32 8 26V2M30 44H4M42 22V10Q42 4 48 4H74M54 22V14"
        />
        <circle className="nd" cx="8" cy="2" r="2.4" />
        <circle className="nd" cx="4" cy="44" r="2.4" />
        <circle className="nd" cx="74" cy="4" r="2.4" />
        <circle className="nd" cx="54" cy="14" r="2" />
        <rect className="bd" x="30" y="22" width="34" height="34" rx="4" />
        <path
          className="pn"
          d="M36 22V17M42 22V17M48 22V17M54 22V17M60 22V17M36 56V61M42 56V61M48 56V61M54 56V61M60 56V61M64 28H69M64 34H69M64 40H69M64 46H69M64 52H69M30 50H25M30 56H25"
        />
        <path
          className="kn"
          d="M39 46 46 33 55 44 39 46M46 33 47 28M55 44 59 48"
        />
        <circle className="nd" cx="39" cy="46" r="2.6" />
        <circle className="nd" cx="46" cy="33" r="2.6" />
        <circle className="nd" cx="55" cy="44" r="2.6" />
      </svg>
    </span>
  );
});

export const GlassAfter = memo(function SynapseGlassAfter() {
  return (
    <span className="holo b">
      nohax
      <span className="fluo">
        <b />
        <b />
        <i>nohax</i>
      </span>
    </span>
  );
});
