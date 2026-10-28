// THIS IS AN APHELION UI FILE
import { Box, Stack } from 'tgui-core/components';

import {
  FeatureNumberInput,
  type FeatureNumericData,
  FeatureValueInput,
  type FeatureValueProps,
} from '../preferences/features/base';
import { see_self_normal_size } from '../preferences/features/character_preferences/aphelion/self_normal_size';

export function BodySizeInput(
  props: FeatureValueProps<number, number, FeatureNumericData>,
) {
  const normalSize =
    props.character_preferences.manually_rendered_features
      ?.see_self_normal_size;

  return (
    <Stack vertical>
      <Stack.Item>
        <FeatureNumberInput {...props} />
      </Stack.Item>
      {normalSize !== undefined && (
        <Stack.Item mt={0.5}>
          <FeatureValueInput
            feature={see_self_normal_size}
            featureId="see_self_normal_size"
            value={normalSize}
          />
          <Box color="label" fontSize="0.9em" mt={0.5}>
            {see_self_normal_size.description}
          </Box>
        </Stack.Item>
      )}
    </Stack>
  );
}
