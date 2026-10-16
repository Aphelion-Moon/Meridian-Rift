// THIS IS AN APHELION UI FILE
import type { ComponentType } from 'react';

/** What a room's decor can show of the world: most of it shows nothing but itself. */
export type DecorProps = {
  /** The station's time, HH:MM, as Electra's mirror shows it. */
  clock: string;
  /** Whether the room's lights are off. */
  lightsOff: boolean;
  /** Turns them, as the header's switch does (Electra's bulb key is one). */
  onLights: () => void;
  /** Whether the room's lighting falls on the character (lightEffects.ts). */
  lightEffects: boolean;
  /** Turns that, as the header's second switch does (Electra's sun key is one). */
  onLightEffects: () => void;
  /** Rounds since the engine last delaminated, as Hephaestus's tag says; a dash before the server says. */
  delamRounds: number | string;
};

/**
 * A theme's decor, by where it hangs in the room:
 * - Wall: on the wall, behind the cards;
 * - Header: on the wall behind the header;
 * - Frame: round the glass (frames, lamps, tubes, tags);
 * - Glass: on the glass, in front of the character;
 * - GlassAfter: over that.
 */
export type RoomDecor = Partial<
  Record<
    'Wall' | 'Header' | 'Frame' | 'Glass' | 'GlassAfter',
    ComponentType<DecorProps>
  >
>;
