// THIS IS AN APHELION UI FILE
import { type ComponentType, Fragment } from 'react';
import { Tooltip } from 'tgui-core/components';

import { type Feature, FeatureValueInput } from '../preferences/features/base';
import {
  muscle_definition,
  muscle_size,
  muscles_automatic,
} from '../preferences/features/character_preferences/aphelion/fitness';
import type { DropdownInputProps } from '../preferences/features/dropdowns';
import type { CharacterPreferencesData } from '../types';

// In the order they show. The server sends them only for a species whose limbs come in muscle sizes.
const MUSCLE_FEATURES = [
  ['muscles_automatic', muscles_automatic],
  ['muscle_definition', muscle_definition],
  ['muscle_size', muscle_size],
] as [string, Feature<unknown>][];

/**
 * The body type input with the muscle inputs under it.
 */
export function withMuscles(Input: ComponentType<DropdownInputProps>) {
  return (props: DropdownInputProps) => (
    <>
      <Input {...props} />
      <Muscles character_preferences={props.character_preferences} />
    </>
  );
}

type MusclesProps = {
  character_preferences: CharacterPreferencesData;
};

/**
 * Whether the character's muscles follow their stats and, while they don't, a slider each for their definition and size.
 */
function Muscles(props: MusclesProps) {
  const values = props.character_preferences.manually_rendered_features ?? {};
  const shown = MUSCLE_FEATURES.filter(([featureId]) => featureId in values);

  if (!shown.length) {
    return null;
  }

  return (
    <div className="Muscles">
      {shown.map(([featureId, feature]) => (
        <Fragment key={featureId}>
          {feature.description ? (
            <Tooltip content={feature.description} position="bottom-start">
              <span className="Muscles__label Muscles__label--hint">
                {feature.name}
              </span>
            </Tooltip>
          ) : (
            <span className="Muscles__label">{feature.name}</span>
          )}
          <div className="Muscles__input">
            <FeatureValueInput
              feature={feature}
              featureId={featureId}
              value={values[featureId]}
            />
          </div>
        </Fragment>
      ))}
    </div>
  );
}
