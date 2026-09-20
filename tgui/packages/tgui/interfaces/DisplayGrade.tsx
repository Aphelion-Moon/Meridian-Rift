import {
  DISPLAY_GRADE_RANGES,
  DISPLAY_GRADE_REFERENCE,
  type DisplayGradeSettings,
  displayGradeFilter,
} from 'common/display-grade';
import { createGradePreview } from 'common/display-grade-preview';
import { useEffect, useMemo, useRef, useState } from 'react';
import { hexToHsva, hsvaToHex } from 'tgui-core/color';
import {
  Box,
  Button,
  LabeledList,
  NumberInput,
  Section,
  Slider,
  Stack,
} from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import { ColorSelector } from './ColorPickerModal/ColorSetter';
import { DisplayGradeSwatches } from './common/DisplayGradeSwatches';

type Data = { session: string; settings: DisplayGradeSettings };
const labels = {
  strength: 'Overall strength',
  saturation: 'Saturation',
  contrast: 'Contrast',
  brightness: 'Brightness',
  shadow_strength: 'Shadow strength',
  midtone_strength: 'Midtone strength',
  highlight_strength: 'Highlight strength',
};

export function DisplayGrade() {
  const { data } = useBackend<Data>();
  return <Editor key={data.session} {...data} />;
}

function Editor({ settings, session }: Data) {
  const { act } = useBackend<Data>();
  const [draft, setDraft] = useState(settings);
  const [bypass, setBypass] = useState(false);
  const [band, setBand] = useState<'shadow' | 'midtone' | 'highlight'>(
    'shadow',
  );
  const [closed, setClosed] = useState(false);
  const actRef = useRef(act);
  actRef.current = act;
  const preview =
    useRef<
      ReturnType<
        typeof createGradePreview<{
          settings: DisplayGradeSettings;
          bypass: boolean;
        }>
      >
    >(undefined);
  useEffect(() => {
    const sender = createGradePreview<{
      settings: DisplayGradeSettings;
      bypass: boolean;
    }>((value, sequence) =>
      actRef.current('preview', { ...value, sequence, session }),
    );
    preview.current = sender;
    return () => sender.close();
  }, [session]);
  const change = (next: DisplayGradeSettings, nextBypass = bypass) => {
    setDraft(next);
    setBypass(nextBypass);
    preview.current?.queue({ settings: next, bypass: nextBypass });
  };
  const finish = (action: 'apply' | 'cancel') => {
    preview.current?.close();
    setClosed(true);
    act(action, { session, settings: draft });
  };
  const color = hexToHsva(draft[`${band}_color`]);
  const graph = useMemo(
    () => displayGradeFilter('aphelion-grade-comparison', draft),
    [draft],
  );
  return (
    <Window width={820} height={850}>
      <Window.Content scrollable>
        <Section
          title="Display grade"
          buttons={
            <>
              <Button
                color="good"
                disabled={closed}
                onClick={() => finish('apply')}
              >
                Apply
              </Button>
              <Button disabled={closed} onClick={() => finish('cancel')}>
                Cancel
              </Button>
            </>
          }
        >
          <Box mb={1}>
            Changes are a temporary Custom draft. Apply saves it for your
            account. Closing discards it. These controls stay neutral.
          </Box>
          <Button
            disabled={closed}
            onClick={() => change({ ...DISPLAY_GRADE_REFERENCE })}
          >
            Reset to Reference
          </Button>
          <Button
            disabled={closed}
            selected={bypass}
            onClick={() => change(draft, !bypass)}
          >
            {bypass ? 'Before (bypassed)' : 'After (preview)'}
          </Button>
        </Section>
        <Section title="Adjustments">
          <LabeledList>
            {Object.entries(DISPLAY_GRADE_RANGES).map(([key, [min, max]]) => (
              <LabeledList.Item key={key} label={labels[key]}>
                <Stack align="center">
                  <Stack.Item grow>
                    <Slider
                      tickWhileDragging
                      value={draft[key] * 100}
                      minValue={min * 100}
                      maxValue={max * 100}
                      step={1}
                      disabled={closed}
                      onChange={(_, value) =>
                        change({ ...draft, [key]: value / 100 })
                      }
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <NumberInput
                      width="80px"
                      value={Math.round(draft[key] * 100)}
                      minValue={min * 100}
                      maxValue={max * 100}
                      step={1}
                      unit="%"
                      disabled={closed}
                      onChange={(value) =>
                        change({ ...draft, [key]: value / 100 })
                      }
                    />
                  </Stack.Item>
                </Stack>
              </LabeledList.Item>
            ))}
          </LabeledList>
        </Section>
        <Section title="Tonal colors">
          {(['shadow', 'midtone', 'highlight'] as const).map((name) => (
            <Button
              key={name}
              selected={band === name}
              onClick={() => setBand(name)}
            >
              <Box
                inline
                mr={1}
                width="14px"
                height="14px"
                backgroundColor={draft[`${name}_color`]}
              />
              {name}
            </Button>
          ))}
          <ColorSelector
            color={color}
            defaultColor={settings[`${band}_color`]}
            setColor={(update) => {
              if (closed) return;
              const next =
                typeof update === 'function' ? update(color) : update;
              change({
                ...draft,
                [`${band}_color`]: hsvaToHex(next).toUpperCase(),
              });
            }}
          />
        </Section>
        <svg
          aria-hidden="true"
          width="0"
          height="0"
          style={{ position: 'absolute' }}
        >
          <defs dangerouslySetInnerHTML={{ __html: graph }} />
        </svg>
        <Stack>
          <Stack.Item grow>
            <Section title="Before">
              <DisplayGradeSwatches />
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            <Section title="After">
              <div
                style={{
                  filter:
                    !bypass && draft.strength
                      ? 'url(#aphelion-grade-comparison)'
                      : undefined,
                }}
              >
                <DisplayGradeSwatches />
              </div>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
}
