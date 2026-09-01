// THIS IS AN APHELION UI FILE
import type { MeridianTheme } from './types';

export const scavenger = {
  id: 'meridian_scavenger',
  name: 'Scavenger',
  construction: '',
  palette: {
    canvas: '#100D0A',
    panel: '#1A1712',
    raised: '#2B251D',
    recessed: '#080705',
    boundary: '#7C6E50',
    text: '#F0E7CE',
    mutedText: '#C9BEA3',
    accent: '#D5A84C',
    secondaryAccent: '#9AAA8C',
    focus: '#FFE6A3',
  },
} as const satisfies MeridianTheme;
