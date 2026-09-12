// THIS IS AN APHELION UI FILE
import type { MeridianTheme } from './types';

export const electra = {
  id: 'meridian_electra',
  name: 'Electra',
  construction: '',
  palette: {
    canvas: '#080D10',
    panel: '#0D171D',
    raised: '#18303A',
    recessed: '#091217',
    boundary: '#4B6B78',
    text: '#E6EEF1',
    mutedText: '#9FB2BC',
    accent: '#58D1C9',
    secondaryAccent: '#7AE2DB',
    focus: '#FFD84D',
  },
} as const satisfies MeridianTheme;
