import { storage } from 'common/storage';
import { useAtom, useAtomValue } from 'jotai';
import { useEffect } from 'react';
// import { highlightsAtom, settingsAtom, settingsLoadedAtom } from './atoms'; // APHELION EDIT REMOVAL - CHAT_SETTINGS
// APHELION EDIT ADDITION START - CHAT_SETTINGS
import { store } from '../events/store';
import {
  highlightsAtom,
  settingsAtom,
  settingsLoadedAtom,
  settingsReadAtom,
} from './atoms';
// APHELION EDIT ADDITION END
import { generalSettingsHandler } from './helpers';
import { startSettingsMigration } from './migration';
import { setDisplayScaling } from './scaling';
import type { SettingsState } from './types';

/** Custom hook that handles loading and updating settings from storage. */
export function useSettings() {
  const [settings, setSettings] = useAtom(settingsAtom);
  const highlights = useAtomValue(highlightsAtom);

  const [loaded, setLoaded] = useAtom(settingsLoadedAtom);

  /** Load and migrate settings */
  useEffect(() => {
    if (loaded) return;

    async function fetchSettings(): Promise<void> {
      try {
        const storedSettings = await storage.read('panel-settings'); // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: const storedSettings = await storage.get('panel-settings');
        console.log('Loaded panel settings from storage:', storedSettings);
        store.set(settingsReadAtom, true); // APHELION EDIT ADDITION - CHAT_SETTINGS
        startSettingsMigration(storedSettings);
      } catch (error) {
        // APHELION EDIT ADDITION START - CHAT_SETTINGS
        // Show the defaults this session and save nothing, so the player's
        // settings are still there next session.
        // APHELION EDIT ADDITION END
        console.error('Failed to load panel settings:', error);
      }
      setLoaded(true); // APHELION EDIT ADDITION - CHAT_SETTINGS
    }

    fetchSettings();
    setDisplayScaling();
    // setLoaded(true); // APHELION EDIT REMOVAL - CHAT_SETTINGS
  }, []);

  function storeSettings(update: SettingsState): void {
    setSettings(update);
    console.log('Updated panel settings:', update);
    // storage.set('panel-settings', { ...update, ...highlights }); // APHELION EDIT REMOVAL - CHAT_SETTINGS
    // APHELION EDIT ADDITION START - CHAT_SETTINGS
    if (store.get(settingsReadAtom)) {
      storage.set('panel-settings', { ...update, ...highlights });
    }
    // APHELION EDIT ADDITION END
  }

  /** Updates any set of keys. Offers type safety based on the selection */
  function updateSettings<TKey extends keyof SettingsState>(
    update: Record<TKey, SettingsState[TKey]>,
  ): void {
    const newSettings: SettingsState = {
      ...settings,
      ...update,
    };

    generalSettingsHandler(newSettings);
    storeSettings(newSettings);
  }

  return { settings, updateSettings };
}
