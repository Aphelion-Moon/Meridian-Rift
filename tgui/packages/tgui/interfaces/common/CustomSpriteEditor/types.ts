// THIS IS AN APHELION UI FILE
import type { BooleanLike } from 'tgui-core/react';
import type { Dir, SpriteEditorToolFlags } from '../SpriteEditor/Types/types';
import type { CompactSprite } from './canvas';

export type CustomSpriteCandidate = {
  source: 'import' | 'restore';
  previews: Record<Dir, string> | null;
  summary?: string | null;
  regions?: string[];
  skipped?: string[];
};

export type RegionMarking = { index: number; name: string; color: string };

export type CustomSpriteBackground = {
  name: string;
  url: string;
  wideUrl: string;
  tallUrl: string;
};

export type CustomSpriteEditorData = {
  context?: 'preferences' | 'salon';
  editorData: {
    sprite: CompactSprite;
    undoStack: string[];
    redoStack: string[];
    toolFlags: SpriteEditorToolFlags;
    serverPalette: string[];
    serverSelectedColor: string;
  };
  colorMode: 'literal' | 'hair' | 'mutant' | 'tint';
  emissive: Record<Dir, boolean>;
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
  edited: Record<Dir, boolean>;
  drawBounds: Record<Dir, [number, number, number, number] | null>;
  drawMask?: Partial<Record<Dir, string[]>> | null;
  resourcesReady?: boolean;
  transferError?: string | null;
  transferNotice?: string | null;
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
  hairColor?: string | null;
  recipientName?: string;
  selfWork?: boolean;
  salonState?: 'drafting' | 'awaiting approval' | 'applying' | 'completed';
  backgrounds?: CustomSpriteBackground[];
  defaultBackground?: string | null;
  regions?: Partial<Record<Dir, string[]>> | null;
  regionZones?: string[];
  regionLabels?: Record<string, string>;
  selectedZone?: string | null;
  focusRevision?: number;
  regionMarkings?: Record<string, RegionMarking[]>;
  regionMarkingChoices?: Record<string, string[]>;
  regionEmissive?: Record<string, Record<Dir, boolean>>;
  lockedRegions?: Record<string, string> | null;
  paletteNotice?: string | null;
  strokeNotice?: string | null;
  visibleView?: string;
  /** Direction -> "1"/"0" rows: canvas pixels hair or a part draws over in game. Static data, markings only. */
  coverMask?: Partial<Record<Dir, string[]>> | null;
  /** The covering parts named by the cover rows' marks: 1-9 then a-z index into it. Static data. */
  coverParts?: string[];
};
