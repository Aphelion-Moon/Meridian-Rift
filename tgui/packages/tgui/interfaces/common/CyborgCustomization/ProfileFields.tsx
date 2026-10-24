// THIS IS AN APHELION UI FILE
import { type FormEvent, type KeyboardEvent, useEffect, useState } from 'react';
import { Box, Input, TextArea } from 'tgui-core/components';
import type { FeatureChoicedServerData } from '../../PreferencesMenu/preferences/features/base';
import { generateOptions } from '../../PreferencesMenu/preferences/features/dropdowns';

/** What the server says a preference can be set to: its choices, or its text limits. */
export type ProfileFieldData = Partial<FeatureChoicedServerData> & {
  maximum_length?: number;
  maximum_bytes?: number;
};

type ProfileFieldKind = 'choice' | 'line' | 'text';

/** The preferences the editor sets beside its name, by how each is entered. */
export const PROFILE_FIELDS: Record<
  string,
  {
    name: string;
    kind: ProfileFieldKind;
    /** Set as a number, though the select carries text. */
    numeric?: boolean;
    placeholder?: string;
  }
> = {
  silicon_gender: { name: 'Gender (Silicon)', kind: 'choice' },
  cyborg_size: { name: 'Cyborg visual size', kind: 'choice', numeric: true },
  silicon_penis_sprite: { name: 'Penis sprite', kind: 'choice' },
  silicon_sheath_sprite: { name: 'Sheath sprite', kind: 'choice' },
  silicon_testicles_sprite: { name: 'Testicles sprite', kind: 'choice' },
  silicon_vagina_sprite: { name: 'Vagina sprite', kind: 'choice' },
  silicon_anus_sprite: { name: 'Anus sprite', kind: 'choice' },
  silicon_breasts_sprite: { name: 'Breasts sprite', kind: 'choice' },
  custom_species_silicon: { name: 'Custom silicon model', kind: 'line' },
  silicon_headshot: { name: 'Headshot (Silicon)', kind: 'line' },
  silicon_headshot_nsfw: { name: 'Silicon headshot (NSFW)', kind: 'line' },
  silicon_flavor_text: { name: 'Flavor Text (Silicon)', kind: 'text' },
  silicon_flavor_text_nsfw: {
    name: 'Flavor Text (Silicon, NSFW)',
    kind: 'text',
  },
  custom_species_lore_silicon: { name: 'Silicon model lore', kind: 'text' },
  ooc_notes_silicon: {
    name: 'SFW OOC Notes',
    kind: 'text',
    placeholder: 'Leave blank to use your human SFW OOC notes.',
  },
  ooc_notes_silicon_nsfw: {
    name: 'NSFW OOC Notes',
    kind: 'text',
    placeholder: 'Leave blank to use your human NSFW OOC notes.',
  },
};

/** Match preferences with a UTF-8 byte budget without splitting a character. */
export function limitTextBytes(value: string, maximumBytes?: number): string {
  if (maximumBytes === undefined) return value;
  let bytes = 0;
  let end = 0;
  for (const character of value) {
    const point = character.codePointAt(0)!;
    const width =
      point <= 0x7f ? 1 : point <= 0x7ff ? 2 : point <= 0xffff ? 3 : 4;
    if (bytes + width > maximumBytes) break;
    bytes += width;
    end += character.length;
  }
  return value.slice(0, end);
}

function byteLimitedInputProps(maximumBytes?: number) {
  if (maximumBytes === undefined) return {};
  return {
    onChangeCapture: (
      event: FormEvent<HTMLInputElement | HTMLTextAreaElement>,
    ) => {
      // Let the IME finish its composition before enforcing the final budget.
      if ((event.nativeEvent as InputEvent).isComposing) return;
      const input = event.currentTarget;
      input.value = limitTextBytes(input.value, maximumBytes);
    },
    onCompositionEnd: (
      event: FormEvent<HTMLInputElement | HTMLTextAreaElement>,
    ) => {
      const input = event.currentTarget;
      const limited = limitTextBytes(input.value, maximumBytes);
      if (limited === input.value) return;
      // Update the native value, then notify Input/TextArea's local state. This
      // also covers browsers whose final input precedes compositionend.
      const prototype =
        input instanceof HTMLTextAreaElement
          ? HTMLTextAreaElement.prototype
          : HTMLInputElement.prototype;
      Object.getOwnPropertyDescriptor(prototype, 'value')!.set!.call(
        input,
        limited,
      );
      input.dispatchEvent(new Event('input', { bubbles: true }));
    },
    onKeyDownCapture: (
      event: KeyboardEvent<HTMLInputElement | HTMLTextAreaElement>,
    ) => {
      const input = event.currentTarget;
      if (event.key !== 'Tab' || !(input instanceof HTMLTextAreaElement))
        return;
      // TextArea inserts tabs through its own state instead of an input event.
      const next = `${input.value.slice(0, input.selectionStart)}\t${input.value.slice(input.selectionEnd)}`;
      if (limitTextBytes(next, maximumBytes) === next) return;
      event.preventDefault();
      event.stopPropagation();
    },
  };
}

/** One of the editor's preferences, shown at once as set while the server catches up. */
export function ProfileField(props: {
  featureId: string;
  value: unknown;
  serverData: ProfileFieldData | undefined;
  label: string;
  /** A slot change shows the new character's value even when it's the same. */
  slot?: number;
  onChange: (value: unknown) => void;
}) {
  const { featureId, serverData, label, onChange } = props;
  const field = PROFILE_FIELDS[featureId];
  const [value, setValue] = useState(props.value);
  useEffect(() => {
    setValue(props.value);
  }, [props.slot, props.value]);
  const change = (next: unknown) => {
    setValue(next);
    onChange(next);
  };
  if (field?.kind === 'choice') {
    const options = serverData
      ? generateOptions({
          ...serverData,
          choices: (serverData.choices ?? []).map(String),
        })
      : [];
    return (
      <select
        className="Input Input--fluid"
        aria-label={label}
        disabled={!serverData}
        value={String(value)}
        onChange={(event) =>
          change(
            field.numeric
              ? Number(event.currentTarget.value)
              : event.currentTarget.value,
          )
        }
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.displayText}
          </option>
        ))}
      </select>
    );
  }
  const maximumBytes = serverData?.maximum_bytes;
  if (field?.kind === 'text') {
    if (!serverData) return <Box>Loading...</Box>;
    return (
      <TextArea
        aria-label={label}
        height="100px"
        fluid
        placeholder={field.placeholder}
        value={value as string}
        maxLength={serverData.maximum_length}
        {...byteLimitedInputProps(maximumBytes)}
        onBlur={(text) => change(limitTextBytes(text, maximumBytes))}
      />
    );
  }
  return (
    <Input
      aria-label={label}
      disabled={!serverData}
      fluid
      value={value as string}
      maxLength={serverData?.maximum_length}
      {...byteLimitedInputProps(maximumBytes)}
      onBlur={(text) => change(limitTextBytes(text, maximumBytes))}
    />
  );
}
