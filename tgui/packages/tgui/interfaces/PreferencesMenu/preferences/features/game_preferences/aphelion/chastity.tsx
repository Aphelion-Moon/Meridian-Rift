// THIS IS AN APHELION UI FILE
import { CheckboxInput, type FeatureToggle } from '../../base';

export const chastity_pref: FeatureToggle = {
  name: 'Chastity devices',
  category: 'ERP',
  description:
    'Chastity devices can be fitted on you, locking your genitals away until they come off.',
  component: CheckboxInput,
};

export const chastity_key_only_pref: FeatureToggle = {
  name: 'Chastity: key only',
  category: 'ERP',
  description:
    "A chastity device locked on you opens only with its key: its lock can't be picked.",
  component: CheckboxInput,
};
