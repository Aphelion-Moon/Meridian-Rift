// THIS IS AN APHELION UI FILE
import type { CSSProperties } from 'react';
import { classes } from 'tgui-core/react';

import { speciesSpriteClasses } from '../SpeciesRegistry/constants';
import {
  CARD_TILE,
  CARD_TILT,
  CARD_ZOOM,
  isLeg,
  type MarkingZone,
  ZONE_BOXES,
  ZONE_NAMES,
} from './constants';
import { paintedPixels } from './customs';
import type { RoomData } from './data';
import { Thumb } from './Thumb';
import { cardTag, type RoomTheme } from './themes';

/** The middle of a zone's box, which its thumbnails centre on. */
export const zoneMiddle = (zone: MarkingZone): [number, number] => {
  const [left, top, right, bottom] = ZONE_BOXES[zone];
  return [(left + right) / 2, (top + bottom) / 2];
};

type Props = {
  theme: RoomTheme;
  room: RoomData;
  zone: MarkingZone;
  side: 'left' | 'right';
  row: number;
  /** Its place in the deal, for its tilt and when it lands. */
  order: number;
  /** The pointer is on this zone, here or on the body. */
  lit: boolean;
  /** The worn marking selected here, by its place, or null. */
  selected: number | null;
  onPoint: (zone: MarkingZone | null) => void;
  /** The pointer is on a worn marking's tile (its place) or the custom drawing's, or off them. */
  onLight: (light: number | 'custom' | null) => void;
  onSelect: (index: number) => void;
  onMenu: (index: number, anchor: HTMLButtonElement) => void;
  onAdd: () => void;
  onDraw: () => void;
};

/**
 * A zone's card, stuck up beside the mirror: its markings as die-cut tiles,
 * a dashed slot for each one it has room for, and apart from them the zone's
 * custom drawing, which opens the custom markings editor. Each theme dresses
 * it its own way; the card carries what any of them draws with: two frame
 * lines, a corner tag, and a meter of how many markings it wears.
 */
export function ZoneCard(props: Props) {
  const { theme, room, zone, side, row, order, lit, selected } = props;
  const { onPoint, onLight, onSelect, onMenu, onAdd, onDraw } = props;
  const worn = room.wornByZone[zone];
  const body = room.speciesIcon
    ? speciesSpriteClasses(room.speciesIcon, 'south', true)
    : undefined;
  const zoom = CARD_ZOOM[zone];
  const middle = zoneMiddle(zone);
  const name = ZONE_NAMES[zone];
  // A taur body takes the legs' place: their markings don't show, and their drawing is the taur's.
  const underTaur = room.taurLegs && isLeg(zone);
  const drawingZone = room.drawingZone(zone);
  const drawn = room.drawn(drawingZone);
  const drawing = room.customViews[drawingZone];
  const point = () => onPoint(zone);

  const names = underTaur
    ? 'Under the taur body'
    : `${worn.length ? worn.map((marking) => marking.name).join(' · ') : 'Bare'}${drawn ? ' + custom' : ''}`;

  return (
    <div
      className={classes([
        'MarkingsRoom__card',
        `MarkingsRoom__card--${side}`,
        lit && 'MarkingsRoom__card--lit',
      ])}
      style={
        {
          left: side === 'left' ? '16px' : '638px',
          top: `${64 + row * 144}px`,
          '--card-delay': `${120 + order * 40}ms`,
          '--card-from': side === 'left' ? '1' : '-1',
          '--card-tilt': `${(CARD_TILT[order] * theme.tilt).toFixed(2)}deg`,
        } as CSSProperties
      }
      onMouseEnter={point}
      onMouseLeave={() => onPoint(null)}
    >
      <span className="MarkingsRoom__cardX1" />
      <span className="MarkingsRoom__cardX2" />
      <span className="MarkingsRoom__cardTag">{cardTag(theme, order)}</span>
      <div className="MarkingsRoom__cardHead">
        {/* Its name again, for a room that letters it a second way (Vector's alien script). */}
        <span className="MarkingsRoom__cardName" data-n={name}>
          {name}
        </span>
        <span className="MarkingsRoom__cardCount">
          {worn.length}/{room.max}
        </span>
      </div>
      <div className="MarkingsRoom__tiles">
        {Array.from({ length: room.max }, (_, index) => {
          const marking = worn[index];
          if (!marking) {
            return (
              <button
                key={`add-${index}`}
                type="button"
                className="MarkingsRoom__tile MarkingsRoom__tile--add"
                disabled={underTaur}
                title={
                  underTaur
                    ? 'Markings here are under the taur body'
                    : undefined
                }
                aria-label={`Add a marking to the ${name.toLowerCase()}`}
                onClick={onAdd}
                onFocus={point}
                onBlur={() => onPoint(null)}
              >
                <svg viewBox="0 0 16 16" aria-hidden="true">
                  <path d="M8 3v10M3 8h10" />
                </svg>
              </button>
            );
          }
          const on = selected === index;
          const icon = room.icons[zone]?.[marking.name];
          return (
            <button
              key={marking.marking_id}
              type="button"
              className={classes([
                'MarkingsRoom__tile',
                on && 'MarkingsRoom__tile--selected',
              ])}
              aria-label={`${marking.name}, slot ${index + 1}${on ? ', selected' : ''}`}
              aria-pressed={on}
              aria-haspopup="menu"
              onClick={() => onSelect(index)}
              onContextMenu={(event) => {
                event.preventDefault();
                onMenu(index, event.currentTarget);
              }}
              onKeyDown={(event) => {
                if (
                  event.key === 'ContextMenu' ||
                  (event.shiftKey && event.key === 'F10')
                ) {
                  event.preventDefault();
                  onMenu(index, event.currentTarget);
                }
              }}
              onMouseEnter={() => {
                point();
                onLight(index);
              }}
              onMouseLeave={() => onLight(null)}
              onFocus={() => {
                point();
                onLight(index);
              }}
              onBlur={() => onLight(null)}
            >
              <Thumb
                className="MarkingsRoom__thumb"
                size={CARD_TILE}
                zoom={zoom}
                centre={middle}
                body={body}
                markings={icon ? [{ icon, color: marking.color }] : []}
              />
              <span
                className="MarkingsRoom__drop"
                style={{ backgroundColor: marking.color }}
              />
              {!!marking.emissive && (
                <span className="MarkingsRoom__glowBadge">UV</span>
              )}
            </button>
          );
        })}
        {room.canDraw && (
          <button
            type="button"
            className={classes([
              'MarkingsRoom__tile',
              'MarkingsRoom__tile--custom',
              drawn ? 'MarkingsRoom__tile--drawn' : 'MarkingsRoom__tile--add',
            ])}
            aria-label={`Custom drawing on the ${underTaur ? 'taur body' : name.toLowerCase()}${
              drawn
                ? ', drawn: open the custom markings editor to edit it'
                : ': open the custom markings editor'
            }`}
            onClick={onDraw}
            onMouseEnter={() => {
              point();
              onLight('custom');
            }}
            onMouseLeave={() => onLight(null)}
            onFocus={() => {
              point();
              onLight('custom');
            }}
            onBlur={() => onLight(null)}
          >
            {drawn ? (
              <>
                <span className="MarkingsRoom__customInner">
                  <Thumb
                    className="MarkingsRoom__thumb"
                    size={CARD_TILE}
                    zoom={zoom}
                    centre={middle}
                    body={body}
                    painted={
                      drawing && {
                        pixels: paintedPixels(drawing, 'south'),
                        width: drawing.width,
                      }
                    }
                  />
                </span>
                <span className="MarkingsRoom__check">
                  <svg viewBox="0 0 10 10" aria-hidden="true">
                    <path d="M2 5.2 4.2 7.4 8 2.8" />
                  </svg>
                </span>
              </>
            ) : (
              <span className="MarkingsRoom__customLabel">
                <svg viewBox="0 0 16 16" aria-hidden="true">
                  <path d="M13.6 2.4c-.6-.6-5 3.6-6.6 5.7l1 1c2.1-1.6 6.2-6.1 5.6-6.7zM6.4 9.4c-1.6-.1-2.8 1-2.8 2.4 0 .8-.5 1.2-1.3 1.3 1 1 2.5 1.3 3.6.9 1.2-.5 1.6-1.6 1.3-2.8z" />
                </svg>
                {underTaur ? 'TAUR' : 'CUSTOM'}
              </span>
            )}
          </button>
        )}
      </div>
      <div className="MarkingsRoom__cardNames">{names}</div>
      <span
        className={`MarkingsRoom__cardMeter MarkingsRoom__cardMeter--m${worn.length}`}
      >
        <i />
        <i />
        <i />
      </span>
    </div>
  );
}
