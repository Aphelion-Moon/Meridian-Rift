import { Box, Button, NoticeBox, Section, Stack } from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  status?: string;
  denial?: string;
  loadout: string;
  includeLoadout: boolean;
  initial: boolean;
  pending: boolean;
  remaining: number;
  body: string;
  core: string;
  preview?: string;
  profile?: string;
  preset?: string;
  adjustments?: string[];
};

export const UplinkShell = () => {
  const { act, data } = useBackend<Data>();
  return (
    <Window width={620} height={690}>
      <Window.Content scrollable>
        {data.status && <NoticeBox>{data.status}</NoticeBox>}
        {data.denial && <NoticeBox danger>{data.denial}</NoticeBox>}
        <Section title="Your AI identity">
          <Box mb={1}>{data.core}</Box>
          <Box mb={1}>{data.body}</Box>
          <Stack>
            <Stack.Item>
              <Button icon="link" onClick={() => act('connect')}>
                Connect to personal shell
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button icon="eye" onClick={() => act('return')}>
                AI View
              </Button>
            </Stack.Item>
          </Stack>
        </Section>
        {data.initial ? (
          <Section title="First issuance">
            <Button.Checkbox
              checked={data.includeLoadout}
              onClick={() => act('loadout')}
            >
              Include personal loadout
            </Button.Checkbox>
            <Button icon="sync" onClick={() => act('preview')}>
              Refresh preview from selected profile
            </Button>
            <Button onClick={() => act('label')}>Shell label</Button>
            {data.preview && (
              <>
                <Box mt={2} mb={1}>
                  {data.profile} — {data.preset}
                </Box>
                <img
                  alt="Confirmed Uplink body preview"
                  src={`data:image/png;base64,${data.preview}`}
                  width={128}
                  height={128}
                  style={{ imageRendering: 'pixelated' }}
                />
                {data.adjustments?.map((text) => (
                  <Box key={text} mb={1} color="label">
                    {text}
                  </Box>
                ))}
                <NoticeBox>
                  Confirming delivers this body without deploying you. Your
                  personal loadout choice becomes permanent after delivery.
                </NoticeBox>
                <Button.Confirm
                  color="good"
                  disabled={!!data.denial}
                  onClick={() => act('issue')}
                >
                  Confirm preview and deliver
                </Button.Confirm>
              </>
            )}
          </Section>
        ) : (
          <Section title="Replacement">
            <Box mb={1}>Personal loadout: {data.loadout}</Box>
            <Box mb={1}>
              Retirement immediately revokes the old body’s personal connection,
              toolkit and camera. Its body and belongings remain in place.
              Replacements contain baseline equipment only.
            </Box>
            {data.pending ? (
              <>
                <Box mb={1}>
                  {data.remaining > 0
                    ? `Ready in ${data.remaining} seconds.`
                    : 'Ready. Retry if delivery is blocked.'}
                </Box>
                <Button
                  disabled={data.remaining > 0 || !!data.denial}
                  onClick={() => act('issue')}
                >
                  Retry delivery
                </Button>
                <Button onClick={() => act('cancel')}>Cancel request</Button>
              </>
            ) : (
              <Button onClick={() => act('replace')}>
                Request replacement
              </Button>
            )}
            <Box mt={1} color="label">
              Cancellation keeps retirement and the accepted deadline. Damage and
              low charge can instead be treated through normal synthetic medical
              care and cyborg rechargers.
            </Box>
          </Section>
        )}
        <Section title="Operating your shell">
          AI View returns you to the real AI eye at the shell’s location. Resume
          reconnects to that body after it moves. It remains vulnerable while
          unattended. Engineering Toolkit requires an empty right hand; drop
          retracts tools. Uplink AI Services provides core interfaces and a local
          network toggle. Physical interaction is the default.
        </Section>
      </Window.Content>
    </Window>
  );
};
