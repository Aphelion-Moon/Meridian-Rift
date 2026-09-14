// THIS IS AN APHELION UI FILE
import { useStore } from 'jotai';
import { useCallback, useEffect } from 'react';
import { useBackend } from 'tgui/backend';
import {
  currentToolAtom,
  previewDataAtom,
  previewLayerAtom,
  selectionBoundsAtom,
} from './atoms';

export function useSpriteEditorHistory() {
  const { act } = useBackend();
  const store = useStore();
  return useCallback(
    (command: 'undo' | 'redo') => {
      // History can return to identical server pixels before a move is acknowledged.
      if (store.get(selectionBoundsAtom)) {
        store.get(currentToolAtom).cancel?.({
          setPreviewData: (value) => store.set(previewDataAtom, value),
          setPreviewLayer: (value) => store.set(previewLayerAtom, value),
          setSelectionBounds: (value) => store.set(selectionBoundsAtom, value),
        });
      }
      act('spriteEditorCommand', { command, count: 1 });
    },
    [act, store],
  );
}

export function useSpriteEditorHotkeys(disabled = false, onSave?: () => void) {
  const history = useSpriteEditorHistory();
  useEffect(() => {
    if (disabled) return;
    const handleKeyDown = (event: KeyboardEvent) => {
      const target = event.target;
      if (
        !event.ctrlKey ||
        event.altKey ||
        event.defaultPrevented ||
        (target instanceof HTMLElement &&
          (target.closest('input, textarea, select') ||
            target.isContentEditable))
      ) {
        return;
      }
      const key = event.key.toLowerCase();
      if (key === 's' && !event.shiftKey && onSave) {
        event.preventDefault();
        onSave();
        return;
      }
      if (key !== 'z' && key !== 'y') return;
      event.preventDefault();
      history(key === 'y' || event.shiftKey ? 'redo' : 'undo');
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [history, disabled, onSave]);
}
