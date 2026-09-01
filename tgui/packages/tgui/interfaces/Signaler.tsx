import { Button, NumberInput, Section, Stack } from 'tgui-core/components';
import { toFixed } from 'tgui-core/math';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  code: number;
  frequency: number;
  cooldown: number;
  minFrequency: number;
  maxFrequency: number;
};

export const Signaler = (props) => {
  const { act, data } = useBackend();
  return (
    <Window width={280} height={128}>
      {/* APHELION EDIT CHANGE - responsive controls; ORIGINAL: <Window.Content> */}
      <Window.Content scrollable>
        <SignalerContent />
      </Window.Content>
    </Window>
  );
};

export const SignalerContent = (props) => {
  const { act, data } = useBackend<Data>();
  const { code, frequency, cooldown, minFrequency, maxFrequency } = data;

  const color = 'rgba(13, 13, 213, 0.7)';
  const backColor = 'rgba(0, 0, 69, 0.5)';
  return (
    <Section>
      {/* APHELION EDIT CHANGE - responsive controls; ORIGINAL: <Stack> */}
      <Stack className="MeridianControlRow">
        <Stack.Item color="label">Frequency:</Stack.Item>
        {/* APHELION EDIT CHANGE - responsive controls; ORIGINAL: <Stack.Item> */}
        <Stack.Item className="MeridianControlRow__fill MeridianControlRow__fill--small">
          <NumberInput
            animated
            tickWhileDragging
            unit="kHz"
            step={0.2}
            stepPixelSize={6}
            minValue={minFrequency / 10}
            maxValue={maxFrequency / 10}
            value={frequency / 10}
            format={(value) => toFixed(value, 1)}
            width="80px"
            onChange={(value) =>
              act('freq', {
                freq: value,
              })
            }
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            ml={1.3}
            icon="sync"
            content="Reset"
            onClick={() =>
              act('reset', {
                reset: 'freq',
              })
            }
          />
        </Stack.Item>
      </Stack>
      {/* APHELION EDIT CHANGE - responsive controls; ORIGINAL: <Stack mt={0.6}> */}
      <Stack mt={0.6} className="MeridianControlRow">
        <Stack.Item pr={5.3} color="label">
          Code:
        </Stack.Item>
        {/* APHELION EDIT CHANGE - responsive controls; ORIGINAL: <Stack.Item> */}
        <Stack.Item className="MeridianControlRow__fill MeridianControlRow__fill--small">
          <NumberInput
            animated
            tickWhileDragging
            step={1}
            stepPixelSize={6}
            minValue={1}
            maxValue={100}
            value={code}
            width="80px"
            onChange={(value) =>
              act('code', {
                code: value,
              })
            }
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            ml={1.3}
            icon="sync"
            content="Reset"
            onClick={() =>
              act('reset', {
                reset: 'code',
              })
            }
          />
        </Stack.Item>
      </Stack>
      {/* APHELION EDIT CHANGE - responsive controls; ORIGINAL: <Stack mt={0.8}> */}
      <Stack mt={0.8} className="MeridianControlRow">
        {/* APHELION EDIT CHANGE - responsive controls; ORIGINAL: <Stack.Item ml={10.5}> */}
        <Stack.Item ml={10.5} className="MeridianControlRow__fill">
          <Button
            mb={-0.1}
            fluid
            tooltip={cooldown && `Cooldown: ${cooldown * 0.1} seconds`}
            icon="arrow-up"
            content="Send Signal"
            textAlign="center"
            onClick={() => act('signal')}
          />
        </Stack.Item>
      </Stack>
    </Section>
  );
};
