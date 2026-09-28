// THIS IS AN APHELION UI FILE
import { Button, Icon, NoticeBox, Section } from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import { rosterHeading, type SpeciesBrowserModel, shownGroups } from './model';
import { noMatchText, SpeciesSearch, stepFocus } from './SpeciesSearch';
import { SpeciesSprite } from './SpeciesSprite';

type Props = {
  model: SpeciesBrowserModel;
};

function RosterTile(props: { model: SpeciesBrowserModel; id: string }) {
  const { model, id } = props;
  const entry = model.species[id];
  const locked = model.isLocked(id);

  return (
    <span
      className={classes([
        'SpeciesRoster__tile',
        id === model.current && 'SpeciesRoster__tile--current',
        locked && 'SpeciesRoster__tile--locked',
      ])}
      data-species={id}
    >
      <Button
        selected={id === model.inspected}
        tooltip={entry.name}
        tooltipPosition="top"
        onClick={() => model.inspect(id)}
        onDoubleClick={() => !locked && model.choose(id)}
      >
        <SpeciesSprite icon={entry.icon} scale={2} />
        <span className="SpeciesRoster__name">{entry.name}</span>
      </Button>
    </span>
  );
}

/** Small tiles in bracketed lineages, like a character-select roster. */
export function SpeciesRoster(props: Props) {
  const { model } = props;
  const { heading, count } = rosterHeading(model);

  let content;
  if (model.matches && !model.matches.length) {
    content = <NoticeBox info>{noMatchText(model)}</NoticeBox>;
  } else if (model.matches) {
    content = (
      <div className="SpeciesRoster__tiles">
        {model.matches.map((id) => (
          <RosterTile key={id} model={model} id={id} />
        ))}
      </div>
    );
  } else {
    content = shownGroups(model).map(({ family, lineages }) => (
      <section key={family.id} className="SpeciesRoster__family">
        <h3 className="SpeciesRoster__familyTitle" title={family.name}>
          <Icon name={family.icon} />
          <span>{family.name}</span>
        </h3>
        <div className="SpeciesRoster__tiles">
          {lineages.map(({ root, members }) =>
            members.length > 1 ? (
              <span key={root} className="SpeciesRoster__lineage">
                <span className="SpeciesRoster__lineageLabel">
                  {model.species[root].name} and variants
                </span>
                <span className="SpeciesRoster__lineageTiles">
                  {members.map(({ id }) => (
                    <RosterTile key={id} model={model} id={id} />
                  ))}
                </span>
              </span>
            ) : (
              <RosterTile key={root} model={model} id={root} />
            ),
          )}
        </div>
      </section>
    ));
  }

  return (
    <Section
      className="SpeciesRoster"
      fill
      scrollable
      title={
        <span className="SpeciesRoster__heading">
          {heading}
          <span className="SpeciesRoster__count ConsoleReading">{count}</span>
        </span>
      }
      buttons={<SpeciesSearch model={model} />}
    >
      <div
        className="SpeciesRoster__body"
        onKeyDown={(event) => stepFocus(event, model.inspect)}
      >
        {content}
      </div>
    </Section>
  );
}
