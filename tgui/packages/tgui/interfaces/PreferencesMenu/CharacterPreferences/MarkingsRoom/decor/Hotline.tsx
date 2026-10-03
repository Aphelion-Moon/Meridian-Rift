// THIS IS AN APHELION UI FILE
// The Hotline markings room's decor, from its mockup (the lab's markings-themes run, canvas/project/
// Main.dc.html), written by the themes-impl run's tools/decor.py. Its CSS is in
// styles/meridianos/markings-room/_hotline.scss. Hand edits are marked HAND.
import { memo } from 'react';

export const Wall = memo(function HotlineWall() {
  return (
    <>
      <span className="ht-tube h" />
      <span className="ht-tube h2" />
      <span className="ht-tube l" />
      <span className="ht-tube r" />
    </>
  );
});

export const Header = memo(function HotlineHeader() {
  return (
    <span className="ht-sign">
      <svg className="ht-lips" viewBox="0 0 66 36" aria-hidden="true">
        <path
          className="t"
          d="M3 18C10 10 17 6 24 7.5C27.5 8.2 30.5 10.5 33 11.5C35.5 10.5 38.5 8.2 42 7.5C49 6 56 10 63 18C55 27 45 31 33 31C21 31 11 27 3 18ZM6 18C15 21 24 21.5 33 20C42 21.5 51 21 60 18"
        />
        <path
          className="c"
          d="M3 18C10 10 17 6 24 7.5C27.5 8.2 30.5 10.5 33 11.5C35.5 10.5 38.5 8.2 42 7.5C49 6 56 10 63 18C55 27 45 31 33 31C21 31 11 27 3 18ZM6 18C15 21 24 21.5 33 20C42 21.5 51 21 60 18"
        />
      </svg>
      <span className="ht-vip">
        vip<b>→</b>
      </span>
    </span>
  );
});

export const Frame = memo(function HotlineFrame() {
  return (
    <>
      <svg className="lamp ht-neon" viewBox="0 0 360 560" aria-hidden="true">
        <path className="t" d="M13 470V64A39 39 0 0 1 52 25H180" />
        <path className="c" d="M13 470V64A39 39 0 0 1 52 25H180" />
      </svg>
      <svg className="lamp ht-neon rd" viewBox="0 0 360 560" aria-hidden="true">
        <path className="cap" d="M113 543h12M13 477v-12" />
        <path
          className="t"
          d="M180 25H308A39 39 0 0 1 347 64V504A39 39 0 0 1 308 543H120"
        />
        <path
          className="c"
          d="M180 25H308A39 39 0 0 1 347 64V504A39 39 0 0 1 308 543H120"
        />
      </svg>
      <span className="ht-clip a" />
      <span className="ht-clip b" />
      <span className="ht-clip c" />
      <span className="ht-clip d" />
    </>
  );
});

export const Glass = memo(function HotlineGlass() {
  return (
    <>
      <svg className="ht-kiss a" viewBox="0 0 44 28" aria-hidden="true">
        <path d="M2 14C8 5 14 4 22 9c8-5 14-4 20 5-6 9-13 12-20 12S8 23 2 14z" />
        <path className="m" d="M3 14c6 2 12 3 19 1 7 2 13 1 19-1" />
      </svg>
      <span className="ht-xo">xoxo</span>
    </>
  );
});
