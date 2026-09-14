// THIS IS AN APHELION UI FILE
import type {
  Dir,
  SpriteData,
  SpriteEditorToolFlags,
} from '../SpriteEditor/Types/types';

export type CustomSpriteEditorData = {
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
  unsupportedZones: string[];
};
