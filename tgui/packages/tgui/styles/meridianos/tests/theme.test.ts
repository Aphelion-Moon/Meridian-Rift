// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';
import {
  DEFAULT_MERIDIAN_BASE_THEME,
  MERIDIAN_BASE_THEME_IDS,
  MERIDIAN_BASE_THEME_OPTIONS,
  MERIDIAN_THEME_IDS,
  MERIDIAN_THEMES,
  normalizeMeridianBaseTheme,
  normalizeMeridianTheme,
  resolveMeridianTheme,
} from '../../../constants/theme';

function channelToLinear(channel: number): number {
  const normalized = channel / 255;
  return normalized <= 0.04045
    ? normalized / 12.92
    : ((normalized + 0.055) / 1.055) ** 2.4;
}

function luminance(hex: string): number {
  const channels = hex
    .match(/[0-9a-f]{2}/gi)
    ?.map((value) => channelToLinear(Number.parseInt(value, 16)));
  if (channels?.length !== 3) {
    throw new Error(`Invalid hex color: ${hex}`);
  }
  return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
}

function contrast(first: string, second: string): number {
  const lighter = Math.max(luminance(first), luminance(second));
  const darker = Math.min(luminance(first), luminance(second));
  return (lighter + 0.05) / (darker + 0.05);
}

describe('MeridianOS theme catalog', () => {
  it('contains fourteen palette skins and fifteen ordered player themes', () => {
    expect(new Set(MERIDIAN_THEME_IDS).size).toBe(14);
    expect(new Set(MERIDIAN_BASE_THEME_IDS).size).toBe(15);
    expect(DEFAULT_MERIDIAN_BASE_THEME).toBe('meridian_aphelion');
    expect(MERIDIAN_THEME_IDS).toEqual([
      'meridian_aphelion',
      'meridian',
      'meridian_vector',
      'meridian_synapse',
      'meridian_highline',
      'meridian_afterlight',
      'meridian_diagnostic',
      'meridian_augmentation',
      'meridian_synapse_xxxo',
      'meridian_cyberpunk',
      'meridian_bastion',
      'meridian_pipboy',
      'meridian_relay',
      'meridian_foundry',
    ]);
    expect(MERIDIAN_BASE_THEME_IDS).toEqual([
      'meridian_aphelion',
      'meridian_classic',
      'meridian',
      'meridian_vector',
      'meridian_synapse',
      'meridian_highline',
      'meridian_afterlight',
      'meridian_diagnostic',
      'meridian_augmentation',
      'meridian_synapse_xxxo',
      'meridian_cyberpunk',
      'meridian_bastion',
      'meridian_pipboy',
      'meridian_relay',
      'meridian_foundry',
    ]);
    expect(MERIDIAN_BASE_THEME_OPTIONS.slice(0, 3)).toEqual([
      expect.objectContaining({ id: 'meridian_aphelion', name: 'Aphelion' }),
      expect.objectContaining({ id: 'meridian_classic', name: 'Classic' }),
      expect.objectContaining({ id: 'meridian', name: 'Electra' }),
    ]);
    expect(MERIDIAN_THEMES.every(({ production }) => production)).toBe(true);
    expect(
      MERIDIAN_BASE_THEME_OPTIONS.find(
        ({ id }) => id === 'meridian_synapse_xxxo',
      ),
    ).toMatchObject({ name: 'Hotline', production: true });
  });

  it('meets text, status-boundary, selection, and focus contrast contracts', () => {
    for (const { id, palette } of MERIDIAN_THEMES) {
      for (const surface of [
        palette.canvas,
        palette.panel,
        palette.raised,
        palette.recessed,
      ]) {
        expect(
          contrast(palette.text, surface),
          `${id}: primary text`,
        ).toBeGreaterThanOrEqual(4.5);
        expect(
          contrast(palette.mutedText, surface),
          `${id}: muted text`,
        ).toBeGreaterThanOrEqual(4.5);
      }

      expect(
        contrast(palette.boundary, palette.panel),
        `${id}: boundary`,
      ).toBeGreaterThanOrEqual(3);
      expect(
        contrast(palette.accent, palette.panel),
        `${id}: accent`,
      ).toBeGreaterThanOrEqual(3);
      expect(
        contrast(palette.secondaryAccent, palette.panel),
        `${id}: selected`,
      ).toBeGreaterThanOrEqual(3);
      expect(
        contrast(palette.canvas, palette.secondaryAccent),
        `${id}: text on selection`,
      ).toBeGreaterThanOrEqual(4.5);
      expect(
        contrast(palette.focus, palette.panel),
        `${id}: focus on panel`,
      ).toBeGreaterThanOrEqual(3);
      expect(
        contrast(palette.focus, palette.canvas),
        `${id}: focus on canvas`,
      ).toBeGreaterThanOrEqual(3);
    }
  });
});

describe('MeridianOS theme resolution', () => {
  it('normalizes base legacy values without rewriting specialty themes', () => {
    expect(normalizeMeridianTheme()).toBe('meridian_aphelion');
    expect(normalizeMeridianTheme('nanotrasen')).toBe('meridian');
    expect(normalizeMeridianTheme('ntos')).toBe('meridian');
    expect(normalizeMeridianTheme('ntos_terminal')).toBe('ntos_terminal');
    expect(normalizeMeridianTheme('paper')).toBe('paper');
    expect(normalizeMeridianBaseTheme('meridian_classic')).toBe(
      'meridian_classic',
    );
    expect(normalizeMeridianBaseTheme('meridian_pipboy')).toBe(
      'meridian_pipboy',
    );
    expect(normalizeMeridianTheme('meridian_pipboy')).toBe('meridian_pipboy');
    expect(normalizeMeridianBaseTheme('unregistered-theme')).toBe(
      'meridian_aphelion',
    );
  });

  it('resolves Aphelion as a requested or saved console theme', () => {
    expect(normalizeMeridianBaseTheme('meridian_aphelion')).toBe(
      'meridian_aphelion',
    );
    expect(normalizeMeridianTheme('meridian_aphelion')).toBe(
      'meridian_aphelion',
    );
    for (const options of [
      { requested: 'meridian_aphelion' },
      { requested: 'meridian', preferred: 'meridian_aphelion' as const },
    ]) {
      expect(resolveMeridianTheme(options)).toEqual({
        base: 'meridian_aphelion',
        classes: ['theme-meridian_aphelion', 'theme-console'],
        isConsole: true,
      });
    }
  });

  it('retains Synapse XXXO as a requested, saved, or debug console theme', () => {
    expect(normalizeMeridianBaseTheme('meridian_synapse_xxxo')).toBe(
      'meridian_synapse_xxxo',
    );
    expect(normalizeMeridianTheme('meridian_synapse_xxxo')).toBe(
      'meridian_synapse_xxxo',
    );
    for (const options of [
      { requested: 'meridian_synapse_xxxo' },
      { requested: 'meridian', preferred: 'meridian_synapse_xxxo' as const },
      { requested: 'paper', debugOverride: 'meridian_synapse_xxxo' as const },
    ]) {
      expect(resolveMeridianTheme(options)).toEqual({
        base: 'meridian_synapse_xxxo',
        classes: ['theme-meridian_synapse_xxxo', 'theme-console'],
        isConsole: true,
      });
    }
  });

  it('falls unknown requested themes back to Aphelion', () => {
    expect(normalizeMeridianTheme('unregistered-theme')).toBe(
      'meridian_aphelion',
    );
    expect(resolveMeridianTheme({ requested: 'unregistered-theme' })).toEqual({
      base: 'meridian_aphelion',
      classes: ['theme-meridian_aphelion', 'theme-console'],
      isConsole: true,
    });
  });

  it('preserves modifier classes and marks only the Meridian family as console', () => {
    expect(
      resolveMeridianTheme({
        requested: 'heretic heretic-theme-ascended',
      }),
    ).toEqual({
      base: 'heretic',
      classes: ['theme-heretic', 'heretic-theme-ascended'],
      isConsole: false,
    });
    expect(resolveMeridianTheme({ requested: 'ntos' })).toEqual({
      base: 'meridian',
      classes: ['theme-meridian', 'theme-console'],
      isConsole: true,
    });
  });

  it('gives the development override precedence over the requested theme', () => {
    expect(
      resolveMeridianTheme({
        requested: 'paper',
        debugOverride: 'meridian_vector',
      }),
    ).toEqual({
      base: 'meridian_vector',
      classes: ['theme-meridian_vector', 'theme-console'],
      isConsole: true,
    });
  });

  it('applies the player preference without replacing specialty themes', () => {
    expect(
      resolveMeridianTheme({
        requested: 'meridian',
        preferred: 'meridian_pipboy',
      }),
    ).toEqual({
      base: 'meridian_pipboy',
      classes: ['theme-meridian_pipboy', 'theme-console'],
      isConsole: true,
    });
    expect(
      resolveMeridianTheme({
        requested: 'meridian_vector',
        preferred: 'meridian_classic',
      }),
    ).toEqual({
      base: 'nanotrasen',
      // Classic wears nanotrasen's paint but carries its own marker, which is
      // the only way CSS can reach it without also reaching genuine legacy
      // windows. A real nanotrasen window must never gain this class.
      classes: ['theme-nanotrasen', 'theme-meridian_classic'],
      isConsole: false,
    });
    expect(
      resolveMeridianTheme({ requested: 'nanotrasen' }).classes,
    ).not.toContain('theme-meridian_classic');
    expect(
      resolveMeridianTheme({ requested: 'ntos_darkmode' }).classes,
    ).not.toContain('theme-meridian_classic');
    expect(
      resolveMeridianTheme({
        requested: 'paper',
        preferred: 'meridian_cyberpunk',
      }),
    ).toEqual({
      base: 'paper',
      classes: ['theme-paper'],
      isConsole: false,
    });
  });
});
