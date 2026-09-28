// THIS IS AN APHELION UI FILE
import type { Species, SpeciesFamily } from '../../types';

/** Species the server files under no family, or one it does not send. */
export const UNCLASSIFIED_FAMILY: SpeciesFamily = {
  id: 'unclassified',
  name: 'Unclassified',
  icon: 'circle-question',
};

/** Tab value that shows every family at once. */
export const ALL_FAMILIES = 'all';

/** Finds a family by id, or Unclassified. */
export type FamilyLookup = (id: string | null | undefined) => SpeciesFamily;

/** The families come from /datum/species_family with the static preference data. */
export function familyLookup(families: SpeciesFamily[]): FamilyLookup {
  const byId = new Map(families.map((family) => [family.id, family]));
  return (id) => (id && byId.get(id)) || UNCLASSIFIED_FAMILY;
}

export type SpeciesMap = Record<string, Species>;

export type LineageMember = {
  id: string;
  /** 0 for the root, 1 for its variants, 2 and up below those. */
  depth: number;
  /** The species this one is a variant of, when it is not the root. */
  parent: string | null;
};

export type SpeciesLineage = {
  root: string;
  members: LineageMember[];
};

export type FamilyGroup = {
  family: SpeciesFamily;
  lineages: SpeciesLineage[];
  size: number;
};

/** The species this one is a variant of, if the page lists that species. */
export function getParentId(species: SpeciesMap, id: string): string | null {
  const parent = species[id]?.variant_of;
  return parent && parent !== id && species[parent] ? parent : null;
}

/**
 * The parent a species is grouped under. A variant filed under another
 * family, like the holiday Vampire, stands on its own there.
 */
function lineageParentId(species: SpeciesMap, id: string): string | null {
  const parent = getParentId(species, id);
  return parent && species[parent].family === species[id].family
    ? parent
    : null;
}

// Humans have always led the list, and still do.
const HUMAN = 'human';

function byName(species: SpeciesMap) {
  return (a: string, b: string) => {
    if (a === HUMAN || b === HUMAN) {
      return a === HUMAN ? -1 : 1;
    }
    return species[a].name.localeCompare(species[b].name);
  };
}

function childrenByParent(species: SpeciesMap): Map<string, string[]> {
  const children = new Map<string, string[]>();
  for (const id of Object.keys(species)) {
    const parent = lineageParentId(species, id);
    if (!parent) {
      continue;
    }
    const siblings = children.get(parent) ?? [];
    siblings.push(id);
    children.set(parent, siblings);
  }
  for (const siblings of children.values()) {
    siblings.sort(byName(species));
  }
  return children;
}

function collectLineage(
  root: string,
  children: Map<string, string[]>,
  visited: Set<string>,
): LineageMember[] {
  const members: LineageMember[] = [];
  const visit = (id: string, depth: number, parent: string | null) => {
    if (visited.has(id)) {
      return;
    }
    visited.add(id);
    members.push({ id, depth, parent });
    for (const child of children.get(id) ?? []) {
      visit(child, depth + 1, id);
    }
  };
  visit(root, 0, null);
  return members;
}

const leadsWithHumans = (lineage: SpeciesLineage) =>
  lineage.members.some(({ id }) => id === HUMAN);

const hasVariants = (lineage: SpeciesLineage) => lineage.members.length > 1;

/**
 * Families in display order, each holding lineages: a root species followed
 * by its variants, depth first. Most lineages are a single species. Humans
 * lead, then the lineages with variants, so every row starts with its boxes.
 */
export function groupSpecies(
  species: SpeciesMap,
  families: SpeciesFamily[],
): FamilyGroup[] {
  const getFamily = familyLookup(families);
  const children = childrenByParent(species);
  const visited = new Set<string>();
  const ids = Object.keys(species).sort(byName(species));
  const roots = ids.filter((id) => !lineageParentId(species, id));
  const lineagesByFamily = new Map<string, SpeciesLineage[]>();

  const place = (root: string) => {
    const members = collectLineage(root, children, visited);
    if (!members.length) {
      return;
    }
    const family = getFamily(species[root].family);
    const lineages = lineagesByFamily.get(family.id) ?? [];
    lineages.push({ root, members });
    lineagesByFamily.set(family.id, lineages);
  };

  roots.forEach(place);
  // A variant_of cycle leaves members without a root; list them on their own.
  ids.filter((id) => !visited.has(id)).forEach(place);

  return [...families, UNCLASSIFIED_FAMILY]
    .filter((family) => lineagesByFamily.has(family.id))
    .map((family) => {
      const lineages = lineagesByFamily.get(family.id) ?? [];
      // Sorting is stable, so each kind stays in name order.
      lineages.sort(
        (a, b) =>
          Number(leadsWithHumans(b)) - Number(leadsWithHumans(a)) ||
          Number(hasVariants(b)) - Number(hasVariants(a)),
      );
      return {
        family,
        lineages,
        size: lineages.reduce((sum, { members }) => sum + members.length, 0),
      };
    });
}

/** Every species in roster order, for keyboard stepping and search order. */
export function flattenGroups(groups: FamilyGroup[]): string[] {
  return groups.flatMap(({ lineages }) =>
    lineages.flatMap(({ members }) => members.map(({ id }) => id)),
  );
}

/** The whole lineage a species belongs to, root first. */
export function getLineage(
  groups: FamilyGroup[],
  id: string,
): SpeciesLineage | undefined {
  for (const { lineages } of groups) {
    const lineage = lineages.find(({ members }) =>
      members.some((member) => member.id === id),
    );
    if (lineage) {
      return lineage;
    }
  }
  return undefined;
}
