// THIS IS AN APHELION UI FILE
// The Electra markings room's decor, from its mockup (the lab's markings-themes run, canvas/project/
// Main.dc.html), written by the themes-impl run's tools/decor.py. Its CSS is in
// styles/meridianos/markings-room/_electra.scss. Hand edits are marked HAND.
import { memo } from 'react';
import { classes } from 'tgui-core/react';

import { keepPress } from './press';
import type { DecorProps } from './types';

export const Glass = memo(function ElectraGlass(props: DecorProps) {
  return (
    <>
      <span className="hud-time">{props.clock}</span>
      <span className="hud-env">
        <b>
          38<small>°C</small>
        </b>
        WATER · ECO
      </span>
      <span className="hud-keys">
        <button
          className={classes(['hk-light', props.lightsOff && 'on'])}
          aria-label="Lights"
          aria-pressed={props.lightsOff}
          onClick={props.onLights}
          onPointerDown={keepPress}
          onDoubleClick={keepPress}
          tabIndex={-1}
          type="button"
        >
          <svg viewBox="0 0 14 14">
            <path d="M5 10.5h4M5.5 12.5h3M7 1.5a3.6 3.6 0 0 0-2.2 6.5c.6.5.8 1 .8 1.6h2.8c0-.6.2-1.1.8-1.6A3.6 3.6 0 0 0 7 1.5z" />
          </svg>
        </button>
        <button
          className={classes(['hk-light', props.lightEffects && 'on'])}
          aria-label="Light effects"
          aria-pressed={props.lightEffects}
          onClick={props.onLightEffects}
          onPointerDown={keepPress}
          onDoubleClick={keepPress}
          tabIndex={-1}
          type="button"
        >
          <svg viewBox="0 0 14 14">
            <circle cx="7" cy="7" r="2.4" />
            <path d="M7 1v1.6M7 11.4V13M1 7h1.6M11.4 7H13M2.8 2.8l1.1 1.1M10.1 10.1l1.1 1.1M2.8 11.2l1.1-1.1M10.1 3.9l1.1-1.1" />
          </svg>
        </button>
        <span>
          <svg viewBox="0 0 14 14">
            <path d="M7 1.5c2 3 4 5 4 7.2a4 4 0 0 1-8 0C3 6.5 5 4.5 7 1.5z" />
          </svg>
        </span>
        <span>
          <svg viewBox="0 0 14 14">
            <path d="M7 1.5v5M4.2 3.6a4.5 4.5 0 1 0 5.6 0" />
          </svg>
        </span>
      </span>
      <span className="ycorner a" />
      <span className="ycorner b" />
      <span className="ycorner c" />
      <span className="ycorner d" />
    </>
  );
});
