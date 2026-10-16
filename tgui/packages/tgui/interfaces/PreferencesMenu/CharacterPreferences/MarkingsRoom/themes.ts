// THIS IS AN APHELION UI FILE

/** The MeridianOS themes, as their room knows them: each one's id without its `meridian_`. */
export type RoomThemeId =
  | 'aphelion'
  | 'classic'
  | 'electra'
  | 'vector'
  | 'synapse'
  | 'highline'
  | 'hephaestus'
  | 'diagnostic'
  | 'augmentation'
  | 'hotline'
  | 'cyberpunk'
  | 'scavenger'
  | 'wastelander'
  | 'shadowbroker'
  | 'foundry';

/** What a room calls its things. */
export type RoomLabels = {
  /** The header's switch for the lights. */
  lights: string;
  /** The selected marking's glow. */
  glow: string;
  /** The marking sets. */
  book: string;
  /** A random set. */
  surprise: string;
};

/**
 * A theme's Augments+ room, as far as the page needs to know it. Most of how a
 * room looks is its stylesheet's (styles/meridianos/markings-room/), and what
 * hangs in it is its decor's (decor/); see the mockups in the lab's
 * markings-themes run, whose THEMES table this is.
 */
export type RoomTheme = {
  id: RoomThemeId;
  /**
   * Where its glass's top left stands in the room. The character stands where
   * the club's does in every room, whatever its glass, as the mockups draw it.
   */
  glass: [number, number];
  /**
   * How much larger its window is than the club's, [width, height], for a
   * thicker frame round the room: Foundry's and Hephaestus's cast frames.
   */
  frame: [number, number];
  /** How crooked its cards hang, against the club's. */
  tilt: number;
  /** The club's neon tubes and clips round the glass. */
  tubes: boolean;
  /**
   * A UV tube over the glass that lights when the lights go out, and lights
   * the character in its colour. Only rooms where a blacklight makes sense
   * have one; elsewhere the lights going out leaves the room dark.
   */
  blacklight: boolean;
  /** What its cards carry in their corner, if anything. Vector's number theirs. */
  tag: string;
  labels: RoomLabels;
};

const CLUB: Omit<RoomTheme, 'id'> = {
  glass: [284, 92],
  frame: [0, 0],
  tilt: 1,
  tubes: true,
  blacklight: true,
  tag: '',
  labels: {
    lights: 'Lights',
    glow: 'Glow',
    book: 'Marking Sets',
    surprise: 'Random',
  },
};

/** A room on the club's lines, with its own changes. */
const room = (
  id: RoomThemeId,
  changes: Partial<Omit<RoomTheme, 'id' | 'labels'>> = {},
  labels: Partial<RoomLabels> = {},
): RoomTheme => ({
  ...CLUB,
  ...changes,
  id,
  labels: { ...CLUB.labels, ...labels },
});

export const ROOM_THEMES: Record<RoomThemeId, RoomTheme> = {
  aphelion: room('aphelion'),
  classic: room('classic', {
    glass: [292, 96],
    tilt: 0,
    tubes: false,
    blacklight: false,
  }),
  electra: room('electra', {
    glass: [290, 88],
    tubes: false,
    blacklight: false,
  }),
  // Vector's room is its holo blueprint (the mockup's vector_holo).
  vector: room('vector', {
    tilt: 0,
    tubes: false,
    blacklight: false,
    tag: 'DETAIL',
  }),
  synapse: room('synapse', { tilt: 0, tubes: false }),
  highline: room('highline', {
    glass: [286, 94],
    tilt: 0,
    tubes: false,
    blacklight: false,
  }),
  hephaestus: room('hephaestus', {
    glass: [298, 106],
    frame: [40, 6],
    tilt: 0,
    tubes: false,
    blacklight: false,
  }),
  diagnostic: room('diagnostic', { tilt: 0, tubes: false, blacklight: false }),
  augmentation: room('augmentation'),
  hotline: room('hotline', {
    glass: [292, 100],
    tilt: 0.6,
    tubes: false,
    tag: 'VIP',
  }),
  cyberpunk: room('cyberpunk'),
  scavenger: room('scavenger', { tilt: 1.3, tubes: false, blacklight: false }),
  wastelander: room('wastelander', {
    glass: [294, 100],
    tilt: 0,
    tubes: false,
    blacklight: false,
  }),
  shadowbroker: room('shadowbroker', {
    glass: [294, 130],
    tilt: 0.5,
    tubes: false,
    tag: 'AS IS',
  }),
  foundry: room('foundry', {
    glass: [294, 106],
    frame: [40, 6],
    tilt: 0.5,
    tubes: false,
    blacklight: false,
  }),
};

/**
 * The themes whose rooms are built so far. The rest keep the old columns
 * until theirs is: a theme joins this when its room is done.
 */
export const BUILT_ROOMS: ReadonlySet<RoomThemeId> = new Set<RoomThemeId>([
  'aphelion',
  'classic',
  'electra',
  'vector',
  'synapse',
  'highline',
  'hephaestus',
  'diagnostic',
  'augmentation',
  'hotline',
  'cyberpunk',
  'scavenger',
  'wastelander',
  'shadowbroker',
  'foundry',
]);

/** A card's tag: the theme's, Vector's numbered by the card's place. */
export const cardTag = (theme: RoomTheme, order: number) =>
  theme.tag === 'DETAIL' ? `DETAIL 0${order + 1}` : theme.tag;
