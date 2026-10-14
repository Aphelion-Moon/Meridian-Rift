// THIS IS AN APHELION UI FILE
import { CheckboxInput, type FeatureToggle } from '../../base';

export const see_self_normal_size: FeatureToggle = {
  name: 'See yourself at normal size',
  category: 'GAMEPLAY',
  description:
    'When your body is larger than normal, you see it at normal size, so you can click what it covers on the tiles around you. Everyone else still sees your true size.',
  component: CheckboxInput,
};
