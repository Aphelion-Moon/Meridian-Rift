// THIS IS AN APHELION UI FILE
// The Classic markings room's decor, from its mockup (the lab's markings-themes run, canvas/project/
// Main.dc.html), written by the themes-impl run's tools/decor.py. Its CSS is in
// styles/meridianos/markings-room/_classic.scss. Hand edits are marked HAND.
import { memo } from 'react';

export const Header = memo(function ClassicHeader() {
  return (
    <span className="washsign">
      <svg viewBox="0 0 24 24">
        <path d="M12 2c3 4.4 6 7.7 6 11.2A6 6 0 0 1 6 13.2C6 9.7 9 6.4 12 2z" />
      </svg>
      <span>
        EMPLOYEES MUST WASH HANDS
        <br />
        BEFORE RETURNING TO WORK
      </span>
    </span>
  );
});

export const Frame = memo(function ClassicFrame() {
  return <span className="lamp-fluor" />;
});

export const Glass = memo(function ClassicGlass() {
  return (
    <>
      <span className="honk">
        <svg viewBox="1 6 44 41" aria-hidden="true">
          <path d="M23 19c-8 0-13 6-13 13s5 13 13 13 13-6 13-13-5-13-13-13z" />
          <path d="M11 26c-4-3-9 0-7 4-4 1-3 7 1 7-2 3 1 7 5 5M35 26c4-3 9 0 7 4 4 1 3 7-1 7 2 3-1 7-5 5" />
          <path d="M16 27.5c1.5-1.8 3.5-1.8 5 0M25 27.5c1.5-1.8 3.5-1.8 5 0M15 37c4 6 12 6 16 0" />
          <path className="nose" d="M23 30.4a3 3 0 1 0 .01 0z" />
          <path d="M19 19l4-9 4 9M23 10l.5-2" />
        </svg>
        <b>HONK!</b>
      </span>
      <span className="stk n2">
        <span>out of soap</span>
        <b>AGAIN.</b>
        <i>ask the janitor</i>
      </span>
      <span className="screw a" />
      <span className="screw b" />
      <span className="screw c" />
      <span className="screw d" />
    </>
  );
});
