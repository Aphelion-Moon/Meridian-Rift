// THIS IS AN APHELION UI FILE
export type MeridianThemePalette = {
  canvas: string;
  panel: string;
  raised: string;
  recessed: string;
  boundary: string;
  text: string;
  mutedText: string;
  accent: string;
  secondaryAccent: string;
  focus: string;
};

/** A selectable theme. Classic uses upstream styles and has no console palette. */
export type MeridianTheme = {
  id: string;
  name: string;
  construction: string;
  /** Omit for the shared NETWORK ACCESS instrument menu. */
  lobby?: {
    heading?: string;
    layout?: 'instrument' | 'custom';
  };
  palette?: MeridianThemePalette;
  /** CSS background for the menu swatch, when the two accents do not carry it. */
  preview?: string;
};
