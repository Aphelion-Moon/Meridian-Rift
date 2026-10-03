// THIS IS AN APHELION UI FILE
import {
  type ComponentRef,
  type ReactNode,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { Floating } from 'tgui-core/components';

import {
  MARKING_ZONES,
  type MarkingZone,
  ZONE_NAMES,
} from '../../PreferencesMenu/CharacterPreferences/MarkingsRoom/constants';
import {
  MarkingSheet,
  type SheetSource,
} from '../../PreferencesMenu/CharacterPreferences/MarkingsRoom/Drawer';
import { markingStartColor } from '../../PreferencesMenu/CharacterPreferences/MarkingsRoom/data';
import type { MarkingSheetsData, RegionMarking } from './types';

/** Whether a region is one of the zones base markings go on. */
export const isMarkingZone = (
  zone: string | null | undefined,
): zone is MarkingZone =>
  !!zone && (MARKING_ZONES as readonly string[]).includes(zone);

type Act = (action: string, params?: Record<string, unknown>) => void;

// The key the window last asked the sheets' data for, and when: a sheet opening
// while the idle prefetch's answer is on its way doesn't ask again.
let lastAsked: { key: string | undefined; at: number } | undefined;
const ASK_AGAIN_MS = 3000;

/** Asks the server for what the sheets draw from, unless the window holds it for this body or has just asked. */
export function askForSheets(
  act: Act,
  sheets: MarkingSheetsData | undefined,
  sheetsKey: string | undefined,
) {
  if (sheets && sheets.key === sheetsKey) {
    return;
  }
  const now = Date.now();
  if (
    lastAsked &&
    lastAsked.key === sheetsKey &&
    now - lastAsked.at < ASK_AGAIN_MS
  ) {
    return;
  }
  lastAsked = { key: sheetsKey, at: now };
  act('markingSheets', { have: sheets?.key });
}

/**
 * Asks for what the sheets draw from once the page is idle, while a region
 * that takes base markings is selected: the first sheet then opens as the
 * rest do, without the server's round trip or the room's fonts and sheets
 * arriving on the click.
 */
export function usePrefetchMarkingSheets(
  enabled: boolean,
  sheets: MarkingSheetsData | undefined,
  sheetsKey: string | undefined,
  act: Act,
) {
  const held = !!sheets && sheets.key === sheetsKey;
  useEffect(() => {
    if (!enabled || held) {
      return;
    }
    const ask = () => askForSheets(act, sheets, sheetsKey);
    if (typeof requestIdleCallback === 'function') {
      const id = requestIdleCallback(ask, { timeout: 2000 });
      return () => cancelIdleCallback(id);
    }
    const id = setTimeout(ask, 500);
    return () => clearTimeout(id);
  }, [enabled, held, sheetsKey]);
}

type Props = {
  zone: MarkingZone;
  /** The markings the region wears, in order. */
  rows: RegionMarking[];
  /** The row a pick swaps out, by its place, or null to add one. */
  replace: number | null;
  /** The markings the region can take. */
  choices: string[];
  /** Their classes on the preferences sheet. */
  icons: Record<string, string> | undefined;
  max: number;
  sheets: MarkingSheetsData | undefined;
  sheetsKey: string | undefined;
  disabled?: boolean;
  act: Act;
  /** What opens the sheet: the row's button, or the add button. */
  children: ReactNode;
};

// Each zone's classes as the sheet draws them, the same object for as long as the server's are.
const prefixed = new WeakMap<Record<string, string>, Record<string, string>>();

function sheetIcons(icons: Record<string, string>) {
  let classes = prefixed.get(icons);
  if (!classes) {
    classes = {};
    for (const [name, icon] of Object.entries(icons)) {
      classes[name] = `preferences32x32 ${icon}`;
    }
    prefixed.set(icons, classes);
  }
  return classes;
}

/**
 * A base marking's sticker sheet in the custom markings editor: character
 * setup's own (MarkingsRoom/Drawer.tsx), each marking on the species' bare
 * body in the colour it would start in, dressed as the markings room's drawer
 * is in this theme. It opens beside what opens it, the way the old picker did,
 * and a pick swaps the row's marking out, adds one, or takes it off.
 */
export function MarkingSheetPicker(props: Props) {
  const { disabled, children } = props;
  const floating = useRef<ComponentRef<typeof Floating>>(null);
  return (
    <Floating
      ref={floating}
      placement="left-start"
      stopChildPropagation
      disabled={disabled}
      contentOffset={10}
      content={
        <SheetPanel {...props} onDone={() => floating.current?.close()} />
      }
    >
      {children}
    </Floating>
  );
}

/**
 * The open sheet. It asks for what it draws from when it first opens, and
 * again when the body changes species or colours: until that comes, it says
 * so rather than draw every thumbnail twice.
 */
function SheetPanel(props: Props & { onDone: () => void }) {
  const {
    zone,
    rows,
    replace,
    choices,
    icons,
    max,
    sheets,
    sheetsKey,
    act,
    onDone,
  } = props;
  const [query, setQuery] = useState('');
  const current = !!sheets && sheets.key === sheetsKey;

  useEffect(() => {
    if (!current) {
      askForSheets(act, sheets, sheetsKey);
    }
  }, [sheetsKey]);

  const source = useMemo((): SheetSource | undefined => {
    if (!sheets) {
      return undefined;
    }
    const { info, fur, defaults } = sheets;
    return {
      choices: { [zone]: choices },
      icons: { [zone]: icons ? sheetIcons(icons) : {} },
      info,
      species: sheets.species,
      speciesName: sheets.speciesName,
      speciesIcon: sheets.speciesIcon,
      // The server offers other species' markings only to a body that may wear them.
      allowMismatched: true,
      max,
      startColor: (name) => markingStartColor(info, fur, defaults, name),
      wornByZone: { [zone]: rows },
    };
  }, [sheets, zone, choices, icons, max, rows]);

  const swapped = replace === null ? undefined : rows[replace];
  return (
    <div className="AugmentsRoom AugmentsRoom--sheet">
      <div
        className="MarkingsRoom__drawer MarkingsRoom__drawer--floating"
        role="dialog"
        aria-label={`${ZONE_NAMES[zone]} markings`}
      >
        {source ? (
          <MarkingSheet
            room={source}
            zone={zone}
            replace={replace}
            query={query}
            onQuery={setQuery}
            onPick={(name) => {
              onDone();
              act(
                swapped ? 'setBaseMarking' : 'addBaseMarking',
                swapped ? { zone, index: swapped.index, name } : { zone, name },
              );
            }}
            onRemove={() => {
              onDone();
              if (swapped) {
                act('removeBaseMarking', { zone, index: swapped.index });
              }
            }}
            onClose={onDone}
          />
        ) : (
          <div className="MarkingsRoom__empty">Fetching the markings…</div>
        )}
      </div>
    </div>
  );
}
