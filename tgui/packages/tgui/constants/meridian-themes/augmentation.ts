// THIS IS AN APHELION UI FILE
import type { MeridianTheme } from './types';

export const augmentation = {
  id: 'meridian_augmentation',
  name: 'Augmentation',
  construction: '',
  palette: {
    canvas: '#070203',
    panel: '#0F0505',
    raised: '#19080B',
    recessed: '#050102',
    boundary: '#C0152A',
    text: '#EAF7F6',
    mutedText: '#A9C7C4',
    accent: '#00E5D4',
    secondaryAccent: '#F04459',
    focus: '#70FFF5',
  },
} as const satisfies MeridianTheme;
