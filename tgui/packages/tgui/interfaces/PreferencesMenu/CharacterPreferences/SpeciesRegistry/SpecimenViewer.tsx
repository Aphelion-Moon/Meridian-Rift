// THIS IS AN APHELION UI FILE
import {
  type CSSProperties,
  type PointerEvent,
  useEffect,
  useRef,
  useState,
} from 'react';
import { Button, Stack } from 'tgui-core/components';

import { DiagnosticAcquisition } from '../../../common/DiagnosticAcquisition';
import type { SpeciesSelfPreview } from '../../types';
import { SPRITE_DIRS } from './constants';
import { PreviewFrame, SpeciesSprite } from './SpeciesSprite';

/** 32px frames at 8x: 256px, large enough to read markings and silhouettes. */
const VIEWER_SCALE = 8;
/** Pointer travel per quarter turn when dragging the specimen. */
const DRAG_STEP_PX = 28;
const TURNTABLE_MS = 650;

const DIR_LABELS = { south: 'S', west: 'W', north: 'N', east: 'E' } as const;

type Props = {
  icon: string;
  name: string;
  /** The character's own preview mob, shown instead of the species sprite. */
  self?: SpeciesSelfPreview;
  /** Called when the specimen is first turned to its body, to fetch those sprites. */
  onBody?: () => void;
};

type ViewerStyle = CSSProperties & { '--specimen-size': string };

/** Whether anyone can see the chamber: its window is showing and focused. */
function useWatched(): boolean {
  const [watched, setWatched] = useState(
    () => !document.hidden && document.hasFocus(),
  );

  useEffect(() => {
    const update = () => setWatched(!document.hidden && document.hasFocus());
    document.addEventListener('visibilitychange', update);
    window.addEventListener('focus', update);
    window.addEventListener('blur', update);
    return () => {
      document.removeEventListener('visibilitychange', update);
      window.removeEventListener('focus', update);
      window.removeEventListener('blur', update);
    };
  }, []);

  return watched;
}

type ChamberStyle = CSSProperties & { '--diagnostic-loader-progress': number };

/**
 * The inspected species in a chamber each theme dresses its own way. Turn it
 * with the buttons, the turntable or by dragging, in uniform or without. The
 * character's own species shows the character itself, as its preview shows it.
 */
export function SpecimenViewer(props: Props) {
  const { icon, name, self, onBody } = props;
  const [turn, setTurn] = useState(0);
  const [bare, setBare] = useState(false);
  const [spinning, setSpinning] = useState(false);
  // Diagnostic's acquisition reticle re-converges on each new specimen.
  const [acquired, setAcquired] = useState(1);
  const drag = useRef<{ x: number } | null>(null);
  // Chamber art and the turntable rest while nobody is looking.
  const watched = useWatched();

  const dir = SPRITE_DIRS[((turn % 4) + 4) % 4];
  const rotate = (steps: number) => setTurn((value) => value + steps);
  const specimen = self ? self.image : icon;

  useEffect(() => {
    if (!spinning || !watched) {
      return;
    }
    const timer = setInterval(() => rotate(1), TURNTABLE_MS);
    return () => clearInterval(timer);
  }, [spinning, watched]);

  useEffect(() => {
    setAcquired(0.15);
    const timer = setTimeout(() => setAcquired(1), 60);
    return () => clearTimeout(timer);
  }, [specimen]);

  const onPointerDown = (event: PointerEvent<HTMLDivElement>) => {
    event.currentTarget.setPointerCapture(event.pointerId);
    drag.current = { x: event.clientX };
  };
  const onPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    if (!drag.current) {
      return;
    }
    const travelled = event.clientX - drag.current.x;
    if (Math.abs(travelled) >= DRAG_STEP_PX) {
      rotate(travelled > 0 ? 1 : -1);
      drag.current = { x: event.clientX };
    }
  };
  const onPointerUp = () => {
    drag.current = null;
  };

  const chamberStyle: ChamberStyle = {
    '--diagnostic-loader-progress': acquired,
  };

  const viewerStyle: ViewerStyle = {
    '--specimen-size': `${32 * VIEWER_SCALE}px`,
  };

  const showing = self ? 'your character' : bare ? 'body' : 'in uniform';

  return (
    <div
      className="SpecimenViewer"
      style={viewerStyle}
      data-motion={watched ? 'running' : 'paused'}
    >
      <div
        className="SpecimenViewer__chamber"
        role="img"
        aria-label={`${name}, ${showing}, facing ${dir}`}
        style={chamberStyle}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
      >
        <span className="SpecimenViewer__backdrop" />
        <span className="SpecimenViewer__grid" />
        <DiagnosticAcquisition />
        <span className="SpecimenViewer__floor" />
        <span key={specimen} className="SpecimenViewer__figure">
          {self ? (
            <PreviewFrame preview={self} dir={dir} box={32 * VIEWER_SCALE} />
          ) : (
            <SpeciesSprite
              icon={icon}
              dir={dir}
              bare={bare}
              scale={VIEWER_SCALE}
            />
          )}
        </span>
        <span key={`sweep-${specimen}`} className="SpecimenViewer__sweep" />
        <span className="SpecimenViewer__glass" />
        <span className="SpecimenViewer__scale" />
        <span className="SpecimenViewer__corner SpecimenViewer__corner--nw" />
        <span className="SpecimenViewer__corner SpecimenViewer__corner--ne" />
        <span className="SpecimenViewer__corner SpecimenViewer__corner--sw" />
        <span className="SpecimenViewer__corner SpecimenViewer__corner--se" />
        <span className="SpecimenViewer__readout ConsoleReading">
          <span>{self ? 'You' : bare ? 'Body' : 'Uniform'}</span>
          <span>Facing {DIR_LABELS[dir]}</span>
        </span>
      </div>
      <Stack className="SpecimenViewer__controls" align="center" g={0.5}>
        <Stack.Item>
          <Button
            icon="undo"
            tooltip="Turn left"
            tooltipPosition="bottom"
            onClick={() => rotate(-1)}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="sync-alt"
            selected={spinning}
            tooltip={spinning ? 'Stop turntable' : 'Turntable'}
            tooltipPosition="bottom"
            onClick={() => setSpinning(!spinning)}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="redo"
            tooltip="Turn right"
            tooltipPosition="bottom"
            onClick={() => rotate(1)}
          />
        </Stack.Item>
        <Stack.Item grow />
        {!self && (
          <>
            <Stack.Item>
              <Button
                icon="tshirt"
                selected={!bare}
                tooltip="Uniform"
                tooltipPosition="bottom"
                onClick={() => setBare(false)}
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="child"
                selected={bare}
                tooltip="Body"
                tooltipPosition="bottom"
                onClick={() => {
                  setBare(true);
                  onBody?.();
                }}
              />
            </Stack.Item>
          </>
        )}
      </Stack>
    </div>
  );
}
