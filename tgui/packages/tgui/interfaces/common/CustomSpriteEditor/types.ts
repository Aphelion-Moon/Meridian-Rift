// THIS IS AN APHELION UI FILE
import type { BooleanLike } from 'tgui-core/react';
import type { MarkingInfo } from '../../PreferencesMenu/types';
import type {
  BaseCopyInfo,
  BaseCopyResult,
  Dir,
  SpriteEditorToolFlags,
} from '../SpriteEditor/Types/types';
import type { Appendage, TryOnHat } from './appendages';
import type { CompactSprite } from './canvas';

export type CustomSpriteCandidate = {
  source: 'import' | 'restore';
  previews: Record<Dir, string> | null;
  summary?: string | null;
  regions?: string[];
  skipped?: string[];
};

export type RegionMarking = {
  index: number;
  name: string;
  color: string;
  /** The marking always wears its own colour, so none can be picked. */
  locked?: BooleanLike;
};

/**
 * What the base markings' sticker sheets draw from, as character setup's
 * markings room has it, sent the first time one opens (send_marking_sheets()).
 */
export type MarkingSheetsData = {
  /** The body it was made for; the static markingSheetsKey says which the body is now. */
  key: string;
  info: Record<string, MarkingInfo>;
  /** The colour each fixed marking starts in, by name. */
  defaults: Record<string, string>;
  /** The three mutant colours the rest follow. */
  fur: [string, string, string];
  species: string;
  speciesName: string;
  /** The species' class on the species page's sheets. */
  speciesIcon: string;
};

/** One graffiti layer, as the editor lists them from the bottom up. */
export type GraffitiLayer = {
  id: string;
  /** HTML-escaped, as the server cleans it. */
  name: string;
  glow: BooleanLike;
};

/**
 * A flattened picture in the g1/g2 codec (graffitiCodec.ts): a saved piece's thumbnail, what a
 * stopped paint job revealed, or the graffiti already on a surface. Always GRAFFITI_HEIGHT tall.
 */
export type GraffitiArt = {
  w: number;
  /** Nine-character `#rrggbbaa` entries, one per colour. */
  pal: string;
  /** Palette indices, 0 transparent. */
  grid: string;
  /** 1 where it glows. */
  glow: string;
};

/** The graffiti editor's own fields, sent with every update. */
export type GraffitiData = {
  kind: 'studio' | 'surface';
  width: number;
  layers: GraffitiLayer[];
  /** The can's charges in a surface session; null in the studio or for a can that never runs out. */
  charges: number | null;
  canSave: BooleanLike;
  /** The paint uses GRAFFITI_MAX_COLORS colours, so the piece takes no new one. */
  full: BooleanLike;
  libraryCount: number | null;
  libraryCap: number;
  /** The surface isn't one graffiti stays on past the round. */
  roundOnly: BooleanLike;
  /** The surface takes one tile only, as a poster does, so the width never changes. */
  oneTile?: BooleanLike;
  /** The library piece this is, once saved. */
  pieceId: string | null;
};

/** A saved piece as the spray can's Custom Graffiti tab lists it. */
export type GraffitiLibraryEntry = {
  id: string;
  /** HTML-escaped, as the server cleans it. */
  name: string;
  /** HTML-escaped, as the server cleans it. */
  description: string;
  width: number;
  /** Unix seconds, as text. */
  created: string;
  updated: string;
  glow: BooleanLike;
  /** How many layers it has. */
  layers: number;
  thumb: GraffitiArt;
};

/** The Unfinished slot: the last interrupted or unsaved piece. */
export type GraffitiUnfinished = Omit<GraffitiLibraryEntry, 'id'> & {
  id: null;
  /** Where it can carry on; null for a studio draft. Opaque to the window but for its progress. */
  resume: { progress: number } | null;
  /** -1 for a freehand draft; otherwise the strips a stopped paint job had revealed. */
  progress: number | null;
  /** What a stopped paint job revealed, flattened. */
  revealed: GraffitiArt | null;
};

export type CustomSpriteBackground = {
  name: string;
  url: string;
  wideUrl: string;
  tallUrl: string;
};

export type CustomSpriteEditorData = {
  context?: 'preferences' | 'salon' | 'graffiti';
  baseCopyInfo?: BaseCopyInfo | null;
  baseCopyResult?: BaseCopyResult;
  editorData: {
    sprite: CompactSprite;
    undoStack: string[];
    redoStack: string[];
    toolFlags: SpriteEditorToolFlags;
    serverPalette: string[];
    serverSelectedColor: string;
  };
  colorMode: 'literal' | 'hair' | 'mutant' | 'tint';
  /** Absent for graffiti, which glows by layer. */
  emissive?: Record<Dir, boolean>;
  emissiveAllowed: boolean;
  saveRevision: number;
  saveError?: string | null;
  customTint: string;
  displayTint: string | null;
  customPalette: string[];
  availableColors: string[];
  maxCustomColors: number;
  guides: Record<Dir, string>;
  previews: Record<Dir, string>;
  /**
   * Each view's glow, for the preview's lights-off view: what glows in its
   * picture, or "" when nothing does. Sent only while the window has its
   * lights off; a view's comes once it's drawn.
   */
  glows?: Partial<Record<Dir, string>> | null;
  /** How far what glows blooms with the lights off: the player's bloom setting. */
  bloom?: number | null;
  edited: Record<Dir, boolean>;
  drawBounds: Record<Dir, [number, number, number, number] | null>;
  drawMask?: Partial<Record<Dir, string[]>> | null;
  resourcesReady?: boolean;
  transferError?: string | null;
  transferNotice?: string | null;
  /** Counts notices, so the status line shows each one for a moment, even one that repeats the last. */
  noticeRevision?: number;
  candidate: CustomSpriteCandidate | null;
  canRestorePrevious?: boolean;
  canChangeHair?: boolean;
  hasGradient?: BooleanLike;
  canHideParts?: BooleanLike;
  hideParts?: BooleanLike;
  canHideUnderwear?: BooleanLike;
  hideUnderwear?: BooleanLike;
  showGradient?: BooleanLike;
  maxBaseMarkings?: number;
  lockedDirections?: string[] | null;
  hairStyle?: string | null;
  hairStyles?: string[];
  hairStyleIcons?: Record<string, string>;
  hairColor?: string | null;
  recipientName?: string;
  selfWork?: boolean;
  salonState?: 'drafting' | 'awaiting approval' | 'applying' | 'completed';
  /** How long the salon's finishing touches take, in milliseconds. */
  applyDuration?: number;
  backgrounds?: CustomSpriteBackground[];
  defaultBackground?: string | null;
  regions?: Partial<Record<Dir, string[]>> | null;
  regionZones?: string[];
  regionLabels?: Record<string, string>;
  selectedZone?: string | null;
  focusRevision?: number;
  regionMarkings?: Record<string, RegionMarking[]>;
  regionMarkingChoices?: Record<string, string[]>;
  regionMarkingIcons?: Record<string, Record<string, string>>;
  /** Static: the key of the sheets' data for the body as it is now. */
  markingSheetsKey?: string;
  /** Sent once a sheet first asks, and kept. */
  markingSheets?: MarkingSheetsData;
  regionEmissive?: Record<string, Record<Dir, boolean>>;
  lockedRegions?: Record<string, string> | null;
  paletteNotice?: string | null;
  strokeNotice?: string | null;
  visibleView?: string;
  /** Direction -> "1"/"0" rows: canvas pixels hair, a part, underwear or clothing draws over in game. Static data, markings only. */
  coverMask?: Partial<Record<Dir, string[]>> | null;
  /** The covering parts named by the cover rows' marks: 1-9 then a-z index into it. Static data. */
  coverParts?: string[];
  /** 1 where the covering part at that index is a worn item, which blocks work on a region it covers. Static data. */
  coverWorn?: number[];
  /** The hair's appendage layers, in order. Hair only. */
  appendages?: Appendage[];
  maxAppendages?: number;
  maxAppendageName?: number;
  /** The Try on hat the previews wear, or null. */
  tryOn?: string | null;
  /** An appendage layer to switch to, sent once after one is added or copied. */
  focusLayer?: string | null;
  /** Try on hats by key. Static data, hair only. */
  tryOnHats?: Record<string, TryOnHat>;
  /** Graffiti only. */
  graffiti?: GraffitiData;
  /** The colours offered before a piece has its own. Static data, graffiti only. */
  defaultPalette?: string[];
  /**
   * The graffiti already on each tile a surface session paints, beneath its own piece: one art or
   * null per tile, left first. Static data, surface sessions only.
   */
  graffitiBackground?: (GraffitiArt | null)[] | null;
};
