// THIS IS AN APHELION UI FILE
import {
  type CSSProperties,
  useId,
  useLayoutEffect,
  useMemo,
  useRef,
} from 'react';
import { useBackend } from 'tgui/backend';

import {
  bloomReach,
  bloomSize,
  LIGHTS_OFF_AMBIENT,
} from '../../../../common/LightsOff';
import type {
  AugmentPaintServerData,
  PreferencesMenuData,
} from '../../../types';
import { useServerPrefs } from '../../../useServerPrefs';
import {
  drawPreviewFacing,
  type PreviewView,
  previewFrameStyle,
  TILE,
} from '../../CharacterPreview/drawing';
import type { SpriteDir } from '../../SpeciesRegistry/constants';
import { isLeg } from '../constants';
import { type FrameRegions, regionsMask } from '../regions';
import { drawSprite, type Sprite, useSprites } from '../sprites';
import { paintMatrices, tintMatrix } from './paint';
import type { StagePart } from './parts';

/** How a try-on sprite is coloured: by the skin, through its packed paint or glow channels, or as drawn. */
type Ink = 'skin' | 'paint' | 'glow' | 'plain';

/** A finish on a part, as the body tries it on: its sprites in drawing order, and the body's zones they replace. */
export type TryOn = {
  layers: readonly { className: string; ink: Ink }[];
  zones: readonly string[];
};

const NOTHING: TryOn = { layers: [], zones: [] };
// Each finish's sprites by part, facing and body, kept per constant data: a
// hover looks them up, it never builds them twice.
const tried = new WeakMap<AugmentPaintServerData, Map<string, TryOn>>();

/**
 * The sprites a finish draws on a part's zones facing `dir`: a recolourable
 * finish's skin base, paint and glow for each zone, from the augment_paint
 * spritesheet the window opens with, or a brand finish's own limb sprites,
 * from the augment_brands one it asks for (brands.ts). A brand finish's legs on
 * a digitigrade body take its digitigrade sprites where it lists them; one that
 * doesn't draws its plain legs there, as the game does when the style's
 * bodyshape drops the digitigrade shape (the server lists <leg>_digi only for a
 * style that draws one, and a style that can't be worn on such legs isn't
 * offered). Nothing when the server sent no sprites for it.
 *
 * Arguments:
 * - humanoid: The body's skin is a mutant colour, which the humanoid ramp draws.
 * - greyscale: The part's augment draws greyscale, which the skin colour tints.
 */
export function tryOnOf(
  data: AugmentPaintServerData | undefined,
  name: string,
  zones: readonly string[],
  dir: SpriteDir,
  humanoid: boolean,
  digi: boolean,
  greyscale: boolean,
): TryOn {
  if (!data) {
    return NOTHING;
  }
  let known = tried.get(data);
  if (!known) {
    known = new Map();
    tried.set(data, known);
  }
  const key = `${name}|${zones.join()}|${dir}|${+humanoid}${+digi}${+greyscale}`;
  let tryOn = known.get(key);
  if (!tryOn) {
    tryOn = buildTryOn(data, name, zones, dir, humanoid, digi, greyscale);
    known.set(key, tryOn);
  }
  return tryOn;
}

function buildTryOn(
  data: AugmentPaintServerData,
  name: string,
  zones: readonly string[],
  dir: SpriteDir,
  humanoid: boolean,
  digi: boolean,
  greyscale: boolean,
): TryOn {
  const finish = data.finishes?.[name];
  if (finish) {
    const layers = zones.flatMap((zone) => {
      const base = `augment_paint32x32 ${finish.id}-${zone}`;
      const has = finish.zones?.[zone];
      return [
        {
          className: `${base}-${humanoid ? 'skinh' : 'skin'}-${dir}`,
          ink: 'skin' as const,
        },
        ...(has?.paint
          ? [{ className: `${base}-paint-${dir}`, ink: 'paint' as const }]
          : []),
        ...(has?.glow
          ? [{ className: `${base}-glow-${dir}`, ink: 'glow' as const }]
          : []),
      ];
    });
    return { layers, zones };
  }
  const brand = data.brands?.[name];
  if (!brand) {
    return NOTHING;
  }
  const sprite = (zone: string) =>
    digi && isLeg(zone) && brand.zones.includes(`${zone}_digi`)
      ? `${zone}_digi`
      : zone;
  const drawn = zones.filter((zone) => brand.zones.includes(sprite(zone)));
  if (!drawn.length) {
    return NOTHING;
  }
  return {
    layers: drawn.map((zone) => ({
      className: `augment_brands32x32 brand-${brand.key}-${sprite(zone)}-${dir}`,
      ink: greyscale ? ('skin' as const) : ('plain' as const),
    })),
    zones: drawn,
  };
}

// The colours a brand finish's unused paint matrices take: it draws none.
const PLAIN = '#ffffff'.repeat(4);
/** The finish a part wears when it wears none: its augment's own look. */
const NO_FINISH = 'None';

/**
 * What the body tries on for a finish under a picker's pointer, as
 * FinishTryOn takes it, or null for nothing: the finish the part wears
 * already shows as it is, under its clothes; "None" shows the augment's own
 * look, when its item names the brand style that look is (`default_style`),
 * but never on a digitigrade body's leg, whose own look is a digitigrade
 * cybernetic leg no brand draws; and a finish the server sent no sprites for
 * shows nothing. Nor does one whose sprites can't be drawn yet, as a brand
 * finish's can't until its sheet has come: until they can, nothing on the
 * body changes, and they show as soon as they can. A recolourable finish
 * wears its default colours.
 *
 * Arguments:
 * - part: The part the finish picker is open on.
 * - name: The finish tried on, or null for none.
 */
export function useFinishTryOn(
  view: PreviewView,
  part: StagePart | undefined,
  name: string | null,
) {
  const paint = useServerPrefs()?.augment_paint;
  const { data } = useBackend<PreferencesMenuData>();
  const style =
    !part || !name || name === part.finish
      ? null
      : name !== NO_FINISH
        ? name
        : data.digi_legs && part.socket.zones.some(isLeg)
          ? null
          : part.augment.default_style;
  const skin = data.augment_paint_skin;
  const tryOn =
    part && style
      ? tryOnOf(
          paint,
          style,
          part.socket.zones,
          view.dir,
          !!skin?.humanoid,
          !!data.digi_legs,
          !!part.augment.uses_greyscale,
        )
      : NOTHING;
  const classNames = useMemo(
    () => tryOn.layers.map((layer) => layer.className),
    [tryOn],
  );
  const found = useSprites(classNames);
  const ready = !!tryOn.layers.length && found.every(Boolean);
  // The same list while the same sprites draw, so FinishTryOn draws again only when they change.
  const sprites = useMemo(
    () => (ready ? (found as Sprite[]) : null),
    [tryOn, ready],
  );
  if (!sprites || !style) {
    return null;
  }
  const finish = paint?.finishes?.[style];
  return {
    tryOn,
    sprites,
    colors: finish ? finish.default : PLAIN,
    skin: skin?.color ?? '#ffffff',
    glowing:
      !!data.augment_paint_emissive &&
      !!finish?.channels.some((channel) => channel.key === 'lights'),
    reach: view.dark
      ? bloomReach(bloomSize(data.game_preferences?.emissive_bloom))
      : 0,
  };
}

// The near leg in profile, east and west, as region lists: kept, so a hover makes none.
const NEAR_RIGHT = ['r_leg'];
const NEAR_LEFT = ['l_leg'];

// One canvas the tried sprites are laid on before height's rows are moved, as
// the markings room's FrameCanvas lays its own; kept, so a hover makes none.
let scratch: CanvasRenderingContext2D | null | undefined;

function frameScratch(width: number, height: number) {
  if (scratch === undefined) {
    scratch = document.createElement('canvas').getContext('2d');
  }
  if (!scratch) {
    return null;
  }
  const { canvas } = scratch;
  if (canvas.width !== width || canvas.height !== height) {
    canvas.width = width;
    canvas.height = height;
  }
  scratch.clearRect(0, 0, width, height);
  scratch.imageSmoothingEnabled = false;
  return scratch;
}

/**
 * A finish tried on the body, drawn over the character in the scan, lined up
 * with its frame pixel for pixel (height's rows moved as the drawing moves
 * them), and tinted on the GPU through the same matrices as the colour
 * editor: no pixel is read, so a sheet served from elsewhere draws too. The
 * limb it replaces is masked out of the character's own canvas through the
 * body's region map, when the stage has one: `--aug-try-hide` on the
 * character's frame holder, which _augments-paint.scss turns into a mask. A
 * far leg in profile is masked the same way (`--aug-try-behind`), so it shows
 * only past the near leg. In the dark only its lights keep their light.
 */
export function FinishTryOn(props: {
  view: PreviewView;
  tryOn: TryOn;
  /** Its sprites, each in its layer's place, all drawable. */
  sprites: readonly Sprite[];
  /** The colour string its paint and glow take. */
  colors: string;
  /** The body's skin colour, which its skin base and a greyscale brand limb take. */
  skin: string;
  /** Whether its lights glow, in the dark view. */
  glowing: boolean;
  /** The body's regions in this facing, to hide the limb it replaces. */
  map: FrameRegions | undefined;
  /** How far the character's canvas reaches past its frame, for the bloom in the dark. */
  reach: number;
}) {
  const { view, tryOn, sprites, colors, skin, glowing, map, reach } = props;
  const { shown, dir, scale, x, y, dark } = view;
  const { preview } = shown;
  const uid = useId();
  const canvas = useRef<HTMLCanvasElement>(null);
  const matrices = useMemo(() => paintMatrices(colors), [colors]);
  // In profile the far leg stands behind the near one, which the game draws
  // over it (a lower layer): it shows only past the near leg's pixels.
  const behind = useMemo(() => {
    const near =
      dir === 'east' && tryOn.zones.includes('l_leg')
        ? NEAR_RIGHT
        : dir === 'west' && tryOn.zones.includes('r_leg')
          ? NEAR_LEFT
          : null;
    return near && map ? regionsMask(map, near) : undefined;
  }, [dir, tryOn, map]);

  useLayoutEffect(() => {
    const context = canvas.current?.getContext('2d');
    const source = context ? frameScratch(preview.width, preview.height) : null;
    if (!context || !source) {
      return;
    }
    const left = preview.x;
    const top = preview.height - preview.y - TILE;
    const shade = dark ? `brightness(${LIGHTS_OFF_AMBIENT})` : '';
    tryOn.layers.forEach((layer, index) => {
      source.filter =
        layer.ink === 'plain'
          ? shade || 'none'
          : `url(#ap-try-${layer.ink}-${uid}) ${shade}`;
      drawSprite(source, sprites[index], left, top, 1, TILE);
    });
    if (dark && glowing) {
      source.filter = `url(#ap-try-light-${uid})`;
      tryOn.layers.forEach((layer, index) => {
        if (layer.ink === 'glow') {
          drawSprite(source, sprites[index], left, top, 1, TILE);
        }
      });
    }
    source.filter = 'none';
    drawPreviewFacing(context, source.canvas, preview, dir, 0);
  }, [preview, dir, dark, glowing, sprites, matrices, skin, uid]);

  // The limb it replaces, hidden: the character's canvas is the frame, grown by the bloom's reach in the dark.
  useLayoutEffect(() => {
    const holder = canvas.current?.parentElement;
    const hide = map ? regionsMask(map, tryOn.zones) : undefined;
    if (!holder || !hide) {
      return;
    }
    holder.style.setProperty('--aug-try-hide', `url(${hide})`);
    holder.style.setProperty('--aug-try-inset', `${reach * scale}px`);
    return () => {
      holder.style.removeProperty('--aug-try-hide');
      holder.style.removeProperty('--aug-try-inset');
    };
  }, [map, tryOn, reach, scale]);

  return (
    <>
      <svg className="paint-defs" aria-hidden="true">
        <filter id={`ap-try-skin-${uid}`} colorInterpolationFilters="sRGB">
          <feColorMatrix type="matrix" values={tintMatrix(skin)} />
        </filter>
        <filter id={`ap-try-paint-${uid}`} colorInterpolationFilters="sRGB">
          <feColorMatrix type="matrix" values={matrices.paint} />
        </filter>
        <filter id={`ap-try-glow-${uid}`} colorInterpolationFilters="sRGB">
          <feColorMatrix type="matrix" values={matrices.glow} />
        </filter>
        <filter id={`ap-try-light-${uid}`} colorInterpolationFilters="sRGB">
          <feColorMatrix type="matrix" values={matrices.light} />
        </filter>
      </svg>
      <canvas
        ref={canvas}
        className="AugStage__try"
        data-preview-pan=""
        width={preview.width}
        height={preview.height}
        style={
          {
            ...previewFrameStyle(preview, scale, x, y),
            '--aug-try-behind': behind && `url(${behind})`,
          } as CSSProperties
        }
      />
    </>
  );
}
