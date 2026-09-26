// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';
import { act, render, screen } from '@testing-library/react';
import { gameDataAtom, store } from '../events/store';

import { CrewManifest } from './CrewManifest';

// get_manifest() files crew whose job has no department under
// DEPARTMENT_UNASSIGNED ("No Department"), a key ui_data never puts in
// positions, so the section has to render without one.
store.set(gameDataAtom, {
  manifest: {
    Engineering: [
      { name: 'Urist McEngi', rank: 'Station Engineer', trim: 'Station Engineer' },
    ],
    'No Department': [
      { name: 'Urist McHobo', rank: 'Assistant', trim: 'Assistant' },
    ],
  },
  positions: {
    Engineering: { color: '#f1a839', exceptions: [], open: 2 },
  },
});

describe('CrewManifest tests', () => {
  it('renders crew filed under no department', () => {
    act(() => render(<CrewManifest />));

    expect(screen.getByText('Urist McEngi')).toBeDefined();
    expect(screen.getByText('Urist McHobo')).toBeDefined();
  });
});
