// THIS IS AN APHELION UI FILE
import { useSetAtom } from 'jotai';
import {
  type CSSProperties,
  Fragment,
  memo,
  type MouseEvent as ReactMouseEvent,
  type ReactNode,
  useCallback,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { useBackend } from 'tgui/backend';
import { Icon } from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import type { AugmentItem, PaintFinish } from '../../../types';
import { useServerPrefs } from '../../../useServerPrefs';
import { CharacterPreview } from '../../CharacterPreview';
import {
  type PreviewView,
  previewFramePoint,
  previewFrameStyle,
  previewMovedY,
  TILE,
} from '../../CharacterPreview/drawing';
import { PreviewLightKey } from '../../CharacterPreview/lights';
import { turnPreview } from '../../CharacterPreview/turn';
import type { MarkingsRoomData } from '../data';
import { facingImage } from '../facing';
import {
  augmentRegions,
  type FrameRegions,
  frameRegionsOf,
  regionAt,
  regionsMask,
  regionsOutline,
} from '../regions';
import { useBrandSpritesWhenIdle } from './brands';
import {
  setStageHover,
  useStageHover,
  useStageHoverIs,
  useStageHovering,
} from './hover';
import { AugmentPaint, channelColor } from './paint';
import {
  CARD_LEFT,
  CARD_WIDTH,
  FIELD_NAMES,
  type Field,
  FLY_LEFT,
  isStock,
  landingsOf,
  ORGAN_CARD_HEIGHT,
  PART_CARD_HEIGHT,
  points,
  rowOffset,
  type Socket,
  type StageOrgan,
  type StagePaint,
  type StagePart,
  tracePath,
} from './parts';
import { FinishGrid, ThumbsAhead, ThumbTip } from './thumbs';
import {
  crossTried,
  dropKept,
  heldTried,
  holdTried,
  keepTried,
  setTried,
  triedNow,
  untry,
  useTried,
} from './tried';
import { FinishTryOn, useFinishTryOn } from './tryOn';

/** The scan chamber, in room pixels, and the character's view inside it, centred where the mirror's is. */
const CHAMBER = { left: 270, top: 64, width: 360, height: 564 } as const;
const VIEW = { left: 14, top: 28, width: 332, height: 520 } as const;
/** As large as the stage shows a character: a tile 384px across, as the mirror does. */
const STAGE_SCALE = 12;
/**
 * The scan's own controls, which turn and light the character with a flyout
 * open: they sit over the stage's scrim, keep the flyout open, and keep what
 * is tried on (leaveTried).
 */
const SCAN_CONTROLS = '.AugStage .rot, .AugStage .CharacterPreview__light';
/** A picker's rows, and the finish picker's tiles, each of which tries itself on. */
const PICKER_ROWS = '.AugStage .fly .opt, .AugStage .fly .tile';
/**
 * What the pointer crosses between a picker's rows and the scan's controls:
 * the scrim over the stage, the flyout's own edge, and the list's padding and
 * the gaps between its rows; or the grid's, between its tiles and over its
 * headings.
 */
const TRANSIT = [
  '.AugStage .scrim',
  '.AugStage .fly',
  '.AugStage .fly-in',
  '.AugStage .fly-list',
  '.AugStage .fly-grid',
  '.AugStage .tile-set',
  '.AugStage .fly-sec',
].join();
/** How long the pointer rests on a row it came onto heading out for the stage before that row is tried on. */
const ROW_REST_MS = 120;

/**
 * The pointer left a picker's rows or the scan's controls for `next`: onto
 * the controls, what is tried on stays, so it can be turned and lit; onto a
 * row, that row tries itself on; onto the stage between the two, it stays
 * while the pointer moves on (holdTried); anywhere else, it comes off.
 */
function leaveTried(next: EventTarget | null) {
  const to = next instanceof Element ? next : null;
  if (to?.closest(SCAN_CONTROLS)) {
    keepTried();
  } else if (to?.matches(TRANSIT)) {
    holdTried();
  } else if (!to?.closest(PICKER_ROWS)) {
    setTried(null);
  }
}

/** Whether an event's other target, as where focus goes, is in what these select. */
const isIn = (next: EventTarget | null, selector: string) =>
  next instanceof Element && !!next.closest(selector);

/** The keyboard left a row or a tile for `next`: onto the scan's controls, what it tried on stays, theirs; else it comes off. */
function blurOption(key: string, next: EventTarget | null) {
  if (isIn(next, SCAN_CONTROLS)) {
    keepTried();
  } else {
    untry(key);
  }
}

/**
 * What a press may land on and keep a flyout open: the flyout itself; the
 * stage's scrim, which closes it on its click so the press lands nowhere
 * else; the scan's own controls; the readout's palette, which swaps one
 * flyout for the other; and the window's own drag and resize handles.
 */
const KEEPS_FLYOUT = [
  '.AugStage .fly',
  '.AugStage .scrim',
  SCAN_CONTROLS,
  '.ro-paint-btn',
  '.TitleBar__dragZone',
  '.Window__resizeHandle__e',
  '.Window__resizeHandle__s',
  '.Window__resizeHandle__se',
].join();

type Props = {
  /** Body parts, or the internals. */
  internals: boolean;
  parts: StagePart[];
  organs: StageOrgan[];
  act: (action: string, params?: Record<string, unknown>) => void;
};

type Open = { slot: string; field: Field; side: 'l' | 'r'; oy: number };

/** Where the character stands, as its overlay last saw it: enough to land traces on it and to point at it. */
type Placed = {
  view: PreviewView;
  regions: FrameRegions | null;
  frame: HTMLElement | null;
};

/** An option in a picker, whatever it picks: a part, an implant, a finish. */
type Option = {
  key: string;
  name: string;
  cost: number;
  info: string;
  item: AugmentItem | null;
  /** Its tags: words, or an icon named by its text. */
  tags: { text: string; className?: string; icon?: string }[];
  current: boolean;
  /** Too dear for the points left. */
  dear: boolean;
};

const optionKey = (item: AugmentItem) => item.path ?? item.name;

/**
 * Augments+ augments in a MeridianOS theme, as the mockups lay them out: the
 * character in a scan chamber, a card for each body part's socket down either
 * side with a trace from it to the part, the internals under an x-ray with a
 * node for each, a picker unfolding from whichever row is clicked, and a
 * console under it all that reads out what the pointer is on and lists
 * what's installed. Every theme has the same stage in its own colours.
 */
export function AugmentsStage(props: Props) {
  const { internals, parts, organs, act } = props;
  const { data } = useBackend<MarkingsRoomData>();
  const pointsOn = !!data.quirk_points_enabled;
  // Positive is over the budget; the backend refuses those, so the pickers do too.
  const balance = -(data.quirks_balance ?? 0);
  const turn = useSetAtom(turnPreview);
  useBrandSpritesWhenIdle();

  const [open, setOpen] = useState<Open | null>(null);
  // The slot the colour editor is open on: one flyout at a time, it or a picker.
  const [paintSlot, setPaintSlot] = useState<string | null>(null);
  // What was last installed, and a count that makes its effects play again.
  const [installed, setInstalled] = useState<{
    slot: string;
    n: number;
  } | null>(null);
  const [placed, setPlaced] = useState<Placed | null>(null);
  // Whether the pointer is on a slot (hover.ts): what it is on, only what shows it reads.
  const hovering = useStageHovering();
  const serverPrefs = useServerPrefs();
  const species =
    serverPrefs?.species?.[data.character_preferences?.misc?.species ?? '']
      ?.name;
  const paintFinishes = serverPrefs?.augment_paint?.finishes;

  // Which body region owns each pixel, asked for each drawing the map held
  // isn't known to fit, as the markings room does.
  const previewId = data.character_preview?.id;
  const regionsFor = data.markings_room_regions_for;
  useEffect(() => {
    if (previewId !== undefined && regionsFor !== previewId) {
      act('markings_room_regions', {
        id: previewId,
        have: data.markings_room_regions?.key,
      });
    }
  }, [previewId]);

  // Puts the picker or the colour editor away, and what was tried on with it.
  const closeFlyout = useCallback(() => {
    setOpen(null);
    setPaintSlot(null);
    setTried(null);
  }, []);

  // A layer change starts afresh.
  useEffect(() => {
    setStageHover(null);
    closeFlyout();
  }, [internals]);

  // Nothing stays pointed at, or tried on, once the stage goes.
  useEffect(
    () => () => {
      setStageHover(null);
      setTried(null);
    },
    [],
  );

  // Escape, or a press anywhere else in the window, puts a flyout away.
  const flyoutOpen = !!open || !!paintSlot;
  useEffect(() => {
    if (!flyoutOpen) {
      return;
    }
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        closeFlyout();
      }
    };
    const onPress = (event: PointerEvent) => {
      const target = event.target instanceof Element ? event.target : null;
      // An alt-drag moves the window, as its handles do.
      if (!event.altKey && !target?.closest(KEEPS_FLYOUT)) {
        closeFlyout();
      }
    };
    window.addEventListener('keydown', onKey);
    document.addEventListener('pointerdown', onPress, true);
    return () => {
      window.removeEventListener('keydown', onKey);
      document.removeEventListener('pointerdown', onPress, true);
    };
  }, [flyoutOpen]);

  const partBySlot = useMemo(
    () => Object.fromEntries(parts.map((part) => [part.socket.slot, part])),
    [parts],
  );
  // The parts whose finish pickers open, which have their thumbnails drawn ahead.
  const finishable = useMemo(() => parts.filter(finishOk), [parts]);
  // The part the colour editor is open on, while its finish is recolourable.
  const painting = paintSlot ? partBySlot[paintSlot] : undefined;
  const paintable = !!painting?.paint;
  // A finish that stops being recolourable closes its editor.
  useEffect(() => {
    if (paintSlot && !paintable) {
      setPaintSlot(null);
    }
  }, [paintSlot, paintable]);
  const organBySlot = useMemo(
    () => Object.fromEntries(organs.map((organ) => [organ.socket.slot, organ])),
    [organs],
  );

  // The same function from render to render, so the cards it's handed to
  // draw again only when what they show changes.
  const openPicker = useCallback(
    (socket: Socket, field: Field, row: number) => {
      setOpen((current) =>
        current?.slot === socket.slot && current.field === field
          ? null
          : {
              slot: socket.slot,
              field,
              side: socket.side,
              oy: rowOffset(socket.top, row),
            },
      );
      setTried(null);
      setPaintSlot(null);
    },
    [],
  );
  const openPaint = useCallback((slot: string) => {
    setPaintSlot((current) => (current === slot ? null : slot));
    setOpen(null);
    setTried(null);
  }, []);

  const pick = (slot: string, field: Field, option: Option) => {
    closeFlyout();
    if (option.current || option.dear) {
      return;
    }
    if (field === 'part') {
      act('set_bodypart_aug', {
        slot,
        augment_path: option.item?.path ?? null,
      });
    } else if (field === 'finish') {
      act('set_bodypart_aug_style', { slot, style_name: option.name });
    } else if (field === 'implant') {
      act('set_internal_implant_aug', {
        internal_implant_slot: `${slot} implant`,
        augment_path: option.item?.path ?? null,
      });
    } else {
      act('set_internal_implant_aug', {
        internal_implant_slot: slot,
        augment_path: option.item?.path ?? null,
      });
    }
    setInstalled((last) => ({ slot, n: (last?.n ?? 0) + 1 }));
  };
  // The same function while a picker stays open, so its rows don't draw again for it.
  const onPick = useCallback(
    (option: Option) => {
      if (open) {
        pick(open.slot, open.field, option);
      }
    },
    [open, act],
  );

  // The picker's options, for what it's open on.
  const options: Option[] = useMemo(() => {
    if (!open) {
      return [];
    }
    const affordable = (current: number, cost: number) =>
      !pointsOn || balance - current + cost <= 0;
    if (open.field === 'organ') {
      const organ = organBySlot[open.slot];
      if (!organ) {
        return [];
      }
      return organ.options.map((item) => ({
        key: optionKey(item),
        name: item.name,
        cost: item.cost,
        info: item.extra_info,
        item,
        tags:
          optionKey(item) === optionKey(organ.installed)
            ? [{ text: 'INSTALLED', className: 'cur' }]
            : [],
        current: optionKey(item) === optionKey(organ.installed),
        dear: !affordable(organ.installed.cost, item.cost),
      }));
    }
    const part = partBySlot[open.slot];
    if (!part) {
      return [];
    }
    if (open.field === 'finish') {
      return part.finishes.map((name) => {
        const tags: Option['tags'] = [];
        if (name === part.finish) {
          tags.push({ text: 'INSTALLED', className: 'cur' });
        }
        if (paintFinishes?.[name]) {
          tags.push({
            text: 'Recolourable',
            className: 'paint',
            icon: 'palette',
          });
        }
        return {
          key: name,
          name,
          cost: 0,
          info: '',
          item: null,
          tags,
          current: name === part.finish,
          dear: false,
        };
      });
    }
    const leg = /Leg/.test(part.socket.slot);
    const list =
      open.field === 'implant' ? (part.implants ?? []) : part.options;
    const current = open.field === 'implant' ? part.implant : part.augment;
    return list.map((item) => {
      const isCurrent = !!current && optionKey(item) === optionKey(current);
      const tags: Option['tags'] = [];
      if (isCurrent) {
        tags.push({ text: 'INSTALLED', className: 'cur' });
      }
      if (open.field === 'part' && item.path) {
        if (leg && item.has_digi) {
          tags.push({ text: 'DIGI' });
        }
        if (item.allows_styles) {
          tags.push({ text: 'FINISH' });
        }
        if (item.allows_implants && part.implants) {
          tags.push({ text: 'SLOT' });
        }
      }
      const dear = !affordable(current?.cost ?? 0, item.cost);
      if (dear && !isCurrent) {
        tags.push({ text: 'NOT ENOUGH POINTS', className: 'dear' });
      }
      return {
        key: optionKey(item),
        name: item.name,
        cost: item.cost,
        info: item.extra_info,
        item,
        tags,
        current: isCurrent,
        dear: dear && !isCurrent,
      };
    });
  }, [open, partBySlot, organBySlot, pointsOn, balance, paintFinishes]);

  const sockets = useMemo(
    () =>
      internals ? organs.map((o) => o.socket) : parts.map((p) => p.socket),
    [internals, organs, parts],
  );
  const cardHeight = internals ? ORGAN_CARD_HEIGHT : PART_CARD_HEIGHT;
  // The slots with something installed, whose traces run live.
  const live = useMemo(
    () =>
      new Set(
        sockets
          .filter((socket) =>
            internals
              ? !isStock(organBySlot[socket.slot]?.installed)
              : partLive(partBySlot[socket.slot]),
          )
          .map((socket) => socket.slot),
      ),
    [sockets, internals, organBySlot, partBySlot],
  );

  // Where each part's trace lands on the body in this facing (landingsOf).
  // Once per region map, which is one per drawing and facing; a taur's or any
  // wider sprite's map lays its frame as the mirror's does.
  const map = placed?.regions;
  const taurLegs = !!data.taur_legs;
  const landings = useMemo(
    () => landingsOf(map ?? undefined, sockets, taurLegs),
    [map, sockets, taurLegs],
  );

  // Where each socket's trace lands, in room pixels, from where the character
  // stands. Without a region map, or for an internal, its port on the tile,
  // moved with the rows height moves.
  const anchors = useMemo(() => {
    const out: Record<string, [number, number]> = {};
    if (!placed) {
      return out;
    }
    const { view } = placed;
    const { preview } = view.shown;
    const tileTop = preview.height - preview.y - TILE;
    const originX = CHAMBER.left + VIEW.left;
    const originY = CHAMBER.top + VIEW.top;
    for (const socket of sockets) {
      const [frameX, frameY] = landings[socket.slot] ?? [
        preview.x + socket.port[0],
        previewMovedY(preview, tileTop + socket.port[1]),
      ];
      const [x, y] = previewFramePoint(
        preview,
        view.scale,
        view.x,
        view.y,
        frameX,
        frameY,
      );
      out[socket.slot] = [originX + x, originY + y];
    }
    return out;
  }, [placed, sockets, landings]);

  // The flash and sheen of the part last put in.
  const installedPart = useMemo(
    () =>
      installed && !internals && partBySlot[installed.slot]
        ? { zones: partBySlot[installed.slot].socket.zones, n: installed.n }
        : null,
    [installed, internals, partBySlot],
  );
  const paintOpen = paintable ? paintSlot : null;
  const openSlot = open?.slot ?? paintOpen;
  // The readout keeps to a part with a palette, which it can then be clicked through.
  const palettePinned =
    !!paintOpen || (!!open && !!partBySlot[open.slot]?.paint);

  return (
    <div
      className={classes([
        'AugStage',
        internals && 'AugStage--internals',
        (!!open || !!paintOpen || hovering) && 'AugStage--hovering',
        palettePinned && 'AugStage--palette',
      ])}
      // A crossing ends where the pointer lands: on the scan's controls, a
      // row, more of the stage between them, or anywhere else, the window
      // past the stage included.
      onMouseOver={(event) => heldTried() && leaveTried(event.target)}
      onMouseMove={() => heldTried() && crossTried()}
      onMouseLeave={(event) => heldTried() && leaveTried(event.relatedTarget)}
    >
      <div className="chamber" />
      <div className="pad" />
      <ThumbsAhead parts={finishable} />
      <StageView
        internals={internals}
        parts={parts}
        partBySlot={partBySlot}
        openSlot={open?.slot ?? null}
        openField={open?.field ?? null}
        unlit={!!paintOpen}
        installed={installedPart}
        regions={data.markings_room_regions}
        regionsFor={regionsFor}
        placed={placed}
        onPlaced={setPlaced}
        onOpen={openPicker}
      />
      <div className="beam" />
      <div className="ch-over">
        <span className="brk c-tl" />
        <span className="brk c-tr" />
        <span className="brk c-bl" />
        <span className="brk c-br" />
        <span className="ch-l l">
          {internals ? 'INTERNAL SCAN' : 'BODY SCAN'}
        </span>
        <span className="ch-l r">{(species ?? '').toUpperCase()}</span>
        <div className="ruler" />
        <div className="sweep" />
      </div>
      {/* The scan's controls, over a flyout's scrim. The lights key sits in a
          box of its preview's own, where the preview's is, so it keeps the
          preview's look in every theme. */}
      <div
        className="ch-ctl"
        onMouseOut={(event) => {
          const from = (event.target as Element).closest(SCAN_CONTROLS);
          if (from && !from.contains(event.relatedTarget as Node | null)) {
            leaveTried(event.relatedTarget);
          }
        }}
        onBlur={(event) => {
          const to = event.relatedTarget;
          if (!isIn(to, SCAN_CONTROLS) && !isIn(to, PICKER_ROWS)) {
            dropKept();
          }
        }}
      >
        <button
          type="button"
          className="rot l"
          aria-label="Turn left"
          onClick={() => turn(true)}
        >
          <svg viewBox="0 0 16 16" aria-hidden="true">
            <path d="M3.5 8a4.5 4.5 0 1 0 1.4-3.3M3.5 2.5v2.6h2.6" />
          </svg>
        </button>
        <button
          type="button"
          className="rot r"
          aria-label="Turn right"
          onClick={() => turn(false)}
        >
          <svg viewBox="0 0 16 16" aria-hidden="true">
            <path d="M12.5 8a4.5 4.5 0 1 1-1.4-3.3M12.5 2.5v2.6H9.9" />
          </svg>
        </button>
        <div className="CharacterPreview CharacterPreview--chamber ch-keys">
          <PreviewLightKey />
        </div>
      </div>
      <Traces
        sockets={sockets}
        anchors={anchors}
        cardHeight={cardHeight}
        openSlot={openSlot}
        live={live}
        bare={internals}
        installed={installed}
      />
      {internals &&
        sockets.map((socket) => (
          <Node
            key={socket.slot}
            socket={socket}
            at={anchors[socket.slot]}
            live={live.has(socket.slot)}
            openSlot={openSlot}
            onOpen={openPicker}
          />
        ))}
      {internals
        ? organs.map((organ, index) => (
            <OrganCard
              key={organ.socket.slot}
              organ={organ}
              index={index}
              openSlot={openSlot}
              openField={open?.slot === organ.socket.slot ? open.field : null}
              pointsOn={pointsOn}
              onOpen={openPicker}
            />
          ))
        : parts.map((part, index) => (
            <PartCard
              key={part.socket.slot}
              part={part}
              index={index}
              openSlot={openSlot}
              openField={open?.slot === part.socket.slot ? open.field : null}
              pointsOn={pointsOn}
              onOpen={openPicker}
              painting={paintOpen === part.socket.slot}
              onPaint={openPaint}
            />
          ))}
      <div className="console">
        <Readout
          internals={internals}
          open={open}
          options={options}
          partBySlot={partBySlot}
          organBySlot={organBySlot}
          pointsOn={pointsOn}
          paintSlot={paintOpen}
          paintFinishes={paintFinishes}
          onPaint={openPaint}
        />
        <Installed parts={parts} organs={organs} pointsOn={pointsOn} />
      </div>
      {!!open && (
        <Picker
          open={open}
          options={options}
          title={
            internals
              ? (organBySlot[open.slot]?.socket.name ?? open.slot)
              : (partBySlot[open.slot]?.socket.name ?? open.slot)
          }
          pointsOn={pointsOn}
          part={internals ? undefined : partBySlot[open.slot]}
          onPick={onPick}
          onClose={closeFlyout}
        />
      )}
      {!!paintOpen && !!painting && (
        <AugmentPaint
          key={paintOpen}
          part={painting}
          side={painting.socket.side}
          oy={rowOffset(painting.socket.top, 1)}
          act={act}
          onClose={() => setPaintSlot(null)}
        />
      )}
    </div>
  );
}

/** Whether a part has anything installed: an augment, or an implant in its socket. */
function partLive(part: StagePart | undefined) {
  if (!part) {
    return false;
  }
  return !isStock(part.augment) || (implantOk(part) && !isStock(part.implant));
}

/** Whether a part takes a finish: an augment that allows one, with a choice of more than none. */
const finishOk = (part: StagePart) =>
  !isStock(part.augment) &&
  part.augment.allows_styles !== 0 &&
  part.finishes.length > 1;

/** Whether a part's implant socket can take one: it has one, and its augment leaves it free. */
const implantOk = (part: StagePart) =>
  !!part.implants &&
  (isStock(part.augment) || part.augment.allows_implants !== 0);

type CardProps<T> = {
  index: number;
  /** The slot a picker is open on, if any: while it is, only its card is lit. */
  openSlot: string | null;
  /** The field of this card a picker is open on, or null. */
  openField: Field | null;
  pointsOn: boolean;
  onOpen: (socket: Socket, field: Field, row: number) => void;
} & T;

type Row = {
  field: Field;
  value: string;
  off: boolean;
  none: boolean;
  cost: number;
};

/**
 * A slot's card: lit while the pointer is on its slot, or while its picker is
 * open. It reads the pointer itself, so only a card whose light changes draws
 * again as the pointer moves.
 */
function Card(props: {
  socket: Socket;
  index: number;
  height: number;
  live: boolean;
  openSlot: string | null;
  openField: Field | null;
  rows: Row[];
  pointsOn: boolean;
  onOpen: (socket: Socket, field: Field, row: number) => void;
  /** A recolourable finish's colours: a palette on the FINISH row opens its editor. */
  paint?: StagePaint | null;
  /** Whether that editor is open. */
  painting?: boolean;
  onPaint?: (slot: string) => void;
}) {
  const { socket, index, height, live, openSlot, openField, rows } = props;
  const { pointsOn, onOpen, paint, painting, onPaint } = props;
  const hovered = useStageHoverIs(socket.slot);
  const on = openSlot === null ? hovered : openSlot === socket.slot;
  const left = socket.side === 'l';
  return (
    <div
      className={classes(['sock', on && 'on', live && 'live'])}
      style={
        {
          left: `${CARD_LEFT[socket.side]}px`,
          top: `${socket.top}px`,
          height: `${height}px`,
          '--d': `${90 + index * 45}ms`,
          '--dir': left ? '1' : '-1',
        } as CSSProperties
      }
      onMouseEnter={() => setStageHover(socket.slot)}
      onMouseLeave={() => setStageHover(null)}
    >
      <div className="sock-hd">
        <span className="sock-code">{socket.code}</span>
        <span className="sock-name">{socket.name}</span>
        <span className="sock-state">{live ? 'INSTALLED' : 'STOCK'}</span>
      </div>
      <div className="rule" />
      {rows.map((row, n) => {
        const isOpen = openField === row.field;
        const button = (
          <button
            key={row.field}
            type="button"
            className={classes(['row', row.none && 'none', isOpen && 'open'])}
            // Disabled for the reader, not the browser: MeridianOS hatches disabled buttons its own way.
            aria-disabled={row.off}
            aria-haspopup="listbox"
            aria-expanded={isOpen}
            onClick={() => !row.off && onOpen(socket, row.field, n)}
            onFocus={() => setStageHover(socket.slot)}
            onBlur={() => setStageHover(null)}
          >
            <span className="row-k">{FIELD_NAMES[row.field]}</span>
            <span className="row-v">{row.value}</span>
            <span className={classes(['row-c', row.cost < 0 && 'refund'])}>
              {pointsOn && !row.off ? points(row.cost) : ''}
            </span>
            <svg className="chev" viewBox="0 0 10 10" aria-hidden="true">
              <path d="M3 1.5 7 5 3 8.5" />
            </svg>
          </button>
        );
        if (row.field !== 'finish' || !paint || !onPaint) {
          return button;
        }
        // Its own button over the row's left edge: a row is a button, which can't hold another.
        return (
          <div key={row.field} className="row-paintable">
            {button}
            <button
              type="button"
              className={classes(['row-paint', painting && 'open'])}
              aria-label={`Recolour ${socket.name}`}
              aria-haspopup="dialog"
              aria-expanded={!!painting}
              onClick={() => onPaint(socket.slot)}
              onFocus={() => setStageHover(socket.slot)}
              onBlur={() => setStageHover(null)}
            >
              <Icon name="palette" />
            </button>
          </div>
        );
      })}
    </div>
  );
}

/** A body part's card: its augment, finish and implant. Drawn again only when one of them, or its picker, changes. */
const PartCard = memo(function PartCard(
  props: CardProps<{
    part: StagePart;
    /** Whether the colour editor is open on it. */
    painting: boolean;
    onPaint: (slot: string) => void;
  }>,
) {
  const { part } = props;
  const { augment } = part;
  const stock = isStock(augment);
  const rows: Row[] = [
    {
      field: 'part',
      value: part.unavailable ? 'Not available' : augment.name,
      off: part.unavailable || part.options.length < 2,
      none: stock,
      cost: augment.cost,
    },
    {
      field: 'finish',
      value: finishOk(part)
        ? part.finish
        : stock
          ? 'Organic, no finish'
          : 'Fixed finish',
      off: !finishOk(part),
      none: !finishOk(part) || part.finish === 'None',
      cost: 0,
    },
    {
      field: 'implant',
      value: implantOk(part)
        ? (part.implant?.name ?? 'None')
        : part.implants
          ? 'Blocked by this part'
          : 'No implant slot',
      off: !implantOk(part),
      none: !implantOk(part) || isStock(part.implant),
      cost: implantOk(part) ? (part.implant?.cost ?? 0) : 0,
    },
  ];
  return (
    <Card
      socket={part.socket}
      index={props.index}
      height={PART_CARD_HEIGHT}
      live={partLive(part)}
      openSlot={props.openSlot}
      openField={props.openField}
      rows={rows}
      pointsOn={props.pointsOn}
      onOpen={props.onOpen}
      paint={part.paint}
      painting={props.painting}
      onPaint={props.onPaint}
    />
  );
});

/** An internal's card: what's in it. Drawn again only when that, or its picker, changes. */
const OrganCard = memo(function OrganCard(
  props: CardProps<{ organ: StageOrgan }>,
) {
  const { organ } = props;
  const stock = isStock(organ.installed);
  return (
    <Card
      socket={organ.socket}
      index={props.index}
      height={ORGAN_CARD_HEIGHT}
      live={!stock}
      openSlot={props.openSlot}
      openField={props.openField}
      rows={[
        {
          field: 'organ',
          value: organ.installed.name,
          off: organ.options.length < 2,
          none: stock,
          cost: organ.installed.cost,
        },
      ]}
      pointsOn={props.pointsOn}
      onOpen={props.onOpen}
    />
  );
});

/**
 * An internal's node on the x-ray, at its trace's end: lit while the pointer
 * is on its slot, or while its picker is open. It reads the pointer itself.
 */
const Node = memo(function Node(props: {
  socket: Socket;
  at: [number, number] | undefined;
  live: boolean;
  openSlot: string | null;
  onOpen: (socket: Socket, field: Field, row: number) => void;
}) {
  const { socket, at, live, openSlot, onOpen } = props;
  const hovered = useStageHoverIs(socket.slot);
  if (!at) {
    return null;
  }
  const on = openSlot === null ? hovered : openSlot === socket.slot;
  return (
    <button
      type="button"
      className={classes(['node', on && 'on', live && 'live'])}
      style={{ left: `${at[0]}px`, top: `${at[1]}px` }}
      aria-label={`${socket.name.toLowerCase()}: open the list`}
      onMouseEnter={() => setStageHover(socket.slot)}
      onMouseLeave={() => setStageHover(null)}
      onFocus={() => setStageHover(socket.slot)}
      onBlur={() => setStageHover(null)}
      onClick={() => onOpen(socket, 'organ', 0)}
    />
  );
});

/** The traces from each card to its socket on the body: the one the pointer or a picker is on runs hot. */
const Traces = memo(function Traces(props: {
  sockets: Socket[];
  anchors: Record<string, [number, number]>;
  cardHeight: number;
  /** The slot a picker is open on, which runs hot whatever the pointer is on. */
  openSlot: string | null;
  /** The slots with something installed. */
  live: ReadonlySet<string>;
  bare: boolean;
  installed: { slot: string; n: number } | null;
}) {
  const { sockets, anchors, cardHeight, openSlot, live, bare, installed } =
    props;
  const hover = useStageHover();
  const active = openSlot ?? hover;
  return (
    <svg className="traces" viewBox="0 0 900 820" aria-hidden="true">
      {sockets.map((socket, k) => {
        const at = anchors[socket.slot];
        if (!at) {
          return null;
        }
        const left = socket.side === 'l';
        const startX = left ? CARD_LEFT.l + CARD_WIDTH : CARD_LEFT.r;
        const startY = Math.min(
          Math.max(at[1], socket.top + 16),
          socket.top + cardHeight - 16,
        );
        const d = tracePath(startX, startY, at[0], at[1], left ? 1 : -1);
        const pulse =
          installed?.slot === socket.slot
            ? installed.n % 2
              ? 'pa'
              : 'pb'
            : '';
        return (
          <g
            key={socket.slot}
            className={classes([
              'tr',
              active === socket.slot && 'on',
              live.has(socket.slot) && 'live',
              bare && 'bare',
            ])}
            style={{ '--k': k } as CSSProperties}
          >
            <path className="tr-glow" d={d} />
            <path className="tr-base" d={d} pathLength={1} />
            <path className="tr-hot" d={d} pathLength={1} />
            <path className="tr-flow" d={d} />
            <path
              className={classes(['tr-pulse', pulse])}
              d={d}
              pathLength={1}
            />
            <rect
              className="tr-port"
              x={startX - 3}
              y={startY - 3}
              width={6}
              height={6}
            />
            <circle className="tr-ring" cx={at[0]} cy={at[1]} r={5} />
            <circle className="tr-dot" cx={at[0]} cy={at[1]} r={2.2} />
          </g>
        );
      })}
    </svg>
  );
});

/**
 * The character in the scan chamber: pointing at a part of its body lights
 * that part's slot, and a tap opens its picker. It reads the pointer itself,
 * so a part lit on the body draws again only the character's view, whose
 * pan finds the new layers as it always does. Its lights key is the other
 * tabs' own, and turns the lights off here too, to show what glows.
 */
const StageView = memo(function StageView(props: {
  internals: boolean;
  parts: StagePart[];
  partBySlot: Record<string, StagePart>;
  /** The slot a picker is open on, which stays lit whatever the pointer is on. */
  openSlot: string | null;
  /** What that picker picks, for what the body tries on from it. */
  openField: Field | null;
  /**
   * Nothing lights, the pointer's part included: the colour editor is open,
   * and the part shows its colours as they are.
   */
  unlit: boolean;
  /** The part last put in, for its flash and sheen. */
  installed: { zones: string[]; n: number } | null;
  regions: MarkingsRoomData['markings_room_regions'];
  regionsFor: number | undefined;
  placed: Placed | null;
  onPlaced: (placed: Placed) => void;
  onOpen: (socket: Socket, field: Field, row: number) => void;
}) {
  const { internals, parts, partBySlot, openSlot, openField, unlit } = props;
  const { installed, regions, regionsFor, placed, onPlaced, onOpen } = props;
  const hover = useStageHover();
  const active = unlit ? null : (openSlot ?? hover);
  const activePart = !internals && active ? partBySlot[active] : undefined;
  const pickerPart = !internals && openSlot ? partBySlot[openSlot] : undefined;

  const zoneAt = (clientX: number, clientY: number) => {
    const frame = placed?.frame;
    const map = placed?.regions;
    if (!frame || !map || !placed) {
      return undefined;
    }
    const box = frame.getBoundingClientRect();
    if (!box.width || !box.height) {
      return undefined;
    }
    const { width, height } = placed.view.shown.preview;
    return regionAt(
      map,
      ((clientX - box.left) / box.width) * width,
      ((clientY - box.top) / box.height) * height,
    );
  };
  const partAt = (clientX: number, clientY: number) => {
    const zone = zoneAt(clientX, clientY);
    return zone
      ? parts.find((part) => part.socket.zones.includes(zone))
      : undefined;
  };

  return (
    <div
      className="AugStage__view"
      onPointerMove={(event) => {
        if (internals || event.buttons) {
          return;
        }
        const part = partAt(event.clientX, event.clientY);
        setStageHover(part ? part.socket.slot : null);
      }}
      onPointerLeave={() => !internals && setStageHover(null)}
    >
      <div className="AugStage__box">
        <CharacterPreview
          motif="chamber"
          pannable={false}
          fitBody
          width={`${VIEW.width}px`}
          height={`${VIEW.height}px`}
          maxScale={STAGE_SCALE}
          onTap={(x, y) => {
            if (internals) {
              return;
            }
            const part = partAt(x, y);
            if (part) {
              onOpen(part.socket, 'part', 0);
            }
          }}
          overlay={(view) => (
            <StageOverlay
              view={view}
              regions={regions}
              regionsFor={regionsFor}
              internals={internals}
              lit={activePart?.socket.zones ?? null}
              pickerPart={pickerPart}
              pickerField={openField}
              installed={installed}
              onPlaced={onPlaced}
            />
          )}
        />
      </div>
    </div>
  );
});

/**
 * Everything the stage draws on the character, lined up with its frame and
 * panning with it: the part the pointer is on, lit in the hot light with a
 * scan running down it and a halo outside it; a part's chrome while its
 * picker tries one on, and a finish itself while its picker tries that on;
 * the flash and sheen of a part going in; and the internals' x-ray. Tells
 * the stage where the character stands. It reads what the picker tries on
 * itself (tried.ts), so only it draws again as the pointer moves down a list.
 */
function StageOverlay(props: {
  view: PreviewView;
  regions: MarkingsRoomData['markings_room_regions'];
  /** The drawing the regions fit. */
  regionsFor: number | undefined;
  internals: boolean;
  lit: string[] | null;
  /** The part a picker is open on, and what it picks. */
  pickerPart: StagePart | undefined;
  pickerField: Field | null;
  installed: { zones: string[]; n: number } | null;
  onPlaced: (placed: Placed) => void;
}) {
  const { view, regions, regionsFor, internals, lit, installed } = props;
  const { pickerPart, pickerField, onPlaced } = props;
  const tried = useTried();
  // A part tried on: its chrome. A finish: the finish itself, over the limb it replaces.
  const peek =
    tried &&
    pickerField === 'part' &&
    pickerPart?.options.some((item) => !!item.path && item.path === tried)
      ? pickerPart.socket.zones
      : null;
  const finishTry = useFinishTryOn(
    view,
    pickerPart,
    pickerField === 'finish' ? tried : null,
  );
  const { shown, dir, scale, x, y } = view;
  const { preview, image } = shown;
  const frame = useRef<HTMLSpanElement>(null);
  // The regions that fit the drawing: the server's for it, or, until they
  // come, the last ones while the frame keeps its geometry, as the mirror
  // holds its map; so a redraw moves nothing on the body for the round trip.
  const geometry = useMemo(
    () =>
      `${preview.width} ${preview.height} ${preview.x} ${preview.y} ${JSON.stringify(preview.rows ?? null)}`,
    [preview],
  );
  const fitted = useRef<string | null>(null);
  const confirmed = !!regions && regionsFor === preview.id;
  const fits = confirmed || fitted.current === geometry;
  useLayoutEffect(() => {
    if (confirmed) {
      fitted.current = geometry;
    }
  }, [confirmed, geometry]);
  const map = useMemo(
    () => (regions && fits ? frameRegionsOf(preview, regions, dir) : undefined),
    [preview, regions, dir, fits],
  );

  useLayoutEffect(() => {
    onPlaced({ view, regions: map ?? null, frame: frame.current });
  }, [preview.id, dir, scale, x, y, map]);

  const style = previewFrameStyle(preview, scale, x, y);
  const masked = (zones: string[] | null) => {
    const url = map && zones?.length ? regionsMask(map, zones) : undefined;
    return url
      ? { ...style, maskImage: `url(${url})`, WebkitMaskImage: `url(${url})` }
      : null;
  };
  // A finish tried on shows as it is, unlit.
  const litStyle = internals || finishTry ? null : masked(lit);
  const peekStyle = internals ? null : masked(peek);
  const installedStyle = installed ? masked(installed.zones) : null;
  const facing =
    internals && image ? facingImage(image, preview, dir) : undefined;
  // The visible augments' own pixels (their eyes, an implant's overlay), which
  // the x-ray leaves showing as they are, a line round each.
  const augments = useMemo(() => {
    const source =
      internals && regions && regionsFor === preview.id
        ? augmentRegions(regions)
        : null;
    return source ? frameRegionsOf(preview, source, dir) : undefined;
  }, [internals, preview, regions, regionsFor, dir]);
  const augmentShape = augments && regionsMask(augments, augments.zones);
  const augmentLine = augments && regionsOutline(augments, augments.zones);
  const xray = facing
    ? {
        ...style,
        maskImage: augmentShape
          ? `url(${facing}), url(${augmentShape})`
          : `url(${facing})`,
        WebkitMaskImage: augmentShape
          ? `url(${facing}), url(${augmentShape})`
          : `url(${facing})`,
        maskComposite: augmentShape ? 'subtract' : undefined,
        WebkitMaskComposite: augmentShape ? 'source-out' : undefined,
      }
    : null;

  // Each layer pans with the character on its own, beside its canvas, so the
  // ones that tint it blend with it.
  return (
    <>
      <span
        ref={frame}
        className="AugStage__frame"
        data-preview-pan=""
        style={style}
      />
      {!!xray && (
        <>
          <span
            className="AugStage__xr AugStage__xr--dim"
            data-preview-pan=""
            style={xray}
          />
          <span
            className="AugStage__xr AugStage__xr--tint"
            data-preview-pan=""
            style={xray}
          />
          <span
            className="AugStage__xr AugStage__xr--lines"
            data-preview-pan=""
            style={xray}
          />
        </>
      )}
      {!!xray && !!augmentLine && (
        <span className="AugStage__implants" data-preview-pan="" style={style}>
          <span
            className="AugStage__implantsLine"
            style={{
              maskImage: `url(${augmentLine})`,
              WebkitMaskImage: `url(${augmentLine})`,
            }}
          />
        </span>
      )}
      {!!finishTry && <FinishTryOn view={view} map={map} {...finishTry} />}
      {!!peekStyle && (
        <span
          key={`peek ${peek?.join()}`}
          className="AugStage__chrome"
          data-preview-pan=""
          style={peekStyle}
        />
      )}
      {!!litStyle && (
        <Fragment key={`lit ${lit?.join()}`}>
          <span
            className="AugStage__lit AugStage__lit--tint"
            data-preview-pan=""
            style={litStyle}
          />
          <span
            className="AugStage__lit AugStage__lit--scan"
            data-preview-pan=""
            style={litStyle}
          />
          <span
            className="AugStage__halo"
            data-preview-pan=""
            style={{
              ...style,
              maskImage: `linear-gradient(#000 0 0), ${litStyle.maskImage}`,
              WebkitMaskImage: `linear-gradient(#000 0 0), ${litStyle.maskImage}`,
            }}
          >
            <span
              className="AugStage__haloZone"
              style={{
                maskImage: litStyle.maskImage,
                WebkitMaskImage: litStyle.maskImage,
              }}
            />
          </span>
        </Fragment>
      )}
      {!!installedStyle && (
        <Fragment key={`installed ${installed?.n}`}>
          <span
            className="AugStage__flash"
            data-preview-pan=""
            style={installedStyle}
          />
          <span
            className="AugStage__sheen"
            data-preview-pan=""
            style={installedStyle}
          />
        </Fragment>
      )}
    </>
  );
}

/** The console's readout: what the pointer, the picker or the colour editor is on. */
function Readout(props: {
  internals: boolean;
  open: Open | null;
  /** The open picker's options, one of which the pointer may be on. */
  options: Option[];
  partBySlot: Record<string, StagePart>;
  organBySlot: Record<string, StageOrgan>;
  pointsOn: boolean;
  /** The slot the colour editor is open on. */
  paintSlot: string | null;
  paintFinishes: Record<string, PaintFinish> | undefined;
  onPaint: (slot: string) => void;
}) {
  const { internals, open, options, partBySlot, organBySlot, pointsOn } = props;
  const { paintSlot, paintFinishes, onPaint } = props;
  // What the pointer is on, a slot or a picker's option: the readout reads both itself, and alone draws again for them.
  const hover = useStageHover();
  const tried = useTried();
  const peeked =
    open && tried ? options.find((option) => option.key === tried) : undefined;
  // The slots' colours, read here and in the colour editor only.
  const augmentColors = useBackend<MarkingsRoomData>().data.augment_colors;
  const lines: { text: string; className?: string; node?: ReactNode }[] = [];
  let kicker = 'SCAN IDLE';
  let title = 'PICK A SLOT';
  const costLine = (cost: number) =>
    !pointsOn
      ? null
      : cost > 0
        ? {
            text: `Costs ${cost} ${cost === 1 ? 'point' : 'points'}`,
            className: 'cost',
          }
        : cost < 0
          ? {
              text: `Gives back ${-cost} ${cost === -1 ? 'point' : 'points'}`,
              className: 'refund',
            }
          : { text: 'No point cost', className: 'dim' };
  const target = open?.slot ?? paintSlot ?? hover;
  // Following the pointer, the readout can't be reached: its palette acts only while it keeps to a flyout's slot.
  const pinned = !!open || !!paintSlot;
  if (open && peeked) {
    const socket = (internals ? organBySlot[open.slot] : partBySlot[open.slot])
      ?.socket;
    kicker = `${socket?.name ?? open.slot} · ${FIELD_NAMES[open.field]}`;
    title = peeked.name.toUpperCase();
    if (peeked.info) {
      lines.push({ text: peeked.info });
    }
    if (open.field === 'finish' && paintFinishes?.[peeked.name]) {
      lines.push({
        text: 'Recolourable',
        className: 'ro-paint',
        node: (
          <>
            <Icon name="palette" />
            Recolourable
          </>
        ),
      });
    }
    if (open.field !== 'finish' && !peeked.item?.path) {
      lines.push({
        text:
          open.field === 'part'
            ? 'Keeps the species stock part.'
            : open.field === 'organ'
              ? 'Keeps the species stock organ.'
              : 'Leaves the slot empty.',
        className: 'dim',
      });
    }
    const cost = costLine(peeked.cost);
    if (cost && open.field !== 'finish') {
      lines.push(cost);
    }
    const part = partBySlot[open.slot];
    if (open.field === 'part' && peeked.item?.path && part) {
      const flags: string[] = [];
      if (/Leg/.test(open.slot) && peeked.item.has_digi) {
        flags.push('digitigrade ready');
      }
      if (peeked.item.allows_styles) {
        flags.push('takes a finish');
      }
      if (peeked.item.allows_implants && part.implants) {
        flags.push('keeps its implant slot');
      }
      if (flags.length) {
        lines.push({ text: flags.join(' · '), className: 'dim' });
      }
    }
    if (peeked.dear) {
      lines.push({
        text: 'Not enough points left for this.',
        className: 'dear',
      });
    }
  } else if (target && !internals && partBySlot[target]) {
    const part = partBySlot[target];
    kicker = `BODY PART · ${part.socket.code}`;
    title = part.socket.slot.toUpperCase();
    lines.push({
      text: `Augment: ${isStock(part.augment) ? 'none, organic' : part.augment.name}`,
    });
    if (finishOk(part)) {
      lines.push({ text: `Finish: ${part.finish}` });
    }
    const { paint } = part;
    if (paint) {
      const colors = augmentColors?.[part.socket.slot] ?? paint.finish.default;
      lines.push({
        text: 'Colours',
        className: 'ro-paint',
        node: (
          <>
            <button
              type="button"
              className="ro-paint-btn"
              aria-label={`Recolour ${part.socket.name}`}
              aria-disabled={!pinned}
              aria-haspopup="dialog"
              aria-expanded={paintSlot === part.socket.slot}
              onClick={() => pinned && onPaint(part.socket.slot)}
            >
              <Icon name="palette" />
            </button>
            Colours
            {paint.finish.channels.map(({ key }) => (
              <span
                key={key}
                className="ro-chip"
                style={{ backgroundColor: channelColor(colors, key) }}
              />
            ))}
          </>
        ),
      });
    }
    if (part.implants) {
      lines.push({
        text: `Implant: ${
          implantOk(part)
            ? `${part.implant?.name ?? 'None'}${part.implant?.extra_info ? ` (${part.implant.extra_info})` : ''}`
            : 'blocked by this part'
        }`,
      });
    } else {
      lines.push({ text: 'No implant slot on this part', className: 'dim' });
    }
  } else if (target && internals && organBySlot[target]) {
    const organ = organBySlot[target];
    kicker = `INTERNAL · ${organ.socket.code}`;
    title = organ.socket.slot.toUpperCase();
    lines.push({
      text: `Installed: ${isStock(organ.installed) ? 'species stock' : organ.installed.name}`,
    });
    lines.push({ text: `${organ.options.length} options`, className: 'dim' });
  }
  return (
    <div className="panel ro">
      <div className="ro-k">{kicker}</div>
      {/* Typed out again whenever it reads something else. */}
      <div key={`${kicker} ${title}`} className="ro-t ta">
        {title}
      </div>
      {lines.map((line) => (
        <div key={line.text} className={classes(['ro-l', line.className])}>
          {line.node ?? line.text}
        </div>
      ))}
    </div>
  );
}

/** The console's list of what's installed, and what it all costs. */
/** Drawn again only when what's installed changes. */
const Installed = memo(function Installed(props: {
  parts: StagePart[];
  organs: StageOrgan[];
  pointsOn: boolean;
}) {
  const { parts, organs, pointsOn } = props;
  const rows: {
    key: string;
    k: string;
    v: string;
    cost: number;
    sub?: boolean;
  }[] = [];
  let net = 0;
  let count = 0;
  for (const part of parts) {
    if (!partLive(part)) {
      continue;
    }
    count++;
    const slot = part.socket.slot;
    rows.push({
      key: slot,
      k: part.socket.name,
      v: isStock(part.augment) ? 'Organic' : part.augment.name,
      cost: part.augment.cost,
    });
    net += part.augment.cost;
    if (finishOk(part) && part.finish !== 'None') {
      rows.push({
        key: `${slot} finish`,
        k: '',
        v: `↳ ${part.finish}`,
        cost: 0,
        sub: true,
      });
    }
    if (implantOk(part) && !isStock(part.implant) && part.implant) {
      rows.push({
        key: `${slot} implant`,
        k: '',
        v: `↳ ${part.implant.name}`,
        cost: part.implant.cost,
        sub: true,
      });
      net += part.implant.cost;
    }
  }
  for (const organ of organs) {
    if (isStock(organ.installed)) {
      continue;
    }
    count++;
    rows.push({
      key: organ.socket.slot,
      k: organ.socket.name,
      v: organ.installed.name,
      cost: organ.installed.cost,
    });
    net += organ.installed.cost;
  }
  return (
    <div className="panel inst">
      <div className="inst-hd">
        <span>INSTALLED</span>
        <span>
          {count} {count === 1 ? 'PART' : 'PARTS'}
        </span>
      </div>
      <div className="inst-list">
        {rows.map((row) => (
          <div key={row.key} className={classes(['inst-r', row.sub && 'sub'])}>
            <span className="inst-k">{row.k}</span>
            <span className="inst-v">{row.v}</span>
            <span className={classes(['inst-c', row.cost < 0 && 'refund'])}>
              {pointsOn ? points(row.cost) : ''}
            </span>
          </div>
        ))}
        {!rows.length && (
          <div className="inst-none">Stock body. Nothing installed yet.</div>
        )}
      </div>
      <div className="inst-tot">
        <span>NET COST</span>
        <span className="inst-tv">
          {pointsOn
            ? `${net} ${Math.abs(net) === 1 ? 'PT' : 'PTS'}`
            : 'NO POINTS'}
        </span>
      </div>
    </div>
  );
});

/** Whether an option answers a search, by its name, its description or a tag. */
const optionMatches = (option: Option, wanted: string) =>
  !wanted ||
  [option.name, option.info, ...option.tags.map((tag) => tag.text)].some(
    (text) => !!text && text.toLowerCase().includes(wanted),
  );

/**
 * A socket's picker, unfolding from the row it was opened from over its side
 * of the stage, its list narrowed by a search as the markings drawer's is.
 * The option the pointer or the keyboard is on is tried on (tried.ts), which
 * draws none of its rows again.
 */
export function Picker(props: {
  open: Open;
  options: Option[];
  title: string;
  pointsOn: boolean;
  /** The part a finish picker is open on, which its thumbnails draw. */
  part?: StagePart;
  onPick: (option: Option) => void;
  onClose: () => void;
}) {
  const { open, options, title, pointsOn, part, onPick, onClose } = props;
  // A finish picker lays its finishes out as thumbnails (thumbs.tsx).
  const thumbnails = open.field === 'finish' && !!part;
  const left = open.side === 'l';
  const organ = open.field === 'organ';
  const list = useRef<HTMLDivElement>(null);
  // The pointer's heading over the list. A row it comes onto heading out
  // sideways for the stage, as to the scan's controls, doesn't take over from
  // what is tried on while it keeps on: only once it rests there, or turns
  // back into the list. Down the list, each row is tried on at once.
  const heading = useRef({ x: 0, y: 0, dx: 0, dy: 0 });
  const crossed = useRef<{ key: string; rest?: ReturnType<typeof setTimeout> }>(
    undefined,
  );
  const toStage = left ? 1 : -1;
  const headingOut = () =>
    heading.current.dx * toStage > Math.abs(heading.current.dy) / 2;
  const settleRow = useCallback(() => {
    const row = crossed.current;
    crossed.current = undefined;
    clearTimeout(row?.rest);
    if (row) {
      setTried(row.key);
    }
  }, []);
  const tryRow = useCallback(
    (key: string) => {
      clearTimeout(crossed.current?.rest);
      crossed.current = undefined;
      if (triedNow() !== null && headingOut()) {
        crossed.current = { key, rest: setTimeout(settleRow, ROW_REST_MS) };
      } else {
        setTried(key);
      }
    },
    [toStage],
  );
  const passRow = useCallback(() => {
    clearTimeout(crossed.current?.rest);
    crossed.current = undefined;
  }, []);
  // Where the pointer goes over the list or the grid, for the rows or tiles it crosses.
  const crossing = useMemo(
    () => ({
      onMouseEnter: (event: ReactMouseEvent<HTMLElement>) => {
        heading.current = {
          x: event.clientX,
          y: event.clientY,
          dx: 0,
          dy: 0,
        };
      },
      onMouseMove: (event: ReactMouseEvent<HTMLElement>) => {
        const h = heading.current;
        h.dx = h.dx / 2 + event.clientX - h.x;
        h.dy = h.dy / 2 + event.clientY - h.y;
        h.x = event.clientX;
        h.y = event.clientY;
        const row = crossed.current;
        if (row && headingOut()) {
          clearTimeout(row.rest);
          row.rest = setTimeout(settleRow, ROW_REST_MS);
        } else if (row) {
          settleRow();
        }
      },
      onMouseLeave: (event: ReactMouseEvent<HTMLElement>) =>
        leaveTried(event.relatedTarget),
    }),
    [toStage],
  );
  const [query, setQuery] = useState('');
  const wanted = query.trim().toLowerCase();
  const shown = wanted
    ? options.filter((option) => optionMatches(option, wanted))
    : options;
  // The keyboard starts on what's installed; nothing stays tried on once the picker goes.
  useEffect(() => {
    list.current?.querySelector<HTMLButtonElement>('.opt.cur')?.focus({
      preventScroll: false,
    });
    return () => {
      clearTimeout(crossed.current?.rest);
      setTried(null);
    };
  }, []);
  return (
    <>
      <button
        type="button"
        className="scrim"
        aria-label="Close the list"
        onClick={onClose}
      />
      <div
        className="fly"
        style={
          {
            left: `${FLY_LEFT[open.side]}px`,
            '--oy': `${open.oy}px`,
            '--dir': left ? '1' : '-1',
          } as CSSProperties
        }
        role="dialog"
        aria-label={`${title.toLowerCase()} ${FIELD_NAMES[open.field].toLowerCase()} list`}
      >
        <div className="fly-in">
          <div className="fly-hd">
            <div className="fly-k">{organ ? 'INTERNAL' : title}</div>
            <div className="fly-t">
              {organ ? title : FIELD_NAMES[open.field]}
            </div>
            <div className="fly-n">{options.length} options</div>
            <button
              type="button"
              className="x"
              aria-label="Close"
              onClick={onClose}
            >
              <svg viewBox="0 0 12 12" aria-hidden="true">
                <path d="M2 2 10 10M10 2 2 10" />
              </svg>
            </button>
          </div>
          <label className="fly-s">
            <svg viewBox="0 0 14 14" aria-hidden="true">
              <circle cx="6" cy="6" r="4.2" />
              <path d="M9.2 9.2 12.5 12.5" />
            </svg>
            <input
              type="search"
              placeholder={`Search ${options.length} options`}
              value={query}
              aria-label="Search options"
              onChange={(event) => setQuery(event.target.value)}
            />
          </label>
          {thumbnails ? (
            <FinishGrid
              options={shown}
              part={part}
              onPick={onPick}
              onTry={tryRow}
              onPass={passRow}
              onBlurOption={blurOption}
              crossing={crossing}
            />
          ) : (
            <div ref={list} className="fly-list" role="listbox" {...crossing}>
              {!shown.length && (
                <div className="fly-none">No options match that.</div>
              )}
              {shown.map((option, i) => (
                <PickerOption
                  key={option.key}
                  option={option}
                  index={i}
                  pointsOn={pointsOn}
                  onPick={onPick}
                  onTry={tryRow}
                  onPass={passRow}
                />
              ))}
            </div>
          )}
        </div>
      </div>
      {thumbnails && <ThumbTip />}
    </>
  );
}

/**
 * An option in a picker: trying it on is the pointer's or the keyboard's
 * business (tried.ts), lit here by :hover and :focus, so it draws again only
 * when the option itself changes.
 */
const PickerOption = memo(function PickerOption(props: {
  option: Option;
  index: number;
  pointsOn: boolean;
  onPick: (option: Option) => void;
  /** The pointer came onto it: tries it on, at once or once it stops there. */
  onTry: (key: string) => void;
  /** The pointer went on past it. */
  onPass: () => void;
}) {
  const { option, index, pointsOn, onPick, onTry, onPass } = props;
  return (
    <button
      type="button"
      className={classes([
        'opt',
        option.current && 'cur',
        option.dear && 'dear',
      ])}
      style={{ '--i': Math.min(index, 18) } as CSSProperties}
      role="option"
      aria-selected={option.current}
      aria-disabled={option.dear}
      onClick={() => onPick(option)}
      onMouseEnter={() => onTry(option.key)}
      onMouseLeave={onPass}
      onFocus={() => setTried(option.key)}
      onBlur={(event) => blurOption(option.key, event.relatedTarget)}
    >
      <span className="opt-n">{option.name}</span>
      <span className={classes(['opt-c', option.cost < 0 && 'refund'])}>
        {pointsOn ? points(option.cost) : ''}
      </span>
      {!!option.info && <span className="opt-x">{option.info}</span>}
      <span className="opt-tags">
        {option.tags.map((tag) =>
          tag.icon ? (
            <span
              key={tag.text}
              className={classes(['tag', 'tag-icon', tag.className])}
              role="img"
              aria-label={tag.text}
              title={tag.text}
            >
              <Icon name={tag.icon} />
            </span>
          ) : (
            <span key={tag.text} className={classes(['tag', tag.className])}>
              {tag.text}
            </span>
          ),
        )}
      </span>
    </button>
  );
});
