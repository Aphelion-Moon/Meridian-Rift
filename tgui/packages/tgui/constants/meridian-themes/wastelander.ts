// THIS IS AN APHELION UI FILE
import type { MeridianTheme } from './types';

export const wastelander = {
  id: 'meridian_pipboy',
  name: 'Wastelander',
  construction: '',
  production: true,
  palette: {
    canvas: '#0C100B',
    panel: '#11160F',
    raised: '#22291B',
    recessed: '#090D08',
    boundary: '#657653',
    text: '#ADB997',
    mutedText: '#919F7E',
    accent: '#90A863',
    secondaryAccent: '#A4BA78',
    focus: '#D3BE7E',
  },
} as const satisfies MeridianTheme;
