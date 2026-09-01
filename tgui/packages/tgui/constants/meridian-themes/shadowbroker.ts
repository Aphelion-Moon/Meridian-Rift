// THIS IS AN APHELION UI FILE
import type { MeridianTheme } from './types';

export const shadowbroker = {
  id: 'meridian_relay',
  name: 'Shadowbroker',
  construction: '',
  production: true,
  palette: {
    canvas: '#101314',
    panel: '#1B2021',
    raised: '#293032',
    recessed: '#080A0B',
    boundary: '#747E7A',
    text: '#F3EEDC',
    mutedText: '#BCB7A8',
    accent: '#F4A62A',
    secondaryAccent: '#6FC5D2',
    focus: '#FFF2A3',
  },
} as const satisfies MeridianTheme;
