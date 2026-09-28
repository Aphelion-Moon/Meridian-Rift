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
  const currentSpecies = data.character_preferences.misc.species;
  // Until the character is drawn again as a newly chosen species, it has no preview.
  const selfPreview =
    data.species_page_self?.species === currentSpecies
      ? data.species_page_self
      : undefined;

  // The sprites come when the page opens, not with every preferences window.
  useEffect(() => {
    act('species_page_sprites');
  }, []);

  // The character's own preview, whenever the page opens or the character
  // changes under it. The server only draws it again if it has changed.
  useEffect(() => {
    act('species_page_self');
  }, [currentSpecies, data.active_slot]);

  if (!serverData) {
    return <LoadingScreen />;
  }

  return (
    <SpeciesBrowser
      species={serverData.species}
      families={serverData.species_families}
      currentSpecies={currentSpecies}
      selfPreview={selfPreview}
      novaStarLocked={!!data.nova_star_restrictions && !data.is_nova_star}
      onBack={props.closeSpecies}
      onChoose={createSetPreference(act, 'species')}
      onLoadBodySprites={() => act('species_page_sprites', { body: true })}
    />
  );
}
