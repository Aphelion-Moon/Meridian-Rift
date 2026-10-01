// THIS IS AN APHELION UI FILE
// The Hephaestus markings room's decor, from its mockup (the lab's markings-themes run, canvas/project/
// Main.dc.html), written by the themes-impl run's tools/decor.py. Its CSS is in
// styles/meridianos/markings-room/_hephaestus.scss. Hand edits are marked HAND.
import { memo } from 'react';

import type { DecorProps } from './types';

export const Header = memo(function HephaestusHeader() {
  return (
    <>
      <span className="hx-pipe" />
      <span className="hx-gauge">
        <i className="a" />
        <i className="b" />
      </span>
    </>
  );
});

export const Frame = memo(function HephaestusFrame(props: DecorProps) {
  return (
    <>
      <span className="hx-frame" />
      <span className="lamp hx-lamp" />
      <span className="hx-wire" />
      <span className="hx-tag">
        LAST DELAM<b>{props.delamRounds}</b>SHIFTS AGO
      </span>
    </>
  );
});
