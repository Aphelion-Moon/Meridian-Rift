// THIS IS AN APHELION UI FILE
import { type CSSProperties, useEffect, useRef, useState } from 'react';
import { useBackend } from 'tgui/backend';
import { Icon } from 'tgui-core/components';

import type { Language, PreferencesMenuData } from '../types';

/** The least of a language only understood that can be set: Common Second Language's lowest setting. */
const UNDERSTANDING_MIN = 25;

/** How far along the track a level sits, from 0 to 1. */
type FillStyle = CSSProperties & { '--understanding-fill': number };

/** How much of what's said gets through at a level. */
function understandingLabel(level: number) {
  if (level >= 100) {
    return 'Understands every word';
  }
  if (level >= 90) {
    return 'Understands nearly every word';
  }
  if (level >= 65) {
    return 'Understands most words';
  }
  if (level >= 40) {
    return 'Understands some words';
  }
  return 'Understands a few words';
}

/**
 * How much of a language the character only understands gets through, from
 * UNDERSTANDING_MIN to every word, and a line in it as they would hear it. The
 * readout follows the slider as it moves; the level is sent when the slider is
 * let go and shown until the server answers.
 */
export function LanguageUnderstanding(props: { language: Language }) {
  const { act, data } = useBackend<PreferencesMenuData>();
  const { name } = props.language;
  const level = data.language_understanding?.[name] ?? 100;
  const sample = data.language_understanding_samples?.[name];
  const [pending, setPending] = useState<number>();
  // The server's level replaces the one the slider was let go at.
  useEffect(() => setPending(undefined), [level]);
  const shown = pending ?? level;
  const label = understandingLabel(shown);
  const fill: FillStyle = {
    '--understanding-fill':
      (shown - UNDERSTANDING_MIN) / (100 - UNDERSTANDING_MIN),
  };

  // React's onChange fires on every step of a drag; the native change event
  // fires once, when the slider is let go or a key moves it.
  const slider = useRef<HTMLInputElement>(null);
  useEffect(() => {
    const input = slider.current!;
    const send = () =>
      act('set_language_understanding', {
        language_name: name,
        level: Number(input.value),
      });
    input.addEventListener('change', send);
    return () => input.removeEventListener('change', send);
  }, [act, name]);

  return (
    <div className="LanguagesMenu__understanding">
      <div className="LanguagesMenu__understandingReadout">
        <span>{label}</span>
        <span className="LanguagesMenu__understandingPercent">{shown}%</span>
      </div>
      <input
        ref={slider}
        type="range"
        className="LanguagesMenu__understandingSlider"
        min={UNDERSTANDING_MIN}
        max={100}
        step={5}
        value={shown}
        aria-label={`How much ${name} is understood`}
        aria-valuetext={`${label}, ${shown}%`}
        style={fill}
        onChange={(event) => setPending(Number(event.target.value))}
      />
      {!!sample && (
        <div className="LanguagesMenu__understandingSample">
          <Icon name="ear-listen" />
          <q>{sample}</q>
        </div>
      )}
    </div>
  );
}
