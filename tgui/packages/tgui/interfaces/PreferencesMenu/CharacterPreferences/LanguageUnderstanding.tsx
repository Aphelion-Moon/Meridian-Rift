// THIS IS AN APHELION UI FILE
import { useEffect, useState } from 'react';
import { useBackend } from 'tgui/backend';
import { BlockQuote, Box, Slider, Stack, Tooltip } from 'tgui-core/components';

import type { Language, PreferencesMenuData } from '../types';

/** The least of a language only understood that can be followed: Common Second Language's lowest setting. */
export const UNDERSTANDING_MIN = 25;

/** How much of what's said gets through at a level. */
export function understandingLabel(level: number) {
  if (level >= 100) {
    return 'all of it';
  }
  if (level >= 90) {
    return 'nearly all of it';
  }
  if (level >= 65) {
    return 'most of it';
  }
  if (level >= 40) {
    return 'some of it';
  }
  return 'a few words';
}

/**
 * How much of a language the character only understands they follow, from
 * UNDERSTANDING_MIN to all of it, and a line in it as they would hear it. The
 * slider sends its level when let go and shows it until the server answers.
 */
export function LanguageUnderstanding(props: { language: Language }) {
  const { act, data } = useBackend<PreferencesMenuData>();
  const { name } = props.language;
  const level = data.language_understanding?.[name] ?? 100;
  const sample = data.language_understanding_samples?.[name];
  const [pending, setPending] = useState<number>();
  // The server's level replaces the one the slider was let go at.
  useEffect(() => setPending(undefined), [level]);
  const shown = pending ?? level;

  return (
    <Stack vertical g={0.5} mt={0.5} className="LanguagesMenu__understanding">
      <Stack.Item>
        <Stack align="center" g={0.5}>
          <Stack.Item>
            <Tooltip content="How much of what's said in it gets through. Common words get through more often.">
              <Box inline>Follows</Box>
            </Tooltip>
          </Stack.Item>
          <Stack.Item grow>
            <Slider
              minValue={UNDERSTANDING_MIN}
              maxValue={100}
              step={5}
              value={shown}
              unit="%"
              onChange={(_event, value) => {
                setPending(value);
                act('set_language_understanding', {
                  language_name: name,
                  level: value,
                });
              }}
            />
          </Stack.Item>
          <Stack.Item className="LanguagesMenu__understandingLabel">
            {understandingLabel(shown)}
          </Stack.Item>
        </Stack>
      </Stack.Item>
      {!!sample && (
        <Stack.Item>
          <BlockQuote className="LanguagesMenu__understandingSample">
            {sample}
          </BlockQuote>
        </Stack.Item>
      )}
    </Stack>
  );
}
