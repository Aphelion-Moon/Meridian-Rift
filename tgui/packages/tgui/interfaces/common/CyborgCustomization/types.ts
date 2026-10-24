import type { BooleanLike } from 'tgui-core/react';
import type { ProfileFieldData } from './ProfileFields';

export const CYBORG_SLOTS = [
  'penis',
  'sheath',
  'testicles',
  'vagina',
  'anus',
  'breasts',
] as const;
export type CyborgSlot = (typeof CYBORG_SLOTS)[number];

export const editorLabel = (value: string) =>
  ({
    idle: 'Standing',
    rest: 'Resting',
    sit: 'Sitting',
    bellyup: 'Belly up',
    rest_deep: 'Deep rest',
    rest_alt: 'Resting (alternate)',
    sit_alt: 'Sitting (alternate)',
    none: 'Unaroused',
    partial: 'Partially aroused',
    full: 'Fully aroused',
    base: 'All arousal states',
  })[value] || value.charAt(0).toUpperCase() + value.slice(1);

export const CYBORG_DIRECTIONS: Record<string, number> = {
  north: 1,
  south: 2,
  east: 4,
  west: 8,
};
export type DirectionEntry = {
  visible: boolean | number;
  pixel_x: number;
  pixel_y: number;
  rotation: number;
  scale: number;
  priority: number;
  arousal?: Record<string, Partial<Omit<DirectionEntry, 'arousal'>>>;
};
export type LayoutEntry = {
  sprite?: string;
  placement_groups?: Record<
    string,
    { pixel_x: number; pixel_y: number; rotation: number }
  >;
  mirror_sides?: boolean | number;
  reuse_south?: boolean | number;
  sprite_size?: number;
  pixel_x: number;
  pixel_y: number;
  rotation: number;
  scale: number;
  colors: string[];
  advanced: Record<string, DirectionEntry>;
};
export type Layout = Record<CyborgSlot, LayoutEntry>;
export type LayoutStore = {
  schema_version: number;
  preset_models?: Record<string, string>;
  model_presets?: Record<string, string>;
  active_preset?: string;
  active: Layout;
  presets: Record<string, Layout>;
  model_defaults: Record<string, Layout>;
};
/** Preset bodies remain on the server; the UI only tests their presence by name. */
export type CyborgEditorStore = Omit<LayoutStore, 'presets'> & {
  presets: Record<string, unknown>;
};
export type CyborgGallery = {
  generation: string;
  catalog_url: string;
  department?: string;
  thumbnails_url?: string;
};
export type CyborgCustomizationData = {
  gallery?: CyborgGallery;
  gallery_loading?: boolean;
  gallery_error?: boolean;
  /** Replaced drafts invalidate commands; ordinary edits only advance revision. */
  context?: number;
  revision?: number;
  resources_pending?: boolean;
  /** Only body/layer pixel changes interrupt placement; option metadata does not. */
  preview_pending?: boolean;
  /** Geometry paired with the last delivered resource set while a refresh waits. */
  rendered_preview?: Pick<
    CyborgCustomizationData,
    | 'model'
    | 'pose'
    | 'direction'
    | 'arousal'
    | 'moving'
    | 'wide'
    | 'body_scale'
    | 'layers'
  > | null;
  save_status?: {
    pending: boolean;
    revision: number;
    session_only: boolean;
    error?: string;
  };
  wide?: boolean | number;
  reference?: string;
  parts?: Partial<Record<CyborgSlot, PartMetadata>>;
  layout_source?: 'active' | 'model_default';
  model_default_available?: BooleanLike;
  allowed: boolean;
  occlusion?: string;
  moving: boolean;
  animation?: {
    /** Missing images reuse the corresponding static preview image. */
    body?: string;
    occlusion?: string;
    x: number;
    y: number;
    delay: number;
  }[];
  unsupported?: boolean;
  models: {
    id: string;
    department: string;
    skin: string;
    thumbnail?: string;
    thumbnail_directions?: Record<string, string>;
  }[];
  body_width: number;
  body_height: number;
  body_scale: number;
  map_view?: number[];
  map_zoom?: number;
  model: string;
  poses: string[];
  pose: string;
  direction: number;
  arousal: string;
  body: string | null;
  layers?: {
    mirror_x?: number;
    slot?: CyborgSlot;
    icon: string;
    x: number;
    y: number;
    rotation: number;
    scale: number;
    priority: number;
  }[];
  store: CyborgEditorStore;
  message?: string;
};
export type PartMetadata = {
  effective_size?: number;
  sizes: { value: number; label: string; icon?: string }[];
  color_channels: number[];
};
export type LayoutAction = (params: Record<string, unknown>) => void;
export type PlacementCommand = {
  operation: 'set_placement' | 'nudge_placement' | 'inherit_placement';
  slot: CyborgSlot;
  target: {
    scope: 'base' | 'pose' | 'arousal';
    direction: string | number;
    pose: string;
    arousal: string;
  };
  changes?: Partial<Omit<DirectionEntry, 'arousal'>>;
};

/** What the editor's window gets from its backend. */
export type CyborgEditorData = {
  cyborg_customization?: CyborgCustomizationData;
  cyborg_resources?:
    | (Partial<CyborgCustomizationData> & {
        layer_icons?: Record<string, string>;
      })
    | null;
  /** The borg's name, which character setup's alternate names set too. */
  name?: string;
  /** A preference this character can't have is left out. */
  values?: Record<string, unknown> | null;
  active_slot?: number;
  preference_data?: Record<string, ProfileFieldData>;
};
