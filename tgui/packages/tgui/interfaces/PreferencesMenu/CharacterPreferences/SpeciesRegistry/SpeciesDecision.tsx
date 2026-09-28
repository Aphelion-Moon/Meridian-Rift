// THIS IS AN APHELION UI FILE
import { Button, NoticeBox } from 'tgui-core/components';

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

/** The tally, the one action on the page, and anything that restricts it. */
export function SpeciesDecision(props: Props) {
  const { model, id } = props;
  const entry = model.species[id];
  const isCurrent = id === model.current;

  return (
    <div className="SpeciesDecision">
      <SpeciesTally perks={entry.perks} />
      <div className="SpeciesDecision__actions">
        <ChooseButton {...props} />
        <div className="SpeciesDecision__hint">
          {isCurrent
            ? 'Your character is this species.'
            : 'Browsing does not change your character.'}
        </div>
      </div>
      {!!entry.holiday && (
        <NoticeBox info className="SpeciesDecision__notice">
          {entry.holiday_active
            ? `Holiday species. It's ${entry.holiday}, so you can join as one this round.`
            : `Holiday species. You can create one any time, but you can only join as one during ${entry.holiday}.`}
        </NoticeBox>
      )}
      {!!entry.off_station && (
        <NoticeBox info className="SpeciesDecision__notice">
          Off-station roles only. You can't join the station crew as this
          species.
        </NoticeBox>
      )}
      {model.isLocked(id) && (
        <NoticeBox className="SpeciesDecision__notice">
          Only Nova Star players can play this species.
        </NoticeBox>
      )}
    </div>
  );
}
