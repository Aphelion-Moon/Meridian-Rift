// THIS IS AN APHELION UI FILE
import type { MeridianTheme } from './types';

export const foundry = {
  id: 'meridian_foundry',
  name: 'Foundry',
  construction: '',
  lobby: {
    // The forge plaque (tgui-lobby styles/meridianos/_foundry.scss).
    layout: 'custom',
  },
  palette: {
    canvas: '#170F09',
    panel: '#24180F',
    raised: '#2A1C12',
    recessed: '#120B07',
    boundary: '#A58252',
    text: '#F1DFBC',
    mutedText: '#D9C29A',
    accent: '#FFA244',
    secondaryAccent: '#FFB35C',
    focus: '#FFDA94',
  },
} as const satisfies MeridianTheme;
