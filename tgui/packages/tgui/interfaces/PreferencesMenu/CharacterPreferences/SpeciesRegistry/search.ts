// THIS IS AN APHELION UI FILE
import { createSearch } from 'tgui-core/string';

import { FOOD_NAMES, PERK_KINDS } from './constants';
import { type FamilyLookup, getParentId, type SpeciesMap } from './taxonomy';

/** Same threshold as the loadout search before results replace the tabs. */
export const MIN_QUERY_LENGTH = 2;
/** Free text is noisy; only search prose once the query says something. */
const MIN_PROSE_QUERY_LENGTH = 4;
/** What a template species answers to: its ribbon, and the family's name it once had. */
const TEMPLATE_WORDS = ['Template', 'Custom', 'Generic'];

/**
 * How closely a species matches: its name, then its family (or, for a
 * template, being one), the species it is a variant of, a trait, a liked
 * food, and last its description or lore. Null when it does not match at all.
 */
function matchRank(
  species: SpeciesMap,
  id: string,
  query: string,
  matches: (text: string) => boolean,
  getFamily: FamilyLookup,
): number | null {
  const entry = species[id];

  if (matches(entry.name)) {
    return 0;
  }
  if (
    matches(getFamily(entry.family).name) ||
    (entry.template && TEMPLATE_WORDS.some(matches))
  ) {
    return 1;
  }
  const parent = getParentId(species, id);
  if (parent && matches(species[parent].name)) {
    return 2;
  }
  const hasPerk = PERK_KINDS.some(({ kind }) =>
    entry.perks[kind].some(
      (perk) => matches(perk.name) || matches(perk.description),
    ),
  );
  if (hasPerk) {
    return 3;
  }
  if (
    entry.diet?.liked_food.some((food) => matches(FOOD_NAMES[food] ?? food))
  ) {
    return 4;
  }
  if (query.length >= MIN_PROSE_QUERY_LENGTH) {
    if (entry.desc && matches(entry.desc)) {
      return 5;
    }
    if (entry.lore && matches(entry.lore.join(' '))) {
      return 6;
    }
  }
  return null;
}

/**
 * The species that match a query, closest first. `order` is the roster
 * order, which is kept among equally close matches.
 */
export function searchSpecies(
  species: SpeciesMap,
  order: string[],
  query: string,
  getFamily: FamilyLookup,
): string[] {
  const trimmed = query.trim();
  if (trimmed.length < MIN_QUERY_LENGTH) {
    return [];
  }
  const matches = createSearch(trimmed, (text: string) => text);
  return order
    .map((id) => ({
      id,
      rank: matchRank(species, id, trimmed, matches, getFamily),
    }))
    .filter((match): match is { id: string; rank: number } => {
      return match.rank !== null;
    })
    .sort((a, b) => a.rank - b.rank)
    .map(({ id }) => id);
}
