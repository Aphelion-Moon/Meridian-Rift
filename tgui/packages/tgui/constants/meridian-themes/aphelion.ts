// THIS IS AN APHELION UI FILE
import type { MeridianTheme } from './types';

export const aphelion = {
  id: 'meridian_aphelion',
  name: 'Aphelion',
  construction: '',
  production: true,
  preview:
    'linear-gradient(90deg, #41f4ff 0%, #79ff79 20%, #ffe675 40%, #ffa966 60%, #ff697b 80%, #e596f3 100%)',
  palette: {
    canvas: '#131110',
    panel: '#1A1714',
    raised: '#211D19',
    recessed: '#0E0C0B',
    boundary: '#8F887C',
    text: '#ECE5D8',
    mutedText: '#A89F90',
    accent: '#56D4DC',
    secondaryAccent: '#56D4DC',
    focus: '#56D4DC',
  },
} as const satisfies MeridianTheme;
