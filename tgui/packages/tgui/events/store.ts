import { atom, createStore } from 'jotai';
// APHELION EDIT ADDITION START - MERIDIAN_UI
import {
  normalizeMeridianBaseTheme,
  type MeridianBaseThemeId,
} from '../constants/theme';
// APHELION EDIT ADDITION END
import type { Config } from './types';

export const chunkingAtom = atom<Record<string, any>>({});
export const configAtom = atom<Config>({} as Config);
export const debugLayoutAtom = atom(false);
// APHELION EDIT ADDITION START - MERIDIAN_UI
export const debugThemeAtom = atom<MeridianBaseThemeId | null>(null);
export const meridianThemeAtom = atom(
  (get) => normalizeMeridianBaseTheme(get(configAtom).meridianTheme),
  (_get, set, nextTheme: MeridianBaseThemeId) => {
    set(configAtom, (previous) => ({
      ...previous,
      meridianTheme: normalizeMeridianBaseTheme(nextTheme),
    }));
  },
);
// APHELION EDIT ADDITION END
export const gameDataAtom = atom<Record<string, any>>({});
export const gameStaticDataAtom = atom<Record<string, any>>({});
export const kitchenSinkAtom = atom(false);
export const sharedAtom = atom<Record<string, any>>({});
export const suspendedAtom = atom<number | false>(Date.now()); // Start as suspended
export const suspendingAtom = atom(false);

export const backendStateAtom = atom((get) => ({
  config: get(configAtom),
  data: {
    ...get(gameDataAtom),
    ...get(gameStaticDataAtom),
  },
  debug: {
    debugLayout: get(debugLayoutAtom),
    debugTheme: get(debugThemeAtom), // APHELION EDIT ADDITION
    kitchenSink: get(kitchenSinkAtom),
  },
  outgoingPayloadQueues: get(chunkingAtom),
  shared: get(sharedAtom),
  staticData: get(gameStaticDataAtom),
  suspended: get(suspendedAtom),
  suspending: get(suspendingAtom),
}));

export const store = createStore();

export function resetStore() {
  // APHELION EDIT ADDITION START - MERIDIAN_UI
  store.set(debugThemeAtom, null);
  store.set(kitchenSinkAtom, false);
  // APHELION EDIT ADDITION END
  store.set(gameDataAtom, {});
  store.set(gameStaticDataAtom, {});
  store.set(sharedAtom, {});
}
