// THIS IS AN APHELION UI FILE
import { useAtomValue } from 'jotai';
import { useEffect, useLayoutEffect, useRef } from 'react';
import { store as backendStore, suspendingAtom } from 'tgui/events/store';
import { Button } from 'tgui-core/components';
import { listenForKeyEvents } from 'tgui-core/hotkeys';
import { selectionBoundsAtom } from './atoms';
import { isTextEntryTarget } from './helpers';
import type { Tool } from './Types/Tool';
import { Select } from './Types/Tools/Select';
import type { SpriteData, SpriteEditorToolContext } from './Types/types';

/// Unmodified key that turns the selection clockwise; with Shift, counter-clockwise.
export const ROTATE_SELECTION_KEY = 'r';

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

/** Drops floating paint onto the canvas, so a save or a finish includes it. A plain selection stays. */
export const settleSelection = () => {
  const current = currentSelect();
  if (current?.select.isFloating()) current.select.release(current.context);
};

/**
 * Selection keys while the Select tool is current: Ctrl+C copies, Ctrl+V pastes into the view shown,
 * R turns the selection clockwise and Shift+R counter-clockwise, and Enter drops it. Keys that have
 * nothing to act on pass through untouched.
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
  const claimedKeys = useRef(new Set<string>());
  useEffect(
    () =>
      listenForKeyEvents((keyEvent) => {
        const event = keyEvent.event;
        const key = event.key.toLowerCase();
        if (keyEvent.isUp()) {
          if (claimedKeys.current.delete(key)) event.preventDefault();
          return;
        }
        const current = currentSelect();
        if (
          !current ||
          event.altKey ||
          event.metaKey ||
          event.defaultPrevented ||
          isTextEntryTarget(event.target)
        ) {
          return;
        }
        const { select, context, data } = current;
        let handled = false;
        if (event.ctrlKey) {
          if (event.shiftKey) return;
          if (key === 'c') handled = select.copy(context, data);
          if (key === 'v') handled = select.paste(context, data);
        } else if (key === ROTATE_SELECTION_KEY) {
          handled = select.rotate(context, data, event.shiftKey ? -1 : 1);
        } else if (
          key === 'enter' &&
          !event.shiftKey &&
          select.hasSelection()
        ) {
          select.release(context);
          handled = true;
        }
        if (!handled) return;
        claimedKeys.current.add(key);
        event.preventDefault();
      }),
    [],
  );
}

/** Quarter-turn buttons for the toolbar, shown while there is a selection. */
export const SelectionTools = (props: { className?: string }) => {
  const bounds = useAtomValue(selectionBoundsAtom);
  if (!bounds) return null;
  const turnButton = (turn: 1 | -1) => (
    <Button
      icon={turn > 0 ? 'rotate-right' : 'rotate-left'}
      aria-label={turn > 0 ? 'Turn clockwise' : 'Turn counter-clockwise'}
      tooltip={
        turn > 0
          ? `Turn the selection clockwise (${ROTATE_SELECTION_KEY.toUpperCase()})`
          : `Turn the selection counter-clockwise (Shift+${ROTATE_SELECTION_KEY.toUpperCase()})`
      }
      onClick={(event) => {
        rotateSelection(turn);
        // Enter then drops the selection rather than pressing this button again.
        event.currentTarget.blur();
      }}
    />
  );
  return (
    <div className={props.className}>
      {turnButton(-1)}
      {turnButton(1)}
    </div>
  );
};
