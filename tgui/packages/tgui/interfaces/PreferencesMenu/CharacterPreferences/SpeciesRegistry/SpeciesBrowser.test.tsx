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
  ashwalker: testSpecies({
    name: 'Ash Walker',
    icon: 'ash_walker',
    family: 'reptilian',
    variant_of: 'lizard',
    off_station: true,
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
    family: 'holiday',
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
    fireEvent.click(screen.getByText('Show holiday species'));
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

  it('keeps the same lines above the description for every species', () => {
    const { view, tile } = renderBrowser();
    const find = (selector: string) =>
      view.container.querySelectorAll<HTMLElement>(selector);

    fireEvent.click(tile('lizard') as Element);
    expect(find('.SpeciesHeading__variant')[0].textContent).toBe('');
    expect(find('.SpeciesDecision__status')).toHaveLength(1);
    expect(
      find('.SpeciesHeading__name')[0].style.getPropertyValue('--name-length'),
    ).toBe('12');

    // A variant names its parent on the line kept for it, and a restriction
    // takes the hint's place rather than adding a box.
    fireEvent.click(tile('ashwalker') as Element);
    expect(find('.SpeciesHeading__variant')[0].textContent).toContain(
      'Lizardperson',
    );
    expect(find('.SpeciesDecision__status')).toHaveLength(1);
    expect(screen.getByText(/Off-station roles only/)).toBeTruthy();
    expect(find('.SpeciesDecision .NoticeBox')).toHaveLength(0);
  });

  it('puts the family tabs right above the roster they sort', () => {
    const { view } = renderBrowser();
    const tabs = view.container.querySelector('.SpeciesToolbar') as Element;
    const roster = view.container.querySelector('.SpeciesRoster');
    expect(tabs.parentElement?.nextElementSibling?.contains(roster)).toBe(true);
    expect(
      tabs.parentElement?.previousElementSibling?.querySelector(
        '.SpeciesStage',
      ),
    ).not.toBeNull();
  });

  it('shows a loader over the character while a newer drawing is on its way', () => {
    const selfPreview = {
      id: 1,
      species: 'human',
      image: 'data:image/png;base64,32x32',
      width: 32,
      height: 32,
      x: 0,
      y: 0,
      frames: { north: 0, south: 32, east: 64, west: 96 },
    };
    const loader = (view: ReturnType<typeof render>) =>
      view.container.querySelector(
        '.SpecimenViewer__drawing .DiagnosticLoader',
      );

    const settled = renderBrowser({ selfPreview });
    expect(loader(settled.view)).toBeNull();
    settled.view.unmount();

    const { view, tile } = renderBrowser({ selfPreview, selfPending: true });
    expect(loader(view)).not.toBeNull();
    // The loader alone says it: no words on screen, only for screen readers.
    expect(loader(view)?.querySelector('.DiagnosticLoader__label')).toBeNull();
    expect(screen.getByRole('progressbar', { name: /^Drawing / })).toBeTruthy();
    // The character keeps showing under it until the new drawing arrives.
    expect(
      view.container.querySelector('.SpeciesSprite__frame'),
    ).not.toBeNull();
    // Other species aren't being drawn.
    fireEvent.click(tile('lizard') as Element);
    expect(loader(view)).toBeNull();
  });

  it('shows the character itself for its own species, and sprites for others', () => {
    const { view, tile } = renderBrowser({
      selfPreview: {
        id: 1,
        species: 'human',
        image: 'data:image/png;base64,32x32',
        width: 32,
        height: 32,
        x: 0,
        y: 0,
        frames: { north: 0, south: 32, east: 64, west: 96 },
      },
    });
    const figure = () =>
      view.container.querySelector('.SpecimenViewer__figure') as Element;
    const bodyButton = () =>
      view.container.querySelector('.SpecimenViewer__controls .fa-child');

    const frame = figure().querySelector(
      '.SpeciesSprite__frame',
    ) as HTMLCanvasElement;
    // The character, drawn from the preview onto its own canvas.
    expect(frame.tagName).toBe('CANVAS');
    expect([frame.width, frame.height]).toEqual([32, 32]);
    expect(screen.getByRole('img', { name: /your character/ })).toBeTruthy();
    // The character is shown as its preview shows it, so there is no body toggle.
    expect(bodyButton()).toBeNull();

    fireEvent.click(tile('lizard') as Element);
    expect(figure().querySelector('.SpeciesSprite__frame')).toBeNull();
    expect(figure().querySelector('.lizardperson-south')).not.toBeNull();
    expect(bodyButton()).not.toBeNull();
  });
});
