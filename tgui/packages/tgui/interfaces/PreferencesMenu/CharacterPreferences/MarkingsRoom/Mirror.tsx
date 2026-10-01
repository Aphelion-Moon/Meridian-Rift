// THIS IS AN APHELION UI FILE
import {
  type CSSProperties,
  type MutableRefObject,
  useLayoutEffect,
  useMemo,
  useRef,
} from 'react';

import { CharacterPreview } from '../CharacterPreview';
import {
  drawPreviewFacing,
  type PreviewView,
  previewFramePoint,
  previewFrameStyle,
  TILE,
} from '../CharacterPreview/drawing';
import { type CustomMarkingView, drawPainted, paintedPixels } from './customs';
import { type DecorProps, ROOM_DECOR, Tubes } from './decor';
import { facingImage } from './facing';
import {
  type FrameRegions,
  frameRegions,
  type MarkingRegions,
  regionAt,
  regionBounds,
  regionMask,
} from './regions';
import { drawSprite, type Sprite, tintedSprite, useSprites } from './sprites';
import type { ThumbMarking } from './Thumb';
import { ROOM_THEMES, type RoomTheme } from './themes';
import { useTried } from './tryOn';

/**
 * The club's glass, which the character's view is centred on in every room:
 * its size, and where it stands in the room.
 */
const GLASS_WIDTH = 332;
const GLASS_HEIGHT = 520;
const CLUB_GLASS = ROOM_THEMES.cyberpunk.glass;
/** How far the view reaches past the club's glass each way: past any room's glass. */
const VIEW_MARGIN = 48;
/** As large as the mirror shows a character: a tile 384px across. */
const MIRROR_SCALE = 12;

/** What the mirror lights on the character. */
export type MirrorLights = {
  /** The zone the pointer is on, on a card or the body: haloed, and the rest of the glass dimmed round it. */
  zone: string | null;
  /** A worn marking to light, in its colour: the one the pointer is on in its card. */
  marking: ThumbMarking | null;
  /** A custom drawing to light: the one whose card slot the pointer is on. */
  custom: CustomMarkingView | null;
  /**
   * While a drawer is open: the markings a pick puts on, by its name. The one
   * the pointer is trying on (tryOn.ts) shimmers over what the character wears.
   */
  tryOn: ((name: string) => ThumbMarking[]) | null;
  /** A marking just put on or painted, inked in while the server draws it. */
  ink: { serial: number; marking: ThumbMarking } | null;
};

/** Where the character stands in the glass, kept for pointing at it and for paint to fly to. */
export type MirrorAnchor = {
  /** One facing's frame, as the glass shows it; its page box maps page pixels to frame pixels. */
  frame: HTMLElement | null;
  view: PreviewView | null;
  regions: FrameRegions | null;
};

type Props = {
  theme: RoomTheme;
  /** What the room's decor shows: the clock, the lights, the engine's record. */
  decor: DecorProps;
  lights: MirrorLights;
  regions?: MarkingRegions;
  anchor: MutableRefObject<MirrorAnchor>;
  /** Where the dimming centres, in glass pixels, or null for none. */
  spot: [number, number] | null;
  /** Told where the character stands whenever that changes. */
  onPlaced: () => void;
  /** The pointer is on a zone of the body, or off it. */
  onPoint: (zone: string | null) => void;
  /** A zone of the body was clicked. */
  onPick: (zone: string) => void;
};

/**
 * The room's mirror, as its theme hangs it: the club's is a frameless glass
 * held by four clips, a neon tube above it and another down its side, lighting
 * the character from both; other rooms frame it their own ways and light it
 * with their own lamps. What is stuck on the glass is in front of the
 * character. The character is the server's drawing, as every tab shows it;
 * the mirror lights it, halos the part the pointer is on, and shows markings
 * tried on. It stands where the club's does in every room, its view reaching
 * past the room's own glass, which clips it.
 */
export function Mirror(props: Props) {
  const { theme, decor, lights, regions, anchor, spot, onPlaced } = props;
  const { onPoint, onPick } = props;
  const { Frame, Glass, GlassAfter } = ROOM_DECOR[theme.id];

  const zoneAt = (clientX: number, clientY: number) => {
    const { frame, view, regions: map } = anchor.current;
    if (!frame || !view || !map) {
      return null;
    }
    const box = frame.getBoundingClientRect();
    if (!box.width || !box.height) {
      return null;
    }
    const { width, height } = view.shown.preview;
    return (
      regionAt(
        map,
        ((clientX - box.left) / box.width) * width,
        ((clientY - box.top) / box.height) * height,
      ) ?? null
    );
  };

  return (
    <div className="MarkingsRoom__mirror">
      {theme.tubes && <Tubes />}
      {!!Frame && <Frame {...decor} />}
      <div
        className={`MarkingsRoom__glass${decor.lightEffects ? '' : ' MarkingsRoom__glass--plain'}`}
        data-zone={lights.zone ?? undefined}
        onPointerMove={(event) => {
          // A held pointer is turning or panning the character.
          if (!event.buttons) {
            onPoint(zoneAt(event.clientX, event.clientY));
          }
        }}
        onPointerLeave={() => onPoint(null)}
      >
        {theme.blacklight && <span className="MarkingsRoom__uvTube" />}
        <span className="MarkingsRoom__behind" />
        <div
          className="MarkingsRoom__view"
          style={{
            left: `${CLUB_GLASS[0] - theme.glass[0] - VIEW_MARGIN}px`,
            top: `${CLUB_GLASS[1] - theme.glass[1] - VIEW_MARGIN}px`,
          }}
        >
          <CharacterPreview
            motif="club"
            width={`${GLASS_WIDTH + 2 * VIEW_MARGIN}px`}
            height={`${GLASS_HEIGHT + 2 * VIEW_MARGIN}px`}
            maxScale={MIRROR_SCALE}
            lit={!decor.lightEffects}
            onTap={(x, y) => {
              const zone = zoneAt(x, y);
              if (zone) {
                onPick(zone);
              }
            }}
            overlay={(view) => (
              <MirrorOverlay
                view={view}
                lights={lights}
                regions={regions}
                anchor={anchor}
                rims={decor.lightEffects}
                blacklight={theme.blacklight}
                onPlaced={onPlaced}
              />
            )}
          >
            <span
              className={`MarkingsRoom__spot${spot ? ' MarkingsRoom__spot--on' : ''}`}
              data-preview-pan=""
              style={
                spot
                  ? ({
                      '--spot-x': `${Math.round(spot[0])}px`,
                      '--spot-y': `${Math.round(spot[1])}px`,
                    } as CSSProperties)
                  : undefined
              }
            />
          </CharacterPreview>
        </div>
        <span className="MarkingsRoom__decor" aria-hidden="true">
          {!!Glass && <Glass {...decor} />}
        </span>
        {/* Out of the decor, which the dark dims, but as hidden from readers. */}
        {!!GlassAfter && (
          <span aria-hidden="true">
            <GlassAfter {...decor} />
          </span>
        )}
        <span className="MarkingsRoom__glare" />
      </div>
    </div>
  );
}

type OverlayProps = {
  view: PreviewView;
  lights: MirrorLights;
  regions?: MarkingRegions;
  anchor: MutableRefObject<MirrorAnchor>;
  /** Whether the room's lamps rim the character (its light effects). */
  rims: boolean;
  /** Whether the room's UV tube lights the character when the lights go out. */
  blacklight: boolean;
  onPlaced: () => void;
};

/**
 * Everything the mirror draws on the character, each lined up with its
 * frame: the neon's rim light on its edges, the halo round the part the
 * pointer is on, a lit marking or drawing, and markings tried on. Marking
 * sprites face south, so those show only while the character does.
 */
function MirrorOverlay(props: OverlayProps) {
  const { view, lights, regions, anchor, rims, blacklight, onPlaced } = props;
  const { shown, dir, scale, x, y } = view;
  const { preview, image } = shown;
  const frame = useRef<HTMLSpanElement>(null);
  const map = useMemo(
    () => (regions ? frameRegions(preview, regions, dir) : undefined),
    [preview, regions, dir],
  );
  const facingMask = useMemo(
    () => (image ? facingImage(image, preview, dir) : undefined),
    [image, preview, dir],
  );
  const zoneMask = useMemo(
    () => (map && lights.zone ? regionMask(map, lights.zone) : undefined),
    [map, lights.zone],
  );

  // Where the character stands, for pointing at it and for paint to fly to.
  useLayoutEffect(() => {
    anchor.current = { frame: frame.current, view, regions: map ?? null };
    onPlaced();
  }, [preview.id, dir, scale, x, y, map]);

  const style = previewFrameStyle(preview, scale, x, y);
  const tile = {
    '--tile-left': `${preview.x * scale}px`,
    '--tile-top': `${(preview.height - preview.y - TILE) * scale}px`,
    '--tile-bottom': `${preview.y * scale}px`,
    '--pixel': `${scale}px`,
  } as CSSProperties;
  const south = dir === 'south';

  const rim = rims &&
    facingMask && {
      ...style,
      ...tile,
      maskImage: `url(${facingMask})`,
      WebkitMaskImage: `url(${facingMask})`,
    };

  return (
    <>
      {/* The neon on the character's edges: screened onto its canvas, so these sit beside it. */}
      {!!rim && (
        <>
          <span
            className="MarkingsRoom__rim MarkingsRoom__rim--top"
            data-preview-pan=""
            style={rim}
          />
          <span
            className="MarkingsRoom__rim MarkingsRoom__rim--side"
            data-preview-pan=""
            style={rim}
          />
          {blacklight && (
            <span
              className="MarkingsRoom__rim MarkingsRoom__rim--uv"
              data-preview-pan=""
              style={rim}
            />
          )}
        </>
      )}
      <span className="MarkingsRoom__overlay" data-preview-pan="">
        <span ref={frame} className="MarkingsRoom__frame" style={style} />
        {!!zoneMask && (
          <span
            key={lights.zone}
            className="MarkingsRoom__halo"
            style={{
              ...style,
              maskImage: `linear-gradient(#000 0 0), url(${zoneMask})`,
              WebkitMaskImage: `linear-gradient(#000 0 0), url(${zoneMask})`,
            }}
          >
            <span
              className="MarkingsRoom__haloZone"
              style={{
                maskImage: `url(${zoneMask})`,
                WebkitMaskImage: `url(${zoneMask})`,
              }}
            />
          </span>
        )}
        {south && !!lights.tryOn && (
          <TriedOn view={view} tryOn={lights.tryOn} />
        )}
        {south && !!lights.ink && (
          <MarkingLayer
            key={lights.ink.serial}
            className="MarkingsRoom__ink"
            view={view}
            markings={[lights.ink.marking]}
          />
        )}
        {south && !!lights.marking && (
          <MarkingLayer
            className="MarkingsRoom__lit"
            view={view}
            markings={[lights.marking]}
          />
        )}
        {!!lights.custom && (
          <FrameCanvas
            className="MarkingsRoom__lit"
            view={view}
            paint={(context, left, top) => {
              const drawing = lights.custom as CustomMarkingView;
              drawPainted(
                context,
                paintedPixels(drawing, dir),
                left - (drawing.width - TILE) / 2,
                top,
                1,
              );
            }}
            paintKey={lights.custom}
          />
        )}
      </span>
    </>
  );
}

/**
 * Markings tried on, shimmering over what the character wears: the pick the
 * drawer's pointer is on. Only this draws again as the pointer moves.
 */
function TriedOn(props: {
  view: PreviewView;
  tryOn: (name: string) => ThumbMarking[];
}) {
  const { view, tryOn } = props;
  const tried = useTried();
  const ghosts = tried ? tryOn(tried) : [];
  if (!ghosts.length) {
    return null;
  }
  return (
    <MarkingLayer
      key={ghosts.map((ghost) => ghost.icon).join()}
      className="MarkingsRoom__ghost"
      view={view}
      markings={ghosts}
    />
  );
}

/** Markings drawn on the character's tile in their colours, once their sprites can be drawn. */
function MarkingLayer(props: {
  view: PreviewView;
  markings: ThumbMarking[];
  className: string;
}) {
  const { view, markings, className } = props;
  const sprites = useSprites(
    markings.map((marking) => marking.nativeIcon ?? marking.icon),
  );
  if (sprites.some((sprite) => !sprite)) {
    return null;
  }
  return (
    <FrameCanvas
      className={className}
      view={view}
      paint={(context, left, top) => {
        markings.forEach((marking, index) => {
          drawSprite(
            context,
            tintedSprite(sprites[index] as Sprite, marking.color),
            left,
            top,
            1,
            TILE,
          );
        });
      }}
      paintKey={markings
        .map((marking) => (marking.nativeIcon ?? marking.icon) + marking.color)
        .join()}
    />
  );
}

/**
 * A canvas lined up with the character's frame, painted in the tile's own
 * pixels: `paint` draws with the tile's top left at `left` and `top`, and
 * height's rows then move as the drawing's do.
 */
function FrameCanvas(props: {
  view: PreviewView;
  paint: (context: CanvasRenderingContext2D, left: number, top: number) => void;
  paintKey: unknown;
  className: string;
}) {
  const { view, paint, paintKey, className } = props;
  const { shown, dir, scale, x, y } = view;
  const { preview } = shown;
  const canvas = useRef<HTMLCanvasElement>(null);

  useLayoutEffect(() => {
    const context = canvas.current?.getContext('2d');
    if (!context) {
      return;
    }
    const source = document.createElement('canvas');
    source.width = preview.width;
    source.height = preview.height;
    const sourceContext = source.getContext('2d');
    if (!sourceContext) {
      return;
    }
    sourceContext.imageSmoothingEnabled = false;
    paint(sourceContext, preview.x, preview.height - preview.y - TILE);
    drawPreviewFacing(context, source, preview, dir, 0);
  }, [preview, dir, paintKey]);

  return (
    <canvas
      ref={canvas}
      className={className}
      width={preview.width}
      height={preview.height}
      style={{
        imageRendering: 'pixelated',
        ...previewFrameStyle(preview, scale, x, y),
      }}
    />
  );
}

/**
 * Where a zone's middle stands in the glass for this view, or undefined when
 * the body has no such zone facing this way.
 */
export function zoneCentre(anchor: MirrorAnchor, zone: string) {
  const { view, regions } = anchor;
  const bounds = view && regions ? regionBounds(regions, zone) : undefined;
  if (!view || !bounds) {
    return undefined;
  }
  return previewFramePoint(
    view.shown.preview,
    view.scale,
    view.x,
    view.y,
    (bounds[0] + bounds[2]) / 2,
    (bounds[1] + bounds[3]) / 2,
  );
}
