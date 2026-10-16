// THIS IS AN APHELION UI FILE
import type { MarkingColorMode } from '../../types';

/** A zone markings go on, as the server names it. */
export type MarkingZone =
  | 'head'
  | 'chest'
  | 'r_arm'
  | 'l_arm'
  | 'r_hand'
  | 'l_hand'
  | 'r_leg'
  | 'l_leg';

/** Every zone, in the order the room reads them. */
export const MARKING_ZONES: readonly MarkingZone[] = [
  'head',
  'chest',
  'r_arm',
  'l_arm',
  'r_hand',
  'l_hand',
  'r_leg',
  'l_leg',
];

export const ZONE_NAMES: Record<MarkingZone, string> = {
  head: 'Head',
  chest: 'Chest',
  r_arm: 'Right arm',
  l_arm: 'Left arm',
  r_hand: 'Right hand',
  l_hand: 'Left hand',
  r_leg: 'Right leg',
  l_leg: 'Left leg',
};

export const isLeg = (zone: string) => zone === 'l_leg' || zone === 'r_leg';

/** The custom drawing zone that takes the legs' place under a taur body. */
export const TAUR_ZONE = 'taur';

/** One zone's card round the mirror: its column and its row in it. */
type ZoneCard = { zone: MarkingZone; side: 'left' | 'right'; row: number };

/** The cards, as they deal in: the character faces us, so their right side is on our left. */
export const ZONE_CARDS: readonly ZoneCard[] = [
  { zone: 'head', side: 'left', row: 0 },
  { zone: 'r_arm', side: 'left', row: 1 },
  { zone: 'r_hand', side: 'left', row: 2 },
  { zone: 'r_leg', side: 'left', row: 3 },
  { zone: 'chest', side: 'right', row: 0 },
  { zone: 'l_arm', side: 'right', row: 1 },
  { zone: 'l_hand', side: 'right', row: 2 },
  { zone: 'l_leg', side: 'right', row: 3 },
];

/** Stuck-on cards hang a little crooked: each card's tilt in degrees, in card order. */
export const CARD_TILT = [-1.4, 0.9, -0.6, 1.2, 1.1, -0.8, 0.7, -1.3];

/** Where each zone sits in a 32px body sprite, [left, top, right, bottom]: thumbnails centre on it. */
export const ZONE_BOXES: Record<MarkingZone, [number, number, number, number]> =
  {
    head: [11, 3, 20, 10],
    chest: [10, 10, 21, 24],
    r_arm: [7, 11, 11, 18],
    l_arm: [20, 11, 24, 18],
    r_hand: [7, 18, 11, 22],
    l_hand: [20, 18, 24, 22],
    r_leg: [9, 23, 15, 32],
    l_leg: [16, 23, 22, 32],
  };

/** How many times a card's 46px tile zooms each zone. */
export const CARD_ZOOM: Record<MarkingZone, number> = {
  head: 4,
  chest: 3,
  r_arm: 5,
  l_arm: 5,
  r_hand: 6,
  l_hand: 6,
  r_leg: 4,
  l_leg: 4,
};

/** How many times the drawer's 60px tile zooms each zone. */
export const DRAWER_ZOOM: Record<MarkingZone, number> = {
  head: 5,
  chest: 4,
  r_arm: 6,
  l_arm: 6,
  r_hand: 8,
  l_hand: 8,
  r_leg: 5,
  l_leg: 5,
};

/** A card's tile, and the drawer's. */
export const CARD_TILE = 46;
export const DRAWER_TILE = 60;
/** The look book's picture of a whole character. */
export const BOOK_TILE = 64;

/** The markers on the counter, as the server's surprise paints with them too. */
export const PAINTS: readonly { color: string; name: string }[] = [
  { color: '#ff3fa4', name: 'hot pink' },
  { color: '#ff4040', name: 'signal red' },
  { color: '#ffb020', name: 'amber' },
  { color: '#f4f1e8', name: 'bone' },
  { color: '#1d1a22', name: 'ink' },
  { color: '#2ff3e0', name: 'cyan' },
  { color: '#3f8cff', name: 'electric blue' },
  { color: '#a066ff', name: 'violet' },
  { color: '#9dff4a', name: 'acid green' },
];

/** What a marking's colour follows until it's painted: one of the species' mutant colours, or its own. */
export const MUTANT_COLOR_NAMES: Record<MarkingColorMode, string> = {
  follows_primary: 'Mutant color 1',
  follows_secondary: 'Mutant color 2',
  follows_tertiary: 'Mutant color 3',
  fixed_default: 'Fixed color',
  locked: 'Fixed color',
};
