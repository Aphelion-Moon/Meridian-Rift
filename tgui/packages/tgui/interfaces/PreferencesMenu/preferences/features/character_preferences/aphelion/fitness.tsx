// THIS IS AN APHELION UI FILE
// Shown under the body type (CharacterPreferences/Muscles.tsx), not in the preference lists.
import { Slider } from 'tgui-core/components';

import {
  CheckboxInput,
  type Feature,
  type FeatureNumericData,
  type FeatureToggle,
  type FeatureValueProps,
} from '../../base';

/** A muscle slider's range, and each step's name from 0 up. */
type MuscleStepData = FeatureNumericData & {
  step_names: string[];
};

type MuscleFeature = Feature<number, number, MuscleStepData>;

export const muscles_automatic: FeatureToggle = {
  name: 'Muscles - automatic',
  description:
    'Your dexterity determines your muscle definition, and your strength your muscle size. Those stats are still to come, so for now this keeps your muscles at Normal size with no definition. Untick it to set them yourself.',
  component: CheckboxInput,
};

export const muscle_definition: MuscleFeature = {
  name: 'Muscle definition',
  component: MuscleSlider,
};

export const muscle_size: MuscleFeature = {
  name: 'Muscle size',
  component: MuscleSlider,
};

/**
 * A muscle slider, showing its step's name. Locked while the character's muscles follow their stats, and showing what that
 * gives them: there are no stats yet, so the lowest step. The step picked comes back when the box is unticked.
 */
function MuscleSlider(
  props: FeatureValueProps<number, number, MuscleStepData>,
) {
  const { character_preferences, handleSetValue, serverData, value } = props;
  const automatic =
    !!character_preferences.manually_rendered_features?.muscles_automatic;
  const names = serverData?.step_names ?? [];
  const lowest = serverData?.minimum ?? 0;

  return (
    <Slider
      className="Muscles__slider"
      disabled={automatic || !serverData}
      minValue={lowest}
      maxValue={serverData?.maximum ?? 0}
      step={1}
      stepPixelSize={40}
      value={automatic ? lowest : value}
      format={(step) => names[step] ?? `${step}`}
      onChange={(_, step) => handleSetValue(step)}
    />
  );
}
