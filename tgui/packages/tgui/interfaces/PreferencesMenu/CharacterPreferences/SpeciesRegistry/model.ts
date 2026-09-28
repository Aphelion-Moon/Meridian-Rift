// THIS IS AN APHELION UI FILE
import { useMemo, useRef, useState } from 'react';

import type { SpeciesFamily, SpeciesSelfPreview } from '../../types';
import { MIN_QUERY_LENGTH, searchSpecies } from './search';
import {
  ALL_FAMILIES,
  type FamilyGroup,
  type FamilyLookup,
  familyLookup,
  flattenGroups,
  groupSpecies,
  type SpeciesMap,
} from './taxonomy';

/** Everything the page needs to draw itself and act. */
export type SpeciesBrowserModel = {
  /** The species the page lists: all of them, or all but the holiday ones. */
  species: SpeciesMap;
  /** Finds a species' family, for its heading. */
  getFamily: FamilyLookup;
  groups: FamilyGroup[];
  /** Every listed species in roster order. */
  order: string[];
  family: string;
  setFamily: (id: string) => void;
  query: string;
  setQuery: (query: string) => void;
  searching: boolean;
  /** Matching species, closest first; null while not searching. */
  matches: string[] | null;
  /** Whether holiday species are listed. */
  showHoliday: boolean;
  setShowHoliday: (show: boolean) => void;
  /** How many holiday species the toggle hides. */
  holidayCount: number;
  /** The species the details show; browsing never changes the character. */
  inspected: string;
  inspect: (id: string) => void;
  current: string;
  /** The character's own preview mob, shown for the current species once drawn. */
  selfPreview?: SpeciesSelfPreview;
  isLocked: (id: string) => boolean;
  choose: (id: string) => void;
  /** Asks for the sprites without uniform, the first time they are shown. */
  loadBodySprites: () => void;
  onBack: () => void;
};

export type SpeciesBrowserInput = {
  species: SpeciesMap;
  /** The families from the static preference data, in page order. */
  families: SpeciesFamily[];
  currentSpecies: string;
  /** The character's own preview mob, facing each way, once the server has drawn it. */
  selfPreview?: SpeciesSelfPreview;
  /** Whether Nova Star restrictions lock this player out of starred species. */
  novaStarLocked: boolean;
  onBack: () => void;
  onChoose: (id: string) => void;
  /** Sends for the sprites without uniform; called once, when first needed. */
  onLoadBodySprites: () => void;
};

/** Holiday species stay listed while they are the character's species. */
function withoutHoliday(species: SpeciesMap, keep: string): SpeciesMap {
  return Object.fromEntries(
    Object.entries(species).filter(
      ([id, entry]) => !entry.holiday || id === keep,
    ),
  );
}

/** Page state lives here, apart from the components that draw it. */
export function useSpeciesBrowser(
  input: SpeciesBrowserInput,
): SpeciesBrowserModel {
  const {
    species: allSpecies,
    families,
    currentSpecies,
    novaStarLocked,
  } = input;
  const [inspected, setInspected] = useState(currentSpecies);
  const [family, setFamily] = useState(ALL_FAMILIES);
  const [query, setQuery] = useState('');
  // During a holiday its species are joinable, so they start out listed.
  const [showHoliday, setShowHoliday] = useState(() =>
    Object.values(allSpecies).some((entry) => !!entry.holiday_active),
  );

  const species = useMemo(
    () =>
      showHoliday ? allSpecies : withoutHoliday(allSpecies, currentSpecies),
    [allSpecies, showHoliday, currentSpecies],
  );
  const holidayCount = useMemo(
    () => Object.values(allSpecies).filter((entry) => !!entry.holiday).length,
    [allSpecies],
  );
  const getFamily = useMemo(() => familyLookup(families), [families]);
  const groups = useMemo(
    () => groupSpecies(species, families),
    [species, families],
  );
  const order = useMemo(() => flattenGroups(groups), [groups]);
  const searching = query.trim().length >= MIN_QUERY_LENGTH;
  const matches = useMemo(
    () => (searching ? searchSpecies(species, order, query, getFamily) : null),
    [species, order, query, searching, getFamily],
  );

  const bodySpritesRequested = useRef(false);
  const loadBodySprites = () => {
    if (!bodySpritesRequested.current) {
      bodySpritesRequested.current = true;
      input.onLoadBodySprites();
    }
  };

  const isLocked = (id: string) =>
    novaStarLocked && !!allSpecies[id]?.nova_stars_only;

  return {
    species,
    getFamily,
    groups,
    order,
    family,
    setFamily,
    query,
    setQuery,
    searching,
    matches,
    showHoliday,
    setShowHoliday,
    holidayCount,
    inspected: species[inspected] ? inspected : order[0],
    inspect: setInspected,
    current: currentSpecies,
    selfPreview: input.selfPreview,
    isLocked,
    choose: (id: string) => {
      if (!isLocked(id)) {
        setInspected(id);
        input.onChoose(id);
      }
    },
    loadBodySprites,
    onBack: input.onBack,
  };
}

/** The families the roster shows under the current tab. */
export function shownGroups(model: SpeciesBrowserModel): FamilyGroup[] {
  return model.family === ALL_FAMILIES
    ? model.groups
    : model.groups.filter(({ family }) => family.id === model.family);
}

/** Heading and count for whatever the roster is showing. */
export function rosterHeading(model: SpeciesBrowserModel): {
  heading: string;
  count: number;
} {
  if (model.matches) {
    return { heading: 'Results', count: model.matches.length };
  }
  const groups = shownGroups(model);
  return {
    heading:
      model.family !== ALL_FAMILIES && groups[0]
        ? groups[0].family.name
        : 'Species',
    count: groups.reduce((sum, { size }) => sum + size, 0),
  };
}
