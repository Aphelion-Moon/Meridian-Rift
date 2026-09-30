// THIS IS AN APHELION UI FILE
import type { KeyboardEvent } from 'react';
import { Button } from 'tgui-core/components';

import { SearchBar } from '../../../common/SearchBar';
import type { SpeciesBrowserModel } from './model';

/** Scrolls only the nearest section, never the window around it. */
function revealInSection(tile: HTMLElement) {
  const scroller = tile.closest<HTMLElement>('.Section__content');
  if (!scroller) {
    return;
  }
  const view = scroller.getBoundingClientRect();
  const rect = tile.getBoundingClientRect();
  if (rect.top < view.top) {
    scroller.scrollTop -= view.top - rect.top + 4;
  } else if (rect.bottom > view.bottom) {
    scroller.scrollTop += rect.bottom - view.bottom + 4;
  }
}

/** Left and right step through the listed species in reading order. */
export function stepFocus(
  event: KeyboardEvent<HTMLElement>,
  inspect: (id: string) => void,
) {
  if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') {
    return;
  }
  const tiles = Array.from(
    event.currentTarget.querySelectorAll<HTMLElement>('[data-species]'),
  );
  const from = tiles.findIndex((tile) => tile.contains(event.target as Node));
  const to = tiles[from + (event.key === 'ArrowRight' ? 1 : -1)];
  if (from < 0 || !to) {
    return;
  }
  event.preventDefault();
  to.querySelector<HTMLElement>('.Button')?.focus({ preventScroll: true });
  revealInSection(to);
  inspect(to.dataset.species as string);
}

/** What to say when nothing matches, including where hidden species went. */
export function noMatchText(model: SpeciesBrowserModel) {
  const base = `No species match “${model.query.trim()}”.`;
  return model.showHoliday || !model.holidayCount
    ? base
    : `${base} Holiday species are hidden; tick Show holiday species to search them too.`;
}

/** The search box and holiday toggle that sit with the roster. */
export function SpeciesSearch(props: { model: SpeciesBrowserModel }) {
  const { model } = props;
  return (
    <span className="SpeciesSearch">
      <span className="SpeciesSearch__field">
        <SearchBar
          query={model.query}
          onSearch={model.setQuery}
          placeholder="Species, trait, food..."
        />
      </span>
      {model.holidayCount > 0 && (
        <Button.Checkbox
          className="SpeciesSearch__holiday"
          checked={model.showHoliday}
          tooltip={`${model.holidayCount} holiday species. You can create them any time, and join as one during its holiday.`}
          tooltipPosition="bottom"
          onClick={() => model.setShowHoliday(!model.showHoliday)}
        >
          Show holiday species
        </Button.Checkbox>
      )}
    </span>
  );
}
