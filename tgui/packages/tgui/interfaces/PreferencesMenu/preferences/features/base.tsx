import { sortBy } from 'es-toolkit';
import {
  type ComponentType,
  createElement,
  type FormEvent,
  type KeyboardEvent,
  type ReactNode,
  useEffect,
  useState,
} from 'react';
import { useBackend } from 'tgui/backend';
import {
  Box,
  Button,
  Dropdown,
  Input,
  NumberInput,
  Slider,
  Stack,
  TextArea, // NOVA EDIT ADDITION
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import {
  type CharacterPreferencesData,
  createSetPreference,
  type PreferencesMenuData,
} from '../../types';
import { useServerPrefs } from '../../useServerPrefs';

export function sortChoices(array: [string, ReactNode][]) {
  return sortBy(array, [([name]) => name]);
}

export type Feature<
  TReceiving,
  TSending = TReceiving,
  TServerData = undefined,
> = {
  name: string;
  component: FeatureValue<TReceiving, TSending, TServerData>;
  category?: string;
  description?: string;
  placeholder?: string;
};

/**
 * Represents a preference.
 * TReceiving = The type you will be receiving
 * TSending = The type you will be sending
 * TServerData = The data the server sends through preferences.json
 */
type FeatureValue<
  TReceiving,
  TSending = TReceiving,
  TServerData = undefined,
> = ComponentType<FeatureValueProps<TReceiving, TSending, TServerData>>;

export type FeatureValueProps<
  TReceiving,
  TSending = TReceiving,
  TServerData = undefined,
> = Readonly<{
  featureId: string;
  handleSetValue: (newValue: TSending) => void;
  serverData: TServerData | undefined;
  shrink?: boolean;
  placeholder?: string;
  value: TReceiving;
  label?: string;
  nativeInput?: boolean;
  character_preferences: CharacterPreferencesData;
}>;

export function FeatureColorInput(props: FeatureValueProps<string>) {
  const { act } = useBackend<PreferencesMenuData>();
  const { featureId, shrink, value } = props;

  return (
    <Button
      onClick={() => {
        act('set_color_preference', {
          preference: featureId,
        });
      }}
    >
      <Stack align="center" fill>
        <Stack.Item>
          <Box
            style={{
              background: value.startsWith('#') ? value : `#${value}`,
              border: '2px solid white',
              boxSizing: 'content-box',
              height: '11px',
              width: '11px',
              ...(shrink
                ? {
                    margin: '1px',
                  }
                : {}),
            }}
          />
        </Stack.Item>

        {!shrink && <Stack.Item>Change</Stack.Item>}
      </Stack>
    </Button>
  );
}

export type FeatureToggle = Feature<BooleanLike, boolean>;

export function CheckboxInput(props: FeatureValueProps<BooleanLike, boolean>) {
  const { handleSetValue, value } = props;

  return (
    <Button.Checkbox
      checked={!!value}
      onClick={() => {
        handleSetValue(!value);
      }}
    />
  );
}

export function CheckboxInputInverse(
  props: FeatureValueProps<BooleanLike, boolean>,
) {
  const { handleSetValue, value } = props;

  return (
    <Button.Checkbox
      checked={!value}
      onClick={() => {
        handleSetValue(!value);
      }}
    />
  );
}

export function createDropdownInput<T extends string | number = string>(
  // Map of value to display texts
  choices: Record<T, ReactNode>,
  dropdownProps?: Record<T, unknown>,
): FeatureValue<T> {
  return (props: FeatureValueProps<T>) => {
    const { handleSetValue, value } = props;

    return (
      <Dropdown
        selected={choices[value] as string}
        onSelected={handleSetValue}
        width="100%"
        options={sortChoices(Object.entries(choices)).map(
          ([dataValue, label]) => {
            return {
              displayText: label,
              value: dataValue,
            };
          },
        )}
        {...dropdownProps}
      />
    );
  };
}

export type FeatureChoicedServerData<TChoice extends string | number = string> =
  {
    choices: TChoice[];
    display_names?: Record<string, string>;
    icons?: Record<string, string>;
    extra_quirk_data?: Record<string, string>; // NOVA EDIT ADDITION
  };

export type FeatureChoiced = Feature<string, string, FeatureChoicedServerData>;
export type FeatureNumericChoiced = Feature<
  number,
  number,
  FeatureChoicedServerData<number>
>;

export type FeatureNumericData = {
  minimum: number;
  maximum: number;
  step: number;
};

export type FeatureNumeric = Feature<number, number, FeatureNumericData>;

export function FeatureNumberInput(
  props: FeatureValueProps<number, number, FeatureNumericData>,
) {
  const { serverData, handleSetValue, value } = props;

  return (
    <NumberInput
      onChange={(value) => handleSetValue(value)}
      disabled={!serverData}
      minValue={serverData?.minimum || 0}
      maxValue={serverData?.maximum || 100}
      step={serverData?.step || 1}
      value={value}
    />
  );
}

export function FeatureSliderInput(
  props: FeatureValueProps<number, number, FeatureNumericData>,
) {
  const { serverData, handleSetValue, value } = props;

  return (
    <Slider
      onChange={(e, value) => {
        handleSetValue(value);
      }}
      disabled={!serverData}
      minValue={serverData?.minimum || 0}
      maxValue={serverData?.maximum || 100}
      step={serverData?.step || 1}
      value={value}
      stepPixelSize={10}
    />
  );
}

type FeatureValueInputProps = {
  feature: Feature<unknown>;
  featureId: string;
  shrink?: boolean;
  value: unknown;
  label?: string;
  nativeInput?: boolean;
};

export function FeatureValueInput(props: FeatureValueInputProps) {
  const { act, data } = useBackend<PreferencesMenuData>();

  const feature = props.feature;

  const [predictedValue, setPredictedValue] = useState(props.value);

  function changeValue(newValue: unknown) {
    setPredictedValue(newValue);
    createSetPreference(act, props.featureId)(newValue);
  }

  useEffect(() => {
    setPredictedValue(props.value);
  }, [data.active_slot, props.value]);

  const serverData = useServerPrefs();

  return createElement(feature.component, {
    featureId: props.featureId,
    serverData: serverData?.[props.featureId] as any,
    shrink: props.shrink,
    placeholder: feature.placeholder,
    label: props.label,
    nativeInput: props.nativeInput,
    handleSetValue: changeValue,
    value: predictedValue,
    character_preferences: data.character_preferences,
  });
}

type FeatureShortTextData = {
  maximum_length: number;
  maximum_bytes?: number;
};

/** Match preferences with a UTF-8 byte budget without splitting a character. */
function limitTextBytes(value: string, maximumBytes?: number): string {
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

export function FeatureShortTextInput(
  props: FeatureValueProps<string, string, FeatureShortTextData>,
) {
  const { serverData, value, handleSetValue } = props;

  return (
    <Input
      aria-label={props.label}
      disabled={!serverData}
      fluid
      value={value}
      maxLength={serverData?.maximum_length}
      {...byteLimitedInputProps(serverData?.maximum_bytes)}
      onBlur={(value) =>
        handleSetValue(limitTextBytes(value, serverData?.maximum_bytes))
      }
    />
  );
}
// NOVA EDIT ADDITION START - NOVA FEATURES DOWN HERE
export const FeatureLongTextInput = (
  props: FeatureValueProps<string, string, FeatureShortTextData>,
) => {
  const { serverData, handleSetValue, value } = props;

  if (!serverData) {
    return <Box>Loading...</Box>;
  }

  return (
    <TextArea
      aria-label={props.label}
      height="100px"
      fluid
      placeholder={props.placeholder}
      value={value}
      maxLength={serverData?.maximum_length}
      {...byteLimitedInputProps(serverData?.maximum_bytes)}
      onBlur={(value) =>
        handleSetValue(limitTextBytes(value, serverData?.maximum_bytes))
      }
    />
  );
};

export const FeatureTriColorInput = (props: FeatureValueProps<string[]>) => {
  const { act } = useBackend<PreferencesMenuData>();
  const { featureId, shrink, value } = props;

  const buttonFromValue = (index) => {
    return (
      <Stack.Item>
        <Button
          onClick={() => {
            act('set_tricolor_preference', {
              preference: featureId,
              value: index + 1,
            });
          }}
        >
          <Stack align="center" fill>
            <Stack.Item>
              <Box
                style={{
                  background: value[index].startsWith('#')
                    ? value[index]
                    : `#${value[index]}`,
                  border: '2px solid white',
                  boxSizing: 'content-box',
                  height: '11px',
                  width: '11px',
                  ...(shrink
                    ? {
                        margin: '1px',
                      }
                    : {}),
                }}
              />
            </Stack.Item>

            {!shrink && <Stack.Item>Change</Stack.Item>}
          </Stack>
        </Button>
      </Stack.Item>
    );
  };
  return (
    <Stack align="center" fill>
      {buttonFromValue(0)}
      {buttonFromValue(1)}
      {buttonFromValue(2)}
    </Stack>
  );
};

export const FeatureTriBoolInput = (props: FeatureValueProps<boolean[]>) => {
  const { handleSetValue, value } = props;

  const buttonFromValue = (index) => {
    return (
      <Stack.Item align="center">
        <Button.Checkbox
          checked={!!value[index]}
          onClick={() => {
            const currentValue = [...value];
            currentValue[index] = !currentValue[index];
            handleSetValue(currentValue);
          }}
        />
      </Stack.Item>
    );
  };
  return (
    <Stack align="center" fill>
      {buttonFromValue(0)}
      {buttonFromValue(1)}
      {buttonFromValue(2)}
    </Stack>
  );
};
// NOVA EDIT ADDITION END
