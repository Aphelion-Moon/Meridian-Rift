// THIS IS A NOVA SECTOR UI FILE
import { useBackend } from 'tgui/backend';
import { BlockQuote, Box, Button, Section, Stack } from 'tgui-core/components';

import type { Language, PreferencesMenuData } from '../types';

export function KnownLanguage(props: { language: Language }) {
  const { act } = useBackend<PreferencesMenuData>();
  return (
    <Stack.Item>
      <Section
        title={
          <>
            <Box
              // Manually putting the icon here instead of using the buttons prop cause it looks better
              mr="2px"
              mb="-4px"
              inline
              className={`languages16x16 ${props.language.icon}`}
            />
            <Box inline>{props.language.name}</Box>
          </>
        }
      >
        <BlockQuote>{props.language.description}</BlockQuote>
        <Stack className="LanguagesMenu__actions" inlineFlex>
          <Stack.Item>
            <Button
              fluid
              color="bad"
              icon="brain"
              tooltip="Forgetting how to understand the language will also prevent you from speaking it."
              onClick={() =>
                act('forget_understand_language', {
                  language_name: props.language.name,
                })
              }
            >
              Forget
            </Button>
          </Stack.Item>
          <Stack.Item>
            <Button
              fluid
              color={props.language.speaking ? 'good' : 'default'}
              icon={props.language.speaking ? 'comment' : 'comment-slash'}
              tooltip={
                props.language.speaking
                  ? 'Forget how to speak the language, but you keep your understanding of it.'
                  : 'Learn to speak the language.'
              }
              onClick={() =>
                act(
                  props.language.speaking
                    ? 'forget_speak_language'
                    : 'speak_language',
                  { language_name: props.language.name },
                )
              }
            >
              Can {props.language.speaking ? 'speak' : 'only understand'}
            </Button>
          </Stack.Item>
        </Stack>
      </Section>
    </Stack.Item>
  );
}

export function UnknownLanguage(props: { language: Language }) {
  const { act, data } = useBackend<PreferencesMenuData>();
  const noPoints =
    data.selected_languages.length === data.total_language_points;
  return (
    <Stack.Item>
      <Section
        title={
          <>
            <Box
              // Manually putting the icon here instead of using the buttons prop cause it looks better
              mr="2px"
              mb="-3px"
              inline
              className={`languages16x16 ${props.language.icon}`}
            />
            <Box inline>{props.language.name}</Box>
          </>
        }
      >
        <BlockQuote>{props.language.description}</BlockQuote>
        <Stack className="LanguagesMenu__actions" inlineFlex>
          <Stack.Item>
            <Button
              fluid
              color={!noPoints ? 'good' : 'grey'}
              icon="comment"
              tooltip="Learn to speak and understand the language."
              onClick={() =>
                act('speak_language', { language_name: props.language.name })
              }
            >
              Speak
            </Button>
          </Stack.Item>
          <Stack.Item>
            <Button
              fluid
              color={!!noPoints && 'grey'}
              icon="brain"
              tooltip="Learn to understand the language but not speak it."
              onClick={() =>
                act('understand_language', {
                  language_name: props.language.name,
                })
              }
            >
              Understand
            </Button>
          </Stack.Item>
        </Stack>
      </Section>
    </Stack.Item>
  );
}

export function LanguagesPage() {
  const { data } = useBackend<PreferencesMenuData>();
  return (
    <>
      <Section textAlign="center">
        Here, you can learn languages using a point system. The <b>Linguist</b>{' '}
        neutral quirk will give you one extra point.
        <br />
        Languages may be either <b>spoken and understood</b> or{' '}
        <b>just understood.</b>
        <br />
        One language is worth <b>1 point,</b> even if that language is only
        understood and not spoken.
        <br />
        You must have at least one known language, and you must understand Sol
        Common to play most station jobs. <br />
        It does not cost points to toggle speech of a language—it only costs
        points to add an entirely new language.
      </Section>
      <Stack wrap>
        <Stack.Item grow basis="24em" minWidth={0}>
          <Section
            title={
              <Box fontSize="150%">
                {data.unselected_languages.length} available languages
              </Box>
            }
          >
            <Stack vertical>
              {data.unselected_languages.map((val) => (
                <UnknownLanguage key={val.icon} language={val} />
              ))}
            </Stack>
          </Section>
        </Stack.Item>
        <Stack.Item grow basis="24em" minWidth={0}>
          <Section
            title={
              <Box fontSize="150%">
                {data.selected_languages.length}/{data.total_language_points}{' '}
                known languages
              </Box>
            }
          >
            <Stack vertical>
              {data.selected_languages.map((val) => (
                <KnownLanguage key={val.icon} language={val} />
              ))}
            </Stack>
          </Section>
        </Stack.Item>
      </Stack>
    </>
  );
}
