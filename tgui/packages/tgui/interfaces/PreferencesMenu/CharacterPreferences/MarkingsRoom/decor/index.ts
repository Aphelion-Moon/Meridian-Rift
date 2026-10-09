// THIS IS AN APHELION UI FILE
import type { RoomThemeId } from '../themes';
import * as Aphelion from './Aphelion';
import * as Classic from './Classic';
import * as Club from './Club';
import * as Diagnostic from './Diagnostic';
import * as Electra from './Electra';
import * as Foundry from './Foundry';
import * as Hephaestus from './Hephaestus';
import * as Highline from './Highline';
import * as Hotline from './Hotline';
import * as Scavenger from './Scavenger';
import * as Shadowbroker from './Shadowbroker';
import * as Synapse from './Synapse';
import type { RoomDecor } from './types';
import * as Vector from './Vector';
import * as Wastelander from './Wastelander';

export { Tubes } from './Club';
export type { DecorProps, RoomDecor } from './types';

const club: RoomDecor = {
  Header: Club.Header,
  Glass: Club.Glass,
  GlassAfter: Club.GlassAfter,
};

/** Each room's decor, by where it hangs. */
export const ROOM_DECOR: Record<RoomThemeId, RoomDecor> = {
  aphelion: Aphelion,
  classic: Classic,
  electra: Electra,
  vector: Vector,
  synapse: Synapse,
  highline: Highline,
  hephaestus: Hephaestus,
  diagnostic: Diagnostic,
  augmentation: club,
  hotline: Hotline,
  cyberpunk: club,
  scavenger: Scavenger,
  wastelander: Wastelander,
  shadowbroker: Shadowbroker,
  foundry: Foundry,
};
