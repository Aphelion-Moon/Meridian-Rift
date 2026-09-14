// THIS IS AN APHELION UI FILE
/** Theme definitions and menu order. See styles/meridianos/README.md to add one. */
import { aphelion } from './aphelion';
import { augmentation } from './augmentation';
import { classic } from './classic';
import { cyberpunk } from './cyberpunk';
import { diagnostic } from './diagnostic';
import { electra } from './electra';
import { foundry } from './foundry';
import { hephaestus } from './hephaestus';
import { highline } from './highline';
import { hotline } from './hotline';
import { scavenger } from './scavenger';
import { shadowbroker } from './shadowbroker';
import { synapse } from './synapse';
import { vector } from './vector';
import { wastelander } from './wastelander';

export type { MeridianTheme, MeridianThemePalette } from './types';

/** The player menu and development picker use this order directly. */
export const MERIDIAN_BASE_THEME_OPTIONS = [
  aphelion,
  classic,
  electra,
  vector,
  synapse,
  highline,
  hephaestus,
  diagnostic,
  augmentation,
  hotline,
  cyberpunk,
  scavenger,
  wastelander,
  shadowbroker,
  foundry,
] as const;

/** Console themes are the catalog entries that provide a Meridian palette. */
export const MERIDIAN_THEMES = MERIDIAN_BASE_THEME_OPTIONS.filter(
  (theme) => 'palette' in theme,
);

export type MeridianThemeId = (typeof MERIDIAN_THEMES)[number]['id'];
export type MeridianBaseThemeId =
  (typeof MERIDIAN_BASE_THEME_OPTIONS)[number]['id'];

export const MERIDIAN_THEME_IDS = MERIDIAN_THEMES.map(({ id }) => id);
export const MERIDIAN_BASE_THEME_IDS = MERIDIAN_BASE_THEME_OPTIONS.map(
  ({ id }) => id,
);

export const MERIDIAN_CLASSIC_THEME_ID = classic.id;
export const DEFAULT_MERIDIAN_BASE_THEME: MeridianBaseThemeId = aphelion.id;
