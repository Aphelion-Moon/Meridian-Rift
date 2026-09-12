// THIS IS AN APHELION UI FILE
import type { MeridianTheme } from './types';

export const vector = {
  id: 'meridian_vector',
  name: 'Vector',
  construction: '',
  palette: {
    canvas: '#070D16',
    panel: '#0B1626',
    raised: '#162D49',
    recessed: '#08111D',
    boundary: '#426B96',
    text: '#E7F1FF',
    mutedText: '#9CB3CF',
    accent: '#54A9FF',
    secondaryAccent: '#7FC0FF',
    focus: '#B8F5FF',
  },
} as const satisfies MeridianTheme;
