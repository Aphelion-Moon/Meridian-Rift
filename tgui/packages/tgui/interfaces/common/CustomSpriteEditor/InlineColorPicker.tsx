// THIS IS AN APHELION UI FILE
import { useAtomValue, useSetAtom } from 'jotai';
import { useEffect, useRef, useState } from 'react';
import { useBackend } from 'tgui/backend';
import {
  type HsvaColor,
  hexToHsva,
  hsvaToHslaString,
  hsvaToRgba,
  rgbaToHex,
} from 'tgui-core/color';
import { Section, Tooltip } from 'tgui-core/components';
import { Hue, SaturationValue } from '../../ColorPickerModal/Color';
import { HexColorInput } from '../../ColorPickerModal/TextSetter';
import {
  currentColorAtom,
  currentColorInternalAtom,
} from '../SpriteEditor/atoms';
import {
  colorToHexString,
  parseHexColorString,
} from '../SpriteEditor/colorSpaces';
import { AlphaBar } from './AlphaBar';
import {
  GRAFFITI_ALPHA_CEILING,
  GRAFFITI_ALPHA_FLOOR,
  GRAFFITI_MAX_COLORS,
} from './graffitiCodec';

/** How long after a slider's last arrow key step its colour is sent, in milliseconds. */
const KEY_STEP_DELAY = 300;

/** A `#rrggbb` or `#rrggbbaa` colour as the picker holds it: its alpha a share of the ceiling, which opaque paint is drawn at. */
const toHsva = (hex: string): HsvaColor => ({
  ...hexToHsva(hex.slice(0, 7)),
  a:
    hex.length >= 9
      ? Math.min(
          1,
          Number.parseInt(hex.slice(7, 9), 16) / GRAFFITI_ALPHA_CEILING,
        )
      : 1,
});

/**
 * The picker's colour as the server keeps it: `#rrggbb` when its alpha reaches the ceiling, else `#rrggbbaa` with its
 * share of the ceiling as the alpha, never under the floor.
 */
const toHex = (hsva: HsvaColor) => {
  const hex = rgbaToHex({ ...hsvaToRgba(hsva), a: 1 });
  const alpha = Math.max(
    GRAFFITI_ALPHA_FLOOR,
    Math.round(hsva.a * GRAFFITI_ALPHA_CEILING),
  );
  return alpha >= GRAFFITI_ALPHA_CEILING
    ? hex
    : `${hex}${alpha.toString(16).padStart(2, '0')}`;
};

/** A colour as the brush holds it, `#rrggbbaa`, so a reply naming it in either form matches. */
const asBrush = (hex: string) => colorToHexString(parseHexColorString(hex));

type InlineColorPickerProps = {
  /** The brush colour the server last sent, which its reply to each colour sent names. */
  serverColor?: string;
  /** The piece uses GRAFFITI_MAX_COLORS colours, so the server takes no new one. */
  full?: boolean;
};

/**
 * Mixes a colour, see-through ones included, and paints with it as it changes. The piece's colours get it once each
 * interaction ends, at a release, a hex commit or a pause in arrow key steps, never while a drag moves. It starts from
 * the brush, so a swatch or the eyedropper picks what it mixes from. Its alpha reads 25% at the floor and 100% at the
 * ceiling, the most placed graffiti is drawn with, which the editor shows as opaque. On a full piece it mixes without
 * touching the brush.
 */
export const InlineColorPicker = (props: InlineColorPickerProps) => {
  const { serverColor, full } = props;
  const { act } = useBackend();
  const brush = colorToHexString(useAtomValue(currentColorAtom));
  // currentColorAtom's own setter sends every colour it is given.
  const setBrush = useSetAtom(currentColorInternalAtom);
  const [hsva, setHsva] = useState(() => toHsva(brush));
  // The brush as the picker last set or saw it: only a change from elsewhere resets the picker, which loses a grey's hue.
  const known = useRef(brush);
  // The colour the picker gave the brush that the server hasn't been sent.
  const unsent = useRef<string>(undefined);
  // The colours sent whose reply hasn't come, oldest first, as the brush holds them. syncBackend() gives the brush the
  // colour each reply names, which puts an earlier pick back once a later one overtook it.
  const sent = useRef<string[]>([]);
  const keyTimer = useRef<ReturnType<typeof setTimeout>>(undefined);
  // A reply means every colour sent up to the one it names has come back. One a later pick overtook stays listed, so
  // the brush can refuse it as syncBackend() applies it.
  useEffect(() => {
    if (!serverColor) return;
    const reply = sent.current.indexOf(asBrush(serverColor));
    if (reply < 0) return;
    sent.current.splice(
      0,
      sent.current[reply] === known.current ? reply + 1 : reply,
    );
  }, [serverColor]);
  useEffect(() => {
    if (brush === known.current) return;
    const reply = sent.current.indexOf(brush);
    if (reply >= 0) {
      // The reply to an earlier pick: the brush keeps the later one.
      sent.current.splice(0, reply + 1);
      setBrush(parseHexColorString(known.current));
      return;
    }
    known.current = brush;
    // The picker's own colour, waiting to be sent, gave way to this one.
    clearTimeout(keyTimer.current);
    unsent.current = undefined;
    setHsva(toHsva(brush));
  }, [brush]);
  const send = () => {
    clearTimeout(keyTimer.current);
    if (unsent.current) {
      act('addColor', { color: unsent.current });
      const color = asBrush(unsent.current);
      // A reply naming the colour the server last sent changes nothing, unless an earlier one comes first.
      if (
        sent.current.length ||
        !serverColor ||
        asBrush(serverColor) !== color
      ) {
        sent.current.push(color);
      }
    }
    unsent.current = undefined;
  };
  useEffect(() => send, []);
  const change = (next: HsvaColor) => {
    setHsva(next);
    // Fully see-through paint shows nothing, and a full piece takes no new colour, so the brush keeps its colour.
    if (full || !Math.round(next.a * 255)) return;
    const hex = toHex(next);
    const color = parseHexColorString(hex);
    const shown = colorToHexString(color);
    if (shown === known.current) return;
    known.current = shown;
    unsent.current = hex;
    setBrush(color);
  };
  const slide = (part: Partial<HsvaColor>) => change({ ...hsva, ...part });
  return (
    <Section
      title={
        full ? (
          <Tooltip
            content={`This piece uses ${GRAFFITI_MAX_COLORS} colours.`}
            position="bottom-start"
          >
            <span>New colour</span>
          </Tooltip>
        ) : (
          'New colour'
        )
      }
    >
      <div className="Graffiti__picker" onBlur={send}>
        <div
          className="react-colorful"
          onPointerUp={send}
          onKeyDown={() => {
            clearTimeout(keyTimer.current);
            keyTimer.current = setTimeout(send, KEY_STEP_DELAY);
          }}
        >
          <SaturationValue hsva={hsva} onChange={slide} />
          <Hue hue={hsva.h} onChange={slide} />
          <AlphaBar
            hsva={hsva}
            onChange={slide}
            className="react-colorful__last-control"
          />
        </div>
        <div className="Graffiti__pickerRow">
          <span className="Graffiti__pickerSwatch">
            <span style={{ backgroundColor: hsvaToHslaString(hsva) }} />
          </span>
          <HexColorInput
            color={toHex(hsva)}
            onChange={(value) => change({ ...hexToHsva(value), a: hsva.a })}
          />
          <span className="Graffiti__pickerAlpha">
            {Math.round(hsva.a * 100)}%
          </span>
        </div>
      </div>
    </Section>
  );
};
