// THIS IS AN APHELION UI FILE
import { useEffect, useLayoutEffect, useRef, useState } from 'react';

import { TILE } from '../CharacterPreview/drawing';
import { speciesSpriteClasses } from '../SpeciesRegistry/constants';
import { MarkingContextMenu } from './ContextMenu';
import { Counter } from './Counter';
import {
  isLeg,
  MARKING_ZONES,
  type MarkingZone,
  PAINTS,
  TAUR_ZONE,
  ZONE_CARDS,
} from './constants';
import { Drawer, type DrawerContents, lookMarkings } from './Drawer';
import { type RoomData, useRoomData, type WornMarking } from './data';
import { ROOM_DECOR } from './decor';
import {
  Mirror,
  type MirrorAnchor,
  type MirrorLights,
  zoneCentre,
} from './Mirror';
import { useDecorProps } from './Room';
import { regionBounds } from './regions';
import { primeSpriteCells } from './sprites';
import type { ThumbMarking } from './Thumb';
import type { RoomTheme } from './themes';
import { setTried } from './tryOn';
import { ZoneCard } from './ZoneCard';

export { useRoomData } from './data';
export {
  AugmentsLayers,
  AugmentsRoom,
  MarkingsTools,
  useClubRoom,
  useRoomTheme,
} from './Room';

/** The room is drawn at this size, whatever the window's zoom. */
const ROOM_WIDTH = 900;

type Props = {
  /** The room's theme. */
  theme: RoomTheme;
  /** Sends a markings action, as the page's other controls do. */
  act: (action: string, params?: Record<string, unknown>) => void;
  /** Puts a look on, once the page has asked whether to replace what it covers. */
  onLook: (preset: string) => void;
};

/** Paint in flight, from what was clicked to the part it lands on, in room pixels. */
type Flight = {
  serial: number;
  path: string;
  color: string;
  x: number;
  y: number;
};

/** A marking just put on or painted, inked in at once while the server draws it. */
type Ink = {
  serial: number;
  marking: ThumbMarking;
  /** The drawing shown when it was inked: it stays until the next comes. */
  previewId: number | undefined;
  at: number;
};

/** What the pointer has lit on a card: a worn marking by its place, or the custom drawing. */
type CardLight = { zone: MarkingZone; what: number | 'custom' };

const isMarkingZone = (zone: string | null): zone is MarkingZone =>
  !!zone && (MARKING_ZONES as readonly string[]).includes(zone);

/** The first marking worn, in card order, for a room that has just been restocked. */
function firstWorn(room: RoomData) {
  for (const card of ZONE_CARDS) {
    if (room.wornByZone[card.zone].length) {
      return { zone: card.zone, index: 0 };
    }
  }
  return null;
}

/**
 * Augments+ Markings: the theme's room round a mirror (the club's is its
 * bathroom mirror, the character lit in it by neon), each zone's markings on a
 * card stuck up either side, and a counter of paints below. Pointing at a part
 * on a card or on the body halos it in the mirror; a drawer of markings or
 * looks tries each on before it is picked. The tabs' character preview is the
 * mirror's picture.
 */
export function MarkingsRoom(props: Props) {
  const { theme, act, onLook } = props;
  const decor = useDecorProps();
  const { Wall } = ROOM_DECOR[theme.id];
  const room = useRoomData();
  const [selection, setSelection] = useState<{
    zone: MarkingZone;
    index: number;
  } | null>(() => firstWorn(room));
  // The zone the pointer is on, on a card or the body: a marking zone, or the taur's.
  const [pointed, setPointed] = useState<string | null>(null);
  const [light, setLight] = useState<CardLight | null>(null);
  const [drawer, setDrawer] = useState<DrawerContents | null>(null);
  const [query, setQuery] = useState('');
  const [contextTarget, setContextTarget] = useState<{
    zone: MarkingZone;
    id: WornMarking['marking_id'];
    anchor: HTMLButtonElement;
  } | null>(null);
  const contextMarking = contextTarget
    ? room.wornByZone[contextTarget.zone].find(
        (marking) => marking.marking_id === contextTarget.id,
      )
    : undefined;
  const [flight, setFlight] = useState<Flight | null>(null);
  const [ink, setInk] = useState<Ink | null>(null);
  // Bumped when the character moves in the glass, so the dimming follows it.
  const [, setPlaced] = useState(0);
  const anchor = useRef<MirrorAnchor>({
    frame: null,
    view: null,
    regions: null,
  });
  const root = useRef<HTMLDivElement>(null);
  // Every marking replaced at once: the markings the server had then, whose
  // replacements get their first one selected when they come.
  const reselect = useRef<{ from: unknown } | null>(null);

  // Which body region owns each pixel, asked for each drawing the room is sent.
  const previewId = room.preview?.id;
  useEffect(() => {
    if (previewId !== undefined) {
      act('markings_room_regions', { id: previewId });
    }
  }, [previewId]);

  // Every card's sprites in one style pass, before the cards ask one by one.
  primeSpriteCells([
    room.speciesIcon
      ? speciesSpriteClasses(room.speciesIcon, 'south', true)
      : undefined,
    ...MARKING_ZONES.flatMap((zone) =>
      room.wornByZone[zone].map((marking) => room.icons[zone]?.[marking.name]),
    ),
  ]);

  const selected: WornMarking | null = selection
    ? (room.wornByZone[selection.zone][selection.index] ?? null)
    : null;

  // A restock lands: select its first marking, as a look book or a surprise does.
  useLayoutEffect(() => {
    if (reselect.current && reselect.current.from !== room.data.markings) {
      reselect.current = null;
      setSelection(firstWorn(room));
    }
  });

  // Ink holds until the server's drawing of it comes, and at least as long as it takes to dry.
  useEffect(() => {
    if (!ink) {
      return;
    }
    const drawn = previewId !== ink.previewId;
    const timer = setTimeout(
      () => setInk(null),
      drawn ? Math.max(0, ink.at + 700 - Date.now()) : 5000,
    );
    return () => clearTimeout(timer);
  }, [ink, previewId]);

  // Nothing stays tried on once the room goes.
  useEffect(() => () => setTried(null), []);

  // Escape puts the drawer away, wherever the keyboard is.
  const drawerOpen = !!drawer;
  useEffect(() => {
    if (!drawerOpen) {
      return;
    }
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        closeDrawer();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [drawerOpen]);

  // Paint lands and is gone.
  useEffect(() => {
    if (!flight) {
      return;
    }
    const timer = setTimeout(() => setFlight(null), 1100);
    return () => clearTimeout(timer);
  }, [flight]);

  const drawerZone = drawer && 'zone' in drawer ? drawer.zone : null;
  // The zone dimmed round in the glass: the one pointed at, or the drawer's.
  const focus = pointed ?? drawerZone;
  // A taur body stands for both legs.
  const cardLit = (zone: MarkingZone) =>
    focus === zone || (focus === TAUR_ZONE && room.taurLegs && isLeg(zone));
  const regionOf = (zone: string) =>
    isLeg(zone) && room.taurLegs ? TAUR_ZONE : zone;

  const lights: MirrorLights = {
    zone: pointed ? regionOf(pointed) : null,
    marking: null,
    custom: null,
    tryOn: null,
    ink: ink && { serial: ink.serial, marking: ink.marking },
  };
  if (light && light.what === 'custom') {
    lights.custom = room.customViews[room.drawingZone(light.zone)] ?? null;
  } else if (light) {
    const marking = room.wornByZone[light.zone][light.what];
    const icon = marking && room.icons[light.zone]?.[marking.name];
    lights.marking = icon
      ? {
          icon,
          nativeIcon: room.nativeIcons[light.zone]?.[marking.name],
          color: marking.color,
        }
      : null;
  }
  if (drawer) {
    lights.tryOn = (name) => {
      if ('book' in drawer) {
        return lookMarkings(room, name);
      }
      const icon = room.icons[drawer.zone]?.[name];
      return icon
        ? [
            {
              icon,
              nativeIcon: room.nativeIcons[drawer.zone]?.[name],
              color: room.startColor(name) ?? '#ffffff',
            },
          ]
        : [];
    };
  }
  const spotZone = focus ? regionOf(focus) : null;
  const spot = spotZone ? (zoneCentre(anchor.current, spotZone) ?? null) : null;

  /** Paint flies from what was clicked to the middle of the part it lands on. */
  const fly = (from: Element, zone: string, color: string) => {
    const box = root.current?.getBoundingClientRect();
    const { frame, view, regions } = anchor.current;
    if (!box || !frame || !view) {
      return;
    }
    const scale = box.width / ROOM_WIDTH || 1;
    const start = from.getBoundingClientRect();
    const x1 = (start.left + start.width / 2 - box.left) / scale;
    const y1 = (start.top + start.height / 2 - box.top) / scale;
    const { preview } = view.shown;
    const bounds = regions ? regionBounds(regions, regionOf(zone)) : undefined;
    // Without the part, the middle of the character's tile.
    const [middleX, middleY] = bounds
      ? [(bounds[0] + bounds[2]) / 2, (bounds[1] + bounds[3]) / 2]
      : [preview.x + TILE / 2, preview.height - preview.y - TILE / 2];
    const target = frame.getBoundingClientRect();
    const x2 =
      (target.left + (middleX / preview.width) * target.width - box.left) /
      scale;
    const y2 =
      (target.top + (middleY / preview.height) * target.height - box.top) /
      scale;
    const f = (value: number) => value.toFixed(1);
    setFlight((last) => ({
      serial: (last?.serial ?? 0) + 1,
      path: `M${f(x1)} ${f(y1)} Q${f((x1 + x2) / 2)} ${f(Math.min(y1, y2) - 110)} ${f(x2)} ${f(y2)}`,
      color,
      x: x2,
      y: y2,
    }));
  };

  /** Inks a marking on a zone in its colour, as it goes on. */
  const inkIn = (zone: MarkingZone, name: string, color: string) => {
    const icon = room.icons[zone]?.[name];
    if (icon) {
      setInk((last) => ({
        serial: (last?.serial ?? 0) + 1,
        marking: { icon, nativeIcon: room.nativeIcons[zone]?.[name], color },
        previewId,
        at: Date.now(),
      }));
    }
  };

  const closeDrawer = () => {
    setDrawer(null);
    setTried(null);
    setQuery('');
  };
  const openDrawer = (contents: DrawerContents) => {
    setContextTarget(null);
    setDrawer(contents);
    setTried(null);
    setQuery('');
  };
  const swapMarking = (zone: MarkingZone, index: number) => {
    setSelection({ zone, index });
    openDrawer({ zone, replace: index });
  };
  const markingParams = (marking: WornMarking) => ({
    bodypart_slot: marking.zone,
    marking_id: marking.marking_id,
  });

  const toggleGlow = (marking: WornMarking) => {
    act('change_emissive', {
      ...markingParams(marking),
      emissive: marking.emissive,
    });
  };
  const removeMarking = (marking: WornMarking) => {
    act('remove_marking', markingParams(marking));
    const left = room.wornByZone[marking.zone].length - 1;
    setSelection(
      left
        ? { zone: marking.zone, index: Math.min(marking.index, left - 1) }
        : null,
    );
  };

  const openDrawing = (zone: string) => {
    if (!room.canDraw) return;
    setContextTarget(null);
    act('open_custom_sprite_editor', {
      target: 'markings',
      body_zone: zone,
    });
  };
  const pickZone = (zone: string) => {
    if (room.taurLegs && zone === TAUR_ZONE) {
      openDrawing(TAUR_ZONE);
      return;
    }
    if (!isMarkingZone(zone) || (room.taurLegs && isLeg(zone))) {
      return;
    }
    if (room.wornByZone[zone].length < room.max) {
      openDrawer({ zone, replace: null });
    } else {
      setSelection({ zone, index: 0 });
    }
  };

  return (
    <div ref={root} className="MarkingsRoom">
      {!!Wall && (
        <div className="MarkingsRoom__wall" aria-hidden="true">
          <Wall {...decor} />
        </div>
      )}
      <Mirror
        theme={theme}
        decor={decor}
        lights={lights}
        regions={room.regions}
        anchor={anchor}
        spot={spot}
        onPlaced={() => setPlaced((count) => count + 1)}
        onPoint={(zone) => setPointed((last) => (last === zone ? last : zone))}
        onPick={pickZone}
      />
      {ZONE_CARDS.map((card, order) => (
        <ZoneCard
          key={card.zone}
          theme={theme}
          room={room}
          zone={card.zone}
          side={card.side}
          row={card.row}
          order={order}
          lit={cardLit(card.zone)}
          selected={selection?.zone === card.zone ? selection.index : null}
          onPoint={setPointed}
          onLight={(what) =>
            setLight(what === null ? null : { zone: card.zone, what })
          }
          onSelect={(index) => {
            setContextTarget(null);
            setSelection({ zone: card.zone, index });
          }}
          onMenu={(index, anchor) => {
            setSelection({ zone: card.zone, index });
            setContextTarget({
              zone: card.zone,
              id: room.wornByZone[card.zone][index].marking_id,
              anchor,
            });
          }}
          onAdd={() => openDrawer({ zone: card.zone, replace: null })}
          onDraw={() => openDrawing(room.drawingZone(card.zone))}
        />
      ))}
      <Counter
        theme={theme}
        room={room}
        selected={selected}
        onSwap={() => selected && swapMarking(selected.zone, selected.index)}
        onGlow={() => selected && toggleGlow(selected)}
        onScrub={() => selected && removeMarking(selected)}
        onPaint={(color, from) => {
          if (!selected) {
            return;
          }
          if (color) {
            act('color_marking', { ...markingParams(selected), color });
          } else {
            act('reset_marking_color', markingParams(selected));
          }
          fly(from, selected.zone, color ?? selected.start);
          inkIn(selected.zone, selected.name, color ?? selected.start);
        }}
        onBook={() => openDrawer({ book: true })}
        onSurprise={(from) => {
          act('surprise_markings');
          reselect.current = { from: room.data.markings };
          fly(
            from,
            'chest',
            PAINTS[Math.floor(Math.random() * PAINTS.length)].color,
          );
        }}
      />
      {!!contextTarget && !!contextMarking && (
        <MarkingContextMenu
          key={`${contextTarget.zone}/${contextTarget.id}`}
          anchor={contextTarget.anchor}
          marking={contextMarking}
          canGlow={room.canGlow}
          onChange={() =>
            swapMarking(contextMarking.zone, contextMarking.index)
          }
          onGlow={() => toggleGlow(contextMarking)}
          onRemove={() => removeMarking(contextMarking)}
          onClose={() => setContextTarget(null)}
        />
      )}
      {!!drawer && (
        <Drawer
          room={room}
          contents={drawer}
          query={query}
          onQuery={setQuery}
          onClose={closeDrawer}
          onPick={(name, from) => {
            if (!drawerZone) {
              return;
            }
            const zone = drawerZone;
            const replace = 'replace' in drawer ? drawer.replace : null;
            const swapped =
              replace !== null ? room.wornByZone[zone][replace] : undefined;
            if (swapped) {
              act('change_marking', {
                ...markingParams(swapped),
                marking_name: name,
              });
              setSelection({ zone, index: swapped.index });
              // A swap keeps the row's colour.
              fly(from, zone, swapped.color);
              inkIn(zone, name, swapped.color);
            } else {
              act('add_marking', { bodypart_slot: zone, marking_name: name });
              setSelection({ zone, index: room.wornByZone[zone].length });
              fly(from, zone, room.startColor(name) ?? '#ffffff');
              inkIn(zone, name, room.startColor(name) ?? '#ffffff');
            }
            closeDrawer();
          }}
          onLook={(name, from) => {
            onLook(name);
            reselect.current = { from: room.data.markings };
            fly(from, 'chest', room.data.marking_fur_colors?.[1] ?? '#ffffff');
            closeDrawer();
          }}
        />
      )}
      {!!flight && (
        <svg
          key={flight.serial}
          className="MarkingsRoom__fx"
          viewBox="0 0 900 820"
          aria-hidden="true"
        >
          <path
            className="MarkingsRoom__trail"
            d={flight.path}
            pathLength={1}
            style={{ stroke: flight.color, color: flight.color }}
          />
          <circle
            className="MarkingsRoom__splash"
            cx={flight.x}
            cy={flight.y}
            r={18}
            style={{ stroke: flight.color }}
          />
        </svg>
      )}
    </div>
  );
}
