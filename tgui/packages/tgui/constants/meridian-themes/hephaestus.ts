// THIS IS AN APHELION UI FILE
import type { MeridianTheme } from './types';

export const hephaestus = {
  id: 'meridian_afterlight',
  name: 'Hephaestus',
  construction: '',
  production: true,
  palette: {
    canvas: '#10181D',
    panel: '#172127',
    raised: '#29353B',
    recessed: '#0C1317',
    boundary: '#A28C68',
    text: '#E6DECA',
    mutedText: '#B8B39F',
    accent: '#DCAD62',
    secondaryAccent: '#B4C6A3',
    focus: '#F3D39A',
  },
} as const satisfies MeridianTheme;
