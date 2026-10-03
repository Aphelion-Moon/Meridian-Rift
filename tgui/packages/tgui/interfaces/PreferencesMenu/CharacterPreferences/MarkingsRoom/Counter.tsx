// THIS IS AN APHELION UI FILE
import {
  type ComponentRef,
  type CSSProperties,
  type MouseEvent,
  useRef,
  useState,
} from 'react';
import { type HsvaColor, hexToHsva, hsvaToHex } from 'tgui-core/color';
import { Button, ColorBox, Floating, Stack } from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import { Hue, SaturationValue } from '../../../ColorPickerModal/Color';
import { HexColorInput } from '../../../ColorPickerModal/TextSetter';
import type { MarkingColorMode } from '../../types';
import { MUTANT_COLOR_NAMES, PAINTS, ZONE_NAMES } from './constants';
import type { RoomData, WornMarking } from './data';
import type { RoomTheme } from './themes';

type Props = {
  theme: RoomTheme;
  room: RoomData;
  /** The marking the counter works on, or null. */
  selected: WornMarking | null;
  onSwap: () => void;
  onGlow: () => void;
  onScrub: () => void;
  /** A colour to paint it, from what was clicked; null paints it back the colour it starts in. */
  onPaint: (color: string | null, from: Element) => void;
  onBook: () => void;
  onSurprise: (from: Element) => void;
};

/**
 * The counter under the mirror: what is selected and what can be done to it,
 * paints to colour it with (the first gives back the colour it starts in; the
 * last mixes any other), and the marking sets and a random one. The theme
 * names them, and its stylesheet makes the paints its own: the club's markers,
 * Classic's crayons, the clan's war paint.
 */
export function Counter(props: Props) {
  const { theme, room, selected, onSwap, onGlow, onScrub, onPaint } = props;
  const { labels } = theme;
  const mode: MarkingColorMode =
    (selected && room.info[selected.name]?.color_mode) || 'follows_primary';
  const locked = !!selected?.locked;
  const none = !selected;
  const fixed = mode === 'fixed_default' || mode === 'locked';
  const furColor = selected
    ? selected.start
    : (room.data.marking_fur_colors?.[0] ?? '#808080');

  // Unpainted, a marking takes its default colour: one of the species' mutant
  // colours, which it follows, or a fixed one of its own.
  const fallback = fixed
    ? 'fixed color'
    : `follows ${MUTANT_COLOR_NAMES[mode].toLowerCase()}`;
  let paint = 'Paints apply to the selected marking';
  if (selected) {
    paint = selected.painted
      ? `Custom paint ${selected.color.toUpperCase()}`
      : `Default: ${fallback}`;
  }

  return (
    <div className="MarkingsRoom__counter">
      <div className="MarkingsRoom__selected">
        <div className="MarkingsRoom__label">SELECTED</div>
        <div className="MarkingsRoom__selName">
          {selected ? selected.name : 'Nothing selected'}
        </div>
        <div className="MarkingsRoom__selWhere">
          {selected
            ? `${ZONE_NAMES[selected.zone].toUpperCase()} · SLOT ${selected.index + 1}`
            : 'PICK A MARKING ON A CARD'}
        </div>
        <div className="MarkingsRoom__selPaint">
          <span
            className="MarkingsRoom__swatch"
            style={{
              backgroundColor: selected ? selected.color : 'transparent',
            }}
          />
          <span>{paint}</span>
        </div>
        <div className="MarkingsRoom__actions">
          <button
            type="button"
            className="MarkingsRoom__pill"
            disabled={none}
            onClick={onSwap}
          >
            Swap
          </button>
          <button
            type="button"
            className={classes([
              'MarkingsRoom__pill',
              !!selected?.emissive && 'MarkingsRoom__pill--on',
            ])}
            disabled={none || (!room.canGlow && !selected?.emissive)}
            title={
              room.canGlow
                ? undefined
                : 'Glow is off for this character: turn on Allow Emissives on the Character tab.'
            }
            aria-pressed={!!selected?.emissive}
            onClick={onGlow}
          >
            <span className="MarkingsRoom__pillDot" />
            {labels.glow}
          </button>
          <button
            type="button"
            className="MarkingsRoom__pill"
            disabled={none}
            onClick={onScrub}
          >
            Remove
          </button>
        </div>
      </div>
      <div className="MarkingsRoom__paints">
        <div className="MarkingsRoom__label">COLORS</div>
        <div className="MarkingsRoom__markers">
          <button
            type="button"
            className={classes([
              'MarkingsRoom__marker',
              !!selected &&
                !selected.painted &&
                'MarkingsRoom__marker--current',
            ])}
            disabled={none}
            aria-label={`Back to the default color: ${fallback}`}
            style={{ '--marker': furColor } as CSSProperties}
            onClick={(event: MouseEvent) => onPaint(null, event.currentTarget)}
          >
            <span className="MarkingsRoom__markerCap" />
            <span className="MarkingsRoom__markerBody" />
            <span className="MarkingsRoom__markerLabel">DEFAULT</span>
          </button>
          {PAINTS.map((paint) => (
            <button
              key={paint.color}
              type="button"
              className={classes([
                'MarkingsRoom__marker',
                !!selected?.painted &&
                  selected.color.toLowerCase() === paint.color &&
                  'MarkingsRoom__marker--current',
              ])}
              disabled={none || locked}
              aria-label={`Paint it ${paint.name}`}
              title={locked ? "This marking's colour is fixed." : undefined}
              style={{ '--marker': paint.color } as CSSProperties}
              onClick={(event: MouseEvent) =>
                onPaint(paint.color, event.currentTarget)
              }
            >
              <span className="MarkingsRoom__markerCap" />
              <span className="MarkingsRoom__markerBody" />
            </button>
          ))}
          <MixCan
            selected={selected}
            disabled={none || locked}
            recommended={
              selected
                ? room.info[selected.name]?.recommended_colors
                : undefined
            }
            onPick={(color, from) => onPaint(color, from)}
          />
        </div>
      </div>
      <div className="MarkingsRoom__room">
        <button
          type="button"
          className="MarkingsRoom__big"
          onClick={props.onBook}
        >
          <svg viewBox="0 0 26 26" aria-hidden="true">
            <path d="M4 5.5c3-1.4 6-1.4 9 .6v15c-3-2-6-2-9-.6zM22 5.5c-3-1.4-6-1.4-9 .6v15c3-2 6-2 9-.6z" />
          </svg>
          <b>{labels.book}</b>
          <small>
            {room.presets.length} presets for {room.speciesName}
          </small>
        </button>
        <button
          type="button"
          className="MarkingsRoom__big MarkingsRoom__big--alt"
          onClick={(event) => props.onSurprise(event.currentTarget)}
        >
          <svg viewBox="0 0 26 26" aria-hidden="true">
            <rect x="4" y="4" width="18" height="18" rx="4" />
            <circle cx="9" cy="9" r="1.2" />
            <circle cx="17" cy="9" r="1.2" />
            <circle cx="13" cy="13" r="1.2" />
            <circle cx="9" cy="17" r="1.2" />
            <circle cx="17" cy="17" r="1.2" />
          </svg>
          <b>{labels.surprise}</b>
        </button>
      </div>
    </div>
  );
}

/**
 * The spray can: any colour, mixed with the colour picker character setup
 * uses everywhere, sent once on Apply. A suggested colour is sent as soon as
 * it's picked.
 */
function MixCan(props: {
  selected: WornMarking | null;
  disabled: boolean;
  recommended?: string[];
  onPick: (color: string, from: Element) => void;
}) {
  const { selected, disabled, recommended, onPick } = props;
  const floating = useRef<ComponentRef<typeof Floating>>(null);
  const can = useRef<HTMLButtonElement>(null);
  const start = selected?.color ?? '#ff3fa4';
  const [hsva, setHsva] = useState<HsvaColor>(() => hexToHsva(start));
  // A typed colour is sent as typed, not as its round trip through HSV.
  const [typed, setTyped] = useState<string | null>(null);
  const [edited, setEdited] = useState(false);
  const picked = typed ?? hsvaToHex(hsva);
  const custom =
    !!selected?.painted &&
    !PAINTS.some((paint) => paint.color === selected.color.toLowerCase());
  const change = (next: Partial<HsvaColor>) => {
    setHsva((current) => ({ ...current, ...next }));
    setTyped(null);
    setEdited(true);
  };
  const pick = (value: string) => {
    if (can.current && value.toLowerCase() !== start.toLowerCase()) {
      onPick(value.toLowerCase(), can.current);
    }
    floating.current?.close();
  };
  const button = (
    <button
      ref={can}
      type="button"
      className={classes([
        'MarkingsRoom__marker',
        'MarkingsRoom__marker--mix',
        custom && 'MarkingsRoom__marker--current',
      ])}
      disabled={disabled}
      aria-label="Mix a custom paint"
    >
      <span className="MarkingsRoom__markerCap" />
      <span className="MarkingsRoom__markerBody" />
      <span className="MarkingsRoom__markerLabel">MIX</span>
    </button>
  );
  if (disabled) {
    return button;
  }
  return (
    <Floating
      ref={floating}
      stopChildPropagation
      placement="top"
      contentClasses="LimbsPage__colorPicker"
      // Each opening starts from the marking's own colour.
      onOpenChange={(open) => {
        if (open) {
          setHsva(hexToHsva(start));
          setTyped(null);
          setEdited(false);
        }
      }}
      content={
        <Stack vertical>
          <Stack.Item>
            <Stack>
              <Stack.Item>
                <div className="react-colorful">
                  <SaturationValue hsva={hsva} onChange={change} />
                  <Hue
                    hue={hsva.h}
                    onChange={change}
                    className="react-colorful__last-control"
                  />
                </div>
              </Stack.Item>
              {!!recommended?.length && (
                <Stack.Item>
                  <Stack vertical>
                    {recommended.map((suggested) => (
                      <Stack.Item key={suggested}>
                        <Button
                          tooltip={`Suggested: ${suggested}`}
                          aria-label={`Suggested color ${suggested}`}
                          onClick={() => pick(suggested)}
                        >
                          <ColorBox color={suggested} />
                        </Button>
                      </Stack.Item>
                    ))}
                  </Stack>
                </Stack.Item>
              )}
            </Stack>
          </Stack.Item>
          <Stack.Item>
            <Stack align="center">
              <Stack.Item>
                <ColorBox color={picked} />
              </Stack.Item>
              <Stack.Item grow>
                <HexColorInput
                  fluid
                  color={picked.substring(1)}
                  onChange={(value) => {
                    setHsva(hexToHsva(value));
                    setTyped(`#${value.toLowerCase()}`);
                    setEdited(true);
                  }}
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  color="good"
                  disabled={!edited}
                  onClick={() => pick(picked)}
                >
                  Apply
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      }
    >
      <div className="MarkingsRoom__mixAnchor">{button}</div>
    </Floating>
  );
}
