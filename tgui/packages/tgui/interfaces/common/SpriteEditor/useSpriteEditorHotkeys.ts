// THIS IS AN APHELION UI FILE
import { useStore } from 'jotai';
import { useCallback } from 'react';
import { useBackend } from 'tgui/backend';
import {
  currentToolAtom,
  previewDataAtom,
  previewLayerAtom,
  selectionBoundsAtom,
  selectionMaskAtom,
  tools,
} from './atoms';
import { isTextEntryTarget } from './helpers';
import { settleSelection } from './selection';
import type { Tool } from './Types/Tool';
import type { SpriteEditorToolCancelContext } from './Types/types';
import { useClaimedKeys } from './useClaimedKeys';

/// Unmodified keys that pick a tool, keyed by the tool's name.
export const toolHotkeys: Record<string, string> = {
  Select: 'm',
  Pencil: 'b',
  Eraser: 'e',
  Fill: 'g',
};

/** A tool's label with its shortcut, plus any extra hint worth listing. */
export function toolTooltip(tool: Tool, extra?: string) {
  const hints = [toolHotkeys[tool.name]?.toUpperCase(), extra].filter(Boolean);
  return hints.length ? `${tool.name} (${hints.join(', ')})` : tool.name;
}

/** A cancel context that writes straight to the store, for key handlers outside a render. */
const cancelContextFor = (
  store: ReturnType<typeof useStore>,
): SpriteEditorToolCancelContext => ({
  setPreviewData: (value) => store.set(previewDataAtom, value),
  setPreviewLayer: (value) => store.set(previewLayerAtom, value),
  setSelectionBounds: (value) => store.set(selectionBoundsAtom, value),
  setSelectionMask: (value) => store.set(selectionMaskAtom, value),
});

export function useSpriteEditorHistory() {
  const { act } = useBackend();
  const store = useStore();
  return useCallback(
    (command: 'undo' | 'redo') => {
      // History can return to identical server pixels before a move is acknowledged.
      if (store.get(selectionBoundsAtom)) {
        store.get(currentToolAtom).cancel?.(cancelContextFor(store));
      }
      act('spriteEditorCommand', { command, count: 1 });
    },
    [act, store],
  );
}

export function useSpriteEditorHotkeys(disabled = false, onSave?: () => void) {
  const history = useSpriteEditorHistory();
  useClaimedKeys(
    (event, key) => {
      if (
        disabled ||
        !event.ctrlKey ||
        event.altKey ||
        event.defaultPrevented ||
        isTextEntryTarget(event.target)
      ) {
        return false;
      }
      if (key === 's' && !event.shiftKey && onSave) {
        // Floating paint is part of what the window shows, so it is saved too.
        settleSelection();
        onSave();
        return true;
      }
      if (key !== 'z' && key !== 'y') return false;
      history(key === 'y' || event.shiftKey ? 'redo' : 'undo');
      return true;
    },
    [history, disabled, onSave],
  );
}

/**
 * Plain letter keys that switch tools.
 *
 * Kept apart from the ctrl chords above because tool choice belongs to the
 * toolbar, which is the only thing that knows which tools an editor allows.
 * Selecting a hidden tool would strand the canvas on something the user can't
 * see or switch away from.
 */
export function useSpriteEditorToolHotkeys(toolFlags: number) {
  const store = useStore();
  useClaimedKeys(
    (event, key) => {
      if (
        event.ctrlKey ||
        event.altKey ||
        event.shiftKey ||
        event.defaultPrevented ||
        isTextEntryTarget(event.target)
      ) {
        return false;
      }
      const index = tools.findIndex((tool) => toolHotkeys[tool.name] === key);
      if (index < 0 || !(toolFlags & (1 << index))) return false;
      store.set(currentToolAtom, tools[index], cancelContextFor(store));
      return true;
    },
    [store, toolFlags],
  );
}
