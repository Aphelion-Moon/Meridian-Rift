// THIS IS AN APHELION UI FILE
import { storage } from 'common/storage';
import { atom, useAtom } from 'jotai';
import { useCallback, useEffect } from 'react';

/** Where the player's choice is kept, so that it stays put between windows. */
const KEPT = 'markings-room-light-effects';

/**
 * Whether the room's lighting falls on the character: its lamps' tint and rim
 * light, its dark with the lights off, its blacklight. Off, the character
 * shows as it is, whatever the room around it does.
 */
export const lightEffectsAtom = atom(true);

let restored = false;

/** The light effects and their switch. The first room to ask reads the player's choice back. */
export function useLightEffects() {
  const [on, setOn] = useAtom(lightEffectsAtom);
  useEffect(() => {
    if (restored) {
      return;
    }
    restored = true;
    storage.get(KEPT).then((kept) => {
      if (typeof kept === 'boolean') {
        setOn(kept);
      }
    });
  }, []);
  const toggle = useCallback(() => {
    setOn(!on);
    storage.set(KEPT, !on);
  }, [on]);
  return [on, toggle] as const;
}
