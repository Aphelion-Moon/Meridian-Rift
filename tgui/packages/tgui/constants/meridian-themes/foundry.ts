// THIS IS AN APHELION UI FILE
import type { MeridianTheme } from './types';

export const foundry = {
  id: 'meridian_foundry',
  name: 'Foundry',
  construction: '',
  palette: {
    canvas: '#17100B',
    panel: '#21170F',
    raised: '#3C2B1D',
    recessed: '#130E09',
    boundary: '#A58252',
    text: '#F1DFBC',
    mutedText: '#C6AD88',
    accent: '#E7AD52',
    secondaryAccent: '#F0C074',
    focus: '#FFDA94',
  },
} as const satisfies MeridianTheme;
