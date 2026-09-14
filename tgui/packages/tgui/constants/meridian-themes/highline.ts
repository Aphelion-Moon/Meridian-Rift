// THIS IS AN APHELION UI FILE
import type { MeridianTheme } from './types';

export const highline = {
  id: 'meridian_highline',
  name: 'Highline',
  construction: '',
  lobby: { layout: 'custom' },
  palette: {
    canvas: '#10151A',
    panel: '#171E24',
    raised: '#29343D',
    recessed: '#0D1216',
    boundary: '#77868F',
    text: '#C9D0D3',
    mutedText: '#AFBAC1',
    accent: '#B9C5CA',
    secondaryAccent: '#A6C5D3',
    focus: '#9DC7DE',
  },
} as const satisfies MeridianTheme;
