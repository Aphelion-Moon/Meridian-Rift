import { useEffect, useRef, useState } from 'react';
import { Box, Input, Stack } from 'tgui-core/components';
import { useDebouncedCommit } from '../useDebouncedCommit';

export function ColorControls({
  colors,
  channels,
  disabled,
  onChange,
}: {
  colors: string[];
  channels: number[];
  disabled?: boolean;
  onChange: (colors: string[]) => void;
}) {
  const [draft, setDraft] = useState(colors);
  const latest = useRef(colors);
  const { pending, schedule, flush } = useDebouncedCommit(onChange);
  // Compare channel values, since unrelated preview updates can rebuild arrays.
  const saved = JSON.stringify(colors);
  useEffect(() => {
    if (!pending.current) {
      latest.current = colors;
      setDraft(colors);
    }
  }, [saved]);
  const setColor = (index: number, value: string) => {
    if (!/^#[\da-f]{6}$/i.test(value) || value === latest.current[index])
      return;
    const next = [...latest.current];
    next[index] = value;
    latest.current = next;
    setDraft(next);
    schedule(next);
  };
  return channels.map((channel) => {
    const index = channel - 1;
    const color = draft[index] || '#ffffff';
    return (
      <Stack key={channel} align="center" mb={0.5}>
        <Stack.Item grow>
          <Box color="label">Channel {channel}</Box>
        </Stack.Item>
        <Stack.Item>
          <input
            type="color"
            aria-label={`Color channel ${channel}`}
            disabled={disabled}
            value={color}
            onChange={(event) => setColor(index, event.currentTarget.value)}
            onBlur={flush}
          />
        </Stack.Item>
        <Stack.Item width="7rem">
          <Input
            fluid
            value={color}
            maxLength={7}
            disabled={disabled}
            onBlur={(value) => {
              setColor(index, value);
              flush();
            }}
          />
        </Stack.Item>
      </Stack>
    );
  });
}
