// THIS IS AN APHELION UI FILE
import { useEffect } from 'react';
import { useBackend } from 'tgui/backend';

import { LoadingScreen } from '../../../common/LoadingScreen';
import { createSetPreference, type PreferencesMenuData } from '../../types';
import { useServerPrefs } from '../../useServerPrefs';
import { SpeciesBrowser } from './SpeciesBrowser';

type SpeciesPageProps = {
  closeSpecies: () => void;
  /** Told while the page is shown, so the window can make room for it. */
  onShown?: (shown: boolean) => void;
};

/** Backend wiring only; everything visual lives in SpeciesBrowser. */
export function SpeciesPage(props: SpeciesPageProps) {
  const { act, data } = useBackend<PreferencesMenuData>();
  const serverData = useServerPrefs();
  const currentSpecies = data.character_preferences.misc.species;
  // The character preview every tab shows, until the character is drawn again as a newly chosen species.
  const selfPreview =
    data.character_preview?.species === currentSpecies
      ? data.character_preview
      : undefined;

  // The sprites come when the page opens, not with every preferences window.
  useEffect(() => {
    act('species_page_sprites');
  }, []);

  useEffect(() => {
    props.onShown?.(true);
    return () => props.onShown?.(false);
  }, []);

  if (!serverData) {
    return <LoadingScreen />;
  }

  return (
    <SpeciesBrowser
      species={serverData.species}
      families={serverData.species_families}
      currentSpecies={currentSpecies}
      selfPreview={selfPreview}
      selfPending={!!data.character_preview_pending}
      novaStarLocked={!!data.nova_star_restrictions && !data.is_nova_star}
      onBack={props.closeSpecies}
      onChoose={createSetPreference(act, 'species')}
      onLoadBodySprites={() => act('species_page_sprites', { body: true })}
    />
  );
}
