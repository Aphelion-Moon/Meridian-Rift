// THIS IS AN APHELION UI FILE
import { afterEach, describe, expect, it, mock } from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  within,
} from '@testing-library/react';

import { MarkingSheetPicker } from './MarkingSheetPicker';
import type { MarkingSheetsData, RegionMarking } from './types';

afterEach(async () => {
  await act(async () => {});
  cleanup();
});

// A vulpkanin's left arm wearing Tiger, which shares its stripes with Zebra.
const sheets: MarkingSheetsData = {
  key: 'vulpkanin #ff8a1c #f3e7d3 #3b2b27',
  info: {
    'Fox Socks': {
      color_mode: 'follows_primary',
      exclusion_group: null,
      recommended_species: 'vulpkanin',
    },
    Pilot: {
      color_mode: 'fixed_default',
      exclusion_group: null,
      recommended_species: null,
    },
    Tiger: {
      color_mode: 'follows_secondary',
      exclusion_group: 'stripes',
      recommended_species: 'tajaran',
    },
    Zebra: {
      color_mode: 'follows_secondary',
      exclusion_group: 'stripes',
      recommended_species: 'tajaran',
    },
  },
  defaults: { Pilot: '#123456' },
  fur: ['#ff8a1c', '#f3e7d3', '#3b2b27'],
  species: 'vulpkanin',
  speciesName: 'Vulpkanin',
  speciesIcon: 'vulpkanin',
};
const rows: RegionMarking[] = [{ index: 1, name: 'Tiger', color: '#f3e7d3' }];
const choices = ['Fox Socks', 'Pilot', 'Tiger', 'Zebra'];
const icons = Object.fromEntries(
  choices.map((name, n) => [name, `body_marking___l_arm___${n}`]),
);

/** Opens the left arm's sheet from its trigger: to swap out the row at `replace`, or to add one. */
async function open(
  replace: number | null,
  data: MarkingSheetsData | null = sheets,
) {
  const send = mock();
  render(
    <MarkingSheetPicker
      zone="l_arm"
      rows={rows}
      replace={replace}
      choices={choices}
      icons={icons}
      max={3}
      sheets={data ?? undefined}
      sheetsKey={sheets.key}
      act={send}
    >
      <button type="button">open</button>
    </MarkingSheetPicker>,
  );
  await act(async () => {
    fireEvent.click(screen.getByText('open'));
  });
  return send;
}

const sheet = () => screen.getByRole('dialog', { name: 'Left arm markings' });

describe('MarkingSheetPicker', () => {
  it("opens the markings room's sheet, the species' own first", async () => {
    await open(0);
    const dialog = sheet();
    expect(within(dialog).getByText('Suits Vulpkanin · 2')).toBeTruthy();
    expect(within(dialog).getByText('Other species · 2')).toBeTruthy();
    expect(within(dialog).getByText('Swap out Tiger')).toBeTruthy();
    // Swapping Tiger out, its stripes keep nothing off.
    expect(within(dialog).getByRole('button', { name: 'Zebra' })).toBeTruthy();
    expect(within(dialog).getByRole('button', { name: 'Tiger' })).toBeTruthy();
  });

  it('keeps off what the backend refuses beside what the region wears', async () => {
    await open(null);
    // Tiger is on, and Zebra shares its stripes.
    for (const name of ['Tiger', 'Zebra']) {
      expect(
        within(sheet()).getByRole('button', { name: `${name}, already on` }),
      ).toBeTruthy();
    }
    expect(within(sheet()).getByRole('button', { name: 'Pilot' })).toBeTruthy();
  });

  it('swaps the row out, takes it off, or adds one', async () => {
    let send = await open(0);
    fireEvent.click(within(sheet()).getByRole('button', { name: 'Pilot' }));
    expect(send).toHaveBeenCalledWith('setBaseMarking', {
      zone: 'l_arm',
      index: 1,
      name: 'Pilot',
    });
    cleanup();

    send = await open(0);
    fireEvent.click(
      within(sheet()).getByRole('button', { name: 'None, take off Tiger' }),
    );
    expect(send).toHaveBeenCalledWith('removeBaseMarking', {
      zone: 'l_arm',
      index: 1,
    });
    cleanup();

    send = await open(null);
    expect(
      within(sheet()).getByText('Add a marking · slot 2 of 3'),
    ).toBeTruthy();
    fireEvent.click(within(sheet()).getByRole('button', { name: 'Fox Socks' }));
    expect(send).toHaveBeenCalledWith('addBaseMarking', {
      zone: 'l_arm',
      name: 'Fox Socks',
    });
  });

  it('asks for what it draws from once, and waits for it', async () => {
    const send = await open(0, null);
    expect(within(sheet()).getByText('Fetching the markings…')).toBeTruthy();
    expect(send).toHaveBeenCalledTimes(1);
    expect(send).toHaveBeenCalledWith('markingSheets', { have: undefined });
  });

  it('asks nothing when it holds the body as it is', async () => {
    const send = await open(0);
    expect(send).not.toHaveBeenCalled();
  });
});
