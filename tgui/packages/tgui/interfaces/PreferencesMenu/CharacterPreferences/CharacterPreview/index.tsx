// THIS IS AN APHELION UI FILE
import { useAtomValue, useSetAtom } from 'jotai';
import { type RefObject, useLayoutEffect, useRef, useState } from 'react';
import { useBackend } from 'tgui/backend';
import { classes } from 'tgui-core/react';

import { DiagnosticLoader } from '../../../common/DiagnosticLoader';
import type { CharacterPreviewDrawing, PreferencesMenuData } from '../../types';
import { useServerPrefs } from '../../useServerPrefs';
import {
  PreviewCanvas,
  previewFit,
  TILE,
  useShownPreview,
  zoomedScale,
} from './drawing';
import { usePreviewGestures } from './gestures';
import { previewFacing, previewTurnAtom, turnPreviewBy } from './turn';

type Props = {
  /** The box's CSS size. It fills it. */
  width?: string;
  height: string;
  className?: string;
};

/**
 * The character preview every tab of character setup shows: the one drawing
 * the server makes of the character, turned by the page and stood on the
 * chosen background, as large as a whole-number scale fits the box. A loader
 * shows while a newer drawing is on its way.
 *
 * Dragging across it turns the character, a quarter per DRAG_STEP pixels, and
 * the wheel zooms it a whole step at a time, from 1x to twice the fit.
 * Double-clicking goes back to the fit.
 */
export function CharacterPreview(props: Props) {
  const { width = '272px', height, className } = props;
  const { data } = useBackend<PreferencesMenuData>();
  const serverData = useServerPrefs();
  const drawing = data.character_preview;
  const box = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState<[number, number]>();
  const [zoom, setZoom] = useState(0);
  // The fitted scale the drawing last had, which bounds the zoom.
  const fitScale = useRef(1);
  const turnBy = useSetAtom(turnPreviewBy);
  const gestures = usePreviewGestures(box, {
    onTurn: turnBy,
    onZoom: (steps) =>
      setZoom((value) => {
        const base = fitScale.current;
        // Stored within reach, so wheeling back always moves at once.
        return zoomedScale(base, value + steps) - base;
      }),
  });

  useLayoutEffect(() => {
    const element = box.current;
    if (!element) {
      return;
    }
    const measure = () => setSize([element.clientWidth, element.clientHeight]);
    measure();
    if (typeof ResizeObserver === 'undefined') {
      return;
    }
    const observer = new ResizeObserver(measure);
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  const tile =
    serverData?.background_state?.tiles?.[
      data.character_preferences?.misc?.background_state
    ];

  return (
    <div
      ref={box}
      className={classes(['CharacterPreview', className])}
      style={{ width, height }}
      onDoubleClick={() => setZoom(0)}
      {...gestures}
    >
      {!!size &&
        (drawing ? (
          <DrawnCharacter
            drawing={drawing}
            width={size[0]}
            height={size[1]}
            tile={tile}
            zoom={zoom}
            fitScale={fitScale}
          />
        ) : (
          <PreviewBackground tile={tile} fit={previewFit(undefined, ...size)} />
        ))}
      {(!drawing || !!data.character_preview_pending) && (
        <span className="CharacterPreview__drawing">
          <DiagnosticLoader
            size="compact"
            label={null}
            ariaLabel="Drawing your character"
          />
        </span>
      )}
    </div>
  );
}

type DrawnCharacterProps = {
  drawing: CharacterPreviewDrawing;
  width: number;
  height: number;
  tile?: string;
  /** Whole steps added to the fitted scale. */
  zoom: number;
  /** Told the fitted scale, which bounds the zoom. */
  fitScale: RefObject<number>;
};

/** The drawing facing the way the tabs have turned it, on its background. */
function DrawnCharacter(props: DrawnCharacterProps) {
  const { width, height, tile, zoom, fitScale } = props;
  const shown = useShownPreview(props.drawing);
  const turn = useAtomValue(previewTurnAtom);
  const fit = previewFit(shown.preview, width, height, shown.bounds, zoom);

  useLayoutEffect(() => {
    fitScale.current = fit.fitScale;
  });

  return (
    <>
      <PreviewBackground tile={tile} fit={fit} />
      <PreviewCanvas
        className="CharacterPreview__figure"
        shown={shown}
        dir={previewFacing(turn)}
        scale={fit.scale}
        x={fit.x}
        y={fit.y}
      />
    </>
  );
}

type PreviewBackgroundProps = {
  tile?: string;
  fit: ReturnType<typeof previewFit>;
};

/** The background's tile repeated at the character's scale, one of them under the character's own tile. */
function PreviewBackground(props: PreviewBackgroundProps) {
  const { tile, fit } = props;
  if (!tile) {
    return null;
  }
  const size = TILE * fit.scale;
  return (
    <span
      className="CharacterPreview__background"
      style={{
        backgroundImage: `url("${tile}")`,
        backgroundSize: `${size}px ${size}px`,
        backgroundPosition: `${fit.x - size / 2}px ${fit.y - size}px`,
      }}
    />
  );
}
