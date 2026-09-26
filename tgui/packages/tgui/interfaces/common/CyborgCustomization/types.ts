export const CYBORG_SLOTS = [
  'penis',
  'sheath',
  'testicles',
  'vagina',
  'anus',
  'breasts',
] as const;
export type CyborgSlot = (typeof CYBORG_SLOTS)[number];
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
export type CyborgCustomizationData = {
  /** Replaced drafts invalidate commands; ordinary edits only advance revision. */
  context?: number;
  revision?: number;
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
  model_default_available?: boolean;
  allowed: boolean;
  occlusion?: string;
  moving: boolean;
  animation?: {
    body: string;
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
  store: LayoutStore;
  message?: string;
};
export type PartMetadata = {
  effective_size?: number;
  sizes: { value: number; label: string; icon?: string }[];
  color_channels: number[];
};
export type LayoutAction = (params: Record<string, unknown>) => void;
export type PlacementCommand = {
  operation: 'set_placement' | 'inherit_placement';
  slot: CyborgSlot;
  target: {
    scope: 'base' | 'pose' | 'arousal';
    direction: string | number;
    pose: string;
    arousal: string;
  };
  changes?: Partial<Omit<DirectionEntry, 'arousal'>>;
};

// A single registry is shared by the creator and ordinary preference filtering.
export const CYBORG_VISUAL_KEYS = [
  'silicon_gender',
  'cyborg_size',
  ...CYBORG_SLOTS.map((slot) => `silicon_${slot}_sprite`),
];
export const CYBORG_LORE_KEYS = [
  'custom_species_silicon',
  'silicon_flavor_text',
  'silicon_flavor_text_nsfw',
  'silicon_headshot',
  'silicon_headshot_nsfw',
  'ooc_notes_silicon',
  'ooc_notes_silicon_nsfw',
  'custom_species_lore_silicon',
];
// Shared AI/silicon controls remain reachable in ordinary character setup.
export const CYBORG_ONLY_KEYS = new Set([
  'silicon_headshot_nsfw',
  'cyborg_size',
  'silicon_genital_layout_presets',
  ...CYBORG_SLOTS.map((slot) => `silicon_${slot}_sprite`),
  'custom_species_silicon',
  'ooc_notes_silicon',
  'ooc_notes_silicon_nsfw',
  'custom_species_lore_silicon',
]);
