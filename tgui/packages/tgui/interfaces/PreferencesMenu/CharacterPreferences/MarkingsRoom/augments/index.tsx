// THIS IS AN APHELION UI FILE
import { useSetAtom } from 'jotai';
import {
  type CSSProperties,
  Fragment,
  memo,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { useBackend } from 'tgui/backend';
import { classes } from 'tgui-core/react';

import type { AugmentItem } from '../../../types';
import { useServerPrefs } from '../../../useServerPrefs';
import { CharacterPreview } from '../../CharacterPreview';
import {
  type PreviewView,
  previewFramePoint,
  previewFrameStyle,
  TILE,
} from '../../CharacterPreview/drawing';
import { turnPreview } from '../../CharacterPreview/turn';
import type { MarkingsRoomData } from '../data';
import { facingImage } from '../facing';
import {
  type FrameRegions,
  frameRegions,
  regionAt,
  regionsMask,
} from '../regions';
import {
  CARD_LEFT,
  CARD_WIDTH,
  FIELD_NAMES,
  type Field,
  isStock,
  ORGAN_CARD_HEIGHT,
  PART_CARD_HEIGHT,
  points,
  rowOffset,
  type Socket,
  type StageOrgan,
  type StagePart,
  tracePath,
} from './parts';

/** The scan chamber, in room pixels, and the character's view inside it, centred where the mirror's is. */
const CHAMBER = { left: 270, top: 64, width: 360, height: 564 } as const;
const VIEW = { left: 14, top: 28, width: 332, height: 520 } as const;
/** As large as the stage shows a character: a tile 384px across, as the mirror does. */
const STAGE_SCALE = 12;

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
  tags: { text: string; className?: string }[];
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

  const [hover, setHover] = useState<string | null>(null);
  const [open, setOpen] = useState<Open | null>(null);
  const [peek, setPeek] = useState<string | null>(null);
  // What was last installed, and a count that makes its effects play again.
  const [installed, setInstalled] = useState<{
    slot: string;
    n: number;
  } | null>(null);
  const [placed, setPlaced] = useState<Placed | null>(null);
  const species =
    useServerPrefs()?.species?.[data.character_preferences?.misc?.species ?? '']
      ?.name;

  // Which body region owns each pixel, asked for each drawing, as the markings room does.
  const previewId = data.character_preview?.id;
  useEffect(() => {
    if (previewId !== undefined) {
      act('markings_room_regions', { id: previewId });
    }
  }, [previewId]);

  // A layer change starts afresh.
  useEffect(() => {
    setHover(null);
    setOpen(null);
    setPeek(null);
  }, [internals]);

  // Escape puts the picker away.
  const pickerOpen = !!open;
  useEffect(() => {
    if (!pickerOpen) {
      return;
    }
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setOpen(null);
        setPeek(null);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [pickerOpen]);

  const partBySlot = useMemo(
    () => Object.fromEntries(parts.map((part) => [part.socket.slot, part])),
    [parts],
  );
  const organBySlot = useMemo(
    () => Object.fromEntries(organs.map((organ) => [organ.socket.slot, organ])),
    [organs],
  );

  const active = open?.slot ?? hover;
  const activePart = !internals && active ? partBySlot[active] : undefined;

  const openPicker = (socket: Socket, field: Field, row: number) => {
    if (open?.slot === socket.slot && open.field === field) {
      setOpen(null);
      setPeek(null);
      return;
    }
    setOpen({
      slot: socket.slot,
      field,
      side: socket.side,
      oy: rowOffset(socket.top, row),
    });
    setPeek(null);
  };

  const pick = (slot: string, field: Field, option: Option) => {
    setOpen(null);
    setPeek(null);
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
      return part.finishes.map((name) => ({
        key: name,
        name,
        cost: 0,
        info: '',
        item: null,
        tags:
          name === part.finish ? [{ text: 'INSTALLED', className: 'cur' }] : [],
        current: name === part.finish,
        dear: false,
      }));
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
  }, [open, partBySlot, organBySlot, pointsOn, balance]);

  const sockets = internals
    ? organs.map((o) => o.socket)
    : parts.map((p) => p.socket);
  const cardHeight = internals ? ORGAN_CARD_HEIGHT : PART_CARD_HEIGHT;

  // Where each socket's trace lands, in room pixels, from where the character stands.
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
      const [x, y] = previewFramePoint(
        preview,
        view.scale,
        view.x,
        view.y,
        preview.x + socket.port[0],
        tileTop + socket.port[1],
      );
      out[socket.slot] = [originX + x, originY + y];
    }
    return out;
  }, [placed, internals]);

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

  const peeked = open && peek ? options.find((o) => o.key === peek) : undefined;

  return (
    <div
      className={classes([
        'AugStage',
        internals && 'AugStage--internals',
        !!active && 'AugStage--hovering',
      ])}
    >
      <div className="chamber" />
      <div className="pad" />
      <div
        className="AugStage__view"
        onPointerMove={(event) => {
          if (internals || event.buttons) {
            return;
          }
          const part = partAt(event.clientX, event.clientY);
          setHover(part ? part.socket.slot : null);
        }}
        onPointerLeave={() => !internals && setHover(null)}
      >
        <div className="AugStage__box">
          <CharacterPreview
            motif="chamber"
            lit
            width={`${VIEW.width}px`}
            height={`${VIEW.height}px`}
            maxScale={STAGE_SCALE}
            onTap={(x, y) => {
              if (internals) {
                return;
              }
              const part = partAt(x, y);
              if (part) {
                openPicker(part.socket, 'part', 0);
              }
            }}
            overlay={(view) => (
              <StageOverlay
                view={view}
                regions={data.markings_room_regions}
                internals={internals}
                lit={activePart?.socket.zones ?? null}
                peek={
                  activePart && open?.field === 'part' && peeked?.item?.path
                    ? activePart.socket.zones
                    : null
                }
                installed={
                  installed && !internals && partBySlot[installed.slot]
                    ? {
                        zones: partBySlot[installed.slot].socket.zones,
                        n: installed.n,
                      }
                    : null
                }
                onPlaced={setPlaced}
              />
            )}
          />
        </div>
      </div>
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
      </div>
      <Traces
        sockets={sockets}
        anchors={anchors}
        cardHeight={cardHeight}
        active={active}
        live={(slot) =>
          internals
            ? !isStock(organBySlot[slot]?.installed)
            : partLive(partBySlot[slot])
        }
        bare={internals}
        installed={installed}
      />
      {internals &&
        sockets.map((socket) => {
          const at = anchors[socket.slot];
          if (!at) {
            return null;
          }
          const organ = organBySlot[socket.slot];
          return (
            <button
              key={socket.slot}
              type="button"
              className={classes([
                'node',
                active === socket.slot && 'on',
                !isStock(organ?.installed) && 'live',
              ])}
              style={{ left: `${at[0]}px`, top: `${at[1]}px` }}
              aria-label={`${socket.name.toLowerCase()}: open the list`}
              onMouseEnter={() => setHover(socket.slot)}
              onMouseLeave={() => setHover(null)}
              onFocus={() => setHover(socket.slot)}
              onBlur={() => setHover(null)}
              onClick={() => openPicker(socket, 'organ', 0)}
            />
          );
        })}
      {internals
        ? organs.map((organ, index) => (
            <OrganCard
              key={organ.socket.slot}
              organ={organ}
              index={index}
              on={active === organ.socket.slot}
              open={open}
              pointsOn={pointsOn}
              onHover={setHover}
              onOpen={openPicker}
            />
          ))
        : parts.map((part, index) => (
            <PartCard
              key={part.socket.slot}
              part={part}
              index={index}
              on={active === part.socket.slot}
              open={open}
              pointsOn={pointsOn}
              onHover={setHover}
              onOpen={openPicker}
            />
          ))}
      <div className="console">
        <Readout
          internals={internals}
          hover={hover}
          open={open}
          peeked={peeked}
          partBySlot={partBySlot}
          organBySlot={organBySlot}
          pointsOn={pointsOn}
        />
        <Installed parts={parts} organs={organs} pointsOn={pointsOn} />
      </div>
      {!!open && (
        <Picker
          open={open}
          options={options}
          peek={peek}
          title={
            internals
              ? (organBySlot[open.slot]?.socket.name ?? open.slot)
              : (partBySlot[open.slot]?.socket.name ?? open.slot)
          }
          pointsOn={pointsOn}
          onPeek={setPeek}
          onPick={(option) => pick(open.slot, open.field, option)}
          onClose={() => {
            setOpen(null);
            setPeek(null);
          }}
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
  on: boolean;
  open: Open | null;
  pointsOn: boolean;
  onHover: (slot: string | null) => void;
  onOpen: (socket: Socket, field: Field, row: number) => void;
} & T;

type Row = {
  field: Field;
  value: string;
  off: boolean;
  none: boolean;
  cost: number;
};

function Card(props: {
  socket: Socket;
  index: number;
  height: number;
  on: boolean;
  live: boolean;
  open: Open | null;
  rows: Row[];
  pointsOn: boolean;
  onHover: (slot: string | null) => void;
  onOpen: (socket: Socket, field: Field, row: number) => void;
}) {
  const { socket, index, height, on, live, open, rows, pointsOn } = props;
  const { onHover, onOpen } = props;
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
      onMouseEnter={() => onHover(socket.slot)}
      onMouseLeave={() => onHover(null)}
    >
      <div className="sock-hd">
        <span className="sock-code">{socket.code}</span>
        <span className="sock-name">{socket.name}</span>
        <span className="sock-state">{live ? 'INSTALLED' : 'STOCK'}</span>
      </div>
      <div className="rule" />
      {rows.map((row, n) => {
        const isOpen = open?.slot === socket.slot && open.field === row.field;
        return (
          <button
            key={row.field}
            type="button"
            className={classes(['row', row.none && 'none', isOpen && 'open'])}
            // Disabled for the reader, not the browser: MeridianOS hatches disabled buttons its own way.
            aria-disabled={row.off}
            aria-haspopup="listbox"
            aria-expanded={isOpen}
            onClick={() => !row.off && onOpen(socket, row.field, n)}
            onFocus={() => onHover(socket.slot)}
            onBlur={() => onHover(null)}
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
      })}
    </div>
  );
}

function PartCard(props: CardProps<{ part: StagePart }>) {
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
      on={props.on}
      live={partLive(part)}
      open={props.open}
      rows={rows}
      pointsOn={props.pointsOn}
      onHover={props.onHover}
      onOpen={props.onOpen}
    />
  );
}

function OrganCard(props: CardProps<{ organ: StageOrgan }>) {
  const { organ } = props;
  const stock = isStock(organ.installed);
  return (
    <Card
      socket={organ.socket}
      index={props.index}
      height={ORGAN_CARD_HEIGHT}
      on={props.on}
      live={!stock}
      open={props.open}
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
      onHover={props.onHover}
      onOpen={props.onOpen}
    />
  );
}

/** The traces from each card to its socket on the body. */
const Traces = memo(function Traces(props: {
  sockets: Socket[];
  anchors: Record<string, [number, number]>;
  cardHeight: number;
  active: string | null;
  live: (slot: string) => boolean;
  bare: boolean;
  installed: { slot: string; n: number } | null;
}) {
  const { sockets, anchors, cardHeight, active, live, bare, installed } = props;
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
              live(socket.slot) && 'live',
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
 * Everything the stage draws on the character, lined up with its frame and
 * panning with it: the part the pointer is on, lit in the hot light with a
 * scan running down it and a halo outside it; a part's chrome while its
 * picker tries one on; the flash and sheen of a part going in; and the
 * internals' x-ray. Tells the stage where the character stands.
 */
function StageOverlay(props: {
  view: PreviewView;
  regions: MarkingsRoomData['markings_room_regions'];
  internals: boolean;
  lit: string[] | null;
  peek: string[] | null;
  installed: { zones: string[]; n: number } | null;
  onPlaced: (placed: Placed) => void;
}) {
  const { view, regions, internals, lit, peek, installed, onPlaced } = props;
  const { shown, dir, scale, x, y } = view;
  const { preview, image } = shown;
  const frame = useRef<HTMLSpanElement>(null);
  const map = useMemo(
    () =>
      regions && regions.id === preview.id
        ? frameRegions(preview, regions, dir)
        : undefined,
    [preview, regions, dir],
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
  const litStyle = internals ? null : masked(lit);
  const peekStyle = internals ? null : masked(peek);
  const installedStyle = installed ? masked(installed.zones) : null;
  const facing =
    internals && image ? facingImage(image, preview, dir) : undefined;
  const xray = facing
    ? {
        ...style,
        maskImage: `url(${facing})`,
        WebkitMaskImage: `url(${facing})`,
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

/** The console's readout: what the pointer or the picker is on. */
function Readout(props: {
  internals: boolean;
  hover: string | null;
  open: Open | null;
  peeked: Option | undefined;
  partBySlot: Record<string, StagePart>;
  organBySlot: Record<string, StageOrgan>;
  pointsOn: boolean;
}) {
  const { internals, hover, open, peeked, partBySlot, organBySlot, pointsOn } =
    props;
  const lines: { text: string; className?: string }[] = [];
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
  const target = open?.slot ?? hover;
  if (open && peeked) {
    const socket = (internals ? organBySlot[open.slot] : partBySlot[open.slot])
      ?.socket;
    kicker = `${socket?.name ?? open.slot} · ${FIELD_NAMES[open.field]}`;
    title = peeked.name.toUpperCase();
    if (peeked.info) {
      lines.push({ text: peeked.info });
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
          {line.text}
        </div>
      ))}
    </div>
  );
}

/** The console's list of what's installed, and what it all costs. */
function Installed(props: {
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
}

/** A socket's picker, unfolding from the row it was opened from over its side of the stage. */
function Picker(props: {
  open: Open;
  options: Option[];
  peek: string | null;
  title: string;
  pointsOn: boolean;
  onPeek: (key: string | null) => void;
  onPick: (option: Option) => void;
  onClose: () => void;
}) {
  const { open, options, peek, title, pointsOn, onPeek, onPick, onClose } =
    props;
  const left = open.side === 'l';
  const organ = open.field === 'organ';
  const list = useRef<HTMLDivElement>(null);
  // The keyboard starts on what's installed.
  useEffect(() => {
    list.current?.querySelector<HTMLButtonElement>('.opt.cur')?.focus({
      preventScroll: false,
    });
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
            left: `${left ? 12 : 588}px`,
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
          <div
            ref={list}
            className="fly-list"
            role="listbox"
            onMouseLeave={() => onPeek(null)}
          >
            {options.map((option, i) => (
              <button
                key={option.key}
                type="button"
                className={classes([
                  'opt',
                  option.current && 'cur',
                  peek === option.key && 'peek',
                  option.dear && 'dear',
                ])}
                style={{ '--i': Math.min(i, 18) } as CSSProperties}
                role="option"
                aria-selected={option.current}
                aria-disabled={option.dear}
                onClick={() => onPick(option)}
                onMouseEnter={() => onPeek(option.key)}
                onFocus={() => onPeek(option.key)}
              >
                <span className="opt-n">{option.name}</span>
                <span
                  className={classes(['opt-c', option.cost < 0 && 'refund'])}
                >
                  {pointsOn ? points(option.cost) : ''}
                </span>
                {!!option.info && <span className="opt-x">{option.info}</span>}
                <span className="opt-tags">
                  {option.tags.map((tag) => (
                    <span
                      key={tag.text}
                      className={classes(['tag', tag.className])}
                    >
                      {tag.text}
                    </span>
                  ))}
                </span>
              </button>
            ))}
          </div>
        </div>
      </div>
    </>
  );
}
