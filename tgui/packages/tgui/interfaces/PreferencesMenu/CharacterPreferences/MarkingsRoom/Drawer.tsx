// THIS IS AN APHELION UI FILE
import { type CSSProperties, memo } from 'react';
import { classes } from 'tgui-core/react';

import { speciesSpriteClasses } from '../SpeciesRegistry/constants';
import {
  BOOK_TILE,
  DRAWER_TILE,
  DRAWER_ZOOM,
  MARKING_ZONES,
  type MarkingZone,
  MUTANT_COLOR_NAMES,
  ZONE_CARDS,
  ZONE_NAMES,
} from './constants';
import {
  presetZoneMarkings,
  type RoomData,
  suitsSpecies,
  unavailableMarkings,
} from './data';
import { primeSpriteCells } from './sprites';
import { Thumb, type ThumbMarking, useBlankMarking } from './Thumb';
import { setTried, useIsTried, useTried } from './tryOn';
import { zoneMiddle } from './ZoneCard';

/** What the drawer holds: a zone's markings, to add one or swap one out (by its place), or the look book. */
export type DrawerContents =
  | { zone: MarkingZone; replace: number | null }
  | { book: true };

type Props = {
  room: RoomData;
  contents: DrawerContents;
  query: string;
  onQuery: (query: string) => void;
  /** A marking was picked, from the tile clicked. */
  onPick: (name: string, from: Element) => void;
  /** None was picked while swapping one out: it comes off. */
  onRemove: () => void;
  /** A look was picked. */
  onLook: (name: string, from: Element) => void;
  onClose: () => void;
};

/** None, in the try-on store while the pointer is on it: no marking is named so. */
const NONE = '\u0000none';

/** The markings a look puts on each zone, in their starting colours, as the mirror and its picture show them. */
export function lookMarkings(room: RoomData, preset: string) {
  const look = room.presets.find((candidate) => candidate.name === preset);
  const markings: ThumbMarking[] = [];
  if (!look) {
    return markings;
  }
  for (const zone of MARKING_ZONES) {
    if (room.taurLegs && (zone === 'l_leg' || zone === 'r_leg')) {
      continue;
    }
    for (const name of presetZoneMarkings(look, room.icons[zone], room.max)) {
      markings.push({
        icon: room.icons[zone][name],
        nativeIcon: room.nativeIcons[zone]?.[name],
        color: room.startColor(name) ?? '#ffffff',
      });
    }
  }
  return markings;
}

/**
 * The drawer that slides out over a column of cards: a sticker sheet of the
 * markings a zone can wear, to add one or swap one out, or the look book of
 * presets. The pointer on one tries it on in the mirror (tryOn.ts): that draws
 * again only the pick, the mirror's ghost and the drawer's foot.
 */
export function Drawer(props: Props) {
  const { contents, onClose } = props;
  const zone = 'zone' in contents ? contents.zone : null;
  // A zone's drawer covers its own column of cards; the look book the right.
  const left =
    zone && ZONE_CARDS.find((card) => card.zone === zone)?.side === 'left';
  return (
    <>
      <button
        type="button"
        className="MarkingsRoom__scrim"
        aria-label="Close the drawer"
        onClick={onClose}
      />
      <div
        className="MarkingsRoom__drawer"
        role="dialog"
        aria-label={zone ? `${ZONE_NAMES[zone]} markings` : 'Marking sets'}
        style={
          {
            left: left ? '12px' : '588px',
            '--drawer-from': left ? '1' : '-1',
          } as CSSProperties
        }
      >
        {zone ? (
          <MarkingSheet
            {...props}
            zone={zone}
            replace={'replace' in contents ? contents.replace : null}
          />
        ) : (
          <LookBook {...props} />
        )}
      </div>
    </>
  );
}

function DrawerHead(props: {
  title: string;
  subtitle: string;
  onClose: () => void;
}) {
  return (
    <div className="MarkingsRoom__drawerHead">
      <div className="MarkingsRoom__drawerTitle" data-n={props.title}>
        {props.title}
      </div>
      <div className="MarkingsRoom__drawerSub">{props.subtitle}</div>
      <button
        type="button"
        className="MarkingsRoom__close"
        aria-label="Close"
        onClick={props.onClose}
      >
        <svg viewBox="0 0 12 12" aria-hidden="true">
          <path d="M2 2 10 10M10 2 2 10" />
        </svg>
      </button>
    </div>
  );
}

function MarkingSheet(
  props: Props & { zone: MarkingZone; replace: number | null },
) {
  const { room, zone, replace, query, onQuery, onPick } = props;
  const worn = room.wornByZone[zone];
  const swapping = replace !== null ? worn[replace] : undefined;
  const offered = room.choices[zone] ?? [];
  const icons = room.icons[zone] ?? {};
  const unavailable = unavailableMarkings(worn, room.info, offered, swapping);
  const wanted = query.trim().toLowerCase();
  const shown = offered.filter(
    (name) => !wanted || name.toLowerCase().includes(wanted),
  );
  const suits = (name: string) =>
    suitsSpecies(room.info[name]?.recommended_species, room.species);
  const suiting = shown.filter(suits);
  // Without mismatched parts, a marking meant for other species is refused.
  const others = room.allowMismatched
    ? shown.filter((name) => !suits(name))
    : [];
  const body = room.speciesIcon
    ? speciesSpriteClasses(room.speciesIcon, 'south', true)
    : undefined;
  // Every pick's cell in one style pass, before the tiles ask one by one.
  primeSpriteCells([body, ...shown.map((name) => icons[name])]);

  // Swapping one out, the first pick is none at all, which takes it off.
  const none = swapping && (
    <NoneTile
      key={NONE}
      name={swapping.name}
      body={body}
      zone={zone}
      onRemove={props.onRemove}
    />
  );
  const first = none ? 1 : 0;
  const tile = (name: string, order: number) => {
    const taken = unavailable.has(name);
    const icon = icons[name];
    return (
      <SheetTile
        key={name}
        name={name}
        order={order + first}
        taken={taken}
        icon={icon}
        body={body}
        zone={zone}
        color={room.startColor(name) ?? '#ffffff'}
        onPick={onPick}
      />
    );
  };

  return (
    <>
      <DrawerHead
        title={ZONE_NAMES[zone]}
        subtitle={
          swapping
            ? `Swap out ${swapping.name}`
            : `Add a marking · slot ${worn.length + 1} of ${room.max}`
        }
        onClose={props.onClose}
      />
      <label className="MarkingsRoom__search">
        <svg viewBox="0 0 14 14" aria-hidden="true">
          <circle cx="6" cy="6" r="4.2" />
          <path d="M9.2 9.2 12.5 12.5" />
        </svg>
        <input
          type="search"
          placeholder={`Search ${offered.length} markings`}
          value={query}
          aria-label="Search markings"
          onChange={(event) => onQuery(event.target.value)}
        />
      </label>
      <div className="MarkingsRoom__list" onMouseLeave={() => setTried(null)}>
        {!!suiting.length && (
          <>
            <div className="MarkingsRoom__section">
              Suits {room.speciesName} · {suiting.length}
            </div>
            <div className="MarkingsRoom__grid">
              {none}
              {suiting.map((name, order) => tile(name, order))}
            </div>
          </>
        )}
        {!!others.length && (
          <>
            <div className="MarkingsRoom__section">
              Other species · {others.length}
            </div>
            <div className="MarkingsRoom__grid">
              {!suiting.length && none}
              {others.map((name, order) => tile(name, order + suiting.length))}
            </div>
          </>
        )}
        {!suiting.length && !others.length && (
          <>
            {!!none && <div className="MarkingsRoom__grid">{none}</div>}
            <div className="MarkingsRoom__empty">No markings match that.</div>
          </>
        )}
      </div>
      <SheetFoot
        room={room}
        offered={offered}
        icons={icons}
        swapping={swapping?.name}
      />
    </>
  );
}

/** None, the sheet's first pick while swapping one out: the bare body, crossed out. Picked, the marking comes off. */
function NoneTile(props: {
  name: string;
  body: string | undefined;
  zone: MarkingZone;
  onRemove: () => void;
}) {
  const { name, body, zone, onRemove } = props;
  const peek = useIsTried(NONE);
  return (
    <button
      type="button"
      className={classes([
        'MarkingsRoom__tile',
        'MarkingsRoom__pick',
        'MarkingsRoom__pick--none',
        peek && 'MarkingsRoom__pick--peek',
      ])}
      style={{ '--pick-order': 0 } as CSSProperties}
      aria-label={`None, take off ${name}`}
      onClick={onRemove}
      onMouseEnter={() => setTried(NONE)}
      onFocus={() => setTried(NONE)}
      onBlur={() => setTried(null)}
    >
      <SheetPicture icon={undefined} body={body} zone={zone} color="" />
      <svg
        className="MarkingsRoom__noneMark"
        viewBox="0 0 12 12"
        aria-hidden="true"
      >
        <path d="M3 3 9 9M9 3 3 9" />
      </svg>
      <span className="MarkingsRoom__back MarkingsRoom__back--none">NONE</span>
    </button>
  );
}

/** The sheet's foot: what the pointer is trying on, and how it is coloured; or, on None, what comes off. */
function SheetFoot(props: {
  room: RoomData;
  offered: string[];
  icons: Record<string, string>;
  /** The marking being swapped out, if one is. */
  swapping?: string;
}) {
  const { room, offered, icons, swapping } = props;
  const trying = useTried();
  const tried = trying && offered.includes(trying) ? trying : null;
  const triedBack = useBlankMarking(tried ? icons[tried] : undefined);
  const triedMode = tried ? room.info[tried]?.color_mode : undefined;
  if (trying === NONE && swapping) {
    return (
      <div className="MarkingsRoom__foot">
        <span className="MarkingsRoom__footName">None</span>
        <span className="MarkingsRoom__footMeta">Takes off {swapping}</span>
      </div>
    );
  }
  return (
    <div className="MarkingsRoom__foot">
      <span className="MarkingsRoom__footName">
        {tried ?? 'Hover a marking to try it on'}
      </span>
      <span className="MarkingsRoom__footMeta">
        {tried
          ? `${
              triedMode === 'fixed_default' || triedMode === 'locked'
                ? 'Fixed color'
                : `Follows ${MUTANT_COLOR_NAMES[triedMode ?? 'follows_primary'].toLowerCase()}`
            }${triedBack ? ' · drawn on the back' : ''}`
          : 'Click one to put it on'}
      </span>
    </div>
  );
}

/** One marking on the sheet, die-cut. Drawn only on the back, it says so: facing south it shows nothing. */
function SheetTile(props: {
  name: string;
  order: number;
  taken: boolean;
  icon: string | undefined;
  body: string | undefined;
  zone: MarkingZone;
  color: string;
  onPick: (name: string, from: Element) => void;
}) {
  const { name, order, taken, icon, body, zone, color, onPick } = props;
  const peek = useIsTried(name);
  return (
    <button
      type="button"
      className={classes([
        'MarkingsRoom__tile',
        'MarkingsRoom__pick',
        taken && 'MarkingsRoom__pick--taken',
        peek && 'MarkingsRoom__pick--peek',
      ])}
      style={{ '--pick-order': Math.min(order, 24) } as CSSProperties}
      aria-label={`${name}${taken ? ', already on' : ''}`}
      aria-disabled={taken}
      onClick={(event) => {
        if (!taken) {
          onPick(name, event.currentTarget);
        }
      }}
      onMouseEnter={() => setTried(name)}
      onFocus={() => setTried(name)}
      onBlur={() => setTried(null)}
    >
      <SheetPicture icon={icon} body={body} zone={zone} color={color} />
    </button>
  );
}

/** Hover changes the button and mirror, but the sheet's artwork stays the same. */
const SheetPicture = memo(function SheetPicture(props: {
  icon: string | undefined;
  body: string | undefined;
  zone: MarkingZone;
  color: string;
}) {
  const { icon, body, zone, color } = props;
  const back = useBlankMarking(icon);
  return (
    <>
      <Thumb
        className="MarkingsRoom__thumb"
        size={DRAWER_TILE}
        zoom={DRAWER_ZOOM[zone]}
        centre={zoneMiddle(zone)}
        body={body}
        markings={icon ? [{ icon, color }] : []}
      />
      {!!back && <span className="MarkingsRoom__back">BACK ONLY</span>}
    </>
  );
});

function LookBook(props: Props) {
  const { room, onLook } = props;
  const body = room.speciesIcon
    ? speciesSpriteClasses(room.speciesIcon, 'south', true)
    : undefined;
  const looks = room.presets.map(
    (preset) => [preset.name, lookMarkings(room, preset.name)] as const,
  );
  primeSpriteCells([
    body,
    ...looks.flatMap(([, markings]) => markings.map((marking) => marking.icon)),
  ]);
  return (
    <>
      <DrawerHead
        title="Marking Sets"
        subtitle="A marking set replaces the markings on every part it covers"
        onClose={props.onClose}
      />
      <div className="MarkingsRoom__list" onMouseLeave={() => setTried(null)}>
        <div className="MarkingsRoom__section">
          {room.presets.length} marking set
          {room.presets.length === 1 ? '' : 's'}
        </div>
        <div className="MarkingsRoom__grid MarkingsRoom__grid--book">
          {looks.map(([name, markings], order) => (
            <BookTile
              key={name}
              name={name}
              order={order}
              body={body}
              markings={markings}
              onLook={onLook}
            />
          ))}
        </div>
      </div>
      <BookFoot room={room} />
    </>
  );
}

/** One look in the book, pictured on the species' body. */
function BookTile(props: {
  name: string;
  order: number;
  body: string | undefined;
  markings: ThumbMarking[];
  onLook: (name: string, from: Element) => void;
}) {
  const { name, order, body, markings, onLook } = props;
  const peek = useIsTried(name);
  return (
    <button
      type="button"
      className={classes([
        'MarkingsRoom__tile',
        'MarkingsRoom__pick',
        'MarkingsRoom__pick--book',
        peek && 'MarkingsRoom__pick--peek',
      ])}
      style={{ '--pick-order': Math.min(order, 24) } as CSSProperties}
      aria-label={`Apply the ${name} marking set`}
      onClick={(event) => onLook(name, event.currentTarget)}
      onMouseEnter={() => setTried(name)}
      onFocus={() => setTried(name)}
      onBlur={() => setTried(null)}
    >
      <Thumb
        className="MarkingsRoom__bookThumb"
        size={BOOK_TILE}
        zoom={2}
        centre={[16, 16]}
        body={body}
        markings={markings}
      />
      <span className="MarkingsRoom__pickName">{name}</span>
    </button>
  );
}

/** The book's foot: the look the pointer is trying on, and what it puts on. */
function BookFoot(props: { room: RoomData }) {
  const { room } = props;
  const trying = useTried();
  const tried = room.presets.find((preset) => preset.name === trying);
  const triedMarkings = tried ? lookMarkings(room, tried.name) : [];
  return (
    <div className="MarkingsRoom__foot">
      <span className="MarkingsRoom__footName">
        {tried ? tried.name : 'Hover a marking set to try it on'}
      </span>
      <span className="MarkingsRoom__footMeta">
        {tried
          ? tried.markings?.length
            ? `${tried.markings.join(', ')} · ${triedMarkings.length} markings`
            : 'No markings at all'
          : 'The mirror shows it before you commit'}
      </span>
    </div>
  );
}
