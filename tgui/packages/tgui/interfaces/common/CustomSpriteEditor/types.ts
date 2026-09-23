// THIS IS AN APHELION UI FILE
import type {
  Dir,
  SpriteData,
  SpriteEditorToolFlags,
} from '../SpriteEditor/Types/types';

export type CustomSpriteCandidate = {
  source: 'import' | 'restore';
  previews: Record<Dir, string>;
  summary?: string | null;
};

export type CustomSpriteEditorData = {
  context?: 'preferences' | 'salon';
  bodyZone: string | null;
  bodyZoneLabel: string | null;
  editorData: {
    sprite: SpriteData;
    undoStack: string[];
    redoStack: string[];
    toolFlags: SpriteEditorToolFlags;
    serverPalette: string[];
    serverSelectedColor: string;
  };
  colorMode: 'literal' | 'hair' | 'tint';
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
  hasGradient?: boolean;
  canHideParts?: boolean;
  hideParts?: boolean;
  canHideUnderwear?: boolean;
  hideUnderwear?: boolean;
  wholeBodyTaur?: boolean;
  showGradient?: boolean;
  canChangeMarkings?: boolean;
  baseMarkings?: { index: number; name: string; color: string }[];
  baseMarkingChoices?: string[];
  maxBaseMarkings?: number;
  lockedDirections?: string[] | null;
  hairStyle?: string | null;
  hairStyles?: string[];
  hairColor?: string | null;
  recipientName?: string;
  selfWork?: boolean;
  salonState?: 'drafting' | 'awaiting approval' | 'applying' | 'completed';
};
