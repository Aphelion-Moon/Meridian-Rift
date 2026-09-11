import { afterEach, beforeEach, describe, expect, it, spyOn } from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import { Provider } from 'jotai';
import { store } from '../events/store';
import { type LobbyMusicState, lobbyMusicAtom } from './atoms';
import { LobbyMusicControls } from './LobbyMusicControls';

const initialMusic: LobbyMusicState = {
  enabled: true,
  playing: true,
  looping: true,
  volume: 80,
  selected: 'server',
  currentTrack: 'Geoxor Virtual',
  serverTrack: 'Geoxor Virtual',
  tracks: [{ id: 'snowfall-id', name: 'Snowfall' }],
};

function showPlayer(music: LobbyMusicState | null = initialMusic) {
  store.set(lobbyMusicAtom, music);
  return render(
    <Provider store={store}>
      <LobbyMusicControls />
    </Provider>,
  );
}

describe('lobby music controls', () => {
  let sendMessage: ReturnType<typeof spyOn>;

  beforeEach(() => {
    sendMessage = spyOn(Byond, 'sendMessage');
  });

  afterEach(() => {
    cleanup();
    sendMessage.mockRestore();
    store.set(lobbyMusicAtom, null);
  });

  it('requests state when opened and shows a loading state', () => {
    showPlayer(null);
    expect(screen.getByText('Loading title music...')).toBeDefined();
    expect(sendMessage).toHaveBeenCalledWith('audio/lobby/request');
  });

  it('defaults to the server choice and submits an explicit track ID', async () => {
    showPlayer();
    const select = screen.getByPlaceholderText('Server selection (default)');
    await act(async () => fireEvent.click(select));
    await act(async () => fireEvent.click(screen.getByText('Snowfall')));
    expect(sendMessage).toHaveBeenCalledWith('audio/lobby/select', {
      id: 'snowfall-id',
    });
  });

  it('updates a removed preference back to the server selection', () => {
    showPlayer({
      ...initialMusic,
      selected: 'snowfall-id',
      currentTrack: 'Snowfall',
    });
    expect(screen.getByPlaceholderText('Snowfall')).toBeDefined();
    act(() => store.set(lobbyMusicAtom, initialMusic));
    expect(
      screen.getByPlaceholderText('Server selection (default)'),
    ).toBeDefined();
  });

  it('offers stop and restart for playing music, then play when stopped', () => {
    showPlayer();
    fireEvent.click(screen.getByText('Stop'));
    expect(sendMessage).toHaveBeenCalledWith('audio/lobby/stop');
    fireEvent.click(screen.getByText('Restart'));
    expect(sendMessage).toHaveBeenCalledWith('audio/lobby/restart');
    act(() => store.set(lobbyMusicAtom, { ...initialMusic, playing: false }));
    fireEvent.click(screen.getByText('Play'));
    expect(sendMessage).toHaveBeenCalledWith('audio/lobby/play');
  });

  it('explains muted music and prevents inaudible play requests', () => {
    showPlayer({ ...initialMusic, playing: false, volume: 0 });
    expect(
      screen.getByText('Muted. Raise the volume to hear title music.'),
    ).toBeDefined();
    sendMessage.mockClear();
    fireEvent.click(screen.getByText('Play'));
    expect(sendMessage).not.toHaveBeenCalled();
  });

  it('disables playback when the server disallows title music', () => {
    showPlayer({ ...initialMusic, enabled: false, playing: false });
    expect(
      screen.getByText('Title music is unavailable on this server.'),
    ).toBeDefined();
    sendMessage.mockClear();
    fireEvent.click(screen.getByText('Play'));
    fireEvent.click(screen.getByText('Restart'));
    expect(sendMessage).not.toHaveBeenCalled();
  });
});
