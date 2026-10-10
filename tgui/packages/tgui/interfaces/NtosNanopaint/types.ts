import type { BooleanLike } from 'tgui-core/react';
import type {
  ServerColorData,
  SpriteEditorData,
} from '../common/SpriteEditor/Types/types';

export type NanopaintFileEntry = {
  name: string;
  extension: string;
  uid: number;
  baseType: string;
};

export type NanopaintNewDialogData = {
  type: 'new';
};

export type NanopaintFileDialogData = {
  type: 'select';
  title: string;
  confirmText: string;
  action: string;
};

export type NanopaintConfirmDialogData = {
  type: 'confirm';
  title: string;
  message: string;
  action: string;
  params: Record<string, unknown>;
};

export type NanopaintErrorDialogData = {
  type: 'error';
  message: string;
};
// APHELION EDIT ADDITION START - Art Galaxy.

export type NanopaintGalleryEntry = {
  name: string;
  ref: string;
  size: string;
};

export type NanopaintGalleryOpenDialogData = {
  type: 'galleryOpen';
};

export type NanopaintResizeDialogData = {
  type: 'resize';
  width: number;
  height: number;
};

export type NanopaintGalleryDialogData = {
  type: 'gallery';
  defaultTitle?: string;
  signature?: string;
  maxTitle?: number;
  size?: string;
  message?: string;
  busy?: BooleanLike;
};
// APHELION EDIT ADDITION END

export type NanopaintDialogData =
  | NanopaintNewDialogData
  | NanopaintFileDialogData
  | NanopaintConfirmDialogData
  | NanopaintGalleryDialogData // APHELION EDIT ADDITION - Art Galaxy.
  | NanopaintGalleryOpenDialogData // APHELION EDIT ADDITION - Art Galaxy.
  | NanopaintResizeDialogData // APHELION EDIT ADDITION - Canvas Size.
  | NanopaintErrorDialogData;

export type NanopaintData = {
  templateSizes: Record<string, [number, number]>;
  saveableTypes: { displayText: string; typepath: string; extension: string }[];
  editorData:
    | Required<ServerColorData>
    | (Required<ServerColorData> & SpriteEditorData);
  workspaceOpen: BooleanLike;
  driveFiles: NanopaintFileEntry[];
  diskFiles: NanopaintFileEntry[];
  minSize: number;
  maxSize: number;
  dialog?: NanopaintDialogData;
  diskInserted: BooleanLike;
  galleryBusy: BooleanLike; // APHELION EDIT ADDITION - Art Galaxy.
  galleryFiles?: NanopaintGalleryEntry[]; // APHELION EDIT ADDITION - Art Galaxy.
};
