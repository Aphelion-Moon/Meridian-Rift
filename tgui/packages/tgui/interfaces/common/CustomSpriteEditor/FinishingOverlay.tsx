// THIS IS AN APHELION UI FILE
import { useEffect, useRef, useState } from 'react';
import { classes } from 'tgui-core/react';
import { DiagnosticLoader } from '../DiagnosticLoader';

/** How long "Interrupted!" stays up before the overlay fades, and how long the fade takes. */
const INTERRUPTED_MS = 1200;
const FADE_MS = 400;

type Phase = 'applying' | 'interrupted' | 'fading';

/**
 * Covers a salon editor while the artist's timed finishing touches run, filling the theme's
 * loader over their length. Finished work closes the window; work cut short leaves it open, so the
 * overlay says so, fades, and the drawing carries on as it was.
 */
export const FinishingOverlay = (props: {
  applying: boolean;
  /** How long the finishing touches take, in milliseconds. */
  duration: number;
}) => {
  const { applying, duration } = props;
  const [phase, setPhase] = useState<Phase | null>(null);
  const [progress, setProgress] = useState(0);
  const started = useRef(0);

  useEffect(() => {
    if (!applying) {
      // The work stopped and the window is still open, so it was cut short.
      setPhase((current) => (current === 'applying' ? 'interrupted' : current));
      return;
    }
    started.current = Date.now();
    setProgress(0);
    setPhase('applying');
    const timer = setInterval(
      () => setProgress(Math.min(1, (Date.now() - started.current) / duration)),
      50,
    );
    return () => clearInterval(timer);
  }, [applying, duration]);

  useEffect(() => {
    if (phase !== 'interrupted' && phase !== 'fading') return;
    const timer = setTimeout(
      () => setPhase(phase === 'interrupted' ? 'fading' : null),
      phase === 'interrupted' ? INTERRUPTED_MS : FADE_MS,
    );
    return () => clearTimeout(timer);
  }, [phase]);

  if (!phase) return null;
  return (
    <div
      className={classes([
        'CustomSpriteEditor__finishing',
        phase === 'fading' && 'CustomSpriteEditor__finishing--fading',
      ])}
      aria-live="polite"
    >
      <DiagnosticLoader
        size="large"
        value={progress}
        label={
          phase === 'applying' ? 'Applying finishing touches…' : 'Interrupted!'
        }
      />
    </div>
  );
};
