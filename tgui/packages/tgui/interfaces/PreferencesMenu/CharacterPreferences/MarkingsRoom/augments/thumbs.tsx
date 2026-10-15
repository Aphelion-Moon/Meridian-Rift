// THIS IS AN APHELION UI FILE
import {
  autoUpdate,
  flip,
  hide,
  offset,
  shift,
  useFloating,
} from '@floating-ui/react';
import {
  type CSSProperties,
  type KeyboardEvent,
  type MouseEventHandler,
  memo,
  useCallback,
  useDeferredValue,
  useEffect,
  useId,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  useSyncExternalStore,
} from 'react';
import { useBackend } from 'tgui/backend';
import { Icon } from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import type {
  AugmentPaintServerData,
  PreferencesMenuData,
} from '../../../types';
import { useServerPrefs } from '../../../useServerPrefs';
import { DRAW_SLICE_MS } from '../drawSlices';
import {
  drawSprite,
  primeSpriteCells,
  type Sprite,
  useSprites,
} from '../sprites';
import { paintMatrices, tintMatrix } from './paint';
import type { StagePart } from './parts';
import { setTried } from './tried';
import { bodyOf, noFinishStyle, type TryOn, tryOnOf } from './tryOn';

/** A finish, as the picker offers it: index.tsx's options for the finish field. */
export type FinishOption = {
  key: string;
  name: string;
  current: boolean;
};

/** A tile's size, and how many times a limb's pixels are drawn up in it. */
const TILE = 60;
const ZOOM = 4;
/** Tiles to a row, as the tile sets lay them out (_augments-paint.scss). */
const COLUMNS = 4;
/** The keys that go round the grid (nextTile). */
const GRID_KEYS = [
  'ArrowLeft',
  'ArrowRight',
  'ArrowUp',
  'ArrowDown',
  'Home',
  'End',
];
/**
 * Each slot's crop on the 32 px cell, facing south, left, top, right and
 * bottom: its part in every style together, an arm's hand included, as the
 * augment_paint and augment_brands sheets draw them; a digitigrade leg's
 * sprites sit inside its plain leg's, and a head's or chest's feminine
 * sprites are in its box. Measured from the generated sheets.
 */
const CROPS: Record<string, readonly [number, number, number, number]> = {
  Head: [10, 1, 21, 13],
  Chest: [9, 9, 22, 24],
  'Right Arm': [6, 10, 13, 25],
  'Left Arm': [18, 10, 25, 25],
  'Right Leg': [9, 18, 16, 32],
  'Left Leg': [15, 18, 22, 32],
};

/** Whether a part's finish picker shows thumbnails: a slot the sheets draw, with a crop. */
export const hasThumbnails = (part: StagePart) =>
  Object.hasOwn(CROPS, part.socket.slot);

/** The body's silhouette, which a tile shows faintly until its own sprites can be drawn. */
const BODY = 'augment_paint32x32 body-south';
const NO_FINISH = 'None';

// Each thumbnail's art at 1x, by what it draws, drawn once and kept, as
// Thumb.tsx keeps its tints: a picker opened again only copies it up. In the
// order it was last used, so the least recently used goes first.
const drawn = new Map<string, HTMLCanvasElement>();
/** How many pieces of art are kept, the least recently used dropped past it and drawn again if needed. */
const DRAWN_KEPT = 256;

/** The art a tile draws for a finish, drawn from its sprites or kept. */
function thumbArt(
  key: string,
  tryOn: TryOn,
  sprites: readonly Sprite[],
  crop: readonly [number, number, number, number],
  inks: Record<string, string>,
) {
  let art = drawn.get(key);
  if (art) {
    drawn.delete(key);
    drawn.set(key, art);
    return art;
  }
  const [left, top, right, bottom] = crop;
  art = document.createElement('canvas');
  art.width = right - left;
  art.height = bottom - top;
  const context = art.getContext('2d');
  if (!context) {
    return undefined;
  }
  tryOn.layers.forEach((layer, index) => {
    context.filter =
      layer.ink === 'plain' ? 'none' : `url(#${inks[layer.ink]})`;
    drawSprite(context, sprites[index], -left, -top, 1);
  });
  if (drawn.size >= DRAWN_KEPT) {
    const oldest = drawn.keys().next().value;
    if (oldest !== undefined) {
      drawn.delete(oldest);
    }
  }
  drawn.set(key, art);
  return art;
}

/** The faint placeholder: the body's silhouette, cropped to the slot. */
function placeholderArt(
  body: Sprite,
  crop: readonly [number, number, number, number],
) {
  const key = `${BODY}|${crop.join()}`;
  let art = drawn.get(key);
  if (!art) {
    const [left, top, right, bottom] = crop;
    art = document.createElement('canvas');
    art.width = right - left;
    art.height = bottom - top;
    const context = art.getContext('2d');
    if (!context) {
      return undefined;
    }
    drawSprite(context, body, -left, -top, 1);
    drawn.set(key, art);
  }
  return art;
}

/** What a finish's tile draws: its sprites, or null for none, and a recolourable finish's colours. */
type Look = { tryOn: TryOn | null; colors: string | null };

/**
 * The looks of a part's finishes, by name: the slot's part in each, facing
 * south, on the body as it's drawn (tryOnOf), "None" in its augment's own look
 * (noFinishStyle), and a recolourable finish in its default colours, or the
 * slot's own on the one it wears.
 */
function finishLooks(
  part: StagePart,
  names: readonly string[],
  paint: AugmentPaintServerData | undefined,
  data: PreferencesMenuData,
) {
  const body = bodyOf(data);
  const greyscale = !!part.augment.uses_greyscale;
  const saved = data.augment_colors?.[part.socket.slot];
  return new Map(
    names.map((name) => {
      const style = name === NO_FINISH ? noFinishStyle(part, body.digi) : name;
      const tryOn = style
        ? tryOnOf(paint, style, part.socket.zones, 'south', body, greyscale)
        : null;
      const finish = paint?.finishes?.[name];
      const look: Look = {
        tryOn: tryOn?.layers.length ? tryOn : null,
        colors: finish
          ? (name === part.finish && saved) || finish.default
          : null,
      };
      return [name, look];
    }),
  );
}

/** The key a look's art is kept under, on a skin. */
const artKey = (tryOn: TryOn, colors: string | null, skin: string) =>
  `${tryOn.layers.map((layer) => `${layer.className}:${layer.ink}`).join()}|${colors}|${skin}`;

/** The recolourable finishes' colours among some looks, once each. */
const palettesOf = (looks: Iterable<Look>) => [
  ...new Set([...looks].flatMap((look) => (look.colors ? [look.colors] : []))),
];

/** A colour string as part of an element id. */
const idPart = (colors: string | null) =>
  colors ? colors.replace(/[^0-9a-z]/gi, '') : 'none';

/**
 * The filters art is drawn through, by ink, from the TileInks of `id`: named
 * by the colours they carry, so a draw that waited can't take another
 * palette's, whatever the search has left.
 */
const inksOf = (id: string, colors: string | null, skin: string) => ({
  skin: `aug-tile-skin-${id}-${idPart(skin)}`,
  paint: `aug-tile-paint-${id}-${idPart(colors)}`,
  glow: `aug-tile-glow-${id}-${idPart(colors)}`,
});

/**
 * The SVG filters thumbnails' art is drawn through: the skin's tint, and
 * each palette's paint and glow, through the colour editor's matrices.
 */
function TileInks(props: {
  id: string;
  skin: string;
  palettes: readonly string[];
}) {
  const { id, skin, palettes } = props;
  return (
    <svg className="paint-defs" aria-hidden="true">
      <filter id={inksOf(id, null, skin).skin} colorInterpolationFilters="sRGB">
        <feColorMatrix type="matrix" values={tintMatrix(skin)} />
      </filter>
      {palettes.map((colors) => {
        const matrices = paintMatrices(colors);
        const inks = inksOf(id, colors, skin);
        return [
          <filter
            key={`paint-${colors}`}
            id={inks.paint}
            colorInterpolationFilters="sRGB"
          >
            <feColorMatrix type="matrix" values={matrices.paint} />
          </filter>,
          <filter
            key={`glow-${colors}`}
            id={inks.glow}
            colorInterpolationFilters="sRGB"
          >
            <feColorMatrix type="matrix" values={matrices.glow} />
          </filter>,
        ];
      })}
    </svg>
  );
}

/**
 * Runs a callback once the window is idle, after the frame being drawn, or
 * after `timeout` ms at most: returns what forgets it.
 */
function whenIdle(callback: () => void, timeout: number) {
  if (typeof requestIdleCallback === 'function') {
    const id = requestIdleCallback(callback, { timeout });
    return () => cancelIdleCallback(id);
  }
  const id = setTimeout(callback);
  return () => clearTimeout(id);
}

/** The longest the augments stage waits for the window to be idle before thumbnails are drawn ahead, in ms. */
const AHEAD_WITHIN_MS = 2000;

/**
 * Draws nothing you see: once the augments stage shows and the window is
 * idle, every limb's finish thumbnails are drawn ahead into the art the tiles
 * copy up, in slices of DRAW_SLICE_MS, so even the first picker opened draws
 * none of its own. Asking for their sprites has their sheets decoded as soon
 * as they come too, the brand sheet's included (brands.ts asks for it), and
 * the brands drawn then. A press or a key puts off what's left until more
 * sprites come; whatever isn't drawn ahead draws as its picker opens.
 */
export function ThumbsAhead(props: {
  /** The parts whose finish pickers can open with thumbnails (hasThumbnails). */
  parts: readonly StagePart[];
}) {
  const [idle, setIdle] = useState(false);
  useEffect(() => whenIdle(() => setIdle(true), AHEAD_WITHIN_MS), []);
  return idle ? <DrawAhead parts={props.parts} /> : null;
}

function DrawAhead(props: { parts: readonly StagePart[] }) {
  const paint = useServerPrefs()?.augment_paint;
  const { data } = useBackend<PreferencesMenuData>();
  const id = useId();
  const skin = data.augment_paint_skin?.color ?? '#ffffff';
  const { jobs, palettes, classNames } = useMemo(() => {
    const jobs = props.parts.flatMap((part) => {
      const crop = CROPS[part.socket.slot];
      const looks = finishLooks(part, part.finishes, paint, data).values();
      return [...looks].flatMap(({ tryOn, colors }) =>
        tryOn ? [{ tryOn, colors, crop }] : [],
      );
    });
    const classNames = jobs.flatMap((job) =>
      job.tryOn.layers.map((layer) => layer.className),
    );
    return {
      jobs,
      palettes: palettesOf(jobs),
      classNames: [...new Set(classNames)],
    };
  }, [props.parts, paint, data]);
  primeSpriteCells(classNames);
  const sprites = useSprites(classNames);
  const drawable = sprites.filter(Boolean).length;

  useEffect(() => {
    const bySprite = new Map(
      classNames.map((name, index) => [name, sprites[index]]),
    );
    let next = 0;
    let cancel = () => {};
    const slice = () => {
      const end = performance.now() + DRAW_SLICE_MS;
      while (next < jobs.length && performance.now() < end) {
        const { tryOn, colors, crop } = jobs[next++];
        const found = tryOn.layers.map((layer) =>
          bySprite.get(layer.className),
        );
        if (found.every(Boolean)) {
          thumbArt(
            artKey(tryOn, colors, skin),
            tryOn,
            found as Sprite[],
            crop,
            inksOf(id, colors, skin),
          );
        }
      }
      if (next < jobs.length) {
        cancel = whenIdle(slice, AHEAD_WITHIN_MS);
      }
    };
    cancel = whenIdle(slice, AHEAD_WITHIN_MS);
    const putOff = () => cancel();
    window.addEventListener('pointerdown', putOff, true);
    window.addEventListener('keydown', putOff, true);
    return () => {
      cancel();
      window.removeEventListener('pointerdown', putOff, true);
      window.removeEventListener('keydown', putOff, true);
    };
  }, [jobs, drawable]);

  return <TileInks id={id} skin={skin} palettes={palettes} />;
}

// MARK: The tooltip

// The tile the pointer or the keyboard is on, for the one tooltip that names
// it: kept outside the picker's state, as tried.ts keeps what is tried on, so
// only the tooltip draws again as it moves.
let pointed: { tile: HTMLElement; name: string } | null = null;
const tipListeners = new Set<() => void>();

function subscribeTip(listener: () => void) {
  tipListeners.add(listener);
  return () => {
    tipListeners.delete(listener);
  };
}

function setPointed(next: { tile: HTMLElement; name: string } | null) {
  if (pointed?.tile === next?.tile && pointed?.name === next?.name) {
    return;
  }
  pointed = next;
  for (const listener of tipListeners) {
    listener();
  }
}

/** A tile no longer pointed at: its name goes, unless another's has come since. */
function unpoint(tile: HTMLElement) {
  if (pointed?.tile === tile) {
    setPointed(null);
  }
}

/**
 * The name of the tile the pointer or the keyboard is on, in a tooltip of the
 * theme's own (.Tooltip), above the tile and centred, or below it when there
 * isn't room, and moved along to stay 8 px inside the window; hidden while
 * its tile is scrolled out of the grid's view. Outside the flyout, so its
 * edges never clip it. It moves in a render of its own after the frame that
 * shows the change, so it never holds up a hover's frame, or the picker's
 * first when it opens under the pointer.
 */
export function ThumbTip() {
  const target = useDeferredValue(
    useSyncExternalStore(subscribeTip, () => pointed),
  );
  // Kept mounted, with no tile at first: useFloating's root context keeps the
  // first reference it's given, so one mounted on a tile would stay on it.
  const { refs, floatingStyles, middlewareData, update } = useFloating({
    elements: { reference: target?.tile ?? null },
    placement: 'top',
    middleware: [
      offset(6),
      flip({ padding: 8 }),
      shift({ padding: 8 }),
      hide(),
    ],
    // Placed again as the grid or the window scrolls or resizes, and as the
    // opening animations end, below. A tile never changes size, and the name
    // changes with its tile.
    whileElementsMounted: (reference, floating, update) =>
      autoUpdate(reference, floating, update, {
        elementResize: false,
        layoutShift: false,
      }),
  });
  // A tile moves by itself only while the picker opens: the flyout unfolds
  // and the tiles slide in. Placed again as each of those ends.
  const tile = target?.tile;
  useEffect(() => {
    const flyout = tile?.closest('.fly');
    flyout?.addEventListener('animationend', update);
    return () => flyout?.removeEventListener('animationend', update);
  }, [tile, update]);
  useEffect(() => () => setPointed(null), []);
  // A tile the search took away, gone before the grid has dropped its name.
  if (!target?.tile.isConnected) {
    return null;
  }
  return (
    <div
      ref={refs.setFloating}
      className={classes([
        'Tooltip',
        'AugStage__tip',
        middlewareData.hide?.referenceHidden && 'AugStage__tip--hidden',
      ])}
      style={floatingStyles}
      aria-hidden="true"
    >
      {target.name}
    </div>
  );
}

// MARK: The grid

/**
 * Where an arrow key, Home or End goes from a tile, by key: the grid reads as
 * its sets lay it out, each set's tiles COLUMNS to a row. Left and right go
 * through the tiles in reading order; up and down go a row, to the same
 * column, or the last tile of a shorter row, across sets. Undefined where
 * there's nowhere further to go.
 */
function nextTile(
  sets: readonly (readonly string[])[],
  key: string,
  move: string,
): string | undefined {
  const flat = sets.flat();
  const at = flat.indexOf(key);
  if (at < 0) {
    return flat[0];
  }
  if (move === 'Home') {
    return flat[0];
  }
  if (move === 'End') {
    return flat[flat.length - 1];
  }
  if (move === 'ArrowRight') {
    return flat[at + 1];
  }
  if (move === 'ArrowLeft') {
    return flat[at - 1];
  }
  const set = sets.findIndex((tiles) => tiles.includes(key));
  const index = sets[set].indexOf(key);
  const column = index % COLUMNS;
  // A row's tiles in a set, by the row's first tile.
  const rowOf = (tiles: readonly string[], start: number) =>
    tiles.slice(start, start + COLUMNS);
  if (move === 'ArrowDown') {
    const below = index - column + COLUMNS;
    if (below < sets[set].length) {
      const row = rowOf(sets[set], below);
      return row[Math.min(column, row.length - 1)];
    }
    const next = sets[set + 1];
    return next && rowOf(next, 0)[Math.min(column, rowOf(next, 0).length - 1)];
  }
  if (move === 'ArrowUp') {
    if (index >= COLUMNS) {
      return rowOf(sets[set], index - column - COLUMNS)[column];
    }
    const previous = sets[set - 1];
    if (!previous) {
      return undefined;
    }
    const row = rowOf(
      previous,
      Math.floor((previous.length - 1) / COLUMNS) * COLUMNS,
    );
    return row[Math.min(column, row.length - 1)];
  }
  return undefined;
}

/**
 * Scrolls the grid so a tile's row is in full view, a whole row at its top:
 * up to the row when it's above, or down to the first row or heading that
 * brings it into view.
 */
function revealRow(grid: HTMLElement, tile: HTMLElement) {
  const top = tile.offsetTop;
  const bottom = top + tile.offsetHeight;
  if (top < grid.scrollTop) {
    grid.scrollTop = top;
    return;
  }
  if (bottom <= grid.scrollTop + grid.clientHeight) {
    return;
  }
  const stops = [...grid.querySelectorAll<HTMLElement>('.tile, .fly-sec')].map(
    (element) => element.offsetTop,
  );
  const wanted = bottom - grid.clientHeight;
  grid.scrollTop = Math.min(
    top,
    ...stops.filter((stop) => stop >= wanted && stop <= top),
  );
}

/** Whether any of a tile shows in the grid's view. */
const inView = (grid: HTMLElement, tile: HTMLElement) =>
  tile.offsetTop < grid.scrollTop + grid.clientHeight &&
  tile.offsetTop + tile.offsetHeight > grid.scrollTop;

/** The space under the last row, as the list keeps under its last option (_augments-paint.scss). */
const END_GAP = 14;

/**
 * Pads the grid's end so its furthest scroll is a stop, a whole row or a
 * heading at its top, and not a sliver of one: END_GAP under the last row,
 * and as much more as takes the furthest scroll on to the next stop. Set as
 * the grid's own bottom padding, which restyles only the grid: an inherited
 * custom property restyled every tile, and cost the open 2 ms.
 */
function padEnd(grid: HTMLElement) {
  const tiles = [...grid.querySelectorAll<HTMLElement>('.tile')];
  const bottom =
    Math.max(0, ...tiles.map((tile) => tile.offsetTop + tile.offsetHeight)) +
    END_GAP;
  const furthest = bottom - grid.clientHeight;
  const stop = [...grid.querySelectorAll<HTMLElement>('.tile, .fly-sec')]
    .map((element) => element.offsetTop)
    .filter((top) => top >= furthest)
    .sort((a, b) => a - b)[0];
  const pad =
    furthest > 0 && stop !== undefined ? END_GAP + stop - furthest : END_GAP;
  // No more than END_GAP: the stylesheet's own padding, with nothing set.
  const padding = pad === END_GAP ? '' : `${pad}px`;
  if (grid.style.paddingBottom !== padding) {
    grid.style.paddingBottom = padding;
  }
}

/**
 * The longest a tile out of view waits to draw, in ms: under the 110 ms its
 * tiles wait to fade in (_augments-paint.scss), so none ever shows undrawn.
 */
const IDLE_DRAW_MS = 100;

type Crossing = {
  onMouseEnter: MouseEventHandler<HTMLElement>;
  onMouseMove: MouseEventHandler<HTMLElement>;
  onMouseLeave: MouseEventHandler<HTMLElement>;
};

/**
 * A part's finishes as a grid of thumbnails, as the markings drawer lays its
 * stickers out: "None" first, then the recolourable finishes and the brand
 * styles under headings of their own. Each tile is the slot's limb in that
 * finish, facing south, its pixels drawn up; a tooltip names the tile the
 * pointer or the keyboard is on (ThumbTip). The arrow keys go round the
 * grid, Home and End to its ends, and Tab leaves it. The pointer tries tiles
 * on as the list tries rows on (index.tsx's Picker hands its crossing over).
 */
export function FinishGrid(props: {
  options: readonly FinishOption[];
  part: StagePart;
  onPick: (option: FinishOption) => void;
  /** The pointer came onto a tile: tries it on, at once or once it stops there. */
  onTry: (key: string) => void;
  /** The pointer went on past a tile. */
  onPass: () => void;
  /** The keyboard left a tile for `next`: what it tried on comes off, or stays (index.tsx's rule). */
  onBlurOption: (key: string, next: EventTarget | null) => void;
  crossing: Crossing;
}) {
  const { options, part, onTry, onPass, onBlurOption, crossing } = props;
  const paint = useServerPrefs()?.augment_paint;
  const { data } = useBackend<PreferencesMenuData>();
  const uid = useId();
  const grid = useRef<HTMLDivElement>(null);
  const opening = useRef(true);
  const finishes = paint?.finishes;
  const sets = useMemo(() => {
    const none: FinishOption[] = [];
    const paintable: FinishOption[] = [];
    const brands: FinishOption[] = [];
    for (const option of options) {
      (option.key === NO_FINISH
        ? none
        : finishes?.[option.key]
          ? paintable
          : brands
      ).push(option);
    }
    return { none, paintable, brands };
  }, [options, finishes]);
  const order = useMemo(
    () =>
      [sets.none, sets.paintable, sets.brands]
        .filter((set) => set.length)
        .map((set) => set.map((option) => option.key)),
    [sets],
  );
  const current = options.find((option) => option.current)?.key;
  const [active, setActive] = useState(current ?? options[0]?.key);
  const picking = useRef(props.onPick);
  picking.current = props.onPick;
  const onPick = useCallback(
    (option: FinishOption) => picking.current(option),
    [],
  );
  const onFocusTile = useCallback(
    (key: string, element: HTMLElement, name: string) => {
      setActive(key);
      setTried(key);
      if (!opening.current) {
        setPointed({ tile: element, name });
      }
    },
    [],
  );
  const tabbable = order.flat().includes(active ?? '')
    ? active
    : order.flat()[0];

  // What every tile is drawn with: its finish's sprites, a recolourable
  // finish's colours, and the body's skin.
  const skin = data.augment_paint_skin?.color ?? '#ffffff';
  const looks = useMemo(
    () =>
      finishLooks(
        part,
        options.map((option) => option.key),
        paint,
        data,
      ),
    [options, part, paint, data],
  );
  const palettes = palettesOf(looks.values());
  const crop = CROPS[part.socket.slot];
  const [bodyFound] = useSprites([BODY]);
  const body = useMemo(() => bodyFound, [!!bodyFound]);

  // The keyboard starts on what's installed, its row in full view, before
  // any tile draws: the tiles in view draw at once, and the rest once the
  // window is idle, after the grid's first frame. Its name shows only once
  // the keyboard moves on.
  const opened = useRef(false);
  const openOnInstalled = useCallback(() => {
    const view = grid.current;
    if (opened.current || !view) {
      return;
    }
    opened.current = true;
    padEnd(view);
    const tile = view.querySelector<HTMLElement>('.tile.cur');
    if (tile) {
      tile.focus({ preventScroll: true });
      revealRow(view, tile);
    }
  }, []);
  const drawTile = useCallback(
    (canvas: HTMLCanvasElement, draw: () => void) => {
      // The first tile to draw opens the grid: its layout effect runs before the grid's.
      openOnInstalled();
      const tile = canvas.parentElement;
      if (grid.current && tile && inView(grid.current, tile)) {
        draw();
        return undefined;
      }
      return whenIdle(draw, IDLE_DRAW_MS);
    },
    [],
  );
  useLayoutEffect(() => {
    openOnInstalled();
    opening.current = false;
  }, []);

  // The search changes how far the grid goes: its end padded again. Not on
  // the grid's first commit, whose opening has padded it.
  const searched = useRef(false);
  useLayoutEffect(() => {
    if (searched.current && grid.current) {
      padEnd(grid.current);
    }
    searched.current = true;
  }, [options]);

  // A tile the search takes away takes its name with it.
  useEffect(() => {
    if (pointed && !pointed.tile.isConnected) {
      setPointed(null);
    }
  }, [options]);

  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const key = (event.target as HTMLElement).closest<HTMLElement>('.tile')
      ?.dataset.key;
    if (!key || !GRID_KEYS.includes(event.key)) {
      return;
    }
    event.preventDefault();
    const to = nextTile(order, key, event.key);
    const tile = [
      ...(grid.current?.querySelectorAll<HTMLElement>('.tile') ?? []),
    ].find((element) => element.dataset.key === to);
    if (grid.current && tile) {
      tile.focus({ preventScroll: true });
      revealRow(grid.current, tile);
    }
  };

  // Every tile's cells in one style pass, before the tiles ask one by one.
  primeSpriteCells([
    BODY,
    ...[...looks.values()].flatMap(
      (look) => look.tryOn?.layers.map((layer) => layer.className) ?? [],
    ),
  ]);

  const tile = (option: FinishOption, index: number) => {
    const look = looks.get(option.key);
    const inks = inksOf(uid, look?.colors ?? null, skin);
    return (
      <FinishTile
        key={option.key}
        option={option}
        index={index}
        recolourable={!!finishes?.[option.key]}
        tryOn={look?.tryOn ?? null}
        artKey={look?.tryOn ? artKey(look.tryOn, look.colors, skin) : ''}
        skinInk={inks.skin}
        paintInk={inks.paint}
        glowInk={inks.glow}
        crop={crop}
        body={body}
        tabbable={option.key === tabbable}
        drawTile={drawTile}
        onPick={onPick}
        onTry={onTry}
        onPass={onPass}
        onFocusTile={onFocusTile}
        onBlurTile={onBlurOption}
      />
    );
  };

  let index = 0;
  return (
    <div
      ref={grid}
      className="fly-grid"
      role="listbox"
      aria-label="Finishes"
      onKeyDown={onKeyDown}
      {...crossing}
    >
      <TileInks id={uid} skin={skin} palettes={palettes} />
      {!!sets.none.length && (
        <div className="tile-set" role="none">
          {sets.none.map((option) => tile(option, index++))}
        </div>
      )}
      {!!sets.paintable.length && (
        <>
          <div id={`${uid}-paintable`} className="fly-sec" aria-hidden="true">
            Recolourable finishes
          </div>
          <div
            className="tile-set"
            role="group"
            aria-labelledby={`${uid}-paintable`}
          >
            {sets.paintable.map((option) => tile(option, index++))}
          </div>
        </>
      )}
      {!!sets.brands.length && (
        <>
          <div id={`${uid}-brands`} className="fly-sec" aria-hidden="true">
            Brand styles
          </div>
          <div
            className="tile-set"
            role="group"
            aria-labelledby={`${uid}-brands`}
          >
            {sets.brands.map((option) => tile(option, index++))}
          </div>
        </>
      )}
      {!options.length && (
        <div className="fly-none">No options match that.</div>
      )}
    </div>
  );
}

/**
 * One finish as a tile: the slot's limb in it, drawn once its sprites can be
 * (a brand's come with the augment_brands sheet), the body's faint
 * silhouette until then, and small badges for the installed finish and a
 * recolourable one. Its accessible name says both. It draws again only when
 * its picture changes: being tried on or pointed at draws nothing here.
 */
const FinishTile = memo(function FinishTile(props: {
  option: FinishOption;
  index: number;
  recolourable: boolean;
  /** The sprites it draws, or null: a "None" with no look of its own, crossed out, or a finish the server sent none for. */
  tryOn: TryOn | null;
  /** The key its art is kept under (artKey), or '' with nothing to draw. */
  artKey: string;
  skinInk: string;
  paintInk: string;
  glowInk: string;
  crop: readonly [number, number, number, number];
  body: Sprite | undefined;
  tabbable: boolean;
  /** Draws its canvas now or soon, by where it is in the grid: returns what forgets a draw still waiting. */
  drawTile: (
    canvas: HTMLCanvasElement,
    draw: () => void,
  ) => (() => void) | undefined;
  onPick: (option: FinishOption) => void;
  onTry: (key: string) => void;
  onPass: () => void;
  onFocusTile: (key: string, element: HTMLElement, name: string) => void;
  onBlurTile: (key: string, next: EventTarget | null) => void;
}) {
  const { option, index, recolourable, tryOn, artKey, crop, body } = props;
  const { onPick, onTry, onPass, onFocusTile, onBlurTile } = props;
  const canvas = useRef<HTMLCanvasElement>(null);
  const classNames = useMemo(
    () => tryOn?.layers.map((layer) => layer.className) ?? [],
    [tryOn],
  );
  const sprites = useSprites(classNames);
  const ready = !!tryOn && sprites.every(Boolean);

  useLayoutEffect(() => {
    const element = canvas.current;
    if (!element) {
      return;
    }
    return props.drawTile(element, () => {
      const context = element.getContext('2d');
      if (!context) {
        return;
      }
      const picture =
        ready && tryOn
          ? thumbArt(artKey, tryOn, sprites as Sprite[], crop, {
              skin: props.skinInk,
              paint: props.paintInk,
              glow: props.glowInk,
            })
          : body && placeholderArt(body, crop);
      context.clearRect(0, 0, TILE, TILE);
      if (!picture) {
        return;
      }
      context.imageSmoothingEnabled = false;
      const width = (crop[2] - crop[0]) * ZOOM;
      const height = (crop[3] - crop[1]) * ZOOM;
      context.drawImage(
        picture,
        Math.round((TILE - width) / 2),
        Math.round((TILE - height) / 2),
        width,
        height,
      );
    });
  }, [ready, artKey, body, crop]);

  const label = `${option.name}${option.current ? ', installed' : ''}${
    recolourable ? ', recolourable' : ''
  }`;
  return (
    <button
      type="button"
      className={classes([
        'tile',
        option.current && 'cur',
        !!tryOn && !ready && 'tile--pending',
      ])}
      style={{ '--i': Math.min(index, 24) } as CSSProperties}
      data-key={option.key}
      role="option"
      aria-selected={option.current}
      aria-label={label}
      tabIndex={props.tabbable ? 0 : -1}
      onClick={() => onPick(option)}
      onMouseEnter={(event) => {
        onTry(option.key);
        setPointed({ tile: event.currentTarget, name: option.name });
      }}
      onMouseLeave={(event) => {
        onPass();
        unpoint(event.currentTarget);
      }}
      onFocus={(event) =>
        onFocusTile(option.key, event.currentTarget, option.name)
      }
      onBlur={(event) => {
        onBlurTile(option.key, event.relatedTarget);
        unpoint(event.currentTarget);
      }}
    >
      {tryOn ? (
        <canvas
          ref={canvas}
          className="tile-art"
          width={TILE}
          height={TILE}
          aria-hidden="true"
        />
      ) : (
        option.key === NO_FINISH && (
          <svg className="tile-none" viewBox="0 0 12 12" aria-hidden="true">
            <path d="M3 3 9 9M9 3 3 9" />
          </svg>
        )
      )}
      {option.current && (
        <span className="tile-badge cur" aria-hidden="true">
          <Icon name="check" />
        </span>
      )}
      {recolourable && (
        <span className="tile-badge paint" aria-hidden="true">
          <Icon name="palette" />
        </span>
      )}
    </button>
  );
});
