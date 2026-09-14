import { useState } from 'react';
import { Box, Button, Dropdown, Input, Section } from 'tgui-core/components';
import type { LayoutAction, LayoutStore } from './types';

export function PresetControls({
  store,
  model,
  onAction,
  models = [],
  embedded = false,
  disabled = false,
}: {
  embedded?: boolean;
  disabled?: boolean;
  store: LayoutStore;
  model?: string;
  models?: { id: string; department: string; skin: string }[];
  onAction: LayoutAction;
}) {
  const [name, setName] = useState(store.active_preset || '');
  const trimmedName = name.trim();
  const exists = !!store.presets[trimmedName];
  const presetModel = store.preset_models?.[trimmedName];
  const modelLabel = (id?: string) => {
    const item = models.find((entry) => entry.id === id);
    return item
      ? `${item.department} / ${item.skin}`
      : id
        ? 'Saved chassis'
        : 'Unbound legacy preset';
  };
  const assigned = model ? store.model_presets?.[model] : undefined;
  const hasDefault = !!model && !!store.model_defaults[model];
  const content = (
    <div className="CyborgEditor__presets">
      {embedded && (
        <div
          className="CyborgEditor__presetHeading"
          title="A preset saves its chassis, selected parts, placement, colors, and overrides. Loading edits your setup; Use on spawn assigns it to a chassis."
        >
          <Box bold mb={1}>
            Saved setups
          </Box>
        </div>
      )}
      <div
        className="CyborgEditor__presetGroup"
        title="Load restores the preset and its saved chassis. Update saves your edits. Use on spawn chooses what that chassis starts with."
      >
        <Box color="label" mb={0.5}>
          Saved presets
        </Box>
        <Dropdown
          width="100%"
          options={Object.keys(store.presets).map((value) => ({
            value,
            displayText: `${value} · ${modelLabel(store.preset_models?.[value])}`,
          }))}
          selected={trimmedName}
          displayText={exists ? trimmedName : 'Choose a saved preset'}
          onSelected={setName}
        />
      </div>
      {exists && (
        <Box mt={0.5} color="label">
          {modelLabel(presetModel)}
        </Box>
      )}
      <div title="Enter a name for the saved preset.">
        <Input
          fluid
          mt={1}
          value={name}
          maxLength={24}
          placeholder="Preset name"
          onChange={setName}
        />
      </div>
      <Box mt={1} className="CyborgEditor__presetActions">
        <Button
          tooltip="Save the selected parts and current layout as a new named preset."
          disabled={
            disabled ||
            !trimmedName ||
            exists ||
            Object.keys(store.presets).length >= 10
          }
          onClick={() => onAction({ operation: 'save', name: trimmedName })}
        >
          Save new
        </Button>
        <Button.Confirm
          key={`overwrite-${trimmedName}`}
          tooltip="Replace the selected preset with the selected parts and current layout."
          disabled={disabled || !exists}
          onClick={() =>
            onAction({
              operation: 'save',
              name: trimmedName,
              overwrite: true,
            })
          }
        >
          Update preset
        </Button.Confirm>
        <Button.Confirm
          key={`load-${trimmedName}`}
          tooltip="Load the selected parts and layout, and switch to its saved chassis. This replaces the working appearance."
          disabled={disabled || !exists}
          onClick={() => onAction({ operation: 'load', name: trimmedName })}
        >
          Load preset
        </Button.Confirm>
        <Button.Confirm
          key={`delete-${trimmedName}`}
          tooltip="Delete the selected saved preset."
          disabled={disabled || !exists}
          color="bad"
          onClick={() => onAction({ operation: 'delete', name: trimmedName })}
        >
          Delete preset
        </Button.Confirm>
      </Box>
      <Box mt={1} color="label">
        {Object.keys(store.presets).length}/10 presets
      </Box>
      <div
        className="CyborgEditor__presetGroup CyborgEditor__modelDefaults"
        title="This assignment is used when a new body selects this chassis. Loading a preset alone does not change it. Updating the assigned preset updates its spawn appearance."
      >
        <Box bold mb={0.5}>
          Spawn appearance
        </Box>
        <Box color="label" mb={0.5}>
          {modelLabel(model)}
        </Box>
        <Box mb={0.75}>
          On spawn:{' '}
          {assigned ||
            (hasDefault ? 'Legacy saved appearance' : 'Character setup')}
        </Box>
        <Box className="CyborgEditor__presetActions">
          <Button.Confirm
            key={`assign-${model}-${trimmedName}`}
            disabled={
              disabled ||
              !model ||
              !exists ||
              (!!presetModel && presetModel !== model)
            }
            tooltip="Assign the selected saved preset to this chassis. Save your edits with Update preset first."
            onClick={() =>
              onAction({ operation: 'assign_default', name: trimmedName })
            }
          >
            Use on spawn
          </Button.Confirm>
          <Button.Confirm
            key={`clear-${model}-${assigned}`}
            color="bad"
            disabled={disabled || !hasDefault}
            tooltip="Remove this chassis assignment; future bodies will use character setup. The named preset is kept."
            onClick={() => onAction({ operation: 'delete_default' })}
          >
            Clear assignment
          </Button.Confirm>
          {hasDefault && (
            <Button.Confirm
              key={`load-default-${model}`}
              disabled={disabled}
              tooltip="Load this chassis's saved spawn appearance into the editor."
              onClick={() => onAction({ operation: 'load_default' })}
            >
              Load spawn appearance
            </Button.Confirm>
          )}
        </Box>
        {!exists && (
          <Box color="label" mt={0.5}>
            Save or select a preset to assign it.
          </Box>
        )}
        {!!presetModel && presetModel !== model && (
          <Box color="label" mt={0.5}>
            Load this preset to switch to its chassis before assigning it.
          </Box>
        )}
      </div>
    </div>
  );
  return embedded ? (
    content
  ) : (
    <details className="CyborgEditor__disclosure">
      <summary>Presets</summary>
      <Section>{content}</Section>
    </details>
  );
}
