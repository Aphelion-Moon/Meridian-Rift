// THIS IS AN APHELION UI FILE
import { useCallback, useMemo } from 'react';
import { Box, NoticeBox } from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import { CyborgCharacterEditor } from './common/CyborgCustomization/CharacterEditor';
import { useCyborgGallery } from './common/CyborgCustomization/gallery';
import {
  PROFILE_FIELDS,
  ProfileField,
} from './common/CyborgCustomization/ProfileFields';
import type { CyborgEditorData } from './common/CyborgCustomization/types';

/** The cyborg editor's own window, opened beside the borg's name in character setup. */
export function CyborgEditor() {
  return (
    <Window width={1180} height={840}>
      <Window.Content>
        <CyborgEditorContent />
      </Window.Content>
    </Window>
  );
}

export function CyborgEditorContent() {
  const { data, act } = useBackend<CyborgEditorData>();
  const state = data.cyborg_customization;
  const resources = data.cyborg_resources;
  const gallery = useCyborgGallery(
    state?.allowed ? resources?.gallery : undefined,
  );
  const customization = useMemo(
    () =>
      state && {
        ...resources,
        ...state,
        models: gallery.models,
        gallery_loading: gallery.loading,
        gallery_error: gallery.error,
        body: resources?.body ?? null,
        body_width: resources?.body_width ?? 32,
        body_height: resources?.body_height ?? 32,
        layers: state.layers?.map((layer) => ({
          ...layer,
          icon: resources?.layer_icons?.[layer.slot || ''] || '',
        })),
        rendered_preview: state.rendered_preview && {
          ...state.rendered_preview,
          layers: state.rendered_preview.layers?.map((layer) => ({
            ...layer,
            icon: resources?.layer_icons?.[layer.slot || ''] || '',
          })),
        },
      },
    [state, resources, gallery.models, gallery.loading, gallery.error],
  );
  const values = data.values ?? {};
  const onPreview = useCallback(
    (params) => act('cyborg_preview', { ...params, context: state?.context }),
    [act, state?.context],
  );
  const onLayout = useCallback(
    (params) =>
      act('cyborg_layout', {
        ...params,
        character_slot: data.active_slot,
        context: state?.context,
      }),
    [act, data.active_slot, state?.context],
  );
  if (!customization)
    return <NoticeBox>Loading cyborg customization…</NoticeBox>;
  if (customization.unsupported)
    return <NoticeBox>{customization.message}</NoticeBox>;
  return (
    <CyborgCharacterEditor
      key={data.active_slot}
      data={customization}
      name={data.name || ''}
      values={values}
      onName={(value) =>
        act('set_preference', { preference: 'cyborg_name', value })
      }
      onPreview={onPreview}
      onLayout={onLayout}
      onGalleryRetry={gallery.retry}
      renderPreference={(key) => {
        const field = PROFILE_FIELDS[key];
        if (values[key] === undefined || !field)
          return <Box color="label">Unavailable for this character.</Box>;
        return (
          <>
            {field.kind !== 'choice' && (
              <Box color="label" mb={0.5}>
                {field.name}
              </Box>
            )}
            <ProfileField
              key={key}
              featureId={key}
              value={values[key]}
              serverData={data.preference_data?.[key]}
              slot={data.active_slot}
              label={
                key === 'silicon_gender'
                  ? 'Pronouns'
                  : key === 'cyborg_size'
                    ? 'Body size'
                    : field.name
              }
              onChange={(value) =>
                act('set_preference', { preference: key, value })
              }
            />
          </>
        );
      }}
    />
  );
}
