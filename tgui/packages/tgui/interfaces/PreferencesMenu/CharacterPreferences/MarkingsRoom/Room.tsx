// THIS IS AN APHELION UI FILE
import { useAtom, useAtomValue } from 'jotai';
import { type ReactNode, useEffect, useRef, useState } from 'react';
import { useBackend } from 'tgui/backend';
import { resolveMeridianTheme } from 'tgui/constants/theme';
import { debugThemeAtom, meridianThemeAtom } from 'tgui/events/store';
import { classes } from 'tgui-core/react';

import { previewLightsOffAtom } from '../CharacterPreview/lights';
import type { MarkingsRoomData } from './data';
import { type DecorProps, ROOM_DECOR } from './decor';
import { useLightEffects } from './lightEffects';
import {
  BUILT_ROOMS,
  ROOM_THEMES,
  type RoomTheme,
  type RoomThemeId,
} from './themes';

/** The window's room: its theme's, as its Layout resolves the theme, once that room is built; else null. */
export function useRoomTheme(): RoomTheme | null {
  const preferred = useAtomValue(meridianThemeAtom);
  const debugOverride = useAtomValue(debugThemeAtom);
  const { base, classes: themeClasses } = resolveMeridianTheme({
    preferred,
    debugOverride: process.env.NODE_ENV !== 'production' ? debugOverride : null,
  });
  // Classic wears nanotrasen's paint, and only its marker class tells it from a real legacy window.
  const id = (
    themeClasses.includes('theme-meridian_classic')
      ? 'classic'
      : base.replace(/^meridian_/, '')
  ) as RoomThemeId;
  return BUILT_ROOMS.has(id) ? ROOM_THEMES[id] : null;
}

/** Whether the window's theme has its Augments+ room; the rest keep the columns. */
export function useClubRoom() {
  return !!useRoomTheme();
}

/**
 * The station's time, HH:MM, ticking on from what the server last said (in
 * deciseconds into the station's day); dashes until it says.
 */
function useStationClock(serverTime: number | undefined) {
  const [now, setNow] = useState(() => Date.now());
  const said = useRef<{ at: number; time: number } | null>(null);
  if (serverTime !== undefined && said.current?.time !== serverTime) {
    said.current = { at: Date.now(), time: serverTime };
  }
  const ticking = serverTime !== undefined;
  // Wakes on each minute's turn, and draws again.
  useEffect(() => {
    if (!ticking) {
      return;
    }
    const timer = setTimeout(
      () => setNow(Date.now()),
      60_000 - (Date.now() % 60_000),
    );
    return () => clearTimeout(timer);
  }, [ticking, now]);
  if (!said.current) {
    return '--:--';
  }
  const ds =
    (said.current.time + Math.floor((now - said.current.at) / 100)) % 864000;
  const minutes = Math.floor(ds / 600);
  const pad = (value: number) => String(value).padStart(2, '0');
  return `${pad(Math.floor(minutes / 60))}:${pad(minutes % 60)}`;
}

/**
 * What the room's decor shows of the world: the lights and their switch,
 * whether they fall on the character, the station's clock, the engine's record.
 */
export function useDecorProps(): DecorProps {
  const [off, setOff] = useAtom(previewLightsOffAtom);
  const [lightEffects, onLightEffects] = useLightEffects();
  const { act, data } = useBackend<MarkingsRoomData>();
  const clock = useStationClock(data.markings_room_clock);
  return {
    clock,
    lightsOff: off,
    onLights: () => {
      setOff(!off);
      act('character_preview_lights', { off: !off });
    },
    lightEffects,
    onLightEffects,
    delamRounds: data.markings_room_delam ?? '—',
  };
}

export type RoomMode = 'augments' | 'markings';

type Props = {
  theme: RoomTheme;
  mode: RoomMode;
  onMode: (mode: RoomMode) => void;
  /** The header's own controls for the mode. */
  tools: ReactNode;
  children: ReactNode;
};

/**
 * Augments+ in a MeridianOS theme: one fixed room, 900 by 820, that never
 * resizes. Its header switches between the augments and the markings, and
 * holds each one's controls; with the markings, the theme's room shows behind
 * everything, and with the lights off it goes dark. As it never resizes, the
 * window doesn't measure itself again for what happens inside it.
 */
export function AugmentsRoom(props: Props) {
  const { theme, mode, onMode, tools, children } = props;
  const uv = useAtomValue(previewLightsOffAtom) && mode === 'markings';
  const markings = mode === 'markings';
  const decor = useDecorProps();
  const { Header } = ROOM_DECOR[theme.id];
  return (
    <div
      className={classes([
        'AugmentsRoom',
        `AugmentsRoom--${mode}`,
        uv && 'AugmentsRoom--uv',
      ])}
      data-window-fit="fixed"
    >
      <div className="AugmentsRoom__bg AugmentsRoom__bg--augments" />
      <div className="AugmentsRoom__bg AugmentsRoom__bg--markings" />
      <div className="AugmentsRoom__bg AugmentsRoom__bg--uv" />
      <header className="AugmentsRoom__header">
        {markings && !!Header && (
          <div className="AugmentsRoom__tags" aria-hidden="true">
            <Header {...decor} />
          </div>
        )}
        <nav className="AugmentsRoom__modes" aria-label="Augments+ sections">
          <button
            type="button"
            className={classes([
              'AugmentsRoom__mode',
              'AugmentsRoom__mode--augments',
              !markings && 'AugmentsRoom__mode--on',
            ])}
            aria-pressed={!markings}
            onClick={() => onMode('augments')}
          >
            <svg
              className="AugmentsRoom__modeIcon"
              viewBox="0 0 20 20"
              aria-hidden="true"
            >
              <rect x="5" y="5" width="10" height="10" />
              <path d="M8 2v3M12 2v3M8 15v3M12 15v3M2 8h3M2 12h3M15 8h3M15 12h3" />
            </svg>
            <span>AUGMENTS</span>
          </button>
          <button
            type="button"
            className={classes([
              'AugmentsRoom__mode',
              'AugmentsRoom__mode--markings',
              markings && 'AugmentsRoom__mode--on',
            ])}
            aria-pressed={markings}
            onClick={() => onMode('markings')}
          >
            <span>Markings</span>
          </button>
        </nav>
        <div className="AugmentsRoom__tools">{tools}</div>
      </header>
      {children}
    </div>
  );
}

/** The header's switch between body parts and internals, with the augments. */
export function AugmentsLayers(props: {
  internals: boolean;
  onInternals: (internals: boolean) => void;
}) {
  const { internals, onInternals } = props;
  return (
    <div className="AugmentsRoom__layers" role="group" aria-label="Layer">
      <button
        type="button"
        className={classes([
          'AugmentsRoom__layer',
          !internals && 'AugmentsRoom__layer--on',
        ])}
        aria-pressed={!internals}
        onClick={() => onInternals(false)}
      >
        BODY PARTS
      </button>
      <button
        type="button"
        className={classes([
          'AugmentsRoom__layer',
          internals && 'AugmentsRoom__layer--on',
        ])}
        aria-pressed={internals}
        onClick={() => onInternals(true)}
      >
        INTERNALS
      </button>
    </div>
  );
}

/**
 * The header's switches, with the markings: the lights, which are the
 * preview's own and every tab shares (off, the server draws what glows), and
 * the light effects, whether those lights fall on the character. The theme
 * dresses both as its own switch.
 */
export function MarkingsTools(props: { theme: RoomTheme }) {
  const { lightsOff, onLights, lightEffects, onLightEffects } = useDecorProps();
  return (
    <>
      <RoomSwitch
        on={lightsOff}
        label={props.theme.labels.lights}
        onClick={onLights}
      />
      <RoomSwitch
        on={lightEffects}
        label="Light effects"
        onClick={onLightEffects}
      />
    </>
  );
}

function RoomSwitch(props: {
  on: boolean;
  label: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      className={classes([
        'AugmentsRoom__uv',
        props.on && 'AugmentsRoom__uv--on',
      ])}
      aria-pressed={props.on}
      onClick={props.onClick}
    >
      <span className="AugmentsRoom__uvTrack">
        <span className="AugmentsRoom__uvKnob" />
      </span>
      <span>{props.label}</span>
    </button>
  );
}
