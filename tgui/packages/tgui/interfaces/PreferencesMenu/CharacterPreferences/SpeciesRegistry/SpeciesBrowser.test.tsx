// THIS IS AN APHELION UI FILE
import { describe, expect, it, mock } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';

import { SpeciesBrowser } from './SpeciesBrowser';
import type { SpeciesMap } from './taxonomy';
import { testFamilies, testSpecies } from './testSpecies';

const species: SpeciesMap = {
  human: testSpecies({ name: 'Human', icon: 'human', family: 'mammalian' }),
  lizard: testSpecies({
    name: 'Lizardperson',
    icon: 'lizardperson',
    family: 'reptilian',
  }),
  golem: testSpecies({
    name: 'Golem',
    icon: 'golem',
    family: 'elemental',
    nova_stars_only: true,
  }),
  skeleton: testSpecies({
    name: 'Skeleton',
    icon: 'skeleton',
    family: 'paranormal',
    holiday: 'Halloween',
  }),
};

function renderBrowser(
  overrides: Partial<Parameters<typeof SpeciesBrowser>[0]> = {},
) {
  const onChoose = mock((_id: string) => undefined);
  const view = render(
    <SpeciesBrowser
      species={species}
      families={testFamilies}
      currentSpecies="human"
      novaStarLocked={false}
      onBack={() => undefined}
      onChoose={onChoose}
      onLoadBodySprites={() => undefined}
      {...overrides}
    />,
  );
  const tile = (id: string) =>
    view.container.querySelector(`[data-species="${id}"] .Button`);
  return { view, onChoose, tile };
}

describe('SpeciesBrowser', () => {
  it('hides holiday species until asked, except the current one', () => {
    const { tile } = renderBrowser();
    expect(tile('skeleton')).toBeNull();
    fireEvent.click(screen.getByText('Holiday'));
    expect(tile('skeleton')).not.toBeNull();

    const current = renderBrowser({ currentSpecies: 'skeleton' });
    expect(current.tile('skeleton')).not.toBeNull();
  });

  it('lists holiday species while their holiday is on', () => {
    const { tile } = renderBrowser({
      species: {
        ...species,
        skeleton: { ...species.skeleton, holiday_active: true },
      },
    });
    expect(tile('skeleton')).not.toBeNull();
    fireEvent.click(tile('skeleton') as Element);
    expect(screen.getByText(/so you can join as one this round/)).toBeTruthy();
  });

  it('browses without choosing, and chooses from the button', () => {
    const { onChoose, tile } = renderBrowser();
    fireEvent.click(tile('lizard') as Element);
    expect(onChoose).not.toHaveBeenCalled();
    expect(screen.getAllByText('Lizardperson').length).toBeGreaterThan(0);

    fireEvent.click(screen.getByText('Select species'));
    expect(onChoose).toHaveBeenCalledWith('lizard');
  });

  it('will not choose a Nova Star species for a locked player', () => {
    const { onChoose, tile } = renderBrowser({ novaStarLocked: true });
    fireEvent.click(tile('golem') as Element);
    expect(screen.getByText('Nova Star only')).toBeTruthy();
    fireEvent.doubleClick(tile('golem') as Element);
    expect(onChoose).not.toHaveBeenCalled();
  });
});
