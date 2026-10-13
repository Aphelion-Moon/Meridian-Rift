// THIS IS AN APHELION UI FILE
import { type ComponentType, useState } from 'react';
import { Button, Floating, LabeledList } from 'tgui-core/components';

import { type Feature, FeatureValueInput } from '../preferences/features/base';
import {
  fitness_arms,
  fitness_legs,
  fitness_match_strength,
  fitness_torso,
} from '../preferences/features/character_preferences/aphelion/fitness';
import type { DropdownInputProps } from '../preferences/features/dropdowns';
import type { CharacterPreferencesData } from '../types';

// In the order they show. The server sends the levels only while the build doesn't follow the strength stat.
const PHYSIQUE_FEATURES = [
  ['fitness_match_strength', fitness_match_strength],
  ['fitness_arms', fitness_arms],
  ['fitness_legs', fitness_legs],
  ['fitness_torso', fitness_torso],
] as [string, Feature<unknown>][];

type PhysiqueAdvancedProps = {
  character_preferences: CharacterPreferencesData;
};

/**
 * The body type input with the Physique (Advanced) button under it.
 */
export function withPhysiqueAdvanced(Input: ComponentType<DropdownInputProps>) {
  return (props: DropdownInputProps) => (
    <>
      <Input {...props} />
      <PhysiqueAdvanced character_preferences={props.character_preferences} />
    </>
  );
}

/**
 * The Physique (Advanced) button and the menu it opens: whether the build follows the strength stat and, while it
 * doesn't, the build of the arms, legs and torso. Nothing for a species whose limbs have no builds.
 */
function PhysiqueAdvanced(props: PhysiqueAdvancedProps) {
  const [open, setOpen] = useState(false);
  const values = props.character_preferences.manually_rendered_features ?? {};
  const shown = PHYSIQUE_FEATURES.filter(([featureId]) => featureId in values);

  if (!shown.length) {
    return null;
  }

  return (
    <Floating
      stopChildPropagation
      placement="bottom-start"
      contentClasses="PhysiqueAdvanced__menu"
      onOpenChange={setOpen}
      content={
        <LabeledList>
          {shown.map(([featureId, feature]) => (
            <LabeledList.Item
              key={featureId}
              label={feature.name}
              tooltip={feature.description}
            >
              <FeatureValueInput
                feature={feature}
                featureId={featureId}
                value={values[featureId]}
              />
            </LabeledList.Item>
          ))}
        </LabeledList>
      }
    >
      <div className="PhysiqueAdvanced__trigger">
        <Button fluid selected={open}>
          Physique (Advanced)
        </Button>
      </div>
    </Floating>
  );
}
