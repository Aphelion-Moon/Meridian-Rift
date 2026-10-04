import { Box, Button, NoticeBox, Section } from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import { CharacterPreview } from './common/CharacterPreview';

type Data = {
  status?: string;
  denial?: string;
  loadout: string;
  includeLoadout: boolean;
  initial: boolean;
  pending: boolean;
  replacementStarted: boolean;
  replacementDelay: number;
  remaining: number;
  hasBody: boolean;
  controllingShell: boolean;
  control: string;
  connectionDenial?: string;
  returnDenial?: string;
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
    <Window width={620} height={650}>
      <Window.Content scrollable>
        <Section title={`Controlling: ${data.control}`}>
          <Box mb={1}>{data.core}</Box>
          <Box mb={1}>{data.body}</Box>
          {data.controllingShell ? (
            <>
              <Button
                fluid
                icon="eye"
                disabled={!!data.returnDenial}
                onClick={() => act('return')}
              >
                Return to AI view
              </Button>
              <Box mt={1} color="label">
                {data.returnDenial ||
                  'Leaves this body unattended. You can reconnect to it later.'}
              </Box>
            </>
          ) : (
            data.hasBody && (
              <>
                <Button
                  fluid
                  icon="link"
                  color="good"
                  disabled={!!data.connectionDenial}
                  onClick={() => act('connect')}
                >
                  Connect to personal shell
                </Button>
                {data.connectionDenial && (
                  <Box mt={1} color="label">
                    {data.connectionDenial}
                  </Box>
                )}
              </>
            )
          )}
        </Section>
        {data.status && <NoticeBox>{data.status}</NoticeBox>}
        {data.initial ? (
          <Section
            title={
              data.preview ? '2. Confirm your shell' : '1. Prepare your shell'
            }
          >
            {data.denial && <NoticeBox danger>{data.denial}</NoticeBox>}
            <Box mb={1}>
              Preview the selected character profile and loadout before
              delivery. Your AI stays in control of its current body.
            </Box>
            <Button.Checkbox
              checked={data.includeLoadout}
              disabled={!!data.denial}
              onClick={() => act('loadout')}
            >
              Include personal loadout
            </Button.Checkbox>
            <Button
              icon="sync"
              disabled={!!data.denial}
              onClick={() => act('preview')}
            >
              {data.preview ? 'Refresh body preview' : 'Create body preview'}
            </Button>
            <Button disabled={!!data.denial} onClick={() => act('label')}>
              Rename shell
            </Button>
            {data.preview && (
              <>
                <Box mt={2} mb={1}>
                  {data.profile} — {data.preset}
                </Box>
                <Box aria-label="Uplink body awaiting confirmation">
                  <CharacterPreview
                    id={data.preview}
                    width="192px"
                    height="192px"
                  />
                </Box>
                {data.adjustments?.map((text) => (
                  <Box key={text} mb={1} color="label">
                    {text}
                  </Box>
                ))}
                <NoticeBox>
                  Delivery is immediate when a safe tile near the core is
                  available. You can connect afterward. The personal loadout
                  choice becomes final on delivery.
                </NoticeBox>
                <Button
                  color="good"
                  fluid
                  disabled={!!data.denial}
                  onClick={() => act('issue')}
                >
                  Confirm preview and deliver
                </Button>
              </>
            )}
          </Section>
        ) : (
          <Section
            title={
              data.pending ? 'Replacement scheduled' : 'Replace your shell'
            }
          >
            {data.denial && <NoticeBox danger>{data.denial}</NoticeBox>}
            <Box mb={1}>
              {data.hasBody
                ? 'Retiring returns you to the core and turns this shell into scrap. Its worn and stored belongings are left on the floor.'
                : 'The previous shell is retired or unavailable. A replacement does not recover its belongings.'}
            </Box>
            <Box mb={1} color="label">
              Personal loadout:{' '}
              {data.loadout === 'issued' ? 'already delivered' : 'declined'}.
              Replacements retain your saved assembly and quirks, with baseline
              equipment. Personal items and quirk supplies are not reissued.
            </Box>
            {!data.replacementStarted && (
              <Box mb={1}>
                Replacement wait: {data.replacementDelay} seconds after you
                accept.
              </Box>
            )}
            {(data.pending || data.replacementStarted) && (
              <NoticeBox>
                {data.remaining > 0
                  ? `${data.remaining} seconds until replacement is available.`
                  : 'Replacement wait complete.'}
                {!data.pending && ' Delivery is not scheduled.'}
              </NoticeBox>
            )}
            {data.pending ? (
              <>
                <Box mb={1}>
                  Delivery is automatic when the wait ends and the core is
                  available. If blocked, clear a floor tile near the core and
                  retry.
                </Box>
                <Button
                  disabled={data.remaining > 0 || !!data.denial}
                  onClick={() => act('issue')}
                >
                  Retry delivery
                </Button>
                <Button onClick={() => act('cancel')}>Cancel delivery</Button>
              </>
            ) : (
              <Button
                icon={data.hasBody ? 'recycle' : 'clock'}
                color={data.hasBody ? 'bad' : undefined}
                disabled={!!data.denial}
                onClick={() => act('replace')}
              >
                {data.hasBody
                  ? 'Retire and replace shell'
                  : data.replacementStarted
                    ? 'Resume replacement request'
                    : 'Schedule replacement'}
              </Button>
            )}
            <Box mt={1} color="label">
              Canceling stops delivery. It does not restore the retired shell or
              restart the wait. Damage and low charge can also be treated
              through normal synthetic medical care and cyborg rechargers.
            </Box>
          </Section>
        )}
        <Section title="Operating your shell">
          AI View returns you to the real AI eye at the shell’s location. Resume
          reconnects to that body after it moves. It remains vulnerable while
          unattended. Engineering Toolkit requires an empty right hand; drop
          retracts tools. AI Services provides core interfaces and a local
          network toggle. Physical interaction is the default.
        </Section>
      </Window.Content>
    </Window>
  );
};
