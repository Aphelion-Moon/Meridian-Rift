// Aphelion display-grade renderer contract. All values are normalized sRGB.
export type DisplayGradeSettings = {
  strength: number;
  saturation: number;
  contrast: number;
  brightness: number;
  shadow_color: string;
  shadow_strength: number;
  midtone_color: string;
  midtone_strength: number;
  highlight_color: string;
  highlight_strength: number;
};

export const DISPLAY_GRADE_REFERENCE: Readonly<DisplayGradeSettings> =
  Object.freeze({
    strength: 1,
    saturation: 0.72,
    contrast: 1,
    brightness: 0,
    shadow_color: '#2D2639',
    shadow_strength: 1,
    midtone_color: '#718A83',
    midtone_strength: 0.4,
    highlight_color: '#D6C998',
    highlight_strength: 1,
  });

const LUMA = [0.2126, 0.7152, 0.0722];
const BANDS = ['shadow', 'midtone', 'highlight'] as const;
export const DISPLAY_GRADE_RANGES = {
  strength: [0, 1],
  saturation: [0, 1.5],
  contrast: [0.5, 1.5],
  brightness: [-0.2, 0.2],
  shadow_strength: [0, 1],
  midtone_strength: [0, 1],
  highlight_strength: [0, 1],
} as const;

export function validateDisplayGrade(
  value: unknown,
): DisplayGradeSettings | null {
  if (!value || typeof value !== 'object') return null;
  const source = value as Record<string, unknown>;
  const result = { ...DISPLAY_GRADE_REFERENCE };
  for (const key of Object.keys(DISPLAY_GRADE_RANGES)) {
    const [min, max] = DISPLAY_GRADE_RANGES[key];
    const field = source[key];
    if (
      typeof field !== 'number' ||
      !Number.isFinite(field) ||
      field < min ||
      field > max
    ) {
      return null;
    }
    result[key] = field;
  }
  for (const band of BANDS) {
    const key = `${band}_color` as const;
    const field = source[key];
    if (
      typeof field !== 'string' ||
      field.length !== 7 ||
      !/^#[0-9a-fA-F]{6}$/.test(field)
    ) {
      return null;
    }
    result[key] = field.toUpperCase();
  }
  return result;
}

function rgb(hex: string): number[] {
  return [1, 3, 5].map(
    (offset) => Number.parseInt(hex.slice(offset, offset + 2), 16) / 255,
  );
}

/** Output-major 4x5 matrix; clamp once after all three adjustments. */
export function displayGradeAdjustment(
  settings: DisplayGradeSettings,
): number[] {
  const { saturation, contrast, brightness } = settings;
  const bias = (1 - contrast) / 2 + brightness;
  return [0, 1, 2]
    .flatMap((output) => [
      ...LUMA.map(
        (luma, input) =>
          contrast *
          ((input === output ? saturation : 0) + (1 - saturation) * luma),
      ),
      0,
      bias,
    ])
    .concat([0, 0, 0, 1, 0]);
}

/** Acceptance oracle only. Rendering uses the SVG graph, never pixel readback. */
export function displayGradeSample(
  rgba: readonly number[],
  settings: DisplayGradeSettings,
): number[] {
  const matrix = displayGradeAdjustment(settings);
  const adjusted = [0, 1, 2].map((channel) =>
    Math.max(
      0,
      Math.min(
        1,
        rgba
          .slice(0, 3)
          .reduce((sum, value, i) => sum + value * matrix[channel * 5 + i], 0) +
          matrix[channel * 5 + 4],
      ),
    ),
  );
  const luma = adjusted.reduce((sum, value, i) => sum + value * LUMA[i], 0);
  const shadow = Math.max(1 - 2 * luma, 0);
  const highlight = Math.max(2 * luma - 1, 0);
  const weights = [shadow, 1 - shadow - highlight, highlight];
  const graded = [0, 0, 0];
  BANDS.forEach((band, index) => {
    const color = rgb(settings[`${band}_color`]);
    const strength = settings[`${band}_strength`];
    for (let channel = 0; channel < 3; channel++) {
      graded[channel] +=
        weights[index] *
        (adjusted[channel] * (1 - strength) + color[channel] * strength);
    }
  });
  return graded
    .map(
      (value, i) =>
        rgba[i] * (1 - settings.strength) + value * settings.strength,
    )
    .concat(rgba[3]);
}

/**
 * Standalone SVG graph, also usable by the future legacy-browser bootstrap.
 * Work in opaque RGB so arithmetic compositing cannot multiply source alpha
 * repeatedly. feColorMatrix unpremultiplies its input; restore SourceAlpha once.
 * No settings strings are interpolated before validation.
 */
export function displayGradeFilter(id: string, value: unknown): string {
  const settings = validateDisplayGrade(value);
  if (!settings || !/^[a-zA-Z][\w-]*$/.test(id)) {
    throw new Error('Invalid display grade filter');
  }
  // Identity really is a bypass, including partially transparent colors.
  if (settings.strength === 0) return '';
  const parts: string[] = [];
  const matrix = (input: string, result: string, values: number[]) => {
    parts.push(
      `<feColorMatrix in="${input}" result="${result}" type="matrix" values="${values.join(' ')}"/>`,
    );
  };
  const arithmetic = (
    input: string,
    other: string,
    result: string,
    k1: number,
    k2: number,
    k3: number,
    k4 = 0,
  ) => {
    parts.push(
      `<feComposite in="${input}" in2="${other}" result="${result}" operator="arithmetic" k1="${k1}" k2="${k2}" k3="${k3}" k4="${k4}"/>`,
    );
  };
  const opaque = (scale: number, color = [0, 0, 0]) => [
    scale,
    0,
    0,
    0,
    color[0],
    0,
    scale,
    0,
    0,
    color[1],
    0,
    0,
    scale,
    0,
    color[2],
    0,
    0,
    0,
    0,
    1,
  ];
  const mask = (slope: number, bias: number) => [
    ...[0, 1, 2].flatMap(() => [...LUMA.map((v) => v * slope), 0, bias]),
    0,
    0,
    0,
    0,
    1,
  ];
  matrix('SourceGraphic', 'original', opaque(1));
  matrix('original', 'adjusted', displayGradeAdjustment(settings));
  matrix('adjusted', 'shadow-mask', mask(-2, 1));
  matrix('adjusted', 'highlight-mask', mask(2, -1));
  // Subtract RGB masks, but force alpha back to 1 before using arithmetic
  // multiplication (subtracting two opaque masks otherwise makes alpha zero).
  arithmetic('shadow-mask', 'highlight-mask', 'outer-mask', 0, 1, 1);
  matrix('outer-mask', 'midtone-mask', opaque(-1, [1, 1, 1]));
  for (const band of BANDS) {
    const strength = settings[`${band}_strength`];
    matrix(
      'adjusted',
      `${band}-tint`,
      opaque(
        1 - strength,
        rgb(settings[`${band}_color`]).map((v) => v * strength),
      ),
    );
    arithmetic(`${band}-tint`, `${band}-mask`, `${band}-weighted`, 1, 0, 0);
  }
  arithmetic('shadow-weighted', 'midtone-weighted', 'lower', 0, 1, 1);
  arithmetic('lower', 'highlight-weighted', 'graded', 0, 1, 1);
  arithmetic(
    'original',
    'graded',
    'mixed',
    0,
    1 - settings.strength,
    settings.strength,
  );
  parts.push('<feComposite in="mixed" in2="SourceAlpha" operator="in"/>');
  return `<filter id="${id}" x="0" y="0" width="100%" height="100%" color-interpolation-filters="sRGB">${parts.join('')}</filter>`;
}
