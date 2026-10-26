// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';

import { Food } from '../../types';
import { searchSpecies } from './search';
import { familyLookup, type SpeciesMap } from './taxonomy';
import { testFamilies, testSpecies } from './testSpecies';

const perk = (name: string) => ({ ui_icon: 'star', name, description: '' });

const species: SpeciesMap = {
  moth: testSpecies({ name: 'Mothperson', family: 'insectoid' }),
  fly: testSpecies({ name: 'Flyperson', family: 'insectoid' }),
  cold: testSpecies({
    name: 'Coldling',
    family: 'elemental',
    perks: { positive: [perk('Snowbound')], neutral: [], negative: [] },
  }),
  baker: testSpecies({
    name: 'Baker',
    family: 'mammalian',
    diet: { liked_food: [Food.Grain], disliked_food: [], toxic_food: [] },
  }),
  sage: testSpecies({
    name: 'Sage',
    family: 'mammalian',
    lore: ['They remember the first moths.'],
  }),
};
const order = Object.keys(species);
const getFamily = familyLookup(testFamilies);
const search = (query: string) =>
  searchSpecies(species, order, query, getFamily);

describe('searchSpecies', () => {
  it('ranks names ahead of families, traits, foods and lore', () => {
    expect(search('moth')).toEqual(['moth', 'sage']);
    expect(search('insect')).toEqual(['moth', 'fly']);
  });

  it('finds species by trait and by liked food', () => {
    expect(search('snow')).toEqual(['cold']);
    expect(search('grain')).toEqual(['baker']);
  });

  it('finds the templates as template, custom or generic', () => {
    const withTemplate: SpeciesMap = {
      ...species,
      anthro: testSpecies({
        name: 'Anthromorph',
        family: 'mammalian',
        template: true,
      }),
    };
    const find = (query: string) =>
      searchSpecies(withTemplate, [...order, 'anthro'], query, getFamily);
    expect(find('template')).toEqual(['anthro']);
    expect(find('custom')).toEqual(['anthro']);
    expect(find('generic')).toEqual(['anthro']);
  });

  it('leaves prose alone until the query says something', () => {
    expect(search('rem')).toEqual([]);
    expect(search('remember')).toEqual(['sage']);
  });
});
