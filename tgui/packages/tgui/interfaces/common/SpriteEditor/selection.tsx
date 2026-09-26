// THIS IS AN APHELION UI FILE
import { useAtomValue } from 'jotai';
import { useEffect, useLayoutEffect } from 'react';
import { store as backendStore, suspendingAtom } from 'tgui/events/store';
import { Button } from 'tgui-core/components';
import { selectionBoundsAtom } from './atoms';
import { isTextEntryTarget } from './helpers';
import type { Tool } from './Types/Tool';
import { Select } from './Types/Tools/Select';
import type { SpriteData, SpriteEditorToolContext } from './Types/types';
import { useClaimedKeys } from './useClaimedKeys';

/// Unmodified key that turns the selection clockwise; with Shift, counter-clockwise.
export const ROTATE_SELECTION_KEY = 'r';
/// With Shift, mirrors the selection left to right, as Shift+H flips horizontally in Aseprite.
export const MIRROR_SELECTION_KEY = 'h';

/**
 * The canvas selection commands act on: its current tool, live context and sprite. A window has one
 * canvas, which registers itself here while it's mounted and enabled.
 */
let canvas:
  | { tool: Tool; context: SpriteEditorToolContext; data: SpriteData }
  | undefined;

/** The Select tool and the canvas it works on, while it's the canvas's current tool. */
const currentSelect = () =>
  canvas?.tool instanceof Select
    ? { select: canvas.tool, context: canvas.context, data: canvas.data }
    : undefined;

/** Turns the selection a quarter turn: 1 clockwise, -1 counter-clockwise. Returns whether it turned. */
export const rotateSelection = (turn: 1 | -1) => {
  const current = currentSelect();
  return !!current?.select.rotate(current.context, current.data, turn);
};

/** Mirrors the selection left to right. Returns whether it mirrored. */
export const mirrorSelection = () => {
  const current = currentSelect();
  return !!current?.select.flip(current.context, current.data);
};

/** Drops floating paint onto the canvas, so a save or a finish includes it. A plain selection stays. */
export const settleSelection = () => {
  const current = currentSelect();
  if (current?.select.isFloating()) current.select.release(current.context);
};

/**
 * Selection keys while the Select tool is current: Ctrl+C copies, Ctrl+V pastes into the view shown,
 * R turns the selection clockwise and Shift+R counter-clockwise, Shift+H mirrors it left to right,
 * and Enter drops it. Keys that have nothing to act on pass through untouched.
 */
export function useSelectionCommands(
  tool: Tool,
  context: SpriteEditorToolContext,
  data: SpriteData,
  disabled: boolean,
) {
  useLayoutEffect(() => {
    canvas = disabled ? undefined : { tool, context, data };
  });
  useEffect(
    () => () => {
      canvas = undefined;
    },
    [],
  );
  // The close button marks the window as suspending before it tells the server; jotai tells
  // subscribers at once, so floating paint is sent ahead of the close.
  useEffect(
    () =>
      backendStore.sub(suspendingAtom, () => {
        if (backendStore.get(suspendingAtom)) settleSelection();
      }),
    [],
  );
  useClaimedKeys((event, key) => {
    const current = currentSelect();
    if (
      !current ||
      event.altKey ||
      event.metaKey ||
      event.defaultPrevented ||
      isTextEntryTarget(event.target)
    ) {
      return false;
    }
    const { select, context, data } = current;
    if (event.ctrlKey) {
      if (event.shiftKey) return false;
      if (key === 'c') return select.copy(context, data);
      if (key === 'v') return select.paste(context, data);
      return false;
    }
    if (key === MIRROR_SELECTION_KEY) {
      return event.shiftKey && select.flip(context, data);
    }
    if (key === ROTATE_SELECTION_KEY) {
      return select.rotate(context, data, event.shiftKey ? -1 : 1);
    }
    if (key === 'enter' && !event.shiftKey && select.hasSelection()) {
      select.release(context);
      return true;
    }
    return false;
  }, []);
}

/** A button for a selection command, labelled and badged like the tool buttons. */
const SelectionButton = (props: {
  icon: string;
  label: string;
  keys: string;
  badge: string;
  command: () => void;
}) => (
  <Button
    icon={props.icon}
    aria-label={props.label}
    tooltip={`${props.label} (${props.keys})`}
    data-hotkey={props.badge}
    onClick={(event) => {
      props.command();
      // Enter then drops the selection rather than pressing this button again.
      event.currentTarget.blur();
    }}
  />
);

/** Turn and mirror buttons for the toolbar, shown while there is a selection. */
export const SelectionTools = (props: { className?: string }) => {
  const bounds = useAtomValue(selectionBoundsAtom);
  if (!bounds) return null;
  const turn = ROTATE_SELECTION_KEY.toUpperCase();
  const mirror = MIRROR_SELECTION_KEY.toUpperCase();
  return (
    <div className={props.className}>
      <SelectionButton
        icon="rotate-left"
        label="Turn counter-clockwise"
        keys={`Shift+${turn}`}
        badge={`⇧${turn}`}
        command={() => rotateSelection(-1)}
      />
      <SelectionButton
        icon="rotate-right"
        label="Turn clockwise"
        keys={turn}
        badge={turn}
        command={() => rotateSelection(1)}
      />
      <SelectionButton
        icon="arrows-left-right"
        label="Mirror"
        keys={`Shift+${mirror}`}
        badge={`⇧${mirror}`}
        command={mirrorSelection}
      />
    </div>
  );
};
