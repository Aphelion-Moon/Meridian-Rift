import { useSetAtom } from 'jotai'; // APHELION EDIT ADDITION - Drawn character preview
import { Suspense, useEffect, useState } from 'react';
import { exhaustiveCheck } from 'tgui-core/exhaustive';
import { fetchRetry } from 'tgui-core/http';

import { resolveAsset } from '../../assets';
import { useBackend } from '../../backend';
import { Window } from '../../layouts';
import { logger } from '../../logging';
import { LoadingScreen } from '../common/LoadingScreen';
import { CharacterPreferenceWindow } from './CharacterPreferences';
import { previewTurnAtom } from './CharacterPreferences/CharacterPreview/turn'; // APHELION EDIT ADDITION - Drawn character preview
import { GamePreferenceWindow } from './GamePreferences';
import {
  GamePreferencesSelectedPage,
  type PreferencesMenuData,
  PrefsWindow,
  type ServerData,
} from './types';
import { RandomToggleState } from './useRandomToggleState';
import { ServerPrefs } from './useServerPrefs';
// NOVA EDIT ADDITION START
import type { AugmentsTab } from './CharacterPreferences/LimbsPage';

// Window dimensions per state
const WINDOW_WIDTH  = 920;
const WINDOW_HEIGHT_DEFAULT  = 820;
const WINDOW_HEIGHT_MARKINGS_BODYPARTS = 980; // taller to fit three-column markings layout
// NOVA EDIT ADDITION END
const WINDOW_HEIGHT_SPECIES = 860; // APHELION EDIT ADDITION - Species page: two whole rows of its roster, in every theme, under the chamber.

export function PreferencesMenu(props) {
  // NOVA EDIT ADDITION START
  const [augmentsTab, setAugmentsTab] = useState<AugmentsTab | null>(null);
  const [speciesShown, setSpeciesShown] = useState(false);
  // Drawn character preview: tgui keeps a closed window's page for the next, so the
  // character is turned back to face south as the window opens, as the game's preview was.
  const setPreviewTurn = useSetAtom(previewTurnAtom);
  useEffect(() => setPreviewTurn(0), []);

  const height =
    augmentsTab !== null
      ? WINDOW_HEIGHT_MARKINGS_BODYPARTS
      : speciesShown
        ? WINDOW_HEIGHT_SPECIES
        : WINDOW_HEIGHT_DEFAULT;
  // NOVA EDIT ADDITION END
  return (
    <Window width={WINDOW_WIDTH} height={height} /* NOVA EDIT CHANGE - ORIGINAL: <Window width={920} height={770}> */>
      <Window.Content>
        <Suspense fallback={<LoadingScreen />}>
          <PrefsWindowInner onAugmentsTabChange={setAugmentsTab} onSpeciesPageShown={setSpeciesShown} /* NOVA EDIT CHANGE - ORIGINAL: <PrefsWindowInner /> */ // APHELION EDIT CHANGE - Species page - ORIGINAL: <PrefsWindowInner onAugmentsTabChange={setAugmentsTab} /* NOVA EDIT CHANGE - ORIGINAL: <PrefsWindowInner /> *//>
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
  onAugmentsTabChange: (tab: AugmentsTab | null) => void; // APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: onAugmentsTabChange: (tab: AugmentsTab) => void;
  onSpeciesPageShown: (shown: boolean) => void;
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
      content = <CharacterPreferenceWindow onAugmentsTabChange={props.onAugmentsTabChange} onSpeciesPageShown={props.onSpeciesPageShown} /* NOVA EDIT CHANGE - ORIGINAL: content = <CharacterPreferenceWindow />; */ // APHELION EDIT CHANGE - Species page - ORIGINAL: content = <CharacterPreferenceWindow onAugmentsTabChange={props.onAugmentsTabChange} /* NOVA EDIT CHANGE - ORIGINAL: content = <CharacterPreferenceWindow />; */ />
      />
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
