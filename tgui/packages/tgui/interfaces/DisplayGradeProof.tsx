import {
  DISPLAY_GRADE_RANGES,
  DISPLAY_GRADE_REFERENCE,
  type DisplayGradeSettings,
  displayGradeFilter,
} from 'common/display-grade';
import { useState } from 'react';
import {
  Box,
  Button,
  Input,
  LabeledList,
  NumberInput,
  Section,
  Stack,
} from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import { DisplayGradeSwatches } from './common/DisplayGradeSwatches';

export function DisplayGradeProof() {
  const { act, data } = useBackend<{
    settings: DisplayGradeSettings;
    enabled: boolean;
    resources: number;
  }>();
  const [draft, setDraft] = useState(data.settings);
  const graph = displayGradeFilter('aphelion-grade-proof', data.settings);
  return (
    <Window width={820} height={720}>
      <Window.Content scrollable>
        <Section title="Renderer acceptance probe">
          <Box mb={1}>
            Diagnostic only. No preferences are saved. Native grading stops on
            floor, perspective, or HUD changes. Closing restores the original
            rendering plate.
          </Box>
          <Button onClick={() => act('render', { settings: draft })}>
            Render parameters
          </Button>
          <Button onClick={() => act('off')}>Off / Before</Button>
          <Button onClick={() => setDraft({ ...DISPLAY_GRADE_REFERENCE })}>
            Reset draft to Reference
          </Button>
          <Box>
            Native graph: {data.enabled ? 'active' : 'off'}; resources:{' '}
            {data.resources}
          </Box>
        </Section>
        <Section title="Neutral controls (fractions, 1 = 100%)">
          <LabeledList>
            {Object.entries(DISPLAY_GRADE_RANGES).map(([key, [min, max]]) => (
              <LabeledList.Item key={key} label={key}>
                <NumberInput
                  value={draft[key]}
                  minValue={min}
                  maxValue={max}
                  step={0.01}
                  onChange={(value) => setDraft({ ...draft, [key]: value })}
                />
              </LabeledList.Item>
            ))}
            {(
              ['shadow_color', 'midtone_color', 'highlight_color'] as const
            ).map((key) => (
              <LabeledList.Item key={key} label={key}>
                <Input
                  value={draft[key]}
                  onChange={(value) => setDraft({ ...draft, [key]: value })}
                />
              </LabeledList.Item>
            ))}
          </LabeledList>
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
                  filter: data.enabled
                    ? 'url(#aphelion-grade-proof)'
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
