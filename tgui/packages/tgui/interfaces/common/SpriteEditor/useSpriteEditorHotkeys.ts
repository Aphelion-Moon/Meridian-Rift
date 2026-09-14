import { useEffect } from 'react';
import { useBackend } from 'tgui/backend';

export function useSpriteEditorHotkeys(disabled = false) {
  const { act } = useBackend();
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
      if (key !== 'z' && key !== 'y') return;
      event.preventDefault();
      act('spriteEditorCommand', {
        command: key === 'y' || event.shiftKey ? 'redo' : 'undo',
        count: 1,
      });
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [act, disabled]);
}
