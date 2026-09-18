// THIS IS AN APHELION UI FILE
import { CheckboxInput, type FeatureToggle } from '../../base';

export const department_ooc_anon: FeatureToggle = {
  name: 'Anonymous department OOC',
  category: 'CHAT',
  description:
    'Toggles whether you are given a codename on the department OOC channels instead of showing your ckey. Admins can always see who is speaking.',
  component: CheckboxInput,
};
