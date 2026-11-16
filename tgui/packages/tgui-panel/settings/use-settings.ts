import { storage } from 'common/storage';
import { useAtom, useAtomValue } from 'jotai';
import { useEffect } from 'react';
import { store } from '../events/store'; // APHELION EDIT ADDITION - CHAT_SETTINGS
import {
  highlightsAtom,
  settingsAtom,
  settingsLoadedAtom,
  settingsReadAtom, // APHELION EDIT ADDITION - CHAT_SETTINGS
} from './atoms';
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
        // The defaults show for this session and nothing is saved, so the
        // stored settings are still there for the next one.
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
    // APHELION EDIT CHANGE START - CHAT_SETTINGS - ORIGINAL: storage.set('panel-settings', { ...update, ...highlights });
    if (store.get(settingsReadAtom)) {
      storage.set('panel-settings', { ...update, ...highlights });
    }
    // APHELION EDIT CHANGE END
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
