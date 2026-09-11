import { atom } from 'jotai';

export type Meta = {
  album: string;
  artist: string;
  duration: string;
  link: string;
  title: string;
  upload_date: string;
};

export const playingAtom = atom(false);
export const visibleAtom = atom(false);
export const metaAtom = atom<Meta | null>(null);

export type LobbyMusicState = {
  enabled: boolean;
  playing: boolean;
  looping: boolean;
  volume: number;
  selected: string;
  currentTrack: string;
  serverTrack: string;
  tracks: { id: string; name: string }[];
};

export const lobbyMusicAtom = atom<LobbyMusicState | null>(null);

//------- Convenience --------------------------------------------------------//

export const audioAtom = atom((get) => ({
  playing: get(playingAtom),
  visible: get(visibleAtom),
  meta: get(metaAtom),
}));
