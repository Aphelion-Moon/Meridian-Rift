// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';

import {
  flattenGroups,
  getLineage,
  groupSpecies,
  type SpeciesMap,
} from './taxonomy';
import { testFamilies, testSpecies } from './testSpecies';

const species: SpeciesMap = {
  kobold: testSpecies({ name: 'Kobold', family: 'reptilian' }),
  lizard: testSpecies({ name: 'Lizardperson', family: 'reptilian' }),
  ashwalker: testSpecies({
    name: 'Ash Walker',
    family: 'reptilian',
    variant_of: 'lizard',
  }),
  unathi: testSpecies({ name: 'Unathi', family: 'reptilian' }),
  felinid: testSpecies({
    name: 'Felinid',
    family: 'mammalian',
    variant_of: 'human',
  }),
  dwarf: testSpecies({ name: 'Dwarf', family: 'mammalian' }),
  human: testSpecies({ name: 'Human', family: 'mammalian' }),
  vampire: testSpecies({
    name: 'Vampire',
    family: 'holiday',
    variant_of: 'human',
    holiday: 'Halloween',
  }),
  mystery: testSpecies({ name: 'Mystery', family: 'no-such-family' }),
};

describe('groupSpecies', () => {
  const groups = groupSpecies(species, testFamilies);

  it('orders families as the page lists them, unknown ones last', () => {
    expect(groups.map(({ family }) => family.id)).toEqual([
      'mammalian',
      'reptilian',
      'holiday',
      'unclassified',
    ]);
  });

  it('starts each row with its lineages that have variants', () => {
    const reptilian = groups[1];
    expect(reptilian.lineages.map(({ root }) => root)).toEqual([
      'lizard',
      'kobold',
      'unathi',
    ]);
  });

  it('leads with the lineage that holds humans', () => {
    const mammalian = groups[0];
    expect(mammalian.lineages.map(({ root }) => root)).toEqual([
      'human',
      'dwarf',
    ]);
    expect(mammalian.lineages[0].members.map(({ id }) => id)).toEqual([
      'human',
      'felinid',
    ]);
    expect(mammalian.size).toBe(3);
  });

  it('leaves a variant filed under another family on its own', () => {
    const holiday = groups.find(({ family }) => family.id === 'holiday');
    expect(holiday?.lineages).toEqual([
      { root: 'vampire', members: [{ id: 'vampire', depth: 0, parent: null }] },
    ]);
  });

  it('lists every species once, even through a variant_of cycle', () => {
    const cyclic: SpeciesMap = {
      a: testSpecies({ name: 'A', family: 'avian', variant_of: 'b' }),
      b: testSpecies({ name: 'B', family: 'avian', variant_of: 'a' }),
    };
    expect(flattenGroups(groupSpecies(cyclic, testFamilies)).sort()).toEqual([
      'a',
      'b',
    ]);
  });
});

describe('getLineage', () => {
  it('finds the whole lineage from any member', () => {
    const groups = groupSpecies(species, testFamilies);
    expect(getLineage(groups, 'ashwalker')?.root).toBe('lizard');
    expect(getLineage(groups, 'lizard')?.members).toHaveLength(2);
  });
});
