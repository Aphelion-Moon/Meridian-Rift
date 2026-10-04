import { Box, Button, NoticeBox, Section, Stack } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Cell = {
  index: number;
  symbol: string;
  available: boolean;
  used: boolean;
};

type Data = {
  grid: Cell[];
  grid_size: number;
  targets: string[][];
  completed: boolean[];
  buffer: string[];
  buffer_limit: number;
  select_row: boolean;
  started: boolean;
  seconds_left: number;
  can_stabilize: boolean;
  recovery_seconds: number;
  self_test: boolean;
  revision: number;
};

export const PersonalCacheLock = () => {
  const { act, data } = useBackend<Data>();
  const {
    grid,
    grid_size,
    targets,
    completed,
    buffer,
    buffer_limit,
    select_row,
    started,
    seconds_left,
    can_stabilize,
    recovery_seconds,
    self_test,
    revision,
  } = data;

  return (
    <Window width={650} height={640}>
      <Window.Content scrollable>
        <NoticeBox info>
          {self_test
            ? 'Practice: your attunement will remain intact.'
            : 'Upload both signatures to remove the current attunement.'}{' '}
          Start on the top row, then alternate column and row. Each cell can be
          used once. Plan before your first pulse starts the trace.
        </NoticeBox>
        <Stack>
          <Stack.Item grow>
            <Section title="Routing grid">
              <Box mb={1} bold>
                {started
                  ? `Next pulse: highlighted ${select_row ? 'row' : 'column'}`
                  : 'First pulse: top row'}
              </Box>
              <Box
                style={{
                  display: 'grid',
                  gridTemplateColumns: `repeat(${grid_size}, 1fr)`,
                  gap: '4px',
                }}
              >
                {grid.map((cell) => (
                  <Button
                    key={cell.index}
                    aria-label={`Pulse ${cell.symbol}, row ${Math.floor((cell.index - 1) / grid_size) + 1}, column ${((cell.index - 1) % grid_size) + 1}`}
                    aria-disabled={!cell.available}
                    fluid
                    textAlign="center"
                    fontFamily="monospace"
                    fontSize={1.3}
                    lineHeight={2.5}
                    selected={cell.available}
                    disabled={!cell.available}
                    tooltip={`Row ${Math.floor((cell.index - 1) / grid_size) + 1}, column ${((cell.index - 1) % grid_size) + 1}${cell.used ? ': consumed' : ''}`}
                    onClick={() => act('pulse', { cell: cell.index, revision })}
                  >
                    {cell.used ? '×' : cell.symbol}
                  </Button>
                ))}
              </Box>
            </Section>
          </Stack.Item>
          <Stack.Item width={18}>
            <Section title="Required signatures">
              {targets.map((target, index) => (
                <Box key={target.join('-')} mb={2}>
                  <Box color={completed[index] ? 'good' : 'label'} mb={0.5}>
                    {completed[index]
                      ? `Signature ${index + 1}: uploaded`
                      : `Signature ${index + 1}: pending`}
                  </Box>
                  <Box fontFamily="monospace" fontSize={1.2}>
                    {target.join(' ')}
                  </Box>
                </Box>
              ))}
              <Box color="label">
                Match each signature consecutively in the buffer. Either order
                works; overlapping symbols can complete both signatures.
              </Box>
            </Section>
            <Section title={started ? 'Trace remaining' : 'Planning'}>
              <Box fontSize={2} color={seconds_left <= 15 ? 'bad' : 'good'}>
                {seconds_left}s
              </Box>
              {!started && (
                <Box color="label">Timer starts on first pulse.</Box>
              )}
            </Section>
          </Stack.Item>
        </Stack>
        <Section title={`Buffer: ${buffer.length} / ${buffer_limit}`}>
          <Stack>
            {Array.from({ length: buffer_limit }, (_, index) => (
              <Stack.Item grow key={`slot-${index + 1}`}>
                <Box
                  backgroundColor={
                    buffer[index] ? 'rgba(70, 170, 210, 0.2)' : undefined
                  }
                  textAlign="center"
                  fontFamily="monospace"
                  fontSize={1.4}
                  p={1}
                >
                  {buffer[index] || '·'}
                </Box>
              </Stack.Item>
            ))}
          </Stack>
        </Section>
        <Section title="Recovery">
          <Button
            icon="clock"
            disabled={!can_stabilize}
            onClick={() => act('stabilize', { revision })}
          >
            Stabilize: +{recovery_seconds}s
          </Button>
          <Box mt={1} color="label">
            One use. Reduces buffer capacity by one slot. Keeps signature
            progress and your current row or column.
          </Box>
        </Section>
        <Button
          icon="power-off"
          color="bad"
          onClick={() => act('abort', { revision })}
        >
          Disconnect
        </Button>
        {!self_test && (
          <Box inline ml={1} color="label">
            Failure or disconnect after the first pulse causes a 30s lockout.
          </Box>
        )}
      </Window.Content>
    </Window>
  );
};
