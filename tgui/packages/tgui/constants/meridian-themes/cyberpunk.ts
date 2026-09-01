// THIS IS AN APHELION UI FILE
import type { MeridianTheme } from './types';

export const cyberpunk = {
  id: 'meridian_cyberpunk',
  name: 'Cyberpunk',
  construction: '',
  production: true,
  palette: {
    canvas: '#090304',
    panel: '#0F0505',
    raised: '#1A090C',
    recessed: '#050203',
    boundary: '#C0152A',
    text: '#F7EDF0',
    mutedText: '#C9A9B0',
    accent: '#FF5267',
    secondaryAccent: '#00E5D4',
    focus: '#74FFF5',
  },
} as const satisfies MeridianTheme;
