// THIS IS AN APHELION UI FILE
import type { Species, SpeciesFamily } from '../../types';

/** A species entry for tests; only what a test names differs from the default. */
export function testSpecies(overrides: Partial<Species> = {}): Species {
  return {
    name: 'Test',
    desc: null,
    lore: null,
    icon: 'test',
    family: null,
    variant_of: null,
    off_station: false,
    holiday: null,
    holiday_active: false,
    use_skintones: false,
    sexes: true,
    enabled_features: [],
    nova_stars_only: false,
    perks: { positive: [], negative: [], neutral: [] },
    ...overrides,
  };
}

/** Families as /datum/species_family sends them, in page order. */
export const testFamilies: SpeciesFamily[] = [
  { id: 'mammalian', name: 'Mammalian', icon: 'fa-paw' },
  { id: 'reptilian', name: 'Reptilian', icon: 'fa-dragon' },
  { id: 'avian', name: 'Avian', icon: 'fa-feather-pointed' },
  { id: 'aquatic', name: 'Aquatic', icon: 'fa-fish' },
  { id: 'insectoid', name: 'Insectoid', icon: 'fa-bug' },
  { id: 'synthetic', name: 'Synthetic', icon: 'fa-robot' },
  { id: 'elemental', name: 'Elemental', icon: 'fa-gem' },
  { id: 'xenobiological', name: 'Exotic', icon: 'tg-zaphelion-alien' },
  { id: 'paranormal', name: 'Paranormal', icon: 'fa-ghost' },
  { id: 'holiday', name: 'Holiday', icon: 'fa-gift' },
  { id: 'generic', name: 'Generic', icon: 'fa-pen-ruler' },
];
