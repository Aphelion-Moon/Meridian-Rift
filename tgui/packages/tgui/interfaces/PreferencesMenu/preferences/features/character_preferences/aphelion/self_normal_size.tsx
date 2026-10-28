// THIS IS AN APHELION UI FILE
import { Button } from 'tgui-core/components';

import type { FeatureToggle } from '../../base';

const name = 'See yourself at normal size';

export const see_self_normal_size: FeatureToggle = {
  name,
  description:
    'Only changes your own view. Other players still see your full size. Applies to all your characters.',
  component: ({ value, handleSetValue }) => (
    <Button.Checkbox checked={!!value} onClick={() => handleSetValue(!value)}>
      {name}
    </Button.Checkbox>
  ),
};
