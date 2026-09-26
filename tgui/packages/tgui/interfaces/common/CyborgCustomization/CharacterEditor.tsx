import { type ReactNode, useState } from 'react';
import {
  Box,
  Button,
  Dropdown,
  Input,
  NoticeBox,
  Section,
  Tabs,
} from 'tgui-core/components';
import { CyborgPreview } from './CyborgPreview';
import { editorLabel, LayoutControls } from './LayoutControls';
import { ModelPicker } from './ModelPicker';
import { PortraitPreview } from './PortraitPreview';
import { PresetControls } from './PresetControls';
import type { PlacementTarget } from './posePlacement';
import {
  CYBORG_DIRECTIONS,
  CYBORG_SLOTS,
  type CyborgCustomizationData,
  type CyborgSlot,
  type LayoutAction,
} from './types';

export function CyborgCharacterEditor(props: {
  data: CyborgCustomizationData;
  name: string;
  values: Record<string, unknown>;
  renderPreference: (key: string) => ReactNode;
  onName: (name: string) => void;
  onPreview: LayoutAction;
  onLayout: LayoutAction;
}) {
  const { data, name, values, renderPreference, onName, onPreview, onLayout } =
    props;
  const [placementTarget, setPlacementTarget] =
    useState<PlacementTarget>('pose');
  const [tab, setTab] = useState('Appearance');
  const [slot, setSlot] = useState<CyborgSlot>('penis');
  const selectSlot = (next: CyborgSlot) => {
    if (next === slot) return;
    setSlot(next);
    onPreview({ selected_part: next });
  };
  const readonly = data.layout_source === 'model_default';
  const identity = (
    <Section title="Identity">
      <div className="CyborgEditor__row CyborgEditor__nameRow">
        <div>
          <Box color="label" mb={0.5}>
            Name
          </Box>
          <Input fluid value={name} onBlur={onName} />
        </div>
        <div>
          <Box color="label" mb={0.5}>
            Chassis
          </Box>
          <ModelPicker data={data} onPreview={onPreview} />
        </div>
      </div>
      <div className="CyborgEditor__row">
        <div>
          <Box color="label" mb={0.5}>
            Pronouns
          </Box>
          {renderPreference('silicon_gender')}
        </div>
        <div>
          <Box color="label" mb={0.5}>
            Body size
          </Box>
          {renderPreference('cyborg_size')}
        </div>
      </div>
      {Number(values.cyborg_size) !== data.body_scale && (
        <Box mt={0.5} color="label">
          This chassis uses {Math.round(data.body_scale * 100)}% size.
        </Box>
      )}
      {tab === 'Appearance' && (
        <>
          <div className="CyborgEditor__row">
            <div>
              <Box color="label" mb={0.5}>
                Pose
              </Box>
              <Dropdown
                width="100%"
                selected={data.pose}
                displayText={editorLabel(data.pose)}
                options={data.poses.map((value) => ({
                  value,
                  displayText: editorLabel(value),
                }))}
                onSelected={(pose) => onPreview({ pose })}
              />
            </div>
            <div>
              <Box color="label" mb={0.5}>
                Arousal
              </Box>
              <Dropdown
                width="100%"
                selected={data.arousal}
                displayText={editorLabel(data.arousal)}
                options={['none', 'partial', 'full'].map((value) => ({
                  value,
                  displayText: editorLabel(value),
                }))}
                onSelected={(arousal) => onPreview({ arousal })}
              />
            </div>
          </div>
          <div className="CyborgEditor__row CyborgEditor__divider CyborgEditor__layoutSource">
            <Button
              tooltip="Edit the current active layout."
              selected={!readonly}
              onClick={() => onPreview({ layout_source: 'active' })}
            >
              Working setup
            </Button>
            <Button
              tooltip="View the saved default layout for this model."
              selected={readonly}
              disabled={!data.model_default_available}
              onClick={() => onPreview({ layout_source: 'model_default' })}
            >
              Spawn preview
            </Button>
          </div>
          {readonly && (
            <Button.Confirm
              fluid
              onClick={() => onLayout({ operation: 'load_default' })}
            >
              Load default into active layout
            </Button.Confirm>
          )}
          <PresetControls
            store={data.store}
            models={data.models}
            model={data.model}
            onAction={onLayout}
            embedded
            disabled={readonly || !data.allowed}
          />
        </>
      )}
    </Section>
  );
  const status = (
    <div className="CyborgEditor__status" role="status">
      {tab === 'Profile'
        ? 'Editing character profile · Changes save automatically'
        : readonly
          ? 'Viewing saved model default · Placement editing disabled'
          : 'Editing working setup · Draft saves automatically; update presets explicitly'}
      {data.save_status && (
        <Box mt={0.5}>
          {data.save_status.error ||
            (data.save_status.pending
              ? 'Unsaved changes…'
              : data.save_status.session_only
                ? 'Session only — not saved to disk.'
                : 'Saved.')}
          {data.save_status.error && (
            <Button
              ml={1}
              onClick={() => onLayout({ operation: 'retry_save' })}
            >
              Retry save
            </Button>
          )}
        </Box>
      )}
      {tab === 'Appearance' && data.message && !data.save_status?.error && (
        <Box mt={0.5}>{data.message}</Box>
      )}
    </div>
  );
  return (
    <div className="CyborgEditor">
      <Tabs>
        {['Appearance', 'Profile'].map((label) => (
          <Tabs.Tab
            key={label}
            selected={tab === label}
            onClick={() => setTab(label)}
          >
            {label}
          </Tabs.Tab>
        ))}
      </Tabs>
      {tab === 'Appearance' ? (
        <div className="CyborgEditor__workspace">
          <div className="CyborgEditor__sidebar">
            {identity}
            {status}
          </div>
          <div className="CyborgEditor__center">
            <CyborgPreview
              key={`${data.model}-${readonly}`}
              data={data}
              slot={slot}
              placementTarget={placementTarget}
              onSelectSlot={selectSlot}
              onPreview={onPreview}
              onLayout={onLayout}
            />
          </div>
          <div className="CyborgEditor__inspector">
            {!data.allowed && (
              <NoticeBox>
                Enable genital content in character preferences to edit anatomy
                placement.
              </NoticeBox>
            )}
            <Section title="Parts">
              <div className="CyborgEditor__parts">
                {CYBORG_SLOTS.map((part) => (
                  <Button
                    key={part}
                    selected={slot === part}
                    tooltip={String(values[`silicon_${part}_sprite`] ?? 'None')}
                    onClick={() => selectSlot(part)}
                  >
                    {editorLabel(part)}
                  </Button>
                ))}
              </div>
            </Section>
            <LayoutControls
              key={`${readonly}-${slot}`}
              slot={slot}
              placementTarget={placementTarget}
              onPlacementTarget={setPlacementTarget}
              wide={!!data.wide}
              part={data.parts?.[slot]}
              store={
                readonly && data.store.model_defaults[data.model]
                  ? {
                      ...data.store,
                      active: data.store.model_defaults[data.model],
                    }
                  : data.store
              }
              model={data.model}
              disabled={readonly || !data.allowed}
              hidePresets
              spriteControl={
                <>
                  <Box color="label" mb={0.5}>
                    Sprite
                  </Box>
                  {readonly ? (
                    <Box>
                      {String(
                        data.store.model_defaults[data.model]?.[slot].sprite ??
                          values[`silicon_${slot}_sprite`] ??
                          'None',
                      )}
                    </Box>
                  ) : (
                    renderPreference(`silicon_${slot}_sprite`)
                  )}
                </>
              }
              preview={{
                direction:
                  Object.keys(CYBORG_DIRECTIONS).find(
                    (key) => CYBORG_DIRECTIONS[key] === data.direction,
                  ) || 'south',
                pose: data.pose,
                poses: data.poses,
                arousal: data.arousal,
                onChange: (change) =>
                  onPreview({
                    ...change,
                    direction: change.direction
                      ? CYBORG_DIRECTIONS[change.direction]
                      : undefined,
                  }),
              }}
              onAction={onLayout}
            />
          </div>
        </div>
      ) : (
        <div className="CyborgEditor__profile">
          <div className="CyborgEditor__sidebar">
            {identity}
            <Section title="Model identity">
              {renderPreference('custom_species_silicon')}
            </Section>
            {[
              ['SFW headshot', 'silicon_headshot'],
              ['NSFW headshot', 'silicon_headshot_nsfw'],
            ].map(([label, key]) => (
              <Section
                key={key}
                title={
                  <span title="Direct HTTPS images (.png, .jpg, .jpeg) from Gyazo (i.gyazo.com), Lensdump (*.l3n.co), Imgbox (images2.imgbox.com or thumbs2.imgbox.com), or BYOND (files.byondhome.com).">
                    {label}
                  </span>
                }
              >
                <PortraitPreview value={values[key]} label={label} />
                {renderPreference(key)}
              </Section>
            ))}
            {status}
          </div>
          <div className="CyborgEditor__inspector">
            {[
              ['SFW Flavor Text', ['silicon_flavor_text']],
              ['NSFW Flavor Text', ['silicon_flavor_text_nsfw']],
              [
                'Background and OOC',
                [
                  'custom_species_lore_silicon',
                  'ooc_notes_silicon',
                  'ooc_notes_silicon_nsfw',
                ],
              ],
            ].map(([title, keys]: [string, string[]]) => (
              <Section key={title} title={title}>
                <div className="CyborgEditor__profileFields">
                  {keys.map((key) => (
                    <div key={key} className="CyborgEditor__profileField">
                      {renderPreference(key)}
                    </div>
                  ))}
                </div>
              </Section>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
