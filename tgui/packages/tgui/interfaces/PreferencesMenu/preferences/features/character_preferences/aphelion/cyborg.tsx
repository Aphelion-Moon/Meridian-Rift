// THIS IS AN APHELION UI FILE
import { CheckboxInput, type FeatureToggle } from '../../base';

// The cyborg-only character preferences are set in the cyborg editor's own window (common/CyborgCustomization/ProfileFields)
export const see_cyborg_genitalia: FeatureToggle = {
  name: 'Show cyborg anatomy',
  category: 'Content',
  component: CheckboxInput,
};
