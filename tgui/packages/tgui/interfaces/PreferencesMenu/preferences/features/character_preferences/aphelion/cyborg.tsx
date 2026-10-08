import {
  CheckboxInput,
  type Feature,
  type FeatureChoiced,
  FeatureLongTextInput,
  type FeatureNumericChoiced,
  FeatureShortTextInput,
  type FeatureToggle,
} from '../../base';
import {
  FeatureDropdownInput,
  FeatureNumericDropdownInput,
} from '../../dropdowns';

export const cyborg_size: FeatureNumericChoiced = {
  name: 'Cyborg visual size',
  component: FeatureNumericDropdownInput,
};
export const silicon_penis_sprite: FeatureChoiced = {
  name: 'Penis sprite',
  component: FeatureDropdownInput,
};
export const silicon_sheath_sprite: FeatureChoiced = {
  name: 'Sheath sprite',
  component: FeatureDropdownInput,
};
export const silicon_testicles_sprite: FeatureChoiced = {
  name: 'Testicles sprite',
  component: FeatureDropdownInput,
};
export const silicon_vagina_sprite: FeatureChoiced = {
  name: 'Vagina sprite',
  component: FeatureDropdownInput,
};
export const silicon_anus_sprite: FeatureChoiced = {
  name: 'Anus sprite',
  component: FeatureDropdownInput,
};
export const silicon_breasts_sprite: FeatureChoiced = {
  name: 'Breasts sprite',
  component: FeatureDropdownInput,
};
export const see_cyborg_genitalia: FeatureToggle = {
  name: 'Show cyborg anatomy',
  category: 'Content',
  component: CheckboxInput,
};
export const custom_species_silicon: Feature<string> = {
  name: 'Custom silicon model',
  component: FeatureShortTextInput,
};
export const custom_species_lore_silicon: Feature<string> = {
  name: 'Silicon model lore',
  component: FeatureLongTextInput,
};
export const ooc_notes_silicon: Feature<string> = {
  name: 'SFW OOC Notes',
  placeholder: 'Leave blank to use your human SFW OOC notes.',
  component: FeatureLongTextInput,
};
export const ooc_notes_silicon_nsfw: Feature<string> = {
  name: 'NSFW OOC Notes',
  placeholder: 'Leave blank to use your human NSFW OOC notes.',
  component: FeatureLongTextInput,
};
export const silicon_headshot_nsfw: Feature<string> = {
  name: 'Silicon headshot (NSFW)',
  component: FeatureShortTextInput,
};
