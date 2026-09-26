// THIS IS AN APHELION UI FILE
import type { MeridianTheme } from './types';

export const diagnostic = {
  id: 'meridian_diagnostic',
  name: 'Diagnostic',
  construction: '',
  palette: {
    canvas: '#050D09',
    panel: '#091611',
    raised: '#123020',
    recessed: '#06100B',
    boundary: '#3F7354',
    text: '#E2F4E8',
    mutedText: '#98BAA3',
    accent: '#4AD879',
    secondaryAccent: '#79E79A',
    focus: '#B1FFD8',
  },
} as const satisfies MeridianTheme;
