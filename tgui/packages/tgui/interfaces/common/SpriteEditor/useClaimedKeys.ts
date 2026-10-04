// THIS IS AN APHELION UI FILE
import { useEffect, useRef } from 'react';
import { listenForKeyEvents } from 'tgui-core/hotkeys';

/**
 * Listens for key presses with `onKeyDown`, which returns whether it claimed the key. A claimed
 * key's release is swallowed as well, so the game never sees half of a shortcut, and an unclaimed
 * key passes through untouched both ways.
 */
export function useClaimedKeys(
  onKeyDown: (event: KeyboardEvent, key: string) => boolean,
  deps: unknown[],
) {
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
        if (!onKeyDown(event, key)) return;
        claimedKeys.current.add(key);
        event.preventDefault();
      }),
    deps,
  );
}
