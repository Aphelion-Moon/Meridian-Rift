import { Suspense, useEffect, useState } from 'react';
import { exhaustiveCheck } from 'tgui-core/exhaustive';
import { fetchRetry } from 'tgui-core/http';

import { resolveAsset } from '../../assets';
import { useBackend } from '../../backend';
import { Window } from '../../layouts';
import { logger } from '../../logging';
import { LoadingScreen } from '../common/LoadingScreen';
import { CharacterPreferenceWindow } from './CharacterPreferences';
// NOVA EDIT ADDITION START
import type { AugmentsTab } from './CharacterPreferences/LimbsPage';
import { GamePreferenceWindow } from './GamePreferences';
import {
  GamePreferencesSelectedPage,
  type PreferencesMenuData,
  PrefsWindow,
  type ServerData,
} from './types';
import { RandomToggleState } from './useRandomToggleState';
import { ServerPrefs } from './useServerPrefs';

// Window dimensions per state
const WINDOW_WIDTH = 920;
const WINDOW_HEIGHT_DEFAULT = 780;
const WINDOW_HEIGHT_MARKINGS_BODYPARTS = 940; // taller to fit three-column markings layout
// NOVA EDIT ADDITION END

export function PreferencesMenu(props) {
  // NOVA EDIT ADDITION START
  const [cyborgTab, setCyborgTab] = useState(false);
  const [augmentsTab, setAugmentsTab] = useState<AugmentsTab | null>(null);

  const height =
    cyborgTab || augmentsTab !== null
      ? WINDOW_HEIGHT_MARKINGS_BODYPARTS
      : WINDOW_HEIGHT_DEFAULT;
  // NOVA EDIT ADDITION END
  return (
    <Window
      width={cyborgTab ? 1200 : WINDOW_WIDTH}
      height={
        height
      } /* NOVA EDIT CHANGE - ORIGINAL: <Window width={920} height={770}> */
    >
      <Window.Content>
        <Suspense fallback={<LoadingScreen />}>
          <PrefsWindowInner
            onCyborgTabChange={setCyborgTab}
            onAugmentsTabChange={
              setAugmentsTab
            } /* NOVA EDIT CHANGE - ORIGINAL: <PrefsWindowInner /> */
          />
        </Suspense>
      </Window.Content>
    </Window>
  );
}

/** We're abstracting this by one level to use Suspense */
//function PrefsWindowInner(props) { // NOVA EDIT REMOVAL
// NOVA EDIT ADDITION START
function PrefsWindowInner(props: {
  onCyborgTabChange: (active: boolean) => void;
  onAugmentsTabChange: (tab: AugmentsTab | null) => void;
}) {
  // NOVA EDIT ADDITION END
  const { data } = useBackend<PreferencesMenuData>();
  const { window } = data;

  const [serverData, setServerData] = useState<ServerData>();
  const randomization = useState(false);

  useEffect(() => {
    fetchRetry(resolveAsset('preferences.json'))
      .then((response) => response.json())
      .then((data) => {
        setServerData(data);
      })
      .catch((error) => {
        logger.log('Failed to fetch preferences.json', error);
      });
  }, []);

  let content;
  let title;
  switch (window) {
    case PrefsWindow.Character:
      content = (
        <CharacterPreferenceWindow
          onCyborgTabChange={props.onCyborgTabChange}
          onAugmentsTabChange={
            props.onAugmentsTabChange
          } /* NOVA EDIT CHANGE - ORIGINAL: content = <CharacterPreferenceWindow />; */
        />
      );
      title = 'Character Preferences';
      break;
    case PrefsWindow.Game:
      content = <GamePreferenceWindow />;
      title = 'Game Preferences';
      break;
    case PrefsWindow.Keybindings:
      content = (
        <GamePreferenceWindow
          startingPage={GamePreferencesSelectedPage.Keybindings}
        />
      );
      title = 'Keybindings';
      break;
    default:
      exhaustiveCheck(window);
  }

  return (
    <ServerPrefs.Provider value={serverData}>
      <RandomToggleState.Provider value={randomization}>
        {content}
      </RandomToggleState.Provider>
    </ServerPrefs.Provider>
  );
}
