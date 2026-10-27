// THIS IS AN APHELION UI FILE
import {
  type CSSProperties,
  Fragment,
  useEffect,
  useId,
  useRef,
  useState,
} from 'react';
import { useBackend } from 'tgui/backend';
import { type HsvaColor, hexToHsva, hsvaToHex } from 'tgui-core/color';
import { Icon } from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import { Hue, SaturationValue } from '../../../../ColorPickerModal/Color';
import { HexColorInput } from '../../../../ColorPickerModal/TextSetter';
import type { PaintChannel, PreferencesMenuData } from '../../../types';
import { useServerPrefs } from '../../../useServerPrefs';
import { FLY_LEFT, type StagePart } from './parts';

const CHANNELS: PaintChannel[] = ['paint', 'accent', 'frame', 'lights'];
const DIRS = ['south', 'east', 'north', 'west'] as const;
const SHINE_W = '#fafbff';
const SHINE_X = '#c4c7d0';

/** The colour string's channel colours, in channel order. */
const split = (colors: string) =>
  CHANNELS.map((_, i) => colors.slice(i * 7, i * 7 + 7));
const join = (parts: string[]) => parts.join('');
const rgb = (hex: string) =>
  [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);

/** One channel's colour in a colour string. */
export const channelColor = (colors: string, channel: PaintChannel) =>
  split(colors)[CHANNELS.indexOf(channel)];

/** A colour string with one channel's colour swapped for another. */
const withChannel = (colors: string, channel: PaintChannel, color: string) =>
  join(split(colors).map((old, i) => (CHANNELS[i] === channel ? color : old)));

/**
 * An feColorMatrix that sums the input's red, green and blue channels into three colours, as the game's 4x4 matrices do.
 * SVG matrices are output-major: each row is one output channel.
 */
function packedMatrix(r: string, g: string, b: string) {
  const [R, G, B] = [rgb(r), rgb(g), rgb(b)];
  return [0, 1, 2]
    .map((out) => `${R[out]} ${G[out]} ${B[out]} 0 0`)
    .concat('0 0 0 1 0')
    .join(' ');
}

/** Multiplies by one colour, as a greyscale limb's skin base is tinted. */
export function tintMatrix(color: string) {
  const [r, g, b] = rgb(color);
  return `${r} 0 0 0 0 0 ${g} 0 0 0 0 0 ${b} 0 0 0 0 0 1 0`;
}

/** Keeps a _glow strip's light (its red channel) as alpha, in the light's colour: the glow's halo in the dark view. */
function lightOnlyMatrix(color: string) {
  const [r, g, b] = rgb(color);
  return `0 0 0 0 ${r} 0 0 0 0 ${g} 0 0 0 0 ${b} 1 0 0 0 0`;
}

/** A colour string's matrices for the packed states: _paint's, _glow's, and _glow's lights alone. */
export function paintMatrices(colors: string) {
  const [p, a, f, l] = split(colors);
  return {
    paint: packedMatrix(p, a, f),
    glow: packedMatrix(l, SHINE_W, SHINE_X),
    light: lightOnlyMatrix(l),
  };
}

type Props = {
  part: StagePart;
  side: 'l' | 'r';
  oy: number;
  act: (action: string, params?: Record<string, unknown>) => void;
  onClose: () => void;
};

/**
 * A recolourable finish's colour editor, unfolding over its card's side of
 * the stage as the pickers do: the part in each facing over the body, tinted
 * on the client as its colours change, the finish's presets, and a row per
 * colour its art uses, each picked in place. Only a preset, Apply, a reset or
 * a copy goes to the server.
 */
export function AugmentPaint(props: Props) {
  const { part, side, oy, act, onClose } = props;
  const paint = part.paint!;
  const { finish } = paint;
  const slot = part.socket.slot;
  const { data } = useBackend<PreferencesMenuData>();
  const swatches = useServerPrefs()?.augment_paint?.swatches;
  const skin = data.augment_paint_skin;
  const uid = useId();
  // The slot's colours: its saved ones, which a reset clears, or the finish's default.
  const savedColors = data.augment_colors?.[slot];
  const saved = !!savedColors;
  const worn = savedColors ?? finish.default;
  // What the preview shows: the colours worn, or a preset on its way to the server.
  const [draft, setDraft] = useState(worn);
  const [editing, setEditing] = useState<PaintChannel | null>(null);
  const [hsva, setHsva] = useState<HsvaColor>(() =>
    hexToHsva(channelColor(worn, 'paint')),
  );
  // A typed or suggested colour is kept as it is, not as its round trip through HSV.
  const [typed, setTyped] = useState<string | null>(null);
  // Only a finish with lights has a dark view, where they glow.
  const lights = finish.channels.some((channel) => channel.key === 'lights');
  const [darkView, setDarkView] = useState(false);
  const dark = lights && darkView;
  // The footer's one line: a word that shows for a moment.
  const [status, setStatus] = useState<{ text: string } | null>(null);
  const sent = useRef(false);
  const dialog = useRef<HTMLDivElement>(null);
  const picker = useRef<HTMLDivElement>(null);

  useEffect(() => setDraft(worn), [worn]);
  // The server's answer to what was sent.
  useEffect(() => {
    if (sent.current) {
      sent.current = false;
      setStatus({ text: 'Saved' });
    }
  }, [worn, saved]);
  useEffect(() => {
    if (!status) {
      return;
    }
    const timer = setTimeout(() => setStatus(null), 2000);
    return () => clearTimeout(timer);
  }, [status]);
  // The keyboard starts on the colours worn.
  useEffect(() => {
    dialog.current
      ?.querySelector<HTMLButtonElement>(
        '.paint-preset[aria-pressed="true"], .paint-row',
      )
      ?.focus();
  }, []);
  useEffect(() => {
    if (editing) {
      picker.current?.scrollIntoView({ block: 'nearest' });
    }
  }, [editing]);

  // The colour being picked, shown in the preview until it's applied or dropped.
  const picked = typed ?? hsvaToHex(hsva);
  const shown = editing ? withChannel(draft, editing, picked) : draft;
  const unchanged = !editing || picked === channelColor(draft, editing);
  const matrices = paintMatrices(shown);
  const l = channelColor(shown, 'lights');
  const zones = part.socket.zones;
  const skinLayer = skin.humanoid ? 'skinh' : 'skin';

  const send = (colors: string | null) => {
    sent.current = true;
    act('set_augment_colors', { slot, colors });
  };
  /**
   * Wears colours, shown at once: the finish's default is saved as none (the
   * reset path), and nothing is sent when that changes nothing.
   */
  const save = (colors: string) => {
    setEditing(null);
    setDraft(colors);
    const next = colors === finish.default ? null : colors;
    if (next !== (savedColors ?? null)) {
      send(next);
    }
  };
  /** Opens a channel's picker on its colour, or closes it: a pick not applied is dropped either way. */
  const toggle = (channel: PaintChannel) => {
    if (editing === channel) {
      setEditing(null);
      return;
    }
    const color = channelColor(draft, channel);
    setEditing(channel);
    setHsva(hexToHsva(color));
    setTyped(color);
  };
  const change = (next: Partial<HsvaColor>) => {
    setHsva((current) => ({ ...current, ...next }));
    setTyped(null);
  };
  const suggest = (color: string) => {
    setHsva(hexToHsva(color));
    setTyped(color);
  };
  const copy = () => {
    act('copy_augment_colors', { slot });
    setStatus({ text: 'Copied' });
  };

  const filter = (kind: string) => ({ filter: `url(#ap-${kind}-${uid})` });
  const sprite = (zone: string, layer: string, dir: string) =>
    `augment_paint32x32 ${finish.id}-${zone}-${layer}-${dir}`;
  // A "Default" tile only when no preset is the default already.
  const presets = finish.presets.some(
    (preset) => preset.colors === finish.default,
  )
    ? finish.presets
    : [{ name: 'Default', colors: finish.default }, ...finish.presets];
  return (
    <>
      <button
        type="button"
        className="scrim"
        aria-label="Close the colour editor"
        onClick={onClose}
      />
      <div
        ref={dialog}
        className="fly paint"
        style={
          {
            left: `${FLY_LEFT[side]}px`,
            '--oy': `${oy}px`,
            '--dir': side === 'l' ? '1' : '-1',
          } as CSSProperties
        }
        role="dialog"
        aria-label={`${paint.name} colours`}
      >
        <div className="fly-in">
          <div className="fly-hd">
            <div className="fly-k">{`${slot.toUpperCase()} · FINISH`}</div>
            <div className="fly-t">{paint.name}</div>
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
          <div className="paint-scan">
            <svg className="paint-defs" aria-hidden="true">
              <filter id={`ap-body-${uid}`} colorInterpolationFilters="sRGB">
                <feFlood className="paint-flood" />
                <feComposite in2="SourceAlpha" operator="in" />
              </filter>
              <filter id={`ap-skin-${uid}`} colorInterpolationFilters="sRGB">
                <feColorMatrix type="matrix" values={tintMatrix(skin.color)} />
              </filter>
              <filter id={`ap-paint-${uid}`} colorInterpolationFilters="sRGB">
                <feColorMatrix type="matrix" values={matrices.paint} />
              </filter>
              <filter id={`ap-glow-${uid}`} colorInterpolationFilters="sRGB">
                <feColorMatrix type="matrix" values={matrices.glow} />
              </filter>
              <filter id={`ap-light-${uid}`} colorInterpolationFilters="sRGB">
                <feColorMatrix type="matrix" values={matrices.light} />
              </filter>
            </svg>
            <div className="paint-k">
              <span>SCAN</span>
              {lights && (
                <button
                  type="button"
                  className="paint-lights"
                  aria-label="Dark view"
                  aria-pressed={dark}
                  onClick={() => setDarkView(!dark)}
                >
                  <Icon name="lightbulb" />
                </button>
              )}
            </div>
            <div className={classes(['paint-view', dark && 'dark'])}>
              {DIRS.map((dir) => (
                <div key={dir} className="paint-cell">
                  <div
                    className={`augment_paint32x32 body-${dir} paint-body`}
                    style={filter('body')}
                  />
                  {/* The lit part, which the dark view dims: everything but its lights. */}
                  <div className="paint-part">
                    {zones.map((zone) => (
                      <Fragment key={zone}>
                        <div
                          className={sprite(zone, skinLayer, dir)}
                          style={filter('skin')}
                        />
                        {!!finish.zones[zone]?.paint && (
                          <div
                            className={sprite(zone, 'paint', dir)}
                            style={filter('paint')}
                          />
                        )}
                        {!!finish.zones[zone]?.glow && (
                          <div
                            className={sprite(zone, 'glow', dir)}
                            style={filter('glow')}
                          />
                        )}
                      </Fragment>
                    ))}
                  </div>
                  {dark &&
                    zones.map(
                      (zone) =>
                        !!finish.zones[zone]?.glow && (
                          <div
                            key={zone}
                            className={`${sprite(zone, 'glow', dir)} paint-halo`}
                            style={{
                              filter: `url(#ap-light-${uid}) drop-shadow(0 0 1px ${l}) drop-shadow(0 0 3px ${l})`,
                            }}
                          />
                        ),
                    )}
                </div>
              ))}
            </div>
          </div>
          <div className="paint-list">
            <div className="paint-k">PRESETS</div>
            <div className="paint-presets">
              {presets.map((preset, i) => (
                <button
                  key={i}
                  type="button"
                  className="paint-preset"
                  aria-pressed={preset.colors === draft}
                  onClick={() => save(preset.colors)}
                >
                  <span className="paint-bar">
                    {finish.channels.map(({ key }) => (
                      <span
                        key={key}
                        style={{
                          backgroundColor: channelColor(preset.colors, key),
                        }}
                      />
                    ))}
                  </span>
                  <span className="paint-preset-n">{preset.name}</span>
                </button>
              ))}
            </div>
            <div className="paint-k">CHANNELS</div>
            {finish.channels.map(({ key, label }) => {
              const color = channelColor(shown, key);
              const open = editing === key;
              return (
                <Fragment key={key}>
                  <button
                    type="button"
                    className={classes(['paint-row', open && 'open'])}
                    aria-expanded={open}
                    onClick={() => toggle(key)}
                  >
                    <span className="paint-row-k">{label}</span>
                    <span
                      className="paint-swatch"
                      style={{ backgroundColor: color }}
                    />
                    <span className="paint-hex">{color.toUpperCase()}</span>
                    {key === 'lights' && !data.augment_paint_emissive && (
                      <span className="paint-note">
                        Glows once Allow emissives is on
                      </span>
                    )}
                  </button>
                  {open && (
                    <div ref={picker} className="paint-picker">
                      <div className="react-colorful">
                        <SaturationValue hsva={hsva} onChange={change} />
                        <Hue
                          hue={hsva.h}
                          onChange={change}
                          className="react-colorful__last-control"
                        />
                      </div>
                      <div className="paint-sws">
                        {(key === 'lights'
                          ? swatches?.lights
                          : swatches?.metal
                        )?.map((suggested) => (
                          <button
                            key={suggested}
                            type="button"
                            className={classes([
                              'paint-sw',
                              suggested === picked && 'on',
                            ])}
                            style={{ backgroundColor: suggested }}
                            aria-label={`Suggested colour ${suggested}`}
                            onClick={() => suggest(suggested)}
                          />
                        ))}
                      </div>
                      <div className="paint-pick">
                        <HexColorInput
                          color={picked.substring(1)}
                          onChange={(value) =>
                            suggest(`#${value.toLowerCase()}`)
                          }
                        />
                        <button
                          type="button"
                          className="paint-act hot"
                          aria-disabled={unchanged}
                          onClick={() => !unchanged && save(shown)}
                        >
                          Apply
                        </button>
                        <button
                          type="button"
                          className="paint-act"
                          onClick={() => setEditing(null)}
                        >
                          Cancel
                        </button>
                      </div>
                    </div>
                  )}
                </Fragment>
              );
            })}
          </div>
          {/* Disabled for the reader, not the browser, as the cards' rows are: MeridianOS hatches disabled buttons its own way. */}
          <div className="paint-ft">
            <button
              type="button"
              className="paint-act"
              aria-disabled={!!editing}
              onClick={() => !editing && copy()}
            >
              Copy to all parts
            </button>
            <button
              type="button"
              className="paint-act"
              aria-disabled={!!editing || !saved}
              onClick={() => !editing && saved && save(finish.default)}
            >
              Reset
            </button>
            <span className="paint-status" role="status">
              {status?.text}
            </span>
          </div>
        </div>
      </div>
    </>
  );
}
