// Standalone visual fixture: actual editor components, isolated from player saves.
import { useState } from 'react';
import { createRoot } from 'react-dom/client';
import { Button, Dropdown, Input, TextArea } from 'tgui-core/components';
import { store as backendStore, gameDataAtom } from '../events/store';
import { CyborgCharacterEditor } from '../interfaces/common/CyborgCustomization/CharacterEditor';
import {
  placementBase,
  placementGroup,
} from '../interfaces/common/CyborgCustomization/placementGroups';
import { posePlacement } from '../interfaces/common/CyborgCustomization/posePlacement';
import {
  CYBORG_SLOTS,
  type CyborgCustomizationData,
  type LayoutStore,
} from '../interfaces/common/CyborgCustomization/types';
import { MainContent } from '../interfaces/InteractionPanel/MainContent';
import {
  ooc_notes_silicon,
  ooc_notes_silicon_nsfw,
} from '../interfaces/PreferencesMenu/preferences/features/character_preferences/aphelion/cyborg';

async function main() {
  const fixtures = await fetch('/fixtures.json').then((response) =>
    response.json(),
  );
  function Fixture() {
    const [size, setSize] = useState({ width: 1180, height: 810 });
    const [panel, setPanel] = useState('creator');
    const [name, setName] = useState('Service companion');
    const [values, setValues] = useState<Record<string, string | number>>({
      silicon_gender: 'They/Them',
      cyborg_size: 1.6,
      silicon_headshot: `data:image/png;base64,${fixtures.reference}`,
      silicon_headshot_nsfw: `data:image/png;base64,${fixtures.reference}`,
      ...Object.fromEntries(
        CYBORG_SLOTS.map((slot) => [`silicon_${slot}_sprite`, 'Plain']),
      ),
    });
    const [state, setState] = useState({
      model: '0',
      direction: 2,
      pose: 'idle',
      arousal: 'none',
      moving: false,
      layout_source: 'active',
    });
    const [store, setStore] = useState<LayoutStore>(() => {
      const active = Object.fromEntries(
        CYBORG_SLOTS.map((slot) => [
          slot,
          {
            pixel_x: 0,
            pixel_y: 0,
            rotation: 0,
            scale: 1,
            colors: ['#ffffff', '#ffffff', '#ffffff'],
            advanced: {},
          },
        ]),
      ) as LayoutStore['active'];
      const saved = structuredClone(active);
      saved.penis.pixel_y = 15;
      return {
        schema_version: 1,
        active,
        presets: { Example: saved },
        preset_models: { Example: '0' },
        model_presets: { '0': 'Example' },
        active_preset: 'Example',
        model_defaults: { '0': saved },
      };
    });
    const model = fixtures.models.find((model) => model.id === state.model);
    const layout =
      state.layout_source === 'model_default'
        ? store.model_defaults[state.model]
        : store.active;
    const entry = placementBase(
      layout.penis,
      placementGroup(model.width > 32, state.direction),
    );
    const correction = posePlacement(
      layout.penis,
      state.direction,
      state.pose,
      state.arousal,
    ).effective;
    const mirror =
      model.width > 32 && entry.mirror_sides !== false && state.direction === 8
        ? -1
        : 1;
    const spriteDirection =
      model.width > 32 && entry.reuse_south && state.direction === 1
        ? 2
        : state.direction;
    const data: CyborgCustomizationData = {
      ...state,
      layout_source: state.layout_source as 'active' | 'model_default',
      allowed: true,
      wide: model.width > 32,
      reference: fixtures.reference,
      body: model.images[[2, 1, 4, 8].indexOf(state.direction)],
      body_width: model.width,
      body_height: model.height,
      body_scale: Math.min(
        Number(values.cyborg_size),
        model.width > 32 ? 1.6 : 2.5,
      ),
      parts: Object.fromEntries(
        CYBORG_SLOTS.map((slot) => [
          slot,
          {
            sizes: [1, 2, 3, 4, 5].map((value) => ({
              value,
              label: String(value),
              icon: fixtures.accessory,
            })),
            color_channels:
              slot === 'sheath' ? [1] : slot === 'anus' ? [] : [1, 2, 3],
          },
        ]),
      ),
      models: fixtures.models.map((model) => ({
        ...model,
        thumbnail: model.images[0],
        thumbnail_directions: Object.fromEntries(
          [2, 1, 4, 8].map((direction, index) => [
            String(direction),
            model.images[index],
          ]),
        ),
      })),
      poses: ['idle', 'rest', 'sit'],
      store,
      model_default_available: !!store.model_defaults[state.model],
      layers: [
        {
          slot: 'penis',
          icon: fixtures.accessory_directions[
            [2, 1, 4, 8].indexOf(spriteDirection)
          ],
          x: entry.pixel_x * mirror + correction.pixel_x,
          y: entry.pixel_y + correction.pixel_y,
          scale: entry.scale * correction.scale,
          rotation: entry.rotation * mirror + correction.rotation,
          mirror_x: mirror,
          priority: correction.priority,
        },
      ],
    };
    const runtimeData = {
      parts: [
        {
          slot: 'penis',
          choice: 'Dogborg Knotted',
          active: 1,
          arousal: 'none',
          can_arouse: 1,
        },
        {
          slot: 'vagina',
          choice: 'Gaping',
          active: 1,
          arousal: 'none',
          can_arouse: 1,
        },
      ],
      character_slot: 1,
      allowed: 1,
      viewer_enabled: 0,
      body_visible: 1,
      model_name: 'Engineering / Drake',
      model_default: 1,
    };
    backendStore.set(
      gameDataAtom,
      panel === 'human'
        ? {
            erp_interaction: 0,
            genital_config: [
              {
                name: 'Penis',
                ref: 'fixture',
                visibility: 'Hidden by clothes',
                layering: 'Normal',
                custom: 0,
                arousal: 'Not aroused',
                can_arouse: 1,
              },
            ],
            genital_visibility_options: [
              'Never show',
              'Hidden by clothes',
              'Custom',
            ],
            genital_layering_options: [
              'Below underwear',
              'Normal',
              'Above underwear',
              'Above all clothing',
            ],
            genital_arousal_options: [
              'Not aroused',
              'Partly aroused',
              'Very aroused',
            ],
          }
        : { erp_interaction: 0, cyborg_runtime: runtimeData },
    );
    return (
      <>
        <div style={{ padding: 8 }}>
          <Button onClick={() => setPanel('creator')}>Creator</Button>
          <Button onClick={() => setPanel('runtime')}>Runtime panel</Button>
          <Button onClick={() => setPanel('human')}>Human panel</Button>
          Browser fixture · UI and framing only · No player saves
          <Button ml={1} onClick={() => setSize({ width: 1180, height: 810 })}>
            1200×940 window
          </Button>
          <Button onClick={() => setSize({ width: 900, height: 810 })}>
            920×940 window
          </Button>
          <Button onClick={() => setSize({ width: 740, height: 650 })}>
            Narrow
          </Button>
        </div>
        {panel !== 'creator' ? (
          <div style={{ width: 480, height: 560, padding: 8 }}>
            <MainContent key={panel} />
          </div>
        ) : (
          <div style={{ width: size.width, height: size.height, padding: 8 }}>
            <CyborgCharacterEditor
              data={data}
              name={name}
              values={values}
              onName={setName}
              onPreview={(params) =>
                setState((current) => ({
                  ...current,
                  ...params,
                  ...(params.model ? { layout_source: 'active' } : {}),
                }))
              }
              onLayout={(params) =>
                setStore((current) => {
                  const next = structuredClone(current);
                  const part = next.active[String(params.slot)];
                  let position = part;
                  if (part && params.placement_group) {
                    part.placement_groups ??= {};
                    part.placement_groups[String(params.placement_group)] ??= {
                      pixel_x: part.pixel_x,
                      pixel_y: part.pixel_y,
                      rotation: part.rotation,
                    };
                    position = part.placement_groups[
                      String(params.placement_group)
                    ] as typeof part;
                  }
                  if (params.operation === 'set')
                    (['pixel_x', 'pixel_y', 'rotation'].includes(
                      String(params.field),
                    )
                      ? position
                      : part)[String(params.field)] = params.value;
                  if (params.operation === 'place')
                    Object.assign(position, {
                      pixel_x: params.x,
                      pixel_y: params.y,
                    });
                  if (params.operation === 'reset_position')
                    Object.assign(next.active[String(params.slot)], {
                      pixel_x: 0,
                      pixel_y: 0,
                      rotation: 0,
                      scale: 1,
                    });
                  if (params.operation === 'reset_colors')
                    next.active[String(params.slot)].colors = [
                      '#ffffff',
                      '#ffffff',
                      '#ffffff',
                    ];
                  if (params.operation === 'reset_overrides')
                    next.active[String(params.slot)].advanced = {};
                  if (params.operation === 'load_default') {
                    next.active = structuredClone(
                      next.model_defaults[state.model],
                    );
                    setState({ ...state, layout_source: 'active' });
                  }
                  const presetName = String(params.name || '');
                  next.preset_models ??= {};
                  next.model_presets ??= {};
                  if (params.operation === 'save') {
                    next.presets[presetName] = structuredClone(next.active);
                    next.preset_models[presetName] = state.model;
                  }
                  if (params.operation === 'load') {
                    next.active = structuredClone(next.presets[presetName]);
                    next.active_preset = presetName;
                    setState({
                      ...state,
                      model: next.preset_models[presetName] || state.model,
                      layout_source: 'active',
                    });
                  }
                  if (params.operation === 'assign_default') {
                    next.model_presets[state.model] = presetName;
                    next.model_defaults[state.model] = structuredClone(
                      next.presets[presetName],
                    );
                  }
                  if (params.operation === 'delete_default') {
                    delete next.model_presets[state.model];
                    delete next.model_defaults[state.model];
                  }
                  return next;
                })
              }
              renderPreference={(key) => {
                const notesFeature =
                  key === 'ooc_notes_silicon'
                    ? ooc_notes_silicon
                    : key === 'ooc_notes_silicon_nsfw'
                      ? ooc_notes_silicon_nsfw
                      : undefined;
                const value = values[key] ?? '';
                const change = (value: string | number) =>
                  setValues((current) => ({ ...current, [key]: value }));
                if (
                  key === 'silicon_gender' ||
                  key === 'cyborg_size' ||
                  key.endsWith('_sprite')
                )
                  return (
                    <Dropdown
                      width="100%"
                      selected={String(value)}
                      options={
                        key === 'silicon_gender'
                          ? [
                              'Use character gender',
                              'He/Him',
                              'She/Her',
                              'They/Them',
                              'It/Its',
                            ]
                          : key === 'cyborg_size'
                            ? ['0.75', '1', '1.6', '2', '2.5']
                            : ['None', 'Plain', 'Alternative']
                      }
                      onSelected={change}
                    />
                  );
                return (
                  <>
                    <div style={{ marginBottom: 6 }}>
                      {notesFeature?.name ?? key.replaceAll('_', ' ')}
                    </div>
                    {key.includes('headshot') ||
                    key === 'custom_species_silicon' ? (
                      <Input fluid value={String(value)} onBlur={change} />
                    ) : (
                      <TextArea
                        fluid
                        height="100px"
                        placeholder={notesFeature?.placeholder}
                        value={String(value)}
                        onChange={change}
                      />
                    )}
                  </>
                );
              }}
            />
          </div>
        )}
      </>
    );
  }
  createRoot(document.getElementById('tgui-root')!).render(<Fixture />);
}
main();
