// THIS IS AN APHELION UI FILE
import {
  CheckboxInput,
  type Feature,
  type FeatureChoicedServerData,
  FeatureColorInput,
  type FeatureToggle,
  type FeatureValueProps,
} from '../../base';
import { FeatureDropdownInput } from '../../dropdowns';

export const feature_pits: Feature<string> = {
  name: 'Armpit hair',
  component: (
    props: FeatureValueProps<string, string, FeatureChoicedServerData>,
  ) => {
    return <FeatureDropdownInput buttons {...props} />;
  },
};

export const feature_pubes: Feature<string> = {
  name: 'Pubic hair',
  component: (
    props: FeatureValueProps<string, string, FeatureChoicedServerData>,
  ) => {
    return <FeatureDropdownInput buttons {...props} />;
  },
};

export const body_hair_matches_hair: FeatureToggle = {
  name: 'Body hair matches hair color',
  description:
    'Armpit and pubic hair take your hair color, and follow it when it changes. Turn this off to pick their own.',
  component: CheckboxInput,
};

export const body_hair_color: Feature<string> = {
  name: 'Body hair color',
  component: FeatureColorInput,
};
