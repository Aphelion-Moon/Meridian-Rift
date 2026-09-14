import type {
  Dir,
  SpriteData,
  SpriteEditorToolFlags,
} from '../SpriteEditor/Types/types';

export type CustomSpriteEditorData = {
  editorData: {
    sprite: SpriteData;
    undoStack: string[];
    redoStack: string[];
    toolFlags: SpriteEditorToolFlags;
    serverPalette: string[];
  };
  tint: string | null;
  guides: Record<Dir, string>;
  previews: Record<Dir, string>;
  edited: Record<Dir, boolean>;
  drawBounds: Record<Dir, [number, number, number, number] | null>;
  unsupportedZones: string[];
};
