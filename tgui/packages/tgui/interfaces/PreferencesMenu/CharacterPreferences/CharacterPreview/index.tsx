// THIS IS AN APHELION UI FILE
import { useAtomValue } from 'jotai';
import { useLayoutEffect, useRef, useState } from 'react';
import { useBackend } from 'tgui/backend';
import { classes } from 'tgui-core/react';

import { DiagnosticLoader } from '../../../common/DiagnosticLoader';
import type { CharacterPreviewDrawing, PreferencesMenuData } from '../../types';
import { useServerPrefs } from '../../useServerPrefs';
import { PreviewCanvas, previewFit, TILE, useShownPreview } from './drawing';
import { previewFacing, previewTurnAtom } from './turn';

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
 */
export function CharacterPreview(props: Props) {
  const { width = '272px', height, className } = props;
  const { data } = useBackend<PreferencesMenuData>();
  const serverData = useServerPrefs();
  const drawing = data.character_preview;
  const box = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState<[number, number]>();

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
    >
      {!!size &&
        (drawing ? (
          <DrawnCharacter
            drawing={drawing}
            width={size[0]}
            height={size[1]}
            tile={tile}
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
};

/** The drawing facing the way the tabs have turned it, on its background. */
function DrawnCharacter(props: DrawnCharacterProps) {
  const { width, height, tile } = props;
  const shown = useShownPreview(props.drawing);
  const turn = useAtomValue(previewTurnAtom);
  const fit = previewFit(shown.preview, width, height, shown.bounds);

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
