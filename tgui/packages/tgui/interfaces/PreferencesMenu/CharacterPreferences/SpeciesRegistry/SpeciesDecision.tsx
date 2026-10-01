// THIS IS AN APHELION UI FILE
import { Button, Icon } from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import type { Species } from '../../types';
import type { SpeciesBrowserModel } from './model';
import { SpeciesTally } from './SpeciesTally';

type Props = {
  model: SpeciesBrowserModel;
  id: string;
};

function ChooseButton(props: Props) {
  const { model, id } = props;
  if (id === model.current) {
    return (
      <Button fluid icon="check" selected>
        Current species
      </Button>
    );
  }
  if (model.isLocked(id)) {
    return (
      <Button
        fluid
        icon="lock"
        disabled
        tooltip="Only Nova Star players can play this species."
      >
        Nova Star only
      </Button>
    );
  }
  return (
    <Button fluid icon="dna" onClick={() => model.choose(id)}>
      Select species
    </Button>
  );
}

type Status = {
  kind: 'hint' | 'info' | 'bad';
  icon: string;
  text: string;
};

/** What keeps a species from the station, if anything, or else a hint. */
function getStatuses(entry: Species, current: boolean, locked: boolean) {
  const statuses: Status[] = [];
  if (locked) {
    statuses.push({
      kind: 'bad',
      icon: 'lock',
      text: 'Only Nova Star players can play this species.',
    });
  }
  if (entry.holiday) {
    statuses.push({
      kind: 'info',
      icon: 'gift',
      text: entry.holiday_active
        ? `Holiday species. It's ${entry.holiday}, so you can join as one this round.`
        : `Holiday species. Create one any time; join as one during ${entry.holiday}.`,
    });
  }
  if (entry.off_station) {
    statuses.push({
      kind: 'info',
      icon: 'shuttle-space',
      text: "Off-station roles only. You can't join the station crew as this species.",
    });
  }
  if (!statuses.length) {
    statuses.push({
      kind: 'hint',
      icon: current ? 'check' : 'eye',
      text: current
        ? 'Your character is this species.'
        : 'Browsing does not change your character.',
    });
  }
  return statuses;
}

/**
 * The tally, the one action on the page, and anything that restricts it. The
 * restrictions take the hint's place, which keeps room for them, so a
 * restricted species doesn't push the description down.
 */
export function SpeciesDecision(props: Props) {
  const { model, id } = props;
  const entry = model.species[id];
  const statuses = getStatuses(entry, id === model.current, model.isLocked(id));

  return (
    <div className="SpeciesDecision">
      <SpeciesTally perks={entry.perks} />
      <ChooseButton {...props} />
      <div className="SpeciesDecision__statuses">
        {statuses.map(({ kind, icon, text }) => (
          <div
            key={text}
            className={classes([
              'SpeciesDecision__status',
              `SpeciesDecision__status--${kind}`,
            ])}
          >
            <Icon name={icon} />
            <span>{text}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
