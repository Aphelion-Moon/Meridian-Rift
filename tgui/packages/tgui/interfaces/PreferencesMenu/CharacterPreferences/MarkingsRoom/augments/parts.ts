// THIS IS AN APHELION UI FILE
import type { AugmentItem } from '../../../types';

/**
 * A socket on the augments stage: a slot of the character setup's augments
 * (its `slot`, as the server names it), the card it gets and where its trace
 * lands on the body. As the mockup lays them out (the lab's markings-themes
 * run, canvas/project/Augments.dc.html): cards down either side of the scan
 * chamber, the character's right side on our left.
 */
export type Socket = {
  slot: string;
  /** What its card calls it. */
  name: string;
  /** Its card's code: B for a body part, I for an internal. */
  code: string;
  side: 'l' | 'r';
  /** Its card's top, in room pixels. */
  top: number;
  /** Where its trace lands: a pixel of the character's 32px tile. */
  port: [number, number];
  /** The body regions it lights: an arm brings its hand along. */
  zones: string[];
};

export const PART_SOCKETS: readonly Socket[] = [
  {
    slot: 'Head',
    name: 'HEAD',
    code: 'B01',
    side: 'l',
    top: 64,
    port: [15.5, 5.5],
    zones: ['head'],
  },
  {
    slot: 'Right Arm',
    name: 'R ARM',
    code: 'B02',
    side: 'l',
    top: 259,
    port: [9, 14.5],
    zones: ['r_arm', 'r_hand'],
  },
  {
    slot: 'Right Leg',
    name: 'R LEG',
    code: 'B03',
    side: 'l',
    top: 454,
    port: [12, 27.5],
    zones: ['r_leg'],
  },
  {
    slot: 'Chest',
    name: 'CHEST',
    code: 'B04',
    side: 'r',
    top: 64,
    port: [15.5, 11],
    zones: ['chest'],
  },
  {
    slot: 'Left Arm',
    name: 'L ARM',
    code: 'B05',
    side: 'r',
    top: 259,
    port: [22, 14.5],
    zones: ['l_arm', 'l_hand'],
  },
  {
    slot: 'Left Leg',
    name: 'L LEG',
    code: 'B06',
    side: 'r',
    top: 454,
    port: [19, 27.5],
    zones: ['l_leg'],
  },
];

export const ORGAN_SOCKETS: readonly Socket[] = [
  {
    slot: 'Ears',
    name: 'EARS',
    code: 'I07',
    side: 'l',
    top: 64,
    port: [13, 2.5],
    zones: [],
  },
  {
    slot: 'Eyes',
    name: 'EYES',
    code: 'I08',
    side: 'l',
    top: 181,
    port: [14.5, 6.5],
    zones: [],
  },
  {
    slot: 'Tongue',
    name: 'TONGUE',
    code: 'I09',
    side: 'l',
    top: 298,
    port: [14.5, 8.8],
    zones: [],
  },
  {
    slot: 'Lungs',
    name: 'LUNGS',
    code: 'I10',
    side: 'l',
    top: 415,
    port: [13.2, 12.6],
    zones: [],
  },
  {
    slot: 'Liver',
    name: 'LIVER',
    code: 'I11',
    side: 'l',
    top: 532,
    port: [13, 16.5],
    zones: [],
  },
  {
    slot: 'Brain',
    name: 'BRAIN',
    code: 'I12',
    side: 'r',
    top: 124,
    port: [16.5, 4],
    zones: [],
  },
  {
    slot: 'Mouth implant',
    name: 'MOUTH',
    code: 'I13',
    side: 'r',
    top: 241,
    port: [16.5, 8.8],
    zones: [],
  },
  {
    slot: 'Heart',
    name: 'HEART',
    code: 'I14',
    side: 'r',
    top: 358,
    port: [17.3, 13.4],
    zones: [],
  },
  {
    slot: 'Stomach',
    name: 'STOMACH',
    code: 'I15',
    side: 'r',
    top: 475,
    port: [17, 17.4],
    zones: [],
  },
];

/** A body part card's height, and an internal's. */
export const PART_CARD_HEIGHT = 174;
export const ORGAN_CARD_HEIGHT = 94;
/** The cards' left edges, either side, and their width. */
export const CARD_LEFT = { l: 16, r: 638 } as const;
export const CARD_WIDTH = 246;

/** What a row of a card picks. */
export type Field = 'part' | 'finish' | 'implant' | 'organ';

export const FIELD_NAMES: Record<Field, string> = {
  part: 'AUGMENT',
  finish: 'FINISH',
  implant: 'IMPLANT',
  organ: 'REPLACEMENT',
};

/** A row's top, from its card's top, for the picker to unfold from. */
export const rowOffset = (top: number, row: number) => top + 2 + row * 40;

/** A point cost as a card shows it: blank when free, "+" when it gives points back. */
export function points(cost: number) {
  if (!cost) {
    return '';
  }
  const size = Math.abs(cost);
  return `${cost < 0 ? '+' : ''}${size}${size === 1 ? ' PT' : ' PTS'}`;
}

/**
 * A trace's path from its card to its port: it leaves the card level, runs
 * out, turns 45 degrees into the part and lands flat on it. With too little
 * room for the diagonal it climbs a short lane first.
 */
export function tracePath(
  sx: number,
  sy: number,
  ax: number,
  ay: number,
  dir: 1 | -1,
) {
  const tail = 12;
  const lane = 14;
  const rise = Math.abs(ay - sy);
  const sign = Math.sign(ay - sy);
  const room = (ax - sx) * dir - tail;
  const points: [number, number][] = [[sx, sy]];
  if (rise >= 1) {
    if (room - rise >= lane) {
      const bend = sx + dir * (room - rise);
      points.push([bend, sy], [bend + dir * rise, ay]);
    } else {
      const laneX = sx + dir * lane;
      const diagonal = Math.max(0, Math.min(rise, room - lane));
      const turnY = ay - sign * diagonal;
      points.push([laneX, sy]);
      if (Math.abs(turnY - sy) > 0.5) {
        points.push([laneX, turnY]);
      }
      points.push([laneX + dir * diagonal, ay]);
    }
  }
  points.push([ax, ay]);
  return `M${points.map(([x, y]) => `${x.toFixed(1)} ${y.toFixed(1)}`).join(' L')}`;
}

/** The species' own part when the server offers no replacement for this slot. */
export const STOCK_AUGMENT: AugmentItem = {
  path: null,
  name: 'None',
  cost: 0,
  extra_info: '',
  has_digi: 1,
  allows_styles: 0,
  allows_implants: 1,
  species_blacklist: null,
  species_whitelist: null,
  ckey_whitelist: null,
};

/** A body part's socket, as the stage shows it: what is in it and what it could take. */
export type StagePart = {
  socket: Socket;
  /** Its augment: the "None" entry, path null, while it's the species' own. */
  augment: AugmentItem;
  options: AugmentItem[];
  /** Its finish, the robotic style, or "None". */
  finish: string;
  /** The finishes its augment takes, "None" first; empty when it takes none. */
  finishes: string[];
  /** Its implant, when it has a socket for one. */
  implant: AugmentItem | null;
  /** The implants its socket takes, "None" first; null when it has no socket. */
  implants: AugmentItem[] | null;
  /** A taur body stands where its legs would: nothing fits. */
  unavailable: boolean;
};

/** An internal's socket: the organ or implant in it and the alternatives. */
export type StageOrgan = {
  socket: Socket;
  installed: AugmentItem;
  options: AugmentItem[];
};

/** Whether nothing is installed: the species' own part, or an empty socket. */
export const isStock = (item: AugmentItem | null | undefined) => !item?.path;
