// THIS IS AN APHELION UI FILE
import { useEffect } from 'react';
import { useBackend } from 'tgui/backend';

import { LoadingScreen } from '../../../common/LoadingScreen';
import { createSetPreference, type PreferencesMenuData } from '../../types';
import { useServerPrefs } from '../../useServerPrefs';
import { SpeciesBrowser } from './SpeciesBrowser';

type SpeciesPageProps = {
  closeSpecies: () => void;
};

/** Backend wiring only; everything visual lives in SpeciesBrowser. */
export function SpeciesPage(props: SpeciesPageProps) {
  const { act, data } = useBackend<PreferencesMenuData>();
  const serverData = useServerPrefs();

  // The sprites come when the page opens, not with every preferences window.
  useEffect(() => {
    act('species_page_sprites');
  }, []);

  if (!serverData) {
    return <LoadingScreen />;
  }

  return (
    <SpeciesBrowser
      species={serverData.species}
      families={serverData.species_families}
      currentSpecies={data.character_preferences.misc.species}
      novaStarLocked={!!data.nova_star_restrictions && !data.is_nova_star}
      onBack={props.closeSpecies}
      onChoose={createSetPreference(act, 'species')}
      onLoadBodySprites={() => act('species_page_sprites', { body: true })}
    />
  );
}
