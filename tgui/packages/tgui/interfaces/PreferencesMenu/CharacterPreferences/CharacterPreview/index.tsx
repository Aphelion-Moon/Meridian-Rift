// THIS IS AN APHELION UI FILE
import { useAtomValue, useSetAtom } from 'jotai';
import {
  type CSSProperties,
  Fragment,
  memo,
  type ReactNode,
  type RefObject,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
} from 'react';
import { useBackend } from 'tgui/backend';
import { classes } from 'tgui-core/react';

import { DiagnosticLoader } from '../../../common/DiagnosticLoader';
import { bloomSize, LIGHTS_OFF_SHADE } from '../../../common/LightsOff';
import type { CharacterPreviewDrawing, PreferencesMenuData } from '../../types';
import { useServerPrefs } from '../../useServerPrefs';
import { useArrival } from './arrival';
import {
  PreviewCanvas,
  type PreviewView,
  previewFit,
  TILE,
  useShownPreview,
  zoomedScale,
} from './drawing';
import { usePreviewGestures } from './gestures';
import { PreviewLightKey, previewLightsOffAtom } from './lights';
import { createPreviewPan, type PreviewPan } from './pan';
import { previewFacing, previewTurnAtom, turnPreviewBy } from './turn';

/**
 * What a tab shows the character for, which the preview's frame marks with a
 * small motif: a portrait's corners (Character), a fitting mirror's glass and
 * clips (Loadout), or a scanner's rule along the character's tile (Augments+).
 * The club mirror (Augments+ Markings, see MarkingsRoom) frames the glass
 * itself, so its motif draws no frame at all, and neither does the augments
 * stage's scan chamber (MarkingsRoom/augments).
 */
export type PreviewMotif =
  | 'portrait'
  | 'mirror'
  | 'scanner'
  | 'club'
  | 'chamber';

type Props = {
  /** The box's CSS size. It fills it. */
  width?: string;
  height: string;
  className?: string;
  /** What the tab shows the character for. A portrait unless it says. */
  motif?: PreviewMotif;
  /** The largest scale the fit may take, in place of a tile filling the box's shorter side. */
  maxScale?: number;
  /**
   * Drawn over the character, in its arrival with it, lined up with it however
   * it turns and zooms. Each layer marked `data-preview-pan` pans with it. They
   * sit beside the character's canvas, so a layer can blend with it.
   */
  overlay?: (view: PreviewView) => ReactNode;
  /** A press on the preview let go before it dragged, where it went down, in page pixels. */
  onTap?: (x: number, y: number) => void;
  /**
   * The lights switch as a key on the frame, at the foot of the portrait or
   * the mirror's glass, in place of a button among the tab's controls.
   */
  lightKey?: boolean;
  /** In front of the frame, such as what is stuck on a mirror's glass. Panned with the character when marked `data-preview-pan`. */
  children?: ReactNode;
  /** Lit whatever the tabs' lights switch says, as the augments stage's scan chamber always is. */
  lit?: boolean;
};

/**
 * The character preview every tab of character setup shows: the one drawing
 * the server makes of the character, turned by the page and stood on the
 * chosen background, as large as a whole-number scale fits the box. A loader
 * shows while a newer drawing is on its way.
 *
 * The theme frames it in its own materials, on the box's edge, and marks what
 * the tab shows it for; see _character_preview.scss. The character comes in
 * the theme's own way, on the tab opening and for each other character; see
 * _portrait-arrival.scss.
 *
 * Dragging across it turns the character, a quarter per DRAG_STEP pixels, and
 * the wheel zooms it a whole step at a time, from 1x to twice the fit. A drag
 * that sets off up or down pans it instead, every way until the pointer lets
 * go, as far as brings any part of the character to the middle. Double-clicking
 * goes back to the fit, unpanned. The frame stays put through all of it.
 */
export function CharacterPreview(props: Props) {
  const {
    width = '272px',
    height,
    className,
    motif = 'portrait',
    maxScale,
    overlay,
    onTap,
    lightKey,
    children,
    lit,
  } = props;
  const { data } = useBackend<PreferencesMenuData>();
  const serverData = useServerPrefs();
  const drawing = data.character_preview;
  const box = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState<[number, number]>();
  const [zoom, setZoom] = useState(0);
  // The fitted scale the drawing last had, which bounds the zoom.
  const fitScale = useRef(1);
  // The same pan for as long as the box is shown.
  const [pan] = useState(() => createPreviewPan(box));
  const turnBy = useSetAtom(turnPreviewBy);
  const gestures = usePreviewGestures(box, {
    onTurn: turnBy,
    onZoom: (steps) =>
      setZoom((value) => {
        const base = fitScale.current;
        // Stored within reach, so wheeling back always moves at once.
        return zoomedScale(base, value + steps) - base;
      }),
    onPanStart: pan.start,
    onPan: pan.move,
    onPanEnd: pan.end,
    onTap,
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

  // The club mirror has its own glass behind the portrait, with no tiled floor,
  // and the scan chamber its own grid. Their hidden background must not be
  // baked back into the emissive canvas.
  const tile =
    motif === 'club' || motif === 'chamber'
      ? undefined
      : serverData?.background_state?.tiles?.[
          data.character_preferences?.misc?.background_state
        ];
  const dark = useAtomValue(previewLightsOffAtom) && !lit;
  const bloom = bloomSize(data.game_preferences?.emissive_bloom);

  return (
    <div
      ref={box}
      className={classes([
        'CharacterPreview',
        `CharacterPreview--${motif}`,
        className,
      ])}
      style={{ width, height }}
      onDoubleClick={() => {
        pan.reset();
        setZoom(0);
      }}
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
            pan={pan}
            dark={dark}
            bloom={bloom}
            maxScale={maxScale}
            overlay={overlay}
          />
        ) : (
          <>
            <PreviewBackground
              tile={tile}
              fit={previewFit(undefined, ...size, undefined, 0, maxScale)}
            />
            {dark && <PreviewDark />}
          </>
        ))}
      <PreviewFrame />
      {lightKey && <PreviewLightKey />}
      {children}
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
  /** Told the scale and how far it may pan, before the browser paints. */
  pan: PreviewPan;
  /** Whether the lights are off, so it shows what glows. */
  dark: boolean;
  /** How far what glows blooms with the lights off. */
  bloom: number;
  /** The largest scale the fit may take. */
  maxScale?: number;
  /** Drawn over the character, in its arrival with it; see Props. */
  overlay?: (view: PreviewView) => ReactNode;
};

/**
 * The drawing facing the way the tabs have turned it, on its background. Each
 * character it shows comes in with the theme's arrival, once its drawing has
 * loaded: the arrival's wrapper and the sweep over it are made anew for it.
 * What a tab draws over the character arrives with it, and pans with it.
 */
function DrawnCharacter(props: DrawnCharacterProps) {
  const { width, height, tile, zoom, fitScale, pan, dark, bloom, maxScale } =
    props;
  const shown = useShownPreview(props.drawing);
  const arrival = useArrival(shown);
  const floor = useFloorTile(dark ? tile : undefined);
  const turn = useAtomValue(previewTurnAtom);
  const dir = previewFacing(turn);
  // The frame's scanner rule stays where the fit puts it, whatever the zoom.
  const fitted = previewFit(
    shown.preview,
    width,
    height,
    shown.bounds,
    0,
    maxScale,
  );
  const fit = zoom
    ? previewFit(shown.preview, width, height, shown.bounds, zoom, maxScale)
    : fitted;

  useLayoutEffect(() => {
    fitScale.current = fit.fitScale;
    pan.place(fit.scale, fit.panBounds);
  });

  return (
    <>
      <PreviewBackground tile={tile} fit={fit} />
      {dark && <PreviewDark />}
      {!!shown.image && (
        <Fragment key={arrival}>
          <span className="CharacterPreview__arrival">
            <PreviewCanvas
              className="CharacterPreview__figure"
              shown={shown}
              dir={dir}
              scale={fit.scale}
              x={fit.x}
              y={fit.y}
              dark={dark}
              bloom={bloom}
              floor={floor}
            />
            {props.overlay?.({
              shown,
              dir,
              scale: fit.scale,
              x: fit.x,
              y: fit.y,
              dark,
            })}
          </span>
          <span className="CharacterPreview__sweep" />
        </Fragment>
      )}
      <PreviewRule fit={fitted} />
    </>
  );
}

/** The background's tile, loaded, while it's wanted: the floor the bloom falls on with the lights off. */
function useFloorTile(tile: string | undefined) {
  const [floor, setFloor] = useState<HTMLImageElement>();
  useEffect(() => {
    setFloor(undefined);
    if (!tile) {
      return;
    }
    let current = true;
    const image = new Image();
    image.onload = () => current && setFloor(image);
    image.src = tile;
    return () => {
      current = false;
    };
  }, [tile]);
  return floor;
}

/**
 * The dark with the lights off, over the floor and under the character: the
 * floor keeps the light the character's unlit pixels keep, but for where the
 * bloom falls on it, which the character's canvas draws. The frame stays lit.
 */
function PreviewDark() {
  return (
    <span
      className="CharacterPreview__dark"
      style={{ backgroundColor: LIGHTS_OFF_SHADE }}
    />
  );
}

const CORNERS = ['nw', 'ne', 'sw', 'se'] as const;

/**
 * The theme's casing round the preview, and the parts the tab's motif draws
 * with: glass, corner marks, and clips on the glass nearest each corner. The
 * styles decide which show. Nothing in it changes, so it never draws again.
 */
export const PreviewFrame = memo(function PreviewFrame() {
  return (
    <>
      <span className="CharacterPreview__glass" />
      <span className="CharacterPreview__case" />
      <span className="CharacterPreview__trim" />
      {CORNERS.map((corner) => (
        <span
          key={`mark-${corner}`}
          className={`CharacterPreview__mark CharacterPreview__mark--${corner}`}
        />
      ))}
      {CORNERS.map((corner) => (
        <span
          key={`clip-${corner}`}
          className={`CharacterPreview__clip CharacterPreview__clip--${corner}`}
        />
      ))}
    </>
  );
});

/**
 * The scanner's rule: the character's own tile from its floor to its top, as
 * the fit shows it, ticked in the drawing's pixels at that scale. It is part
 * of the frame, so it stays put while the view zooms and pans.
 */
function PreviewRule(props: { fit: ReturnType<typeof previewFit> }) {
  const { fit } = props;
  const size = TILE * fit.scale;
  return (
    <span
      className="CharacterPreview__rule"
      style={
        {
          top: `${fit.y - size}px`,
          height: `${size + 1}px`,
          '--preview-pixel': `${fit.scale}px`,
        } as CSSProperties
      }
    />
  );
}

type PreviewBackgroundProps = {
  tile?: string;
  fit: ReturnType<typeof previewFit>;
};

/**
 * The background's tile repeated at the character's scale, one of them under
 * the character's own tile. It reaches a tile past the box above and to the
 * left, so a pan can move it by the pan less whole tiles, which looks the same
 * as the whole pan and never uncovers the box.
 */
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
        top: `${-size}px`,
        left: `${-size}px`,
        backgroundImage: `url("${tile}")`,
        backgroundSize: `${size}px ${size}px`,
        backgroundPosition: `${fit.x - size / 2}px ${fit.y - size}px`,
      }}
    />
  );
}
