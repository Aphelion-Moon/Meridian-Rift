import { useAtomValue } from 'jotai';
import { useEffect } from 'react';
import {
  Box,
  Button,
  Dropdown,
  Section,
  Slider,
  Stack,
} from 'tgui-core/components';
import { lobbyMusicAtom } from './atoms';

export function LobbyMusicControls() {
  const music = useAtomValue(lobbyMusicAtom);

  useEffect(() => {
    const refresh = () => Byond.sendMessage('audio/lobby/request');
    refresh();
    const interval = setInterval(refresh, 5000);
    return () => clearInterval(interval);
  }, []);

  return (
    <Section title="Title / lobby music">
      {!music ? (
        <Box color="label">Loading title music...</Box>
      ) : (
        <Stack vertical>
          <Stack.Item>
            <Dropdown
              fluid
              searchInput
              width="100%"
              maxItems={8}
              menuWidth="100%"
              disabled={!music.enabled}
              selected={music.selected}
              displayText={
                music.tracks.find((track) => track.id === music.selected)
                  ?.name || 'Server selection (default)'
              }
              options={[
                { value: 'server', displayText: 'Server selection (default)' },
                ...music.tracks.map((track) => ({
                  value: track.id,
                  displayText: track.name,
                })),
              ]}
              onSelected={(id: string) =>
                Byond.sendMessage('audio/lobby/select', { id })
              }
            />
          </Stack.Item>
          <Stack.Item color="label">
            {music.playing ? 'Playing: ' : 'Selected: '}
            {music.currentTrack}
          </Stack.Item>
          {music.selected !== 'server' && (
            <Stack.Item color="label">
              Server selection: {music.serverTrack}
            </Stack.Item>
          )}
          <Stack.Item>
            <Stack>
              <Stack.Item>
                <Button
                  icon={music.playing ? 'stop' : 'play'}
                  disabled={!music.enabled || (!music.playing && !music.volume)}
                  onClick={() =>
                    Byond.sendMessage(
                      music.playing ? 'audio/lobby/stop' : 'audio/lobby/play',
                    )
                  }
                >
                  {music.playing ? 'Stop' : 'Play'}
                </Button>
                <Button
                  icon="rotate-left"
                  disabled={!music.enabled || !music.volume}
                  onClick={() => Byond.sendMessage('audio/lobby/restart')}
                >
                  Restart
                </Button>
              </Stack.Item>
              <Stack.Item grow>
                <Slider
                  minValue={0}
                  maxValue={100}
                  step={1}
                  value={music.volume}
                  disabled={!music.enabled}
                  format={(value) => `${Math.round(value)}%`}
                  onChange={(_, volume) =>
                    Byond.sendMessage('audio/lobby/volume', { volume })
                  }
                />
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item color="label" fontSize="0.9em">
            {!music.enabled
              ? 'Title music is unavailable on this server.'
              : !music.volume
                ? 'Muted. Raise the volume to hear title music.'
                : 'Loops in the lobby; finishes the track after joining or observing.'}
          </Stack.Item>
        </Stack>
      )}
    </Section>
  );
}
