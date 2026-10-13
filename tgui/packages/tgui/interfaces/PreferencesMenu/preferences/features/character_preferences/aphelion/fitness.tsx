// THIS IS AN APHELION UI FILE
// Shown in the Physique (Advanced) menu beside the body type, not in the preference lists.
import {
  CheckboxInput,
  type FeatureChoiced,
  type FeatureToggle,
} from '../../base';
import { FeatureDropdownInput } from '../../dropdowns';

export const fitness_match_strength: FeatureToggle = {
  name: 'Match strength stat',
  description:
    'Your build follows your strength stat. There is no strength stat yet, so while this is on your limbs keep their baseline build. Turn it off to pick the build of your arms, legs and torso.',
  component: CheckboxInput,
};

export const fitness_arms: FeatureChoiced = {
  name: 'Arms',
  component: FeatureDropdownInput,
};

export const fitness_legs: FeatureChoiced = {
  name: 'Legs',
  component: FeatureDropdownInput,
};

export const fitness_torso: FeatureChoiced = {
  name: 'Torso',
  component: FeatureDropdownInput,
};
