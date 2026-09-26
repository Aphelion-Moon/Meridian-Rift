import { type ReactNode, useState } from 'react';
import { Box, Button, Dropdown, Section, Tabs } from 'tgui-core/components';
import { AdjustmentSlider } from '../AdjustmentSlider';
import { ColorControls } from './ColorControls';
import { PresetControls } from './PresetControls';
import { placementBase, placementGroup } from './placementGroups';
import { type PlacementTarget, posePlacement } from './posePlacement';
import {
  CYBORG_SLOTS,
  type CyborgSlot,
  type DirectionEntry,
  type LayoutAction,
  type LayoutStore,
  type PartMetadata,
  type PlacementCommand,
} from './types';

export const editorLabel = (value: string) =>
  ({
    idle: 'Standing',
    rest: 'Resting',
    sit: 'Sitting',
    bellyup: 'Belly up',
    rest_deep: 'Deep rest',
    rest_alt: 'Resting (alternate)',
    sit_alt: 'Sitting (alternate)',
    none: 'Unaroused',
    partial: 'Partially aroused',
    full: 'Fully aroused',
    base: 'All arousal states',
  })[value] || value.charAt(0).toUpperCase() + value.slice(1);

const adjustments = {
  pixel_x: {
    label: 'Horizontal position',
    min: -128,
    max: 128,
    step: 1,
    unit: 'px',
  },
  pixel_y: {
    label: 'Vertical position',
    min: -128,
    max: 128,
    step: 1,
    unit: 'px',
  },
  rotation: { label: 'Rotation', min: -180, max: 180, step: 1, unit: '°' },
  scale: { label: 'Part scale', min: 25, max: 200, step: 5, unit: '%' },
  priority: { label: 'Layer order', min: 1, max: 10, step: 1, unit: '' },
};

export function LayoutControls(props: {
  store: LayoutStore;
  model?: string;
  onAction: LayoutAction;
  slot?: CyborgSlot;
  part?: PartMetadata;
  parts?: Partial<Record<CyborgSlot, PartMetadata>>;
  spriteControl?: ReactNode;
  hidePresets?: boolean;
  disabled?: boolean;
  wide?: boolean;
  placementTarget?: PlacementTarget;
  onPlacementTarget?: (target: PlacementTarget) => void;
  preview?: {
    direction: string;
    pose: string;
    poses: string[];
    arousal: string;
    onChange: (change: {
      direction?: string;
      pose?: string;
      arousal?: string;
    }) => void;
  };
}) {
  const { store, model, onAction } = props;
  const [localSlot, setSlot] = useState<CyborgSlot>('penis');
  const slot = props.slot ?? localSlot;
  const [localDirection, setDirection] = useState('south');
  const [localPose, setPose] = useState('idle');
  const [localArousal, setArousal] = useState('none');
  const [localTarget, setLocalTarget] = useState<PlacementTarget>('base');
  const target = props.placementTarget ?? localTarget;
  const setTarget = props.onPlacementTarget ?? setLocalTarget;
  const stateOverride = target === 'arousal';
  const direction = props.preview?.direction ?? localDirection;
  const pose = props.preview?.pose ?? localPose;
  const arousal = props.preview?.arousal ?? localArousal;
  const entry = store.active[slot];
  const group = placementGroup(!!props.wide, direction);
  const base = placementBase(entry, group);
  const part = props.part ?? props.parts?.[slot];
  const sizeIndex = Math.max(
    0,
    part?.sizes.findIndex(
      (size) =>
        size.value ===
        (part.effective_size ??
          entry.sprite_size ??
          (slot === 'penis' || slot === 'testicles' || slot === 'sheath'
            ? 2
            : 1)),
    ) ?? 0,
  );
  const set = (field: string, value: unknown) =>
    onAction({ operation: 'set', slot, field, value, placement_group: group });
  const placement = (scope: 'base' | 'pose' | 'arousal') => ({
    scope,
    direction,
    pose,
    arousal,
  });
  const setPlacement = (field: string, value: unknown) =>
    onAction({
      operation: 'set_placement',
      slot,
      target: placement(target),
      changes: { [field]: value },
    } as PlacementCommand);
  const {
    key: directionKey,
    directional,
    effective: arousalPlacement,
  } = posePlacement(entry, direction, pose, arousal);
  const effective = stateOverride ? arousalPlacement : directional;
  const sliders = (
    values: DirectionEntry | typeof entry,
    update: typeof set,
    advanced = false,
  ) =>
    (advanced
      ? (['pixel_x', 'pixel_y', 'rotation', 'scale', 'priority'] as const)
      : (['pixel_x', 'pixel_y', 'rotation', 'scale'] as const)
    ).map((field) => (
      <AdjustmentSlider
        key={
          slot +
          '-' +
          (advanced
            ? directionKey + stateOverride + arousal
            : (group ?? 'base')) +
          '-' +
          field
        }
        {...adjustments[field]}
        wholeNumbers={field === 'pixel_x' || field === 'pixel_y'}
        label={(advanced ? 'Override: ' : '') + adjustments[field].label}
        disabled={props.disabled}
        value={Number(values[field]) * (field === 'scale' ? 100 : 1)}
        onChange={(value) =>
          update(field, value / (field === 'scale' ? 100 : 1))
        }
      />
    ));
  return (
    <>
      <Section title={`${editorLabel(slot)} appearance`}>
        {!props.slot && (
          <Dropdown
            width="100%"
            options={CYBORG_SLOTS.map((value) => ({
              value,
              displayText: editorLabel(value),
            }))}
            selected={slot}
            displayText={editorLabel(slot)}
            onSelected={(value) => setSlot(value as CyborgSlot)}
          />
        )}
        {props.spriteControl}
        <Tabs mt={1}>
          {(
            [
              ['base', 'Shared placement'],
              ['pose', 'This pose'],
              ['arousal', 'This arousal'],
            ] as const
          ).map(([value, label]) => (
            <Tabs.Tab
              key={value}
              selected={target === value}
              onClick={() => setTarget(value)}
            >
              {label}
            </Tabs.Tab>
          ))}
        </Tabs>
        {target === 'base' ? (
          <>
            {props.wide && (
              <div>
                <Button.Checkbox
                  checked={!!(entry.mirror_sides ?? true)}
                  disabled={props.disabled}
                  tooltip="Base X and rotation use the east-facing view and reflect when facing west. View-specific offsets stay in screen coordinates."
                  onClick={() =>
                    set('mirror_sides', !(entry.mirror_sides ?? true))
                  }
                >
                  Mirror east/west placement
                </Button.Checkbox>
                <Button.Checkbox
                  checked={!!entry.reuse_south}
                  disabled={props.disabled}
                  tooltip="Use this part's south-facing artwork in the north view. Useful when the authored north sprite is blank; position and layers still use north settings."
                  onClick={() => set('reuse_south', !entry.reuse_south)}
                >
                  Use south sprite when facing north
                </Button.Checkbox>
              </div>
            )}
            {!!part?.sizes.length && (
              <div className="CyborgEditor__size">
                <Box color="label">Part size</Box>
                <div className="CyborgEditor__sizeOptions">
                  <Button
                    icon="chevron-left"
                    aria-label="Smaller part size"
                    disabled={props.disabled || sizeIndex <= 0}
                    onClick={() =>
                      set('sprite_size', part.sizes[sizeIndex - 1].value)
                    }
                  />
                  {part.sizes[sizeIndex]?.icon && (
                    <img
                      src={`data:image/png;base64,${part.sizes[sizeIndex].icon}`}
                      alt="Selected part size"
                    />
                  )}
                  <Dropdown
                    width="100%"
                    disabled={props.disabled}
                    selected={String(part.sizes[sizeIndex]?.value)}
                    displayText={part.sizes[sizeIndex]?.label}
                    options={part.sizes.map((size) => ({
                      value: String(size.value),
                      displayText: size.label,
                    }))}
                    onSelected={(value) => set('sprite_size', Number(value))}
                  />
                  <Button
                    icon="chevron-right"
                    aria-label="Larger part size"
                    disabled={
                      props.disabled || sizeIndex >= part.sizes.length - 1
                    }
                    onClick={() =>
                      set('sprite_size', part.sizes[sizeIndex + 1].value)
                    }
                  />
                </div>
              </div>
            )}
            <Box mt={1} color="label">
              {group === 'side'
                ? 'East / West placement'
                : group
                  ? `${editorLabel(group)} placement`
                  : 'All views'}{' '}
              · Positive Y moves upward.
            </Box>
            {sliders(base, setPlacement)}
            {!!part?.color_channels.length && (
              <Box bold my={1}>
                Colors
              </Box>
            )}
            <ColorControls
              key={slot}
              colors={entry.colors}
              channels={part?.color_channels ?? []}
              disabled={props.disabled}
              onChange={(colors) => set('colors', colors)}
            />
          </>
        ) : (
          <>
            <Box my={1} color="label">
              Dragging and sliders edit this target together. Offsets adjust
              shared placement; scale multiplies shared scale.
              {!stateOverride &&
                directional.arousal?.[arousal] &&
                ' This arousal has saved overrides; use This arousal to edit those values.'}
            </Box>
            <div title="Layer order is saved per direction, pose, and optional arousal state. Higher values draw above other parts; equal values follow part order. The chassis body mask always covers parts.">
              <Box color="label" mb={1}>
                Layer order: 1 behind other parts → 10 in front. Body masks stay
                above parts.
              </Box>
            </div>
            {!props.slot &&
              (['direction', 'pose', 'arousal'] as const).map((key) => (
                <Box mb={1} key={key}>
                  <Dropdown
                    width="100%"
                    selected={{ direction, pose, arousal }[key]}
                    displayText={editorLabel({ direction, pose, arousal }[key])}
                    options={(key === 'direction'
                      ? ['north', 'south', 'east', 'west']
                      : key === 'pose'
                        ? (props.preview?.poses ?? [
                            'idle',
                            'rest',
                            'sit',
                            'bellyup',
                            'rest_deep',
                            'rest_alt',
                            'sit_alt',
                          ])
                        : ['none', 'partial', 'full']
                    ).map((value) => ({
                      value,
                      displayText: editorLabel(value),
                    }))}
                    onSelected={(value) =>
                      props.preview
                        ? props.preview.onChange({ [key]: value })
                        : {
                            direction: setDirection,
                            pose: setPose,
                            arousal: setArousal,
                          }[key](value)
                    }
                  />
                </Box>
              ))}
            <Box my={1} color="label">
              {stateOverride ? editorLabel(arousal) : 'All arousal states'} ·{' '}
              {editorLabel(pose)} · {editorLabel(direction)}
              {(stateOverride
                ? !directional.arousal?.[arousal]
                : !entry.advanced[directionKey]) && ' · Inherited placement'}
            </Box>
            <Button.Checkbox
              disabled={props.disabled}
              checked={!!effective.visible}
              onClick={() => setPlacement('visible', !effective.visible)}
            >
              Visible in this view
            </Button.Checkbox>
            {sliders(effective, setPlacement, true)}
            <Button.Confirm
              disabled={
                props.disabled ||
                (stateOverride
                  ? !entry.advanced[directionKey]?.arousal?.[arousal]
                  : !entry.advanced[directionKey])
              }
              onClick={() =>
                onAction({
                  operation: 'inherit_placement',
                  slot,
                  target: placement(target),
                } satisfies PlacementCommand)
              }
            >
              {stateOverride
                ? 'Inherit pose placement'
                : 'Inherit shared placement'}
            </Button.Confirm>
          </>
        )}
        <div className="CyborgEditor__resets">
          {(['position', 'colors', 'overrides'] as const).map((kind) => (
            <Button.Confirm
              key={`${slot}-${kind}`}
              disabled={props.disabled}
              confirmContent="Confirm?"
              onClick={() => onAction({ operation: `reset_${kind}`, slot })}
            >
              Reset {kind === 'position' ? 'placement' : kind}
            </Button.Confirm>
          ))}
        </div>
      </Section>
      {!props.hidePresets && (
        <PresetControls store={store} model={model} onAction={onAction} />
      )}
    </>
  );
}
