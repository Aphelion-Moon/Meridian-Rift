// THIS IS AN APHELION UI FILE
import { CheckboxInput, type FeatureToggle } from '../../base';

export const verb_search: FeatureToggle = {
  name: 'Verb search bar',
  category: 'UI',
  description: 'Shows a search bar in the stat panel to search all verbs.',
  component: CheckboxInput,
};

export const verb_favourites: FeatureToggle = {
  name: 'Verb favourites',
  category: 'UI',
  description:
    'Shows the Favourites tab and stars beside verbs in the stat panel. Hiding them keeps your saved favourites.',
  component: CheckboxInput,
};
