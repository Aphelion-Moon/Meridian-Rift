// THIS IS AN APHELION UI FILE
/** MeridianOS runtime theme resolution; editable definitions live in meridian-themes/. */
import {
  DEFAULT_MERIDIAN_BASE_THEME,
  MERIDIAN_BASE_THEME_IDS,
  MERIDIAN_CLASSIC_THEME_ID,
  MERIDIAN_THEME_IDS,
  type MeridianBaseThemeId,
  type MeridianThemeId,
} from './meridian-themes';

export * from './meridian-themes';

export const MERIDIAN_STATUS_COLORS = {
  information: '#63B4FF',
  success: '#54D98C',
  warning: '#F2BD52',
  danger: '#FF6B6B',
} as const;

const MERIDIAN_THEME_ID_SET = new Set<string>(MERIDIAN_THEME_IDS);
const MERIDIAN_BASE_THEME_ID_SET = new Set<string>(MERIDIAN_BASE_THEME_IDS);

// Themes with deliberately separate visual languages. Unknown runtime values
// are not allowed to create an unstyled `theme-*` class; they fall back to
// the default while these established specialty themes remain intact.
const SPECIALTY_THEME_ID_SET = new Set([
  'Heretic',
  'abductor',
  'admin',
  'armament',
  'cardtable',
  'clockwork',
  'dark',
  'generic',
  'hackerman',
  'heretic',
  'malfunction',
  'neutral',
  'ntOS95',
  'ntos_cat',
  'ntos_darkmode',
  'ntos_lightmode',
  'ntos_spooky',
  'ntos_synth',
  'ntos_terminal',
  'operating_computer',
  'paper',
  'retro',
  'slimecore',
  'spookyconsole',
  'syndicate',
  'wizard',
]);

const LEGACY_THEME_ALIASES: Readonly<Record<string, MeridianBaseThemeId>> = {
  nanotrasen: 'meridian',
  ntos: 'meridian',
  meridian_standard: 'meridian',
};

export function isMeridianTheme(theme: string): theme is MeridianThemeId {
  return MERIDIAN_THEME_ID_SET.has(theme);
}

export function isMeridianBaseTheme(
  theme: string,
): theme is MeridianBaseThemeId {
  return MERIDIAN_BASE_THEME_ID_SET.has(theme);
}

/** Normalize untrusted player-preference values to a selectable theme ID. */
export function normalizeMeridianBaseTheme(
  requested?: string | null,
): MeridianBaseThemeId {
  const aliased = requested
    ? (LEGACY_THEME_ALIASES[requested] ?? requested)
    : '';
  return isMeridianBaseTheme(aliased) ? aliased : DEFAULT_MERIDIAN_BASE_THEME;
}

/** Normalize the base token while retaining specialty modifier classes. */
export function normalizeMeridianTheme(requested?: string): string {
  const tokens = requested?.trim().split(/\s+/).filter(Boolean) ?? [];
  const base = tokens.shift() || DEFAULT_MERIDIAN_BASE_THEME;
  const aliasedBase = LEGACY_THEME_ALIASES[base] ?? base;
  const normalizedBase =
    isMeridianBaseTheme(aliasedBase) || SPECIALTY_THEME_ID_SET.has(aliasedBase)
      ? aliasedBase
      : DEFAULT_MERIDIAN_BASE_THEME;
  return [normalizedBase, ...tokens].join(' ');
}

export type ResolvedTheme = {
  base: string;
  classes: string[];
  isConsole: boolean;
};

/**
 * Resolution precedence: development override, specialty device theme,
 * player preference, requested theme, default.
 */
export type ResolveMeridianThemeOptions = {
  requested?: string;
  preferred?: MeridianBaseThemeId | null;
  debugOverride?: MeridianBaseThemeId | null;
};

export function resolveMeridianTheme(
  options: ResolveMeridianThemeOptions = {},
): ResolvedTheme {
  const { requested, preferred, debugOverride } = options;
  const normalizedRequested = normalizeMeridianTheme(requested);
  const [requestedBase, ...requestedModifiers] =
    normalizedRequested.split(/\s+/);
  const requestedIsSpecialty = SPECIALTY_THEME_ID_SET.has(requestedBase);
  const selectedTheme = debugOverride
    ? normalizeMeridianBaseTheme(debugOverride)
    : requestedIsSpecialty
      ? requestedBase
      : normalizeMeridianBaseTheme(preferred || requestedBase);
  const base =
    selectedTheme === MERIDIAN_CLASSIC_THEME_ID ? 'nanotrasen' : selectedTheme;
  const modifiers = debugOverride ? [] : requestedModifiers;
  const isConsole = isMeridianTheme(base);
  return {
    base,
    classes: [
      `theme-${base}`,
      // Classic NT borrows nanotrasen's paint wholesale, which leaves it
      // indistinguishable in CSS from a genuine legacy window. This marker is
      // the only thing separating the two, so Classic can be given geometry
      // fixes that must not reach the real legacy themes. It carries no paint.
      ...(selectedTheme === MERIDIAN_CLASSIC_THEME_ID
        ? [`theme-${MERIDIAN_CLASSIC_THEME_ID}`]
        : []),
      ...(isConsole ? ['theme-console'] : []),
      ...modifiers,
    ],
    isConsole,
  };
}

/** MeridianOS Base16 palette, used by the Kitchen Sink JSON inspector. */
export const MERIDIAN_BASE16 = {
  scheme: 'meridian16',
  author: 'Meridian-Rift contributors',
  base00: '#080D10',
  base01: '#0D171D',
  base02: '#18303A',
  base03: '#4B6B78',
  base04: '#9FB2BC',
  base05: '#E6EEF1',
  base06: '#F5F8F9',
  base07: '#FFFFFF',
  base08: MERIDIAN_STATUS_COLORS.danger,
  base09: MERIDIAN_STATUS_COLORS.warning,
  base0A: '#FFD84D',
  base0B: MERIDIAN_STATUS_COLORS.success,
  base0C: '#7AE2DB',
  base0D: '#58D1C9',
  base0E: '#C477E8',
  base0F: '#F0A35A',
} as const;
