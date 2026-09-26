import { useEffect } from 'react';
import { useBackend } from 'tgui/backend';
import { Box, NoticeBox } from 'tgui-core/components';
import { CyborgCharacterEditor } from '../../common/CyborgCustomization/CharacterEditor';
import { features } from '../preferences/features';
import { FeatureValueInput } from '../preferences/features/base';
import type { PreferencesMenuData } from '../types';
import { cyborgPreferenceValues } from './cyborgValues';

export function CyborgCharacterPage() {
  const { data, act } = useBackend<PreferencesMenuData>();
  useEffect(() => {
    act('cyborg_page', { active: true });
    return () => act('cyborg_page', { active: false });
  }, [act]);
  const state = data.cyborg_customization;
  const resources = data.cyborg_resources;
  const customization = state && {
    ...resources,
    ...state,
    models: resources?.models ?? [],
    body: resources?.body ?? null,
    body_width: resources?.body_width ?? 32,
    body_height: resources?.body_height ?? 32,
    layers: state.layers?.map((layer) => ({
      ...layer,
      icon: resources?.layer_icons?.[layer.slot || ''] || '',
    })),
  };
  if (!customization)
    return <NoticeBox>Loading cyborg customization…</NoticeBox>;
  if (customization.unsupported)
    return <NoticeBox>{customization.message}</NoticeBox>;
  const values = cyborgPreferenceValues(data.character_preferences);
  return (
    <CyborgCharacterEditor
      key={data.active_slot}
      data={customization}
      name={data.character_preferences.names.cyborg_name || ''}
      values={values}
      onName={(value) =>
        act('set_preference', { preference: 'cyborg_name', value })
      }
      onPreview={(params) =>
        act('cyborg_preview', { ...params, context: customization.context })
      }
      onLayout={(params) =>
        act('cyborg_layout', {
          ...params,
          character_slot: data.active_slot,
          context: customization.context,
        })
      }
      renderPreference={(key) =>
        values[key] !== undefined && features[key] ? (
          <>
            {!['silicon_gender', 'cyborg_size'].includes(key) &&
              !key.endsWith('_sprite') && (
                <Box color="label" mb={0.5}>
                  {features[key].name}
                </Box>
              )}
            <FeatureValueInput
              key={key}
              feature={features[key]}
              featureId={key}
              value={values[key]}
            />
          </>
        ) : (
          <Box color="label">Unavailable for this character.</Box>
        )
      }
    />
  );
}
